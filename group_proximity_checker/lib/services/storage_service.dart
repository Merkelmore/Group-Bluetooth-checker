import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../models/member.dart';

/// Manages local persistence of group data using Hive.
class StorageService {
  static const String _groupBoxName = 'group_box';
  static const String _groupKey = 'active_group';

  /// Initialize Hive and register adapters. Call once at app startup.
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MemberAdapter());
    Hive.registerAdapter(GroupAdapter());
    await Hive.openBox<Group>(_groupBoxName);
  }

  static Box<Group> get _box => Hive.box<Group>(_groupBoxName);

  /// Save the active group (coordinator or member).
  static Future<void> saveGroup(Group group) async {
    await _box.put(_groupKey, group);
  }

  /// Load the active group, or null if none exists.
  static Group? loadGroup() {
    return _box.get(_groupKey);
  }

  /// Delete the active group (leave/disband).
  static Future<void> deleteGroup() async {
    await _box.delete(_groupKey);
  }

  /// Add a member to the active group.
  static Future<void> addMember(Member member) async {
    final group = loadGroup();
    if (group == null) return;
    group.members.add(member);
    await group.save();
  }

  /// Update the members list (e.g., after a scan updates nearby statuses).
  static Future<void> updateMembers(List<Member> members) async {
    final group = loadGroup();
    if (group == null) return;
    final updated = group.copyWith(members: members);
    await _box.put(_groupKey, updated);
  }
}
