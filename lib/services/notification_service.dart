import 'dart:async';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../models/saved_notification.dart';
import 'database_service.dart';
import 'notification_categorizer.dart';

class NotificationService {
  // Keep method channel only for getAppName (package doesn't provide app names)
  static const MethodChannel _channel =
      MethodChannel('karma.notify_guard/notification');

  final DatabaseService _databaseService;
  StreamSubscription? _subscription;
  final _notificationController =
      StreamController<SavedNotification>.broadcast();
  final Set<String> _processingKeys = {};

  Stream<SavedNotification> get notificationStream =>
      _notificationController.stream;

  NotificationService(this._databaseService);

  Future<bool> isNotificationAccessGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      // Fallback to method channel if package fails
      try {
        final bool result =
            await _channel.invokeMethod('isNotificationAccessGranted');
        return result;
      } on PlatformException {
        return false;
      }
    }
  }

  Future<void> openNotificationSettings() async {
    // Don't use NotificationListenerService.requestPermission() - it has a bug
    // that calls result.success() twice causing "Reply already submitted" crash
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
    _subscription?.cancel();
    _subscription = null;
    _processingKeys.clear();

    _subscription =
        NotificationListenerService.notificationsStream.listen(
      (event) async {
        // Skip removed notifications
        if (event.hasRemoved == true) return;

        // Skip ongoing notifications (media players, downloads, etc.)
        if (event.onGoing == true) return;

        final packageName = event.packageName ?? '';

        // Skip blocked packages
        if (NotificationCategorizer.blockedPackages.contains(packageName)) {
          return;
        }

        final title = event.title ?? '';
        final text = event.content ?? '';
        final id = event.id?.toString() ?? '';

        // Skip empty notifications
        if (title.isEmpty && text.isEmpty) return;

        // Generate a dedup key
        final sbnKey = '$packageName:$id';
        final timestamp = DateTime.now();

        // Synchronous dedup check before any await
        if (_processingKeys.contains(sbnKey)) return;
        _processingKeys.add(sbnKey);

        // Clean up old processing keys (keep last 100)
        if (_processingKeys.length > 100) {
          _processingKeys.remove(_processingKeys.first);
        }

        // Categorize on Dart side
        final category = NotificationCategorizer.categorize(title, text);

        // Skip general/non-critical notifications
        if (category == 'general') {
          _processingKeys.remove(sbnKey);
          return;
        }

        final appName = await getAppName(packageName);

        final notification = SavedNotification(
          id: id,
          packageName: packageName,
          appName: appName,
          title: title,
          text: text,
          category: category,
          timestamp: timestamp,
          sbnKey: sbnKey,
        );

        // Check for duplicates before saving
        final isDuplicate = await _databaseService.isDuplicate(notification);
        if (!isDuplicate) {
          await _databaseService.saveNotification(notification);
          _notificationController.add(notification);
        }

        // Remove from processing set after a delay to prevent rapid duplicates
        Future.delayed(const Duration(seconds: 5), () {
          _processingKeys.remove(sbnKey);
        });
      },
      onError: (error) {
        print('Error receiving notification: $error');
      },
    );
  }

  /// Fetch active notifications from the notification shade
  /// (replaces the old getMissedNotifications via method channel)
  Future<void> processActiveNotifications() async {
    try {
      final activeNotifications =
          await NotificationListenerService.getActiveNotifications();

      for (final event in activeNotifications) {
        final packageName = event.packageName ?? '';

        if (NotificationCategorizer.blockedPackages.contains(packageName)) {
          continue;
        }

        final title = event.title ?? '';
        final text = event.content ?? '';
        final id = event.id?.toString() ?? '';

        if (title.isEmpty && text.isEmpty) continue;

        final sbnKey = '$packageName:$id';
        final category = NotificationCategorizer.categorize(title, text);

        // Skip general/non-critical notifications
        if (category == 'general') continue;

        final appName = await getAppName(packageName);

        final notification = SavedNotification(
          id: id,
          packageName: packageName,
          appName: appName,
          title: title,
          text: text,
          category: category,
          timestamp: DateTime.now(),
          sbnKey: sbnKey,
        );

        final isDuplicate = await _databaseService.isDuplicate(notification);
        if (!isDuplicate) {
          await _databaseService.saveNotification(notification);
          _notificationController.add(notification);
        }
      }
    } catch (e) {
      print('Failed to get active notifications: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _processingKeys.clear();
  }

  void dispose() {
    stopListening();
    _notificationController.close();
  }
}
