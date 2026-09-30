# Notices

## 软件许可证

`LICENSE` 中的 MIT 许可证适用于本仓库的**软件源代码**（Swift / Java 源码、脚本、构建配置、以及描述软件的文档）。

## 内置宠物素材

`WorkPet/Sources/WorkPet/Resources/PetPacks/` 下的图片与视频素材**不属于** MIT 许可证的授权范围，按下列方式处理：

- `orange-cat/`：项目自有的示例资源包，可随源码一起分发。
- `wang-lin/`：维护者提供的宠物皮肤资源包（`frames/` 为应用直接使用的帧资源）。该资源包按皮肤素材引入，其素材权属与 `orange-cat/` 不同，MIT 软件许可证不覆盖其图片内容。
- `wang-lin/source-videos/`：仅用于开发期帧提取的源视频，默认被 `.gitignore` 排除，不随仓库分发。
- `docs/videos/`：README 演示视频，为 `wang-lin/` 皮肤运行效果的录屏，授权情况与该皮肤一致，MIT 软件许可证不覆盖其内容。

二次分发或商业使用这些素材前，需要由使用者自行完成授权确认。

## 第三方商标

WorkPet 与微信、飞书、DataGrip / JetBrains、Apple 等第三方不存在隶属、赞助或背书关系。项目中出现的产品名称与图标标识仅用于说明兼容性，相关商标归各自权利人所有。

## 运行时与数据边界

WorkPet 为本地运行应用，不包含远程服务、账号登录或 API Key 配置。只读访问的通知数据库内容、日历数据、DataGrip 任务摘要均保留在本机，项目不实现上传通道。详见 `README.md` 的“隐私、权限与数据边界”。
