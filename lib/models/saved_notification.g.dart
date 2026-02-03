// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_notification.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedNotificationAdapter extends TypeAdapter<SavedNotification> {
  @override
  final int typeId = 0;

  @override
  SavedNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedNotification(
      id: fields[0] as String,
      packageName: fields[1] as String,
      appName: fields[2] as String,
      title: fields[3] as String,
      text: fields[4] as String,
      category: fields[5] as String,
      timestamp: fields[6] as DateTime,
      key: fields[7] as String,
      isRead: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SavedNotification obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.appName)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.key)
      ..writeByte(8)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
