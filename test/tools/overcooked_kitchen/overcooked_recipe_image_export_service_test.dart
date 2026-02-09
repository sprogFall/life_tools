import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/overcooked_kitchen/services/overcooked_recipe_image_export_service.dart';

void main() {
  group('OvercookedRecipeImageExportService', () {
    test('exportPng 返回文件路径并携带相册成功结果', () async {
      String? receivedName;
      Uint8List? receivedBytes;
      final service = OvercookedRecipeImageExportService(
        fileExporter: ({required name, required bytes}) async {
          receivedName = name;
          receivedBytes = bytes;
          return '/tmp/$name.png';
        },
        gallerySaver: ({required name, required bytes}) async {
          expect(name, 'dish');
          expect(bytes, isNotEmpty);
          return const OvercookedGallerySaveResult.saved(
            path: 'gallery://dish',
          );
        },
      );

      final result = await service.exportPng(
        name: 'dish',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );

      expect(receivedName, 'dish');
      expect(receivedBytes, isNotNull);
      expect(result.filePath, '/tmp/dish.png');
      expect(result.galleryResult.status, OvercookedGallerySaveStatus.saved);
      expect(result.galleryResult.path, 'gallery://dish');
    });

    test('exportPng 相册保存抛异常时应降级为失败结果', () async {
      final service = OvercookedRecipeImageExportService(
        fileExporter: ({required name, required bytes}) async {
          return '/tmp/$name.png';
        },
        gallerySaver: ({required name, required bytes}) async {
          throw StateError('permission denied');
        },
      );

      final result = await service.exportPng(
        name: 'dish',
        bytes: Uint8List.fromList(const [7, 8]),
      );

      expect(result.filePath, '/tmp/dish.png');
      expect(result.galleryResult.status, OvercookedGallerySaveStatus.failed);
      expect(result.galleryResult.errorMessage, contains('permission denied'));
    });
  });

  group('OvercookedGallerySaveResult.fromPluginResult', () {
    test('支持解析成功 map 返回', () {
      final result = OvercookedGallerySaveResult.fromPluginResult({
        'isSuccess': true,
        'filePath': '/storage/emulated/0/Pictures/a.png',
      });

      expect(result.status, OvercookedGallerySaveStatus.saved);
      expect(result.path, '/storage/emulated/0/Pictures/a.png');
    });

    test('支持解析失败 map 返回', () {
      final result = OvercookedGallerySaveResult.fromPluginResult({
        'isSuccess': false,
        'errorMessage': 'no permission',
      });

      expect(result.status, OvercookedGallerySaveStatus.failed);
      expect(result.errorMessage, 'no permission');
    });

    test('支持解析字符串路径返回', () {
      final result = OvercookedGallerySaveResult.fromPluginResult('/tmp/a.png');

      expect(result.status, OvercookedGallerySaveStatus.saved);
      expect(result.path, '/tmp/a.png');
    });
  });
}
