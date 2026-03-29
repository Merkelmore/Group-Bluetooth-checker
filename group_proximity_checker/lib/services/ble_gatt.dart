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
  /// Extracts member info from the local name or manufacturer data.
  Future<void> _processJoinResult({
    required ScanResult result,
    required String groupId,
    required void Function(Member member) onMemberFound,
    required Set<int> knownMemberIds,
  }) async {
    // Primary: parse identity from local name (most reliable).
    final advName = result.advertisementData.advName;
    final decoded = BleConstants.decodeLocalName(advName);

    final int memberId;
    String? memberName;

    if (decoded != null && decoded.groupId == groupId) {
      memberId = decoded.memberId;
      memberName = decoded.name;
    } else {
      // Fallback: try manufacturer data.
      final manufacturerData = result.advertisementData.manufacturerData;
      final data = manufacturerData[BleConstants.manufacturerId];
      if (data == null) return;

      final mfrDecoded = BleConstants.decodeAdvertisementData(
        Uint8List.fromList(data),
      );
      if (mfrDecoded == null || mfrDecoded.groupId != groupId) return;
      memberId = mfrDecoded.memberId;
    }

    // Skip already-known members.
    if (knownMemberIds.contains(memberId)) return;

    final member = Member(
      memberId: memberId,
      name: memberName ?? 'Member $memberId',
    );

    knownMemberIds.add(memberId);
    onMemberFound(member);
  }

  /// Stop listening for joining members.
  Future<void> stopListening(StreamSubscription? subscription) async {
    await FlutterBluePlus.stopScan();
    await subscription?.cancel();
  }
}
