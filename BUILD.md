# MovieHub 构建脚本说明

本项目提供两个构建脚本，用于生成不同的发布版本：

## 构建脚本

### 1. `build-release-public.ps1` - GitHub 公开发布版本

**用途**：构建不包含 cards 图片的版本，用于上传到 GitHub Release

**使用方法**：
```powershell
.\build-release-public.ps1
```

**特点**：
- 自动构建 Flutter Windows Release
- 自动删除 `build` 输出目录中的 cards 图片
- 适合公开分发，无版权风险

### 2. `build-release-private.ps1` - 个人完整版本

**用途**：构建包含 cards 图片的完整版本，仅供个人使用

**使用方法**：
```powershell
.\build-release-private.ps1
```

**特点**：
- 构建完整功能版本
- 包含所有 cards 图片
- 仅供个人使用，不要公开分发

## 构建流程

1. 运行对应的构建脚本
2. 等待 Flutter 构建完成
3. 使用 Inno Setup 打开 `installer\MovieHub.iss`
4. 编译生成安装包

## 版本管理

- **版本号**：统一在 `pubspec.yaml` 的 `version` 字段维护
- **Git 仓库**：cards 图片已在 `.gitignore` 中忽略，不会提交到仓库
- **公开发布**：只上传通过 `build-release-public.ps1` 构建的版本

## 注意事项

- `assets/cards/images/` 中的图片文件不会被 Git 跟踪
- 公开版本运行时会显示渐变卡面（因为图片被删除）
- 个人版本包含完整卡池图片
- 不要将个人版本上传到 GitHub Release
