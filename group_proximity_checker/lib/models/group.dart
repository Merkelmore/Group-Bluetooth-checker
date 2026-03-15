import 'package:hive_flutter/hive_flutter.dart';
import 'member.dart';

part 'group.g.dart';

@HiveType(typeId: 0)
class Group extends HiveObject {
  @HiveField(0)
  final String groupId;

  @HiveField(1)
  final String groupName;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final List<Member> members;

  @HiveField(4)
  final bool isCoordinator;

  @HiveField(5)
  final int myMemberId;

  Group({
    required this.groupId,
    required this.groupName,
    required this.createdAt,
    required this.members,
    required this.isCoordinator,
    required this.myMemberId,
  });

  Group copyWith({
    String? groupId,
    String? groupName,
    DateTime? createdAt,
    List<Member>? members,
    bool? isCoordinator,
    int? myMemberId,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? List.from(this.members),
      isCoordinator: isCoordinator ?? this.isCoordinator,
      myMemberId: myMemberId ?? this.myMemberId,
    );
  }

  /// Number of members currently detected as nearby.
  int get nearbyCount => members.where((m) => m.isNearby).length;
}
