import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_camera_page.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkPhotoCameraService - 缩放功能', () {
    test('应支持设置缩放级别', () async {
      final service = MockWorkPhotoCameraService();

      expect(service.currentZoom, 1.0);
      expect(service.minZoom, 1.0);
      expect(service.maxZoom, 10.0);

      await service.setZoomLevel(5.0);
      expect(service.currentZoom, 5.0);

      await service.setZoomLevel(15.0);
      expect(service.currentZoom, 10.0);

      await service.setZoomLevel(0.5);
      expect(service.currentZoom, 1.0);
    });
  });

  group('WorkPhotoCameraService - 预览比例', () {
    test('竖屏时应返回 CameraPreview 实际使用的纵向比例', () async {
      final aspectRatio =
          WorkPhotoCameraService.displayAspectRatioForOrientation(
            cameraAspectRatio: 16 / 9,
            orientation: DeviceOrientation.portraitUp,
          );

      expect(aspectRatio, closeTo(9 / 16, 0.0001));
    });

    test('横屏时应返回 CameraPreview 实际使用的横向比例', () async {
      final aspectRatio =
          WorkPhotoCameraService.displayAspectRatioForOrientation(
            cameraAspectRatio: 16 / 9,
            orientation: DeviceOrientation.landscapeLeft,
          );

      expect(aspectRatio, closeTo(16 / 9, 0.0001));
    });
  });

  group('WorkPhotoCameraPreviewFrame', () {
    testWidgets('按比例覆盖取景区域，避免压成横向扁条', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 600,
            child: ClipRect(
              child: WorkPhotoCameraPreviewFrame(
                aspectRatio: 9 / 16,
                child: ColoredBox(
                  key: _previewKey,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ),
        ),
      );

      final previewSize = tester.getSize(find.byKey(_previewKey));
      expect(previewSize.width, closeTo(800, 0.1));
      expect(previewSize.height, closeTo(800 / (9 / 16), 0.1));
      expect(previewSize.height, greaterThan(600));
      expect(previewSize.width / previewSize.height, closeTo(9 / 16, 0.0001));
    });
  });
}

const _previewKey = ValueKey('work-photo-camera-preview');

class MockWorkPhotoCameraService extends WorkPhotoCameraService {
  MockWorkPhotoCameraService({double aspectRatio = 9 / 16})
    : _aspectRatio = aspectRatio;

  double _zoom = 1.0;
  final double _min = 1.0;
  final double _max = 10.0;
  final double _aspectRatio;

  @override
  bool get isInitialized => true;

  @override
  double get currentZoom => _zoom;

  @override
  double get minZoom => _min;

  @override
  double get maxZoom => _max;

  @override
  double get aspectRatio => _aspectRatio;

  @override
  Future<void> initialize() async {
    _zoom = 1.0;
  }

  @override
  Future<void> setZoomLevel(double zoom) async {
    _zoom = zoom.clamp(_min, _max);
  }

  @override
  Widget buildPreview() =>
      const ColoredBox(key: _previewKey, color: CupertinoColors.activeBlue);
}
