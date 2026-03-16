import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests all BLE and camera permissions needed by the app.
/// Returns true if all critical permissions are granted.
Future<bool> requestPermissions(BuildContext context) async {
  // On web, permissions are handled differently — skip native permission requests.
  if (kIsWeb) return true;

  final permissions = <Permission>[
    Permission.camera,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ];

  // Location is required for BLE scanning on Android.
  if (Platform.isAndroid) {
    permissions.add(Permission.locationWhenInUse);
  }

  final statuses = await permissions.request();

  final denied = statuses.entries
      .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
      .toList();

  if (denied.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Some permissions were denied. The app needs Bluetooth and Camera '
          'access to work properly. Please enable them in Settings.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    return false;
  }

  return true;
}
