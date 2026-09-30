# 宠物资源包

以下命令默认已在仓库根目录设置 `REPO_ROOT`，例如：`export REPO_ROOT="$(pwd)"`。

WorkPet 当前使用图片资源包渲染宠物，不再把 Swift 手绘图形作为主方案。这样后续可以直接替换 PNG / JPG / WebP 素材，不需要改绘图代码。

## 内置资源包

内置资源包目录：

```text
WorkPet/Sources/WorkPet/Resources/PetPacks/
```

当前默认资源包：

```text
orange-cat/
  pet.json
  idle-1.png
  idle-2.png
  curious.png
  happy.png
  alert.png
  love.png
  sleep.png
  focused.png
  squish.png
```

## 用户自定义资源包

用户资源包放在：

```text
~/Library/Application Support/WorkPet/pets/
```

示例：

```text
~/Library/Application Support/WorkPet/pets/my-cat/
  pet.json
  idle.jpg
  alert.jpg
  happy.jpg
```

WorkPet 会同时扫描内置目录和用户目录。右键点击宠物，选择 `选择宠物` 即可切换。

## pet.json 格式

```json
{
  "id": "my-cat",
  "name": "我的猫",
  "version": "0.1.0",
  "author": "your-name",
  "size": {
    "width": 148,
    "height": 148
  },
  "states": {
    "idle": {
      "image": "idle.jpg"
    },
    "bouncing": {
      "frames": ["alert-1.png", "alert-2.png"],
      "frameDuration": 0.15
    },
    "happy": {
      "image": "happy.jpg"
    },
    "default": {
      "image": "idle.jpg"
    }
  }
}
```

## 支持的图片格式

使用 `NSImage` 能解码的格式，例如：

- `.png`
- `.jpg` / `.jpeg`
- `.webp`，取决于当前 macOS 的 AppKit 解码能力

如果宠物需要透明背景，推荐使用 PNG。

## 状态匹配顺序

每次 `PetState` 更新时，WorkPet 按以下顺序寻找图片状态：

1. `action.rawValue`，例如 `bouncing`、`waving`、`sleeping`
2. `mood.rawValue`，例如 `excited`、`happy`、`sleepy`
3. `idle`
4. `default`

简单资源包只需要提供 `idle` 和 `default`。更精细的资源包可以为不同动作提供帧动画。

## 重新生成内置示例素材

当前内置 PNG 由以下脚本生成：

```bash
cd "$REPO_ROOT"
swift scripts/generate-default-pet-assets.swift
```
