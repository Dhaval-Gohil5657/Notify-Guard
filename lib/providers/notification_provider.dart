import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/saved_notification.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  late final NotificationService _notificationService;

  List<SavedNotification> _notifications = [];
  bool _isInitialized = false;
  bool _hasNotificationAccess = false;
  StreamSubscription? _notificationSubscription;

  NotificationProvider(this._databaseService) {
    _notificationService = NotificationService(_databaseService);
  }

  List<SavedNotification> get notifications => _notifications;
  bool get isInitialized => _isInitialized;
  bool get hasNotificationAccess => _hasNotificationAccess;

  Future<void> init() async {
    await _databaseService.init();
    _loadNotifications();
    _hasNotificationAccess = await _notificationService.isNotificationAccessGranted();

    if (_hasNotificationAccess) {
      // Pick up notifications stored by native service while app was killed
      await _notificationService.processMissedNotifications();
      _loadNotifications();

      _startListening();
    }

    _isInitialized = true;
    notifyListeners();
  }

  void _loadNotifications() {
    _notifications = _databaseService.getAllNotifications();
    notifyListeners();
  }

  void _startListening() {
    // Cancel existing subscriptions to prevent duplicate listeners
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notificationService.stopListening();

    _notificationService.startListening();
    _notificationSubscription = _notificationService.notificationStream.listen(
      (notification) {
        // Prevent duplicates in the in-memory list using content-based check
        final isDuplicate = _notifications.any(
          (n) =>
              n.packageName == notification.packageName &&
              n.title == notification.title &&
              n.text == notification.text &&
              (notification.timestamp.difference(n.timestamp).inSeconds).abs() <
                  5,
        );
        if (!isDuplicate) {
          _notifications.insert(0, notification);
          notifyListeners();
        }
      },
    );
  }

  Future<bool> checkNotificationAccess() async {
    _hasNotificationAccess = await _notificationService.isNotificationAccessGranted();

    if (_hasNotificationAccess && _notificationSubscription == null) {
      _startListening();
    }

    notifyListeners();
    return _hasNotificationAccess;
  }

  Future<void> openNotificationSettings() async {
    await _notificationService.openNotificationSettings();
  }

  Future<void> refresh() async {
    await checkNotificationAccess();
    _loadNotifications();
  }

  List<SavedNotification> getByCategory(String category) {
    return _notifications.where((n) => n.category == category).toList();
  }

  int getCountByCategory(String category) {
    return _notifications.where((n) => n.category == category).length;
  }

  int getUnreadCountByCategory(String category) {
    return _notifications
        .where((n) => n.category == category && !n.isRead)
        .length;
  }

  Future<void> markAsRead(SavedNotification notification) async {
    await _databaseService.markAsRead(notification);
    notifyListeners();
  }

  Future<void> deleteNotification(SavedNotification notification) async {
    _notifications.removeWhere((n) => n.key == notification.key);
    notifyListeners();
    if (notification.isInBox) {
      await _databaseService.deleteNotification(notification);
    }
  }

  Future<void> deleteMultipleNotifications(List<SavedNotification> notifications) async {
    final keys = notifications.map((n) => n.key).toSet();
    _notifications.removeWhere((n) => keys.contains(n.key));
    notifyListeners();
    await _databaseService.deleteMultipleNotifications(notifications);
  }

  Future<void> deleteAllNotifications() async {
    await _databaseService.deleteAllNotifications();
    _notifications.clear();
    notifyListeners();
  }

  Future<void> deleteOldNotifications(int daysOld) async {
    await _databaseService.deleteOldNotifications(daysOld);
    _loadNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
}
