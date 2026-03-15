// GENERATED CODE — hand-written to match Hive annotations.
// Normally produced by `dart run build_runner build`.

part of 'group.dart';

class GroupAdapter extends TypeAdapter<Group> {
  @override
  final int typeId = 0;

  @override
  Group read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Group(
      groupId: fields[0] as String,
      groupName: fields[1] as String,
      createdAt: fields[2] as DateTime,
      members: (fields[3] as List).cast<Member>(),
      isCoordinator: fields[4] as bool,
      myMemberId: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Group obj) {
    writer
      ..writeByte(6) // number of fields
      ..writeByte(0)
      ..write(obj.groupId)
      ..writeByte(1)
      ..write(obj.groupName)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.members)
      ..writeByte(4)
      ..write(obj.isCoordinator)
      ..writeByte(5)
      ..write(obj.myMemberId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
