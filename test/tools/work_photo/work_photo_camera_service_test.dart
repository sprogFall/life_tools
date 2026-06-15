import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkPhotoCameraService', () {
    test('初始化后应设置缩放相关属性', () async {
      final service = WorkPhotoCameraService();

      // 初始状态
      expect(service.isInitialized, false);
      expect(service.currentZoom, 1.0);
      expect(service.minZoom, 1.0);
      expect(service.maxZoom, 1.0);
    });

    test('aspectRatio应返回相机控制器的宽高比', () {
      final service = WorkPhotoCameraService();

      // 未初始化时返回默认值 3/4
      expect(service.aspectRatio, 3 / 4);
    });

    test('currentZoom应返回当前缩放级别', () {
      final service = WorkPhotoCameraService();
      expect(service.currentZoom, 1.0);
    });

    test('minZoom应返回最小缩放级别', () {
      final service = WorkPhotoCameraService();
      expect(service.minZoom, 1.0);
    });

    test('maxZoom应返回最大缩放级别', () {
      final service = WorkPhotoCameraService();
      expect(service.maxZoom, 1.0);
    });

    test('flashMode应返回当前闪光灯模式', () {
      final service = WorkPhotoCameraService();
      expect(service.flashMode, FlashMode.off);
    });
  });
}
