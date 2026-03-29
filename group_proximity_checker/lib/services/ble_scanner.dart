import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/member.dart';
import '../utils/ble_constants.dart';

/// Result of detecting a group member via BLE scan.
class ScanMemberResult {
  final int memberId;
  final int rssi;
  final DateTime detectedAt;
  final String? name;

  ScanMemberResult({
    required this.memberId,
    required this.rssi,
    required this.detectedAt,
    this.name,
  });
}

/// Manages BLE central-mode scanning to detect nearby group members.
class BleScanner {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  /// Scan for group members for [duration] seconds.
  /// Calls [onMemberDetected] each time a member with the matching [groupId]
  /// is found. Returns all detected members when the scan completes.
  Future<List<ScanMemberResult>> scanForMembers({
    required String groupId,
    Duration duration = const Duration(seconds: 8),
    void Function(ScanMemberResult)? onMemberDetected,
  }) async {
    if (_isScanning) return [];

    final detectedMembers = <int, ScanMemberResult>{};

    _isScanning = true;

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final memberResult = _parseResult(result, groupId);
        if (memberResult != null) {
          detectedMembers[memberResult.memberId] = memberResult;
          onMemberDetected?.call(memberResult);
        }
      }
    });

    // Start the scan without a service UUID filter. The 128-bit UUID +
    // manufacturer data + local name often exceeds the 31-byte legacy BLE
    // advertisement limit, causing Android to drop the service UUID and
    // making the withServices filter miss our devices. We filter by
    // manufacturer data in _parseResult instead.
    await FlutterBluePlus.startScan(
      timeout: duration,
      androidUsesFineLocation: true,
      continuousUpdates: true,
    );

    // Wait for the scan to complete.
    await Future.delayed(duration + const Duration(milliseconds: 500));

    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;

    return detectedMembers.values.toList();
  }

  /// Stop an ongoing scan early.
  Future<void> stopScan() async {
    if (!_isScanning) return;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  /// Parse a BLE scan result to extract group/member info.
  /// Returns null if the advertisement doesn't match our protocol.
  ScanMemberResult? _parseResult(ScanResult result, String groupId) {
    final manufacturerData = result.advertisementData.manufacturerData;
    if (manufacturerData.isEmpty) return null;

    // Look for our manufacturer ID.
    final data = manufacturerData[BleConstants.manufacturerId];
    if (data == null) return null;

    final decoded =
        BleConstants.decodeAdvertisementData(Uint8List.fromList(data));
    if (decoded == null) return null;

    // Only accept members from the same group.
    if (decoded.groupId != groupId) return null;

    return ScanMemberResult(
      memberId: decoded.memberId,
      rssi: result.rssi,
      detectedAt: DateTime.now(),
      name: _extractName(result),
    );
  }

  /// Extract the member display name from the BLE advertisement local name.
  String? _extractName(ScanResult result) {
    final advName = result.advertisementData.advName;
    if (advName.startsWith('GC:')) {
      return advName.substring(3);
    }
    return advName.isNotEmpty ? advName : null;
  }

  /// Update a list of [Member] models with scan results.
  /// Members found in the scan are marked as nearby; others are marked absent.
  /// Unknown members (detected but not in the list) are automatically added.
  static List<Member> applyResults(
    List<Member> members,
    List<ScanMemberResult> results,
  ) {
    final resultMap = {for (final r in results) r.memberId: r};
    final knownIds = {for (final m in members) m.memberId};

    final updated = members.map((member) {
      final result = resultMap[member.memberId];
      if (result != null) {
        return member.copyWith(
          isNearby: true,
          lastSeen: result.detectedAt,
          lastRssi: result.rssi,
        );
      } else {
        return member.copyWith(isNearby: false);
      }
    }).toList();

    // Auto-add any new members detected that aren't in the list yet.
    for (final result in results) {
      if (!knownIds.contains(result.memberId)) {
        updated.add(Member(
          memberId: result.memberId,
          name: result.name ?? 'Member ${result.memberId}',
          isNearby: true,
          lastSeen: result.detectedAt,
          lastRssi: result.rssi,
        ));
      }
    }

    return updated;
  }
}
