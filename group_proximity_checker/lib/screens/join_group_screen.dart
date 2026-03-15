import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/group_provider.dart';
import 'member_screen.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _nameController = TextEditingController();
  String? _groupId;
  String? _groupName;
  bool _scanned = false;
  bool _joining = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final groupId = data['groupId'] as String?;
        final groupName = data['groupName'] as String?;

        if (groupId != null && groupName != null) {
          setState(() {
            _groupId = groupId;
            _groupName = groupName;
            _scanned = true;
          });
          return;
        }
      } catch (_) {
        // Not our QR code - ignore.
      }
    }
  }

  Future<void> _joinGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _groupId == null || _groupName == null) return;

    setState(() => _joining = true);

    await ref.read(groupProvider.notifier).joinGroup(
          groupId: _groupId!,
          groupName: _groupName!,
          myName: name,
        );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MemberScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_scanned) {
      // QR scanning view.
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
        body: Column(
          children: [
            Expanded(
              child: MobileScanner(
                onDetect: _onQrDetected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Point your camera at the coordinator\'s QR code',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // QR scanned — ask for name.
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Join "$_groupName"',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'e.g. Alice',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              onSubmitted: (_) => _joinGroup(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _joining ? null : _joinGroup,
                child: _joining
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Join & Start Broadcasting',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
