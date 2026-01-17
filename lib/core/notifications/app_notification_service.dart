abstract class AppNotificationService {
  Future<void> init();

  Future<void> showMessage({required String title, required String body});
}

