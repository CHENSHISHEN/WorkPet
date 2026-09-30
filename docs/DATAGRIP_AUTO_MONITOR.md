# DataGrip 自动监听插件

以下命令默认已在仓库根目录设置 `REPO_ROOT`，例如：`export REPO_ROOT="$(pwd)"`。

文件钩子 `datagrip-notify.sh` 很稳定，但它不是自动监听。要做到“在 DataGrip 里正常点击执行 SQL，WorkPet 自动知道执行完成或报错”，需要 JetBrains 插件。

本仓库包含本地插件工程：

```text
datagrip-plugin/
```

## 工作原理

插件订阅 DataGrip 的数据库会话状态：

```text
com.intellij.database.console.session.DatabaseSessionStateListener
```

插件把一个 DataGrip database session 生命周期视为一个执行批次：

- `STARTED`：记录任务身份和开始时间。
- `CHANGED`：只更新内部结果摘要，不弹通知。
- 第一次 `ERROR`：立即通知失败，并停止跟踪该批次。
- `STOPPED` / finalized idle：整个批次结束，只通知一次。

这意味着：如果一个 SQL Console 里有很多段 ETL 脚本，WorkPet 不会每段都弹，而是等最后一段完成后通知；如果中途报错，则立即通知。

## 多窗口区分

多个 Hive / DataGrip SQL 窗口并行执行时，通知第一行会尽量包含：

- SQL 文件名或 Console 名
- 数据源名
- DBMS 类型，例如 Hive
- session hash，用于区分同名窗口

示例：

```text
etl_user_profile.sql · hive-prod · Hive · #7f31aa
成功 | 执行 8 条 | 用时 3m 12s
```

## 通知内容

通知正文会尽量包含：

- 成功 / 警告 / 错误 / 取消状态
- 执行 work 数
- 总耗时
- DataGrip 暴露的每条 work 状态描述

如果 DataGrip 通过 `DatabaseSession.State.WorkStatus` 暴露错误描述，WorkPet 会显示出来。若某个数据库驱动只把详细错误打印到 DataGrip 控制台或内部日志，而不暴露给该 API，则当前插件可能只能显示失败摘要。下一步可继续增加 `AuditService` hook。

## 构建插件

```bash
cd "$REPO_ROOT/datagrip-plugin"
./build-local.sh
```

输出文件：

```text
$REPO_ROOT/datagrip-plugin/build/WorkPetDataGripNotifier.zip
```

## 安装到 DataGrip

1. 打开 DataGrip。
2. 进入 `设置 / Settings > 插件 / Plugins`。
3. 点击齿轮图标。
4. 选择 `从磁盘安装插件 / Install Plugin from Disk...`。
5. 选择：

```text
$REPO_ROOT/datagrip-plugin/build/WorkPetDataGripNotifier.zip
```

6. 重启 DataGrip。
7. 启动 WorkPet。
8. 在 SQL Console 中执行 SQL。

## 当前限制

插件使用的是 DataGrip 2025.2.5 的数据库会话内部 API。它是实现自动 SQL 完成通知的正确接入层，但 JetBrains 内部 API 可能随版本变化，需要在真实工作流中验证。
