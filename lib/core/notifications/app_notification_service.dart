abstract class AppNotificationService {
  Future<void> init();

  Future<void> showMessage({required String title, required String body});

  Future<void> scheduleMessage({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  });

  Future<void> cancel(int id);
}

