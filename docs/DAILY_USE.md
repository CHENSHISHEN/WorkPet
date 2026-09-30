# 日常使用

以下命令默认已在仓库根目录设置 `REPO_ROOT`，例如：`export REPO_ROOT="$(pwd)"`。

## 启动 WorkPet

```bash
cd "$REPO_ROOT"
./build-app.sh
open build/WorkPet.app
```

开发调试时也可以直接运行：

```bash
cd "$REPO_ROOT/WorkPet"
swift run WorkPet
```

## 设置登录启动

安装登录启动：

```bash
"$REPO_ROOT/scripts/install-login-item.sh"
```

取消登录启动：

```bash
"$REPO_ROOT/scripts/install-login-item.sh" uninstall
```

## 必要 macOS 权限

日历权限：

- 打开 `系统设置 > 隐私与安全性 > 日历`
- 允许 WorkPet 访问日历

提醒事项权限：

- 打开 `系统设置 > 隐私与安全性 > 提醒事项`
- 允许 WorkPet 访问提醒事项

微信 / 飞书 / DataGrip 系统通知捕获：

- 打开 `系统设置 > 隐私与安全性 > 完全磁盘访问权限`
- 允许 WorkPet

> 说明：系统通知适配器会读取本机 macOS 通知数据库。这不是苹果公开稳定 API，系统升级后可能需要重新验证。

## DataGrip 通知快速测试

```bash
"$REPO_ROOT/scripts/datagrip-notify.sh" "DataGrip 任务完成" "任务已执行完毕"
```

如果 WorkPet 正在运行，宠物应弹出 DataGrip 通知。

DataGrip 外部工具配置见 [DataGrip 文件钩子接入](DATAGRIP_INTEGRATION.md)。
