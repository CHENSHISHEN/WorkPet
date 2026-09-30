package dev.workpet.datagrip;

import com.intellij.database.console.session.DatabaseSession;
import com.intellij.database.console.session.DatabaseSessionStateListener;
import com.intellij.database.dataSource.DatabaseConnectionPoint;
import com.intellij.database.dataSource.LocalDataSource;
import com.intellij.database.datagrid.DataRequest;
import com.intellij.openapi.vfs.VirtualFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public final class WorkPetDatabaseSessionListener implements DatabaseSessionStateListener {
    private static final DateTimeFormatter FILE_TIME = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss-SSS");
    private static final long MIN_DURATION_MS = 120;

    private final Map<DatabaseSession, BatchTracker> batchesBySession = new ConcurrentHashMap<>();

    @Override
    public void clientAttached(com.intellij.database.console.client.VisibleDatabaseSessionClient client) {
    }

    @Override
    public void clientDetached(com.intellij.database.console.client.VisibleDatabaseSessionClient client) {
    }

    @Override
    public void clientReattached(
            com.intellij.database.console.client.VisibleDatabaseSessionClient client,
            DatabaseSession oldSession,
            DatabaseSession newSession
    ) {
    }

    @Override
    public void renamed(DatabaseSession session) {
    }

    @Override
    public void connected(DatabaseSession session) {
    }

    @Override
    public void disconnected(DatabaseSession session) {
    }

    @Override
    public void stateChanged(ChangeEvent event) {
        DatabaseSession session = event.getSession();
        ChangeEvent.EventType type = event.getType();

        if (type == ChangeEvent.EventType.STARTED) {
            BatchTracker tracker = batchesBySession.computeIfAbsent(session, ignored -> new BatchTracker(session));
            tracker.markStarted();
            return;
        }

        BatchTracker tracker = batchesBySession.get(session);
        if (tracker != null) {
            tracker.updateFrom(session);

            if (tracker.hasError()) {
                batchesBySession.remove(session);
                writeWorkPetNotification(session, tracker, true);
                return;
            }
        }

        if (type == ChangeEvent.EventType.STOPPED || isFinalizedIdle(session)) {
            tracker = batchesBySession.remove(session);
            if (tracker == null) {
                return;
            }

            long durationMs = tracker.durationMs();
            if (durationMs < MIN_DURATION_MS) {
                return;
            }

            writeWorkPetNotification(session, tracker, false);
        }
    }

    private boolean isFinalizedIdle(DatabaseSession session) {
        try {
            DatabaseSession.State state = session.getState();
            return state != null && state.isFinalized() && state.isIdle();
        } catch (Throwable ignored) {
            return false;
        }
    }

    private void writeWorkPetNotification(DatabaseSession session, BatchTracker tracker, boolean stoppedOnError) {
        Path directory = Path.of(
                System.getProperty("user.home"),
                "Library",
                "Application Support",
                "WorkPet",
                "datagrip-tasks"
        );

        ExecutionSummary summary = tracker.summary;
        if (summary.durationMs <= 0) {
            summary.durationMs = tracker.durationMs();
        }
        summary.stoppedOnError = stoppedOnError;

        String title = summary.hasError ? "DataGrip SQL 执行失败" : "DataGrip SQL 执行完成";
        String body = buildNotificationBody(tracker.identity, summary);

        String fileName = "datagrip-auto-" + FILE_TIME.format(LocalDateTime.now()) + ".done";
        Path output = directory.resolve(fileName);

        try {
            Files.createDirectories(directory);
            Files.writeString(output, title + "\n" + body + "\n", StandardCharsets.UTF_8);
        } catch (IOException ignored) {
            // WorkPet is optional; never disturb DataGrip query execution.
        }
    }

    private ExecutionSummary summarize(DatabaseSession session, long fallbackDurationMs, ExecutionSummary previous) {
        ExecutionSummary summary = new ExecutionSummary();
        summary.durationMs = fallbackDurationMs;

        try {
            DatabaseSession.State state = session.getState();
            if (state == null) {
                return summary;
            }

            long stateDuration = state.getTimeSpentMs();
            if (stateDuration > 0) {
                summary.durationMs = stateDuration;
            }
            summary.cancelled = state.isCancelled();

            List<DatabaseSession.State.Work> works = state.getWork();
            if (works == null || works.isEmpty()) {
                if (previous != null) {
                    return previous;
                }
                return summary;
            }

            summary.workCount = works.size();

            for (DatabaseSession.State.Work work : works) {
                appendWorkSummary(summary, work);
            }
        } catch (Throwable t) {
            summary.details.add("结果摘要读取失败: " + shortText(t.getMessage(), 180));
        }

        return summary;
    }

    private void appendWorkSummary(ExecutionSummary summary, DatabaseSession.State.Work work) {
        try {
            DatabaseSession.State.WorkStatus status = work.getStatus();
            String statusType = status == null || status.getType() == null ? "UNKNOWN" : status.getType().name();
            String description = status == null ? "" : safe(status.getDescription());
            long workDuration = work.getTimeSpentMs();

            if ("ERROR".equals(statusType)) {
                summary.hasError = true;
            } else if ("WARNING".equals(statusType)) {
                summary.hasWarning = true;
            } else if ("CANCELLED".equals(statusType)) {
                summary.cancelled = true;
            } else if ("SUCCESS".equals(statusType)) {
                summary.successCount += 1;
            }

            String requestText = requestText(work);
            StringBuilder line = new StringBuilder();
            line.append(statusLabel(statusType));
            if (!description.isBlank()) {
                line.append(" ").append(description);
            }
            if (!requestText.isBlank()) {
                line.append(" | ").append(requestText);
            }
            if (workDuration > 0) {
                line.append(" | ").append(formatDuration(workDuration));
            }

            String text = shortText(line.toString(), 260);
            if (!text.isBlank()) {
                summary.details.add(text);
            }
        } catch (Throwable t) {
            summary.details.add("单条结果读取失败: " + shortText(t.getMessage(), 160));
        }
    }

    private String requestText(DatabaseSession.State.Work work) {
        try {
            DataRequest request = work.getRequest();
            if (request == null) {
                return "";
            }

            String text = safe(request.toString());
            if (text.contains("@")) {
                return "";
            }
            return text.replaceAll("\\s+", " ");
        } catch (Throwable ignored) {
            return "";
        }
    }

    private String buildNotificationBody(TaskIdentity identity, ExecutionSummary summary) {
        List<String> lines = new ArrayList<>();

        if (!identity.displayName().isBlank()) {
            lines.add(identity.displayName());
        }

        String status;
        if (summary.hasError) {
            status = summary.stoppedOnError ? "报错已停止" : "失败";
        } else if (summary.cancelled) {
            status = "已取消";
        } else if (summary.hasWarning) {
            status = "完成但有警告";
        } else {
            status = "成功";
        }

        String overview = status
                + " | 执行 " + Math.max(summary.workCount, summary.successCount) + " 条"
                + " | 用时 " + formatDuration(summary.durationMs);
        lines.add(overview);

        int limit = summary.hasError || summary.hasWarning ? 5 : 3;
        for (String detail : summary.details) {
            if (lines.size() >= limit + 2) {
                break;
            }
            if (!detail.isBlank()) {
                lines.add(detail);
            }
        }

        return String.join("\n", lines);
    }

    private TaskIdentity identify(DatabaseSession session) {
        TaskIdentity identity = new TaskIdentity();

        identity.sessionTitle = safeSessionTitle(session);
        identity.dataSource = safeDataSourceName(session);
        identity.dbms = safeDbmsName(session);
        identity.fileName = safeClientFileName(session);
        identity.sessionHash = Integer.toHexString(System.identityHashCode(session));

        return identity;
    }

    private String safeSessionTitle(DatabaseSession session) {
        try {
            String title = session.getTitle();
            return title == null ? "" : title.trim();
        } catch (Throwable ignored) {
            return "";
        }
    }

    private String safeDataSourceName(DatabaseSession session) {
        try {
            DatabaseConnectionPoint point = session.getConnectionPoint();
            if (point == null || point.getDataSource() == null) {
                return "";
            }

            LocalDataSource dataSource = point.getDataSource();
            String name = dataSource.getName();
            if (name == null || name.isBlank()) {
                name = dataSource.getSourceName();
            }
            return safe(name);
        } catch (Throwable ignored) {
            return "";
        }
    }

    private String safeDbmsName(DatabaseSession session) {
        try {
            DatabaseConnectionPoint point = session.getConnectionPoint();
            if (point == null || point.getDbms() == null) {
                return "";
            }
            return safe(point.getDbms().getDisplayName());
        } catch (Throwable ignored) {
            return "";
        }
    }

    private String safeClientFileName(DatabaseSession session) {
        try {
            com.intellij.database.console.client.DatabaseSessionClientWithFile[] clients = session.getClientsWithFile();
            if (clients == null || clients.length == 0) {
                return "";
            }

            VirtualFile file = clients[0].getVirtualFile();
            if (file != null && file.getName() != null) {
                return file.getName();
            }

            String title = clients[0].getTitle();
            return safe(title);
        } catch (Throwable ignored) {
            return "";
        }
    }

    private String formatDuration(long durationMs) {
        if (durationMs < 1000) {
            return durationMs + "ms";
        }

        long seconds = durationMs / 1000;
        long minutes = seconds / 60;
        long remainSeconds = seconds % 60;

        if (minutes == 0) {
            return seconds + "s";
        }

        return minutes + "m " + remainSeconds + "s";
    }

    private String statusLabel(String statusType) {
        return switch (statusType) {
            case "SUCCESS" -> "成功";
            case "WARNING" -> "警告";
            case "ERROR" -> "错误";
            case "CANCELLED" -> "取消";
            default -> "未知";
        };
    }

    private String safe(String text) {
        return text == null ? "" : text.trim();
    }

    private String shortText(String text, int limit) {
        String safeText = safe(text).replaceAll("\\s+", " ");
        if (safeText.length() <= limit) {
            return safeText;
        }
        return safeText.substring(0, limit) + "...";
    }

    private static final class ExecutionSummary {
        long durationMs;
        int workCount;
        int successCount;
        boolean hasError;
        boolean hasWarning;
        boolean cancelled;
        boolean stoppedOnError;
        final List<String> details = new ArrayList<>();
    }

    private final class BatchTracker {
        final TaskIdentity identity;
        long startedAtMs;
        long lastUpdatedAtMs;
        ExecutionSummary summary;

        BatchTracker(DatabaseSession session) {
            this.identity = identify(session);
            this.summary = new ExecutionSummary();
            markStarted();
        }

        void markStarted() {
            long now = System.currentTimeMillis();
            if (startedAtMs == 0) {
                startedAtMs = now;
            }
            lastUpdatedAtMs = now;
        }

        void updateFrom(DatabaseSession session) {
            lastUpdatedAtMs = System.currentTimeMillis();
            summary = summarize(session, durationMs(), summary);
        }

        long durationMs() {
            long end = lastUpdatedAtMs == 0 ? System.currentTimeMillis() : lastUpdatedAtMs;
            return Math.max(0, end - startedAtMs);
        }

        boolean hasError() {
            return summary != null && summary.hasError;
        }
    }

    private static final class TaskIdentity {
        String sessionTitle = "";
        String dataSource = "";
        String dbms = "";
        String fileName = "";
        String sessionHash = "";

        String displayName() {
            List<String> parts = new ArrayList<>();

            if (!fileName.isBlank()) {
                parts.add(fileName);
            }
            if (!dataSource.isBlank()) {
                parts.add(dataSource);
            }
            if (!dbms.isBlank()) {
                parts.add(dbms);
            }
            if (!sessionTitle.isBlank() && !sessionTitle.equals(fileName)) {
                parts.add(sessionTitle);
            }
            if (!sessionHash.isBlank()) {
                parts.add("#" + sessionHash);
            }

            return String.join(" · ", parts);
        }
    }
}
