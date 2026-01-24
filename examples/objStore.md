# 资源存储（对象存储）调用示例

本项目已在 `lib/main.dart` 通过 Provider 全局注入：

- `ObjStoreConfigService`：负责保存/读取「资源存储」配置
- `ObjStoreService`：提供上传/查询（URI 解析）通用接口

用户可在首页右上角「设置」中进入「资源存储」完成配置与测试。

## 1) 上传图片/视频（bytes -> key/uri）

```dart
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();

// bytes / filename 由你的工具自行获取（如 image_picker / file_picker）
final Uint8List bytes = ...;
final String filename = 'demo.png';

final uploaded = await objStore.uploadBytes(
  bytes: bytes,
  filename: filename,
);

// uploaded.key：建议业务侧持久化保存（用于后续查询）
// uploaded.uri：本地存储为 file://...；七牛公有空间为 https://.../key；七牛私有空间为“带签名的临时链接”（会过期）
print(uploaded.key);
print(uploaded.uri);
```

## 2) 查询图片/视频（key -> uri）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();

final key = 'media/xxxx.png';
final uri = await objStore.resolveUri(key: key);

// 若配置为七牛私有空间，这里返回带签名的临时下载链接（带 e/token）
```

## 3) 异常处理（未配置提示用户去配置）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_errors.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();

try {
  final uploaded = await objStore.uploadBytes(bytes: bytes, filename: filename);
  // TODO: 使用 uploaded.key / uploaded.uri 做后续业务逻辑
} on ObjStoreNotConfiguredException catch (e) {
  // TODO: 提示用户先到 设置 -> 资源存储 完成配置
  // e.message 可直接展示
} catch (e) {
  // TODO: 其他上传/解析错误提示
}
```

## 4) 调用注意事项（重要）

1. **只持久化 Key，不要持久化 URI**
   - `uploaded.key`：建议业务侧持久化保存（数据库/配置等）
   - `uploaded.uri`：仅用于当前展示/调试
   - 七牛私有空间的 `uri` 是“带签名的临时下载链接”，会过期；需要展示时应 `resolveUri(key: ...)` 重新获取

2. **优先用 bytes 上传，避免路径副作用**
   - 推荐：选择文件后读出 `Uint8List bytes`，再调用 `objStore.uploadBytes(bytes: ..., filename: ...)`
   - 不要把“选中的文件路径”当成稳定输入：不同平台/插件可能会产生临时复制文件

3. **Android + file_picker：必须处理临时复制文件，避免相册出现重复图片**
   - `file_picker` 在 Android 上可能会把选中的图片复制到缓存目录（如 `.../Android/data/<包名>/cache/file_picker/`），系统媒体库会扫描到，从而在相册里出现“多出一张重复图片”
   - 若只是“选图上传”，移动端优先使用 `image_picker`（系统照片选择器）读取 bytes 再上传，避免产生可被相册扫描的临时落盘文件
   - 规范做法：
     - 选择完成并读取后调用 `FilePicker.platform.clearTemporaryFiles()`
     - 若需要“暂存到本地以便预览/稍后上传”，优先使用 `stageFileToPendingUploadDir(...)`（见 `lib/core/utils/pending_upload_file.dart`），它会把文件复制到应用临时目录并写入 `.nomedia`，上传完成后再删除暂存文件
     - 若你需要自定义清理逻辑，请复用：
       - `shouldCleanupPickedFilePath(...)`（`lib/core/utils/picked_file_cleanup.dart`）：判断该路径是否属于可安全删除的临时复制文件
       - `ensureNoMediaFileInDir(...)`（`lib/core/utils/no_media.dart`）：在目录内写入 `.nomedia`，阻止媒体库扫描

4. **大文件注意**
   - `uploadBytes(...)` 需要一次性把文件读入内存；对大视频/超大图片请先限制大小、压缩或拆分流程，避免内存峰值过高
