import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/recipe/overcooked_image_viewer_page.dart';
import 'package:life_tools/tools/overcooked_kitchen/widgets/overcooked_image.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../test_helpers/test_app_wrapper.dart';

class _CountingObjStoreService extends ObjStoreService {
  static const List<int> _pngBytes = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  int ensureCachedFileCallCount = 0;
  int resolveUriCallCount = 0;
  late final String _fileUri;

  _CountingObjStoreService()
    : super(
        configService: ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        ),
        localStore: LocalObjStore(
          baseDirProvider: () async {
            final dir = Directory(
              p.join(Directory.systemTemp.path, 'overcooked_image_perf_cache'),
            );
            if (!dir.existsSync()) dir.createSync(recursive: true);
            return dir;
          },
        ),
        qiniuClient: QiniuClient(),
      ) {
    final dir = Directory(
      p.join(Directory.systemTemp.path, 'overcooked_image_perf_assets'),
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'one_px.png'));
    if (!file.existsSync()) {
      file.writeAsBytesSync(_pngBytes, flush: true);
    }
    _fileUri = file.uri.toString();
  }

  @override
  Future<File?> ensureCachedFile({
    required String key,
    Duration timeout = const Duration(seconds: 12),
    Future<String> Function()? resolveUriWhenMiss,
  }) async {
    ensureCachedFileCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return null;
  }

  @override
  Future<String> resolveUri({required String key}) async {
    resolveUriCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _fileUri;
  }
}

void main() {
  group('Overcooked 图片组件性能', () {
    testWidgets('OvercookedImageByKey 重建时不应重复解析 URI', (tester) async {
      final service = _CountingObjStoreService();
      late VoidCallback rebuild;

      await tester.pumpWidget(
        TestAppWrapper(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = () => setState(() {});
              return Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: OvercookedImageByKey(
                      objStoreService: service,
                      objectKey: 'recipes/1.png',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 12));

      expect(service.resolveUriCallCount, 1);

      rebuild();
      await tester.pump(const Duration(milliseconds: 12));

      expect(service.resolveUriCallCount, 1);
    });

    testWidgets('OvercookedImageViewerPage 重建时不应重复触发缓存/URI 查询', (tester) async {
      final service = _CountingObjStoreService();
      late VoidCallback rebuild;
      var titleVersion = 0;

      await tester.pumpWidget(
        TestAppWrapper(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = () {
                titleVersion++;
                setState(() {});
              };
              return Provider<ObjStoreService>.value(
                value: service,
                child: OvercookedImageViewerPage(
                  objectKeys: const ['recipes/detail-1.png'],
                  title: '查看图片-$titleVersion',
                ),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 12));

      expect(service.ensureCachedFileCallCount, 1);
      expect(service.resolveUriCallCount, 1);

      rebuild();
      await tester.pump(const Duration(milliseconds: 12));

      expect(service.ensureCachedFileCallCount, 1);
      expect(service.resolveUriCallCount, 1);
    });
  });
}
