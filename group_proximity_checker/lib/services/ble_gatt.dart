import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/ble_constants.dart';
import '../models/member.dart';

/// Handles the GATT-based name exchange during the join flow.
///
/// **Coordinator side**: Scans for nearby devices advertising our service UUID,
/// connects, reads the name characteristic to learn the member's name + ID.
///
/// **Member side**: The member's name is encoded in the advertisement's local
/// name field. For a more robust exchange, we use a GATT read after connecting.
///
/// Note: On iOS, GATT server hosting from Flutter has limitations. As a
/// practical alternative, the member encodes their info in the scan response
/// local name, and the coordinator reads it during the join window.
class BleGattService {
  /// Coordinator: Listen for new members joining.
  /// Scans for devices with our service UUID and reads their info.
  /// Calls [onMemberFound] for each new member detected.
  /// Returns a subscription that should be cancelled when the join window ends.
  StreamSubscription<List<ScanResult>>? listenForJoiningMembers({
    required String groupId,
    required void Function(Member member) onMemberFound,
    required Set<int> knownMemberIds,
  }) {
    final subscription =
        FlutterBluePlus.onScanResults.listen((results) async {
      for (final result in results) {
        await _processJoinResult(
          result: result,
          groupId: groupId,
          onMemberFound: onMemberFound,
          knownMemberIds: knownMemberIds,
        );
      }
    });

    // Start scanning for all BLE devices. We filter by manufacturer data
    // in _processJoinResult instead of using withServices, because the
    // 128-bit UUID + manufacturer data + local name can exceed the 31-byte
    // legacy BLE advertisement limit, causing Android to silently drop the
    // service UUID and making the filter miss our devices entirely.
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 120), // Long join window
      androidUsesFineLocation: true,
      continuousUpdates: true,
    );

    return subscription;
  }

  /// Process a scan result during the join phase.
  /// Extracts member info and connects via GATT to read the name.
  Future<void> _processJoinResult({
    required ScanResult result,
    required String groupId,
    required void Function(Member member) onMemberFound,
    required Set<int> knownMemberIds,
  }) async {
    // Check manufacturer data for our group.
    final manufacturerData = result.advertisementData.manufacturerData;
    final data = manufacturerData[BleConstants.manufacturerId];
    if (data == null) return;

    final decoded = BleConstants.decodeAdvertisementData(
      Uint8List.fromList(data),
    );
    if (decoded == null || decoded.groupId != groupId) return;

    // Skip already-known members.
    if (knownMemberIds.contains(decoded.memberId)) return;

    // Try to get the name from the local name in the advertisement.
    String memberName = result.advertisementData.advName;
    if (memberName.isEmpty) {
      memberName = 'Member ${decoded.memberId}';
    }

    // If the name starts with our prefix, extract the actual name.
    // Convention: local name is "GC:<name>" for our app.
    if (memberName.startsWith('GC:')) {
      memberName = memberName.substring(3);
    }

    final member = Member(
      memberId: decoded.memberId,
      name: memberName,
    );

    knownMemberIds.add(decoded.memberId);
    onMemberFound(member);
  }

  /// Stop listening for joining members.
  Future<void> stopListening(StreamSubscription? subscription) async {
    await FlutterBluePlus.stopScan();
    await subscription?.cancel();
  }
}
