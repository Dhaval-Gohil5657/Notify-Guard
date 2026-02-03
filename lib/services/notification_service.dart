import 'dart:async';
import 'package:flutter/services.dart';
import '../models/saved_notification.dart';
import 'database_service.dart';

class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('karma.notify_guard/notification');
  static const EventChannel _eventChannel =
      EventChannel('karma.notify_guard/notification_stream');

  final DatabaseService _databaseService;
  StreamSubscription? _subscription;
  final _notificationController =
      StreamController<SavedNotification>.broadcast();

  Stream<SavedNotification> get notificationStream =>
      _notificationController.stream;

  NotificationService(this._databaseService);

  Future<bool> isNotificationAccessGranted() async {
    try {
      final bool result =
          await _channel.invokeMethod('isNotificationAccessGranted');
      return result;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException catch (e) {
      print('Failed to open settings: ${e.message}');
    }
  }

  Future<String> getAppName(String packageName) async {
    try {
      final String result = await _channel.invokeMethod(
        'getAppName',
        {'packageName': packageName},
      );
      return result;
    } on PlatformException {
      return packageName;
    }
  }

  void startListening() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        if (event is Map) {
          final packageName = event['packageName'] ?? '';
          final appName = await getAppName(packageName);
          final notification = SavedNotification.fromMap(event, appName);

          // Check for duplicates before saving
          final isDuplicate = await _databaseService.isDuplicate(notification);
          if (!isDuplicate) {
            await _databaseService.saveNotification(notification);
            _notificationController.add(notification);
          }
        }
      },
      onError: (error) {
        print('Error receiving notification: $error');
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _notificationController.close();
  }
}
