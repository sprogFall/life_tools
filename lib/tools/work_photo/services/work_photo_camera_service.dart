import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'work_photo_capture_coordinator.dart';

class WorkPhotoCameraService implements WorkPhotoCameraCapture {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isTakingPicture => _controller?.value.isTakingPicture ?? false;

  int get cameraCount => _cameras.length;

  FlashMode get flashMode => _flashMode;

  double get currentZoom => _currentZoom;

  double get minZoom => _minZoom;

  double get maxZoom => _maxZoom;

  double get aspectRatio {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return 3 / 4;
    final orientation =
        controller.value.previewPauseOrientation ??
        controller.value.lockedCaptureOrientation ??
        controller.value.deviceOrientation;
    return displayAspectRatioForOrientation(
      cameraAspectRatio: controller.value.aspectRatio,
      orientation: orientation,
    );
  }

  static double displayAspectRatioForOrientation({
    required double cameraAspectRatio,
    required DeviceOrientation orientation,
  }) {
    return switch (orientation) {
      DeviceOrientation.landscapeLeft ||
      DeviceOrientation.landscapeRight => cameraAspectRatio,
      DeviceOrientation.portraitUp ||
      DeviceOrientation.portraitDown => 1 / cameraAspectRatio,
    };
  }

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('当前设备没有可用摄像头');
    }
    _cameraIndex = 0;
    await _openCamera(_cameraIndex);
  }

  Future<void> _openCamera(int index) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    await controller.setFlashMode(_flashMode);

    // 获取缩放范围并设置初始缩放为 1.0（标准焦距）
    _minZoom = await controller.getMinZoomLevel();
    _maxZoom = await controller.getMaxZoomLevel();
    // 初始缩放设为 1.0，如果超出范围则限制在有效范围内
    _currentZoom = 1.0.clamp(_minZoom, _maxZoom);
    await controller.setZoomLevel(_currentZoom);

    _controller = controller;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameraIndex);
  }

  Future<FlashMode> toggleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      FlashMode.always => FlashMode.off,
    };
    _flashMode = next;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setFlashMode(next);
    }
    return next;
  }

  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  Future<void> setZoomLevel(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    await controller.setZoomLevel(clampedZoom);
    _currentZoom = clampedZoom;
  }

  @override
  Future<File> takePictureFile() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('相机尚未初始化');
    }
    if (controller.value.isTakingPicture) {
      throw StateError('正在拍摄中');
    }
    final file = await controller.takePicture();
    return File(file.path);
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
