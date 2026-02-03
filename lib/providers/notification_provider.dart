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
    _notificationService.startListening();
    _notificationSubscription = _notificationService.notificationStream.listen(
      (notification) {
        _notifications.insert(0, notification);
        notifyListeners();
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
    await _databaseService.deleteNotification(notification);
    _notifications.remove(notification);
    notifyListeners();
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
