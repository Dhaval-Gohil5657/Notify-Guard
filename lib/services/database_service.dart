import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_notification.dart';

class DatabaseService {
  static const String _boxName = 'notifications';
  late Box<SavedNotification> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SavedNotificationAdapter());
    _box = await Hive.openBox<SavedNotification>(_boxName);
  }

  Future<void> saveNotification(SavedNotification notification) async {
    await _box.add(notification);
  }

  List<SavedNotification> getAllNotifications() {
    return _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<SavedNotification> getNotificationsByCategory(String category) {
    return _box.values
        .where((n) => n.category == category)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> markAsRead(SavedNotification notification) async {
    notification.isRead = true;
    await notification.save();
  }

  Future<void> deleteNotification(SavedNotification notification) async {
    await notification.delete();
  }

  Future<void> deleteAllNotifications() async {
    await _box.clear();
  }

  Future<void> deleteOldNotifications(int daysOld) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    final toDelete =
        _box.values.where((n) => n.timestamp.isBefore(cutoff)).toList();
    for (var notification in toDelete) {
      await notification.delete();
    }
  }

  Future<bool> isDuplicate(SavedNotification notification) async {
    // Check if a notification with same key exists within last 5 seconds
    final recentNotifications = _box.values.where((n) {
      final timeDiff = notification.timestamp.difference(n.timestamp).inSeconds;
      return n.key == notification.key && timeDiff.abs() < 5;
    });
    return recentNotifications.isNotEmpty;
  }

  int getUnreadCount() {
    return _box.values.where((n) => !n.isRead).length;
  }

  int getUnreadCountByCategory(String category) {
    return _box.values.where((n) => !n.isRead && n.category == category).length;
  }
}
