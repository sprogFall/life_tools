import 'package:flutter/foundation.dart';

import '../notifications/app_notification_service.dart';
import 'message_repository.dart';
import 'models/app_message.dart';

class MessageService extends ChangeNotifier {
  final MessageRepository _repository;
  final AppNotificationService? _notificationService;
  final int _maxMessages;

  List<AppMessage> _messages = const [];

  MessageService({
    MessageRepository? repository,
    AppNotificationService? notificationService,
    int maxMessages = 20,
  }) : _repository = repository ?? MessageRepository(),
       _notificationService = notificationService,
       _maxMessages = maxMessages;

  List<AppMessage> get messages => List.unmodifiable(_messages);

  Future<void> init() async {
    _messages = await _repository.listMessages(limit: _maxMessages);
    notifyListeners();
  }

  Future<void> pushMessage({
    required String toolId,
    required String title,
    required String body,
    String? dedupeKey,
    DateTime? createdAt,
    bool notify = false,
  }) async {
    final insertedId = await _repository.createMessage(
      toolId: toolId,
      title: title,
      body: body,
      dedupeKey: dedupeKey,
      createdAt: createdAt,
    );
    if (insertedId == null) return;

    _messages = await _repository.listMessages(limit: _maxMessages);
    notifyListeners();

    if (notify) {
      await _notificationService?.showMessage(title: title, body: body);
    }
  }
}

