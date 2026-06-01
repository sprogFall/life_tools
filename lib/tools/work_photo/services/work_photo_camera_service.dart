import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'work_photo_capture_coordinator.dart';

class WorkPhotoCameraService implements WorkPhotoCameraCapture {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isTakingPicture => _controller?.value.isTakingPicture ?? false;

  int get cameraCount => _cameras.length;

  FlashMode get flashMode => _flashMode;

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
