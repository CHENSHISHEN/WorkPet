# DataGrip 文件钩子接入

以下命令默认已在仓库根目录设置 `REPO_ROOT`，例如：`export REPO_ROOT="$(pwd)"`。

WorkPet 会监听以下目录：

```text
~/Library/Application Support/WorkPet/datagrip-tasks/
```

当目录中出现 `.txt` 或 `.done` 文件时，WorkPet 会读取文件内容，将其作为 DataGrip 任务通知展示，然后删除该文件。

## 快速测试

```bash
"$REPO_ROOT/scripts/datagrip-notify.sh" "SQL 执行完成" "报表刷新任务已结束"
```

预期效果：宠物弹出 DataGrip 通知气泡。

## 文件格式

```text
第一行作为标题
第二行及后续内容作为正文
```

示例：

```text
SQL 执行失败
line 42: Table not found: dws_hub.xxx
```

## DataGrip External Tool 配置

在 DataGrip 中：

1. 打开 `Settings > Tools > External Tools`
2. 新增工具，名称可设为 `Notify WorkPet`
3. `Program` 填：

```text
$REPO_ROOT/scripts/datagrip-notify.sh
```

4. `Arguments` 填：

```text
"DataGrip 任务完成" "$FileName$"
```

## 与自动监听插件的区别

文件钩子稳定、简单，但不会自动感知你在 SQL Console 里点击执行。它适合脚本、External Tool 或任务包装器主动通知 WorkPet。

如果你要“在 DataGrip 中正常点击执行 SQL，执行完最后一段或中途报错时自动通知”，请使用 [DataGrip 自动监听插件](DATAGRIP_AUTO_MONITOR.md)。
