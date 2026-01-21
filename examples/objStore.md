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
// uploaded.uri：本地存储为 file://...，七牛云为 https://.../key
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

