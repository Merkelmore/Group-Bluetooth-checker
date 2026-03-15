import 'package:hive_flutter/hive_flutter.dart';

part 'member.g.dart';

@HiveType(typeId: 1)
class Member extends HiveObject {
  @HiveField(0)
  final int memberId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  bool isNearby;

  @HiveField(3)
  DateTime? lastSeen;

  @HiveField(4)
  int? lastRssi;

  Member({
    required this.memberId,
    required this.name,
    this.isNearby = false,
    this.lastSeen,
    this.lastRssi,
  });

  Member copyWith({
    int? memberId,
    String? name,
    bool? isNearby,
    DateTime? lastSeen,
    int? lastRssi,
  }) {
    return Member(
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      isNearby: isNearby ?? this.isNearby,
      lastSeen: lastSeen ?? this.lastSeen,
      lastRssi: lastRssi ?? this.lastRssi,
    );
  }

  /// Rough distance description based on RSSI value.
  String get distanceLabel {
    if (lastRssi == null || !isNearby) return '';
    final rssi = lastRssi!;
    if (rssi > -50) return 'Very close';
    if (rssi > -70) return 'Nearby';
    return 'Edge of range';
  }
}
