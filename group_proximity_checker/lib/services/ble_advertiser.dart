import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../utils/ble_constants.dart';

/// Manages BLE peripheral advertising — makes this device visible to the
/// coordinator's scanner by broadcasting the group ID and member ID.
class BleAdvertiser {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;

  bool get isAdvertising => _isAdvertising;

  /// Start advertising with the given group and member identifiers.
  Future<void> startAdvertising({
    required String groupId,
    required int memberId,
    String? memberName,
  }) async {
    if (_isAdvertising) return;

    final data = BleConstants.encodeAdvertisementData(
      groupId: groupId,
      memberId: memberId,
    );

    // Encode the member name in the local name field with our prefix.
    final localName = memberName != null ? 'GC:$memberName' : null;

    // Omit the service UUID from the advertisement to stay under the
    // 31-byte legacy BLE advertisement limit. The coordinator identifies us
    // via manufacturer data (group ID + member ID) which is more reliable.
    // Including a 128-bit UUID (18 bytes) alongside manufacturer data
    // (10 bytes) and a local name would overflow the packet, causing
    // Android to silently drop fields.
    final advertiseData = AdvertiseData(
      manufacturerId: BleConstants.manufacturerId,
      manufacturerData: data,
      localName: localName,
    );

    final advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowLatency,
      connectable: true, // Allow GATT connections during join phase
      timeout: 0, // Advertise indefinitely
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
    );

    await _peripheral.start(
      advertiseData: advertiseData,
      advertiseSettings: advertiseSettings,
    );
    _isAdvertising = true;
  }

  /// Stop advertising.
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    await _peripheral.stop();
    _isAdvertising = false;
  }

  /// Check if the device supports BLE peripheral mode.
  Future<bool> isSupported() async {
    return await _peripheral.isSupported;
  }
}
