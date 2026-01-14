import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

typedef OnShareReceived = void Function(String jsonText);

class ReceiveShareService {
  StreamSubscription? _subscription;
  OnShareReceived? _onShareReceived;

  void init(OnShareReceived onShareReceived) {
    _onShareReceived = onShareReceived;

    // 应用运行时收到的分享
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (err) => debugPrint('ReceiveShareService error: $err'),
    );

    // 应用冷启动时收到的分享
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedFiles);
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty || _onShareReceived == null) return;

    for (final file in files) {
      if (file.path.isEmpty) continue;

      final ext = file.path.toLowerCase();
      if (!ext.endsWith('.txt') && !ext.endsWith('.json')) continue;

      try {
        final content = await File(file.path).readAsString(encoding: utf8);
        _onShareReceived!(content);
        break;
      } catch (e) {
        debugPrint('读取分享文件失败: $e');
      }
    }

    ReceiveSharingIntent.instance.reset();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
