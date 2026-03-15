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

  ScanMemberResult({
    required this.memberId,
    required this.rssi,
    required this.detectedAt,
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

    // Start the scan, filtering by our service UUID.
    await FlutterBluePlus.startScan(
      withServices: [BleConstants.serviceUuid],
      timeout: duration,
      androidUsesFineLocation: true,
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
    );
  }

  /// Update a list of [Member] models with scan results.
  /// Members found in the scan are marked as nearby; others are marked absent.
  static List<Member> applyResults(
    List<Member> members,
    List<ScanMemberResult> results,
  ) {
    final resultMap = {for (final r in results) r.memberId: r};

    return members.map((member) {
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
  }
}
