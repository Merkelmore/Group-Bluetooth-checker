import 'dart:typed_data';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Constants and helpers for the BLE protocol used by the app.
class BleConstants {
  BleConstants._();

  /// The app's unique service UUID — used to identify our app's BLE signals.
  /// Generated once, hardcoded. All instances of this app share this UUID.
  static final Guid serviceUuid =
      Guid('a1b2c3d4-e5f6-7890-abcd-ef1234567890');

  /// GATT characteristic UUID for the name exchange during join handshake.
  static final Guid nameCharacteristicUuid =
      Guid('a1b2c3d4-e5f6-7890-abcd-ef1234567891');

  /// Custom manufacturer ID (using 0xFFFF which is reserved for testing).
  /// In production, register with Bluetooth SIG for a real company ID.
  static const int manufacturerId = 0xFFFF;

  /// Encodes a group ID (8-char hex string) and member ID (int) into
  /// manufacturer data bytes for BLE advertisement.
  ///
  /// Layout: [groupId: 4 bytes] [memberId: 2 bytes] = 6 bytes total
  static Uint8List encodeAdvertisementData({
    required String groupId,
    required int memberId,
  }) {
    final bytes = Uint8List(6);
    // Group ID: 8 hex chars = 4 bytes
    for (var i = 0; i < 4; i++) {
      bytes[i] = int.parse(groupId.substring(i * 2, i * 2 + 2), radix: 16);
    }
    // Member ID: 2 bytes, big-endian
    bytes[4] = (memberId >> 8) & 0xFF;
    bytes[5] = memberId & 0xFF;
    return bytes;
  }

  /// Decodes manufacturer data bytes back into group ID and member ID.
  /// Returns null if the data is not in the expected format.
  static ({String groupId, int memberId})? decodeAdvertisementData(
      Uint8List data) {
    if (data.length < 6) return null;

    final groupId = data
        .sublist(0, 4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final memberId = (data[4] << 8) | data[5];

    return (groupId: groupId, memberId: memberId);
  }

  /// Generates a random 8-character hex string for use as a group ID.
  static String generateGroupId() {
    final random = Random.secure();
    final bytes = List.generate(4, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a random member ID (1–65534, avoiding 0 which is coordinator).
  static int generateMemberId() {
    return Random.secure().nextInt(65534) + 1;
  }
}
