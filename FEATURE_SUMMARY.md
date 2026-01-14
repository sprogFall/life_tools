# 备份还原功能改进 - 功能总结

## 📋 功能概述

本次更新完全重构了备份还原页面的导出功能，新增了文件分享和从外部应用导入的能力，使得备份管理更加便捷和用户友好。

## ✨ 核心改进

### 1. 导出并分享（推荐方式）⭐

**一键操作**：导出 → 分享 → 完成

- 点击"导出并分享"按钮
- 系统自动创建备份文件
- 弹出系统分享面板
- 选择目标应用（云存储、通讯软件、邮件等）
- 完成分享

**优势**：
- ✅ 无需手动查找文件位置
- ✅ 直接分享到任何支持接收文件的应用
- ✅ 适合备份到云端或发送给他人
- ✅ 全平台支持（移动端、桌面端、Web）

### 2. 保存到指定目录

**灵活控制**：用户可以选择任意目录保存备份

- **移动端和Web**：系统文件选择器（FileSaver）
- **桌面端**：原生目录选择对话框

**优势**：
- ✅ 自主管理备份文件位置
- ✅ 可以保存到固定位置便于查找
- ✅ 适合需要本地管理备份的用户

### 3. 从外部应用导入（新增）🎉

**多种导入方式**：

#### 方式1：文件管理器
1. 在文件管理器中找到备份文件
2. 点击"分享"或"打开方式"
3. 选择"生活工具箱"
4. 确认导入

#### 方式2：云存储应用
1. 从云盘下载或打开备份文件
2. 点击"分享"或"发送到其他应用"
3. 选择"生活工具箱"
4. 确认导入

#### 方式3：接收好友分享
1. 好友通过微信/QQ等发送备份文件
2. 下载文件
3. 长按文件，选择"用其他应用打开"
4. 选择"生活工具箱"
5. 确认导入

**智能识别**：
- ✅ 自动识别 `.txt` 和 `.json` 文件
- ✅ 文件内容自动填充到文本框
- ✅ 用户可以检查内容后再导入
- ✅ 完善的错误提示

## 🎨 界面设计

### 导出区域

```
┌─────────────────────────────────────┐
│  导出                                │
│                                      │
│  ┌──────────────────────────────┐  │
│  │    导出并分享（蓝色主按钮）   │  │
│  └──────────────────────────────┘  │
│                                      │
│  ┌───────────────┐  ┌─────────────┐ │
│  │ 保存到指定目录 │  │ 复制到剪切板 │ │
│  └───────────────┘  └─────────────┘ │
└─────────────────────────────────────┘
```

### 导入区域（保持不变）

```
┌─────────────────────────────────────┐
│  还原                                │
│                                      │
│  [文本输入框 - 8行]                  │
│                                      │
│  ┌───────────────┐  ┌─────────────┐ │
│  │ 从剪切板粘贴   │  │ 从TXT文件导入│ │
│  └───────────────┘  └─────────────┘ │
│                                      │
│  ┌──────────────────┐               │
│  │      清空         │               │
│  └──────────────────┘               │
│                                      │
│  ┌──────────────────────────────┐  │
│  │  开始还原（覆盖本地）- 红色   │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 🔧 技术亮点

### 1. 跨平台统一体验

```dart
// 平台自适应逻辑
if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
  // 移动端：使用 FileSaver
  await FileSaver.instance.saveFile(...);
} else {
  // 桌面端：使用目录选择器
  final directoryPath = await FilePicker.platform.getDirectoryPath();
  // 保存文件到选择的目录
}
```

### 2. 分享功能实现

```dart
// 1. 创建临时文件
final tempDir = await getTemporaryDirectory();
final file = File('${tempDir.path}/$fileName');
await file.writeAsString(jsonText);

// 2. 通过系统分享
final xFile = XFile(filePath);
await Share.shareXFiles([xFile], text: '生活工具箱备份文件');
```

### 3. 接收外部分享

```dart
// 监听分享的文件
ReceiveSharingIntent.instance
    .getMediaStream()
    .listen((files) {
      // 处理分享的文件
      _handleSharedFiles(files);
    });

// 处理app启动时的分享
ReceiveSharingIntent.instance
    .getInitialMedia()
    .then(_handleSharedFiles);
```

### 4. 单例服务传递数据

```dart
// 避免全局变量，使用单例服务
class SharedFileImportService {
  static final instance = SharedFileImportService._internal();
  String? _sharedFilePath;
  
  void setSharedFilePath(String? path) => _sharedFilePath = path;
  String? getAndClearSharedFilePath() {
    final path = _sharedFilePath;
    _sharedFilePath = null;
    return path;
  }
}
```

## 📱 平台配置

### Android - Intent Filters

```xml
<!-- 接收分享的文件 -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/*" />
</intent-filter>

<!-- 打开 .txt 和 .json 文件 -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:scheme="file" />
    <data android:mimeType="text/plain" />
    <data android:pathPattern=".*\\.txt" />
</intent-filter>
```

### iOS - Document Types

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Text File</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.plain-text</string>
            <string>public.json</string>
        </array>
    </dict>
</array>
```

## 🧪 测试覆盖

### 单元测试
- ✅ 备份还原页面按钮文本验证
- ✅ 导出功能（3种方式）
- ✅ 导入功能（2种原有方式 + 外部分享）

### 集成测试建议
- [ ] Android 端分享功能测试
- [ ] iOS 端分享功能测试
- [ ] 桌面端目录选择测试
- [ ] 文件管理器打开文件测试
- [ ] 云存储应用分享测试

### 测试结果
```
✅ 72/72 测试用例通过
✅ 代码分析无问题
✅ 代码格式化完成
```

## 📈 用户体验提升

### 导出流程对比

#### 之前：
1. 点击"导出为 TXT 文件"
2. 文件保存到系统默认位置（不明确）
3. 用户需要记住路径或在文件管理器中搜索
4. 手动复制或移动文件

#### 现在：
1. 点击"导出并分享"
2. 选择目标应用（云盘、通讯软件等）
3. 完成✨

**效率提升**：从4步减少到2步，操作更直观

### 导入流程对比

#### 之前：
1. 打开应用
2. 导航到备份还原页面
3. 点击"从 TXT 文件导入"
4. 在文件选择器中找到文件
5. 导入

#### 现在：
1. 在任何应用中找到备份文件
2. 点击"分享" → 选择"生活工具箱"
3. 确认导入✨

**效率提升**：可以从任何地方直接导入，无需先打开应用

## 🎯 使用建议

### 日常备份
- **推荐**：使用"导出并分享"到云存储应用
- **优点**：自动同步到云端，不占用本地空间

### 设备迁移
- **方法**：旧设备导出分享，新设备接收导入
- **途径**：即时通讯软件、邮件、AirDrop等

### 备份管理
- **桌面端**：使用"保存到指定目录"，集中管理备份文件
- **移动端**：使用"导出并分享"到云存储或文件管理器

### 快速备份
- **小数据**：使用"复制到剪切板"，粘贴到笔记应用
- **大数据**：使用"导出并分享"或"保存到指定目录"

## 🔒 安全提醒

1. **API Key保护**：备份文件包含 API Key 等敏感信息
2. **分享注意**：通过网络分享时注意数据安全
3. **备份加密**：敏感数据建议使用加密云存储
4. **定期清理**：删除不需要的旧备份文件

## 📚 相关文档

- [详细功能说明](docs/backup_restore_improvements.md)
- [更新日志](CHANGELOG_backup_feature.md)
- [测试报告](test/core/backup/backup_restore_page_test.dart)

## 🚀 未来规划

- [ ] 支持备份文件加密
- [ ] 支持增量备份
- [ ] 支持自动定期备份到云存储
- [ ] 支持备份历史版本管理
- [ ] 支持选择性还原（只还原部分数据）
- [ ] 支持备份文件压缩

---

**版本**：feat/export-select-directory-and-share-import  
**状态**：✅ 开发完成，测试通过  
**建议**：可以合并到 dev 分支进行进一步测试
