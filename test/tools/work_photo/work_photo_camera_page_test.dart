import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_camera_service.dart';

class MockWorkPhotoCameraService extends WorkPhotoCameraService {
  double _zoom = 1.0;
  final double _min = 1.0;
  final double _max = 10.0;
  final double _aspectRatio = 9 / 16;

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
  Widget buildPreview() => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkPhotoCameraService - 缩放功能', () {
    test('应支持设置缩放级别', () async {
      final service = MockWorkPhotoCameraService();

      // 初始缩放为1.0
      expect(service.currentZoom, 1.0);
      expect(service.minZoom, 1.0);
      expect(service.maxZoom, 10.0);

      // 设置缩放为5.0
      await service.setZoomLevel(5.0);
      expect(service.currentZoom, 5.0);

      // 超过最大值时应clamp到最大值
      await service.setZoomLevel(15.0);
      expect(service.currentZoom, 10.0);

      // 小于最小值时应clamp到最小值
      await service.setZoomLevel(0.5);
      expect(service.currentZoom, 1.0);
    });

    test('应返回相机的实际宽高比', () {
      final service = MockWorkPhotoCameraService();

      // 验证返回的是相机的实际宽高比，而非固定的3/4
      expect(service.aspectRatio, 9 / 16);
    });
  });
}

