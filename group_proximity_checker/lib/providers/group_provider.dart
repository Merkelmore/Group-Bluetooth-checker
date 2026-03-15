import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../services/ble_advertiser.dart';
import '../services/ble_scanner.dart';
import '../services/ble_gatt.dart';
import '../services/storage_service.dart';
import '../utils/ble_constants.dart';

// ─── Service instances ─────────────────────────────────────────────────────

final bleAdvertiserProvider = Provider<BleAdvertiser>((ref) => BleAdvertiser());
final bleScannerProvider = Provider<BleScanner>((ref) => BleScanner());
final bleGattServiceProvider = Provider<BleGattService>((ref) => BleGattService());

// ─── Group state ───────────────────────────────────────────────────────────

/// Holds the active group (or null when not in a group).
class GroupNotifier extends Notifier<Group?> {
  @override
  Group? build() {
    // Restore from storage.
    return StorageService.loadGroup();
  }

  /// Create a new group as coordinator.
  Future<void> createGroup(String groupName) async {
    final group = Group(
      groupId: BleConstants.generateGroupId(),
      groupName: groupName,
      createdAt: DateTime.now(),
      members: [],
      isCoordinator: true,
      myMemberId: 0,
    );
    await StorageService.saveGroup(group);
    state = group;
  }

  /// Join an existing group as a member.
  Future<void> joinGroup({
    required String groupId,
    required String groupName,
    required String myName,
  }) async {
    final memberId = BleConstants.generateMemberId();
    final group = Group(
      groupId: groupId,
      groupName: groupName,
      createdAt: DateTime.now(),
      members: [],
      isCoordinator: false,
      myMemberId: memberId,
    );
    await StorageService.saveGroup(group);
    state = group;

    // Start BLE advertising so the coordinator can detect us.
    await ref.read(bleAdvertiserProvider).startAdvertising(
          groupId: groupId,
          memberId: memberId,
        );
  }

  /// Add a newly joined member (coordinator only).
  void addMember(Member member) {
    if (state == null) return;
    final updated = state!.copyWith(
      members: [...state!.members, member],
    );
    state = updated;
    StorageService.saveGroup(updated);
  }

  /// Update member list after a scan.
  void updateMembers(List<Member> members) {
    if (state == null) return;
    final updated = state!.copyWith(members: members);
    state = updated;
    StorageService.saveGroup(updated);
  }

  /// Leave / disband the group.
  Future<void> leaveGroup() async {
    await ref.read(bleAdvertiserProvider).stopAdvertising();
    await StorageService.deleteGroup();
    state = null;
  }
}

final groupProvider =
    NotifierProvider<GroupNotifier, Group?>(GroupNotifier.new);

// ─── Scanning state ────────────────────────────────────────────────────────

enum ScanStatus { idle, scanning, done }

class ScanState {
  final ScanStatus status;
  final List<ScanMemberResult> results;

  const ScanState({this.status = ScanStatus.idle, this.results = const []});
}

class ScanNotifier extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  /// Run a proximity scan and update the group's member statuses.
  Future<void> scan() async {
    final group = ref.read(groupProvider);
    if (group == null) return;

    state = const ScanState(status: ScanStatus.scanning);

    final scanner = ref.read(bleScannerProvider);
    final results = await scanner.scanForMembers(
      groupId: group.groupId,
      onMemberDetected: (result) {
        // Update state progressively as members are detected.
        state = ScanState(
          status: ScanStatus.scanning,
          results: [...state.results, result],
        );
      },
    );

    // Apply results to member list.
    final updatedMembers = BleScanner.applyResults(group.members, results);
    ref.read(groupProvider.notifier).updateMembers(updatedMembers);

    state = ScanState(status: ScanStatus.done, results: results);
  }

  void reset() {
    state = const ScanState();
  }
}

final scanProvider =
    NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);
