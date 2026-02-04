import 'package:hive/hive.dart';

part 'saved_notification.g.dart';

@HiveType(typeId: 0)
class SavedNotification extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String packageName;

  @HiveField(2)
  final String appName;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final String text;

  @HiveField(5)
  final String category;

  @HiveField(6)
  final DateTime timestamp;

  @HiveField(7)
  final String sbnKey;

  @HiveField(8)
  bool isRead;

  SavedNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.category,
    required this.timestamp,
    required this.sbnKey,
    this.isRead = false,
  });

  factory SavedNotification.fromMap(Map<dynamic, dynamic> map, String appName) {
    return SavedNotification(
      id: map['id'] ?? '',
      packageName: map['packageName'] ?? '',
      appName: appName,
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      category: map['category'] ?? 'general',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(map['timestamp'] ?? '0') ?? 0,
      ),
      sbnKey: map['key'] ?? '',
    );
  }

  String get categoryDisplayName {
    switch (category) {
      case 'otp':
        return 'OTP / Verification';
      case 'bank':
        return 'Banking';
      case 'security':
        return 'Security Alert';
      case 'emergency':
        return 'emergency';
      default:
        return 'General';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedNotification &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}
