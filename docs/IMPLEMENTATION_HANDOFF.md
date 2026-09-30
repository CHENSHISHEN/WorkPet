# 实现交接说明

## 项目形态

WorkPet 是一个 Swift Package Manager macOS 可执行应用，UI 使用 AppKit。当前没有引入 Xcode 工程文件，便于通过命令行和 AI 继续维护。

```text
WorkPet/
  Package.swift
  Sources/WorkPet/
    App/        # 应用生命周期和依赖装配
    Core/       # 通知模型、Hub、宠物状态
    Rules/      # 来源分级规则
    Adapters/   # 日历、系统通知、DataGrip 等外部输入
    Overlay/    # 桌面浮窗和宠物展示
    Pets/       # 宠物资源包模型和加载器
    Resources/  # 默认配置和内置宠物资源包
  Tests/WorkPetTests/
```

DataGrip 插件位于：

```text
datagrip-plugin/
```

## 核心边界

- Adapter 负责外部输入，统一发出 `WorkNotification`。
- `NotificationHub` 负责去重和分发。
- `SourceRuleEngine` 负责按来源决定提醒级别。
- `PetOverlayController` 负责窗口层级、免打扰和提醒生命周期。
- `PetView` 负责显示消息气泡和图片资源包宠物。
- DataGrip 自动监听逻辑在 `datagrip-plugin`，不要塞进 macOS App 侧。

## 当前重点文件

- `WorkPet/Sources/WorkPet/App/WorkPetApp.swift`
- `WorkPet/Sources/WorkPet/Core/NotificationHub.swift`
- `WorkPet/Sources/WorkPet/Core/PetState.swift`
- `WorkPet/Sources/WorkPet/Adapters/CalendarAdapter.swift`
- `WorkPet/Sources/WorkPet/Adapters/SystemNotificationAdapter.swift`
- `WorkPet/Sources/WorkPet/Adapters/DataGripAdapter.swift`
- `WorkPet/Sources/WorkPet/Adapters/PermissionDiagnosticsAdapter.swift`
- `WorkPet/Sources/WorkPet/Overlay/PetOverlayController.swift`
- `WorkPet/Sources/WorkPet/Overlay/PetView.swift`
- `WorkPet/Sources/WorkPet/Pets/PetAssetPack.swift`
- `WorkPet/Sources/WorkPet/Pets/PetAssetStore.swift`
- `datagrip-plugin/src/main/java/dev/workpet/datagrip/WorkPetDatabaseSessionListener.java`

## 后续建议

1. 做偏好设置窗口，支持编辑来源规则、免打扰、宠物资源包目录。
2. 给 WorkPet 做正式签名和权限引导页。
3. 继续增强 DataGrip 插件，必要时接入 `AuditService` 获取更完整的 SQL 错误日志。
4. 将宠物资源包做成安装/预览界面。
5. 对微信、飞书做更稳定的专用接入，而不是只依赖 macOS 通知数据库。

