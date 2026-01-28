# 资源存储（对象存储）调用示例

本项目已在 `lib/main.dart` 通过 Provider 全局注入：

- `ObjStoreConfigService`：负责保存/读取「资源存储」配置
- `ObjStoreService`：提供上传/查询/缓存通用接口（调用方只需要保存 key）

用户可在首页右上角「设置」中进入「资源存储」完成配置与测试。

## 调用方只需要知道的规则

1. 业务侧**只持久化 `key`**（数据库/配置/导入导出都只存 key）
2. 展示图片时，**只通过 `ObjStoreService` 的公共方法**拿到“可用资源”（本地文件或 URL）
3. 不要关心当前到底是“本地存储还是七牛云”，也不要自己维护缓存目录/缓存策略

下面是最常用的 3 个场景示例。

## 1) 上传图片/视频（bytes -> key）

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

// 只保存 key（后续展示/缓存/导入导出都用这个 key）
final String key = uploaded.key;
```

## 2) 展示图片（key -> 自动优先缓存，否则用 URL）

你只需要把 `key` 交给公共方法，方法内部会：
- 能读到本地文件就直接返回 `File`
- 否则自动去拿下载 URL 并下载到缓存目录，再返回 `File`

注意：当「资源存储」未配置、资源已被清理、或网络下载失败时，`ensureCachedFile(...)` / `resolveUri(...)` 可能抛异常。UI 层建议用 `catchError` 做兜底，避免 `FutureBuilder` 进入 error 状态导致空白。

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();
final String key = 'media/xxxx.png';

Widget buildImage() {
  return FutureBuilder<File?>(
    future: objStore.ensureCachedFile(key: key).catchError((_) => null),
    builder: (context, snapshot) {
      final file = snapshot.data;
      if (file != null && file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      // 磁盘缓存不可用/下载失败时，兜底用 URL（调用方无需判断本地/七牛）
      return FutureBuilder<String>(
        future: objStore.resolveUri(key: key).catchError((_) => ''),
        builder: (context, snap) {
          final url = snap.data;
          if (url == null || url.trim().isEmpty) return const SizedBox();
          return Image.network(url, fit: BoxFit.cover);
        },
      );
    },
  );
}
```

## 2.1) 只需要一个可用 URI（key -> file:// 或 http(s)://）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();

final key = 'media/xxxx.png';
final uri = await objStore.resolveUri(key: key);
```

## 3) 只查缓存（不触发下载）

```dart
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';

final objStore = context.read<ObjStoreService>();

final File? cached = await objStore.getCachedFile(key: 'media/xxxx.png');
if (cached != null && cached.existsSync()) {
  // 命中缓存，可直接用 Image.file(cached)
}
```

## 异常处理（未配置提示用户去配置）

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

## 调用注意事项（重要）

1. **只持久化 `key`**
   - 不要持久化 URL（URL 可能变化/可能带临时 token）

2. **优先用 bytes 上传，避免路径副作用**
   - 推荐：选择文件后读出 `Uint8List bytes`，再调用 `objStore.uploadBytes(bytes: ..., filename: ...)`
   - 不要把“选中的文件路径”当成稳定输入：不同平台/插件可能会产生临时复制文件

3. **Android + file_picker：必须处理临时复制文件，避免相册出现重复图片**
   - `file_picker` 在 Android 上可能会把选中的图片复制到缓存目录（如 `.../Android/data/<包名>/cache/file_picker/`），系统媒体库会扫描到，从而在相册里出现“多出一张重复图片”
   - 若只是“选图上传”，移动端优先使用 `image_picker`（系统照片选择器）读取 bytes 再上传，避免产生可被相册扫描的临时落盘文件
   - 规范做法：
     - 选择完成并读取后调用 `FilePicker.platform.clearTemporaryFiles()`
     - 若需要“暂存到本地以便预览/稍后上传”，优先使用 `stageFileToPendingUploadDir(...)`（见 `lib/core/utils/pending_upload_file.dart`），它会把文件复制到应用临时目录并写入 `.nomedia`；上传完成后**请自行删除**暂存文件
     - 若你需要自定义清理逻辑，请复用：
       - `shouldCleanupPickedFilePath(...)`（`lib/core/utils/picked_file_cleanup.dart`）：判断该路径是否属于可安全删除的临时复制文件
       - `ensureNoMediaFileInDir(...)`（`lib/core/utils/no_media.dart`）：在目录内写入 `.nomedia`，阻止媒体库扫描

4. **大文件注意**
   - `uploadBytes(...)` 需要一次性把文件读入内存；对大视频/超大图片请先限制大小、压缩或拆分流程，避免内存峰值过高
