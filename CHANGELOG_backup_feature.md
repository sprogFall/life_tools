# 备份还原功能改进 - 更新日志

## 版本：功能分支 feat/export-select-directory-and-share-import

### 新增功能

#### 1. 导出并分享 🎉
- **一键分享**：导出备份文件后直接通过系统分享功能分享到其他应用
- **多种分享方式**：支持分享到云存储、即时通讯、邮件等任何能接收文件的应用
- **跨平台支持**：Android、iOS、Web、Windows、macOS、Linux 全平台支持
- **用户友好**：不需要手动查找文件位置，系统会自动处理

#### 2. 保存到指定目录 📁
- **自主选择**：用户可以选择任意目录保存备份文件
- **平台适配**：
  - 移动端和Web：使用系统文件选择器（FileSaver）
  - 桌面端：使用原生目录选择对话框
- **易于管理**：可以将备份保存到固定位置，便于查找和管理

#### 3. 从外部应用导入 📥
- **接收分享文件**：其他应用可以将 `.txt` 或 `.json` 文件分享到本应用
- **自动识别**：应用会自动识别备份文件并提示是否导入
- **多种来源**：
  - 文件管理器直接打开
  - 云存储应用分享
  - 即时通讯接收文件后分享
  - 邮件附件打开
- **智能填充**：文件内容会自动填充到还原文本框，方便用户检查后导入

### 界面改进

#### 导出区域
- **主按钮**："导出并分享" - 蓝色主要操作按钮（IOS26Theme.primaryColor）
- **辅助按钮（左）**："保存到指定目录" - 灰色辅助按钮
- **辅助按钮（右）**："复制到剪切板" - 灰色辅助按钮

#### 布局优化
- 使用Row布局将两个辅助按钮并排显示
- 保持iOS 26风格的圆角（14px）和间距
- 按钮文字更加简洁明了

### 技术实现

#### 新增依赖
```yaml
share_plus: ^10.1.3          # 跨平台分享功能
receive_sharing_intent: ^1.8.1  # 接收外部应用分享的文件
```

#### Android 配置
在 `AndroidManifest.xml` 中添加了以下 Intent Filters：
- `android.intent.action.SEND` - 接收分享的文件
- `android.intent.action.VIEW` - 打开 .txt 和 .json 文件
- 支持 `text/*` 和 `*/*` MIME 类型

#### iOS 配置
在 `Info.plist` 中添加了：
- `CFBundleDocumentTypes` - 声明支持的文档类型
- 支持 `public.plain-text` 和 `public.json` 内容类型
- 启用文档浏览器支持（`UISupportsDocumentBrowser`）
- 启用就地打开文档（`LSSupportsOpeningDocumentsInPlace`）

#### 架构设计
- **SharedFileImportService**：单例服务，用于在 main.dart 和页面之间传递分享文件路径
- **平台适配**：使用 `Platform.isXXX` 和 `kIsWeb` 区分不同平台，提供最佳体验
- **错误处理**：完善的异常捕获和用户提示

### 文件修改列表

#### 核心代码
- `lib/main.dart` - 添加分享意图监听，MyApp 改为 StatefulWidget
- `lib/core/backup/pages/backup_restore_page.dart` - 重构导出功能，添加分享和目录选择

#### 平台配置
- `android/app/src/main/AndroidManifest.xml` - 添加 Android Intent Filters
- `ios/Runner/Info.plist` - 添加 iOS 文档类型声明

#### 依赖配置
- `pubspec.yaml` - 添加 share_plus 和 receive_sharing_intent 依赖
- `pubspec.lock` - 更新依赖锁定版本

#### 测试
- `test/core/backup/backup_restore_page_test.dart` - 更新测试用例以匹配新的按钮文本

#### 文档
- `docs/backup_restore_improvements.md` - 详细的功能说明和使用指南
- `CHANGELOG_backup_feature.md` - 本更新日志

### 测试结果

✅ 所有测试通过（72个测试用例）
✅ 静态代码分析无问题（flutter analyze）
✅ 代码格式化符合规范

### 兼容性

- **最低 Dart SDK**：^3.10.7
- **支持平台**：
  - ✅ Android
  - ✅ iOS
  - ✅ Web
  - ✅ Windows
  - ✅ macOS
  - ✅ Linux

### 向后兼容

- ✅ 保留了原有的"从剪切板粘贴"和"从 TXT 文件导入"功能
- ✅ 现有的备份文件格式完全兼容
- ✅ 不影响现有功能和数据

### 使用建议

1. **推荐导出方式**：优先使用"导出并分享"，可以直接分享到云存储或发送给他人
2. **备份管理**：如果需要固定备份位置，使用"保存到指定目录"
3. **快速备份**：小量数据可以使用"复制到剪切板"快速备份
4. **从云端导入**：从云存储下载备份文件后，直接分享到应用即可导入
5. **安全提醒**：备份文件包含 API Key 等敏感信息，请妥善保管

### 已知问题

无

### 后续计划

- [ ] 支持加密备份文件
- [ ] 支持自动备份到云存储
- [ ] 支持备份历史版本管理
- [ ] 支持选择性还原（只还原部分数据）

### 贡献者

- 实现：AI Assistant
- 需求来源：用户反馈 - 改进文件导出的目录选择和分享功能

---

📅 更新日期：2024年
🔖 分支：feat/export-select-directory-and-share-import
