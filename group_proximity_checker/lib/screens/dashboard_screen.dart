import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/group_provider.dart';
import '../models/member.dart';
import 'home_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _autoScanTimer;
  bool _autoScan = false;

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoScan() {
    setState(() {
      _autoScan = !_autoScan;
      if (_autoScan) {
        _startAutoScan();
      } else {
        _autoScanTimer?.cancel();
        _autoScanTimer = null;
      }
    });
  }

  void _startAutoScan() {
    // Scan immediately, then every 30 seconds.
    ref.read(scanProvider.notifier).scan();
    _autoScanTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(scanProvider.notifier).scan();
    });
  }

  void _showQrCode() {
    final group = ref.read(groupProvider);
    if (group == null) return;

    final qrData = jsonEncode({
      'groupId': group.groupId,
      'groupName': group.groupName,
    });

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this QR code for new members:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'Are you sure you want to disband this group? '
          'All member data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _autoScanTimer?.cancel();
      await ref.read(groupProvider.notifier).leaveGroup();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider);
    final scanState = ref.watch(scanProvider);

    if (group == null) return const HomeScreen();

    final members = group.members;
    final nearby = members.where((m) => m.isNearby).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.groupName),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showQrCode,
            icon: const Icon(Icons.qr_code),
            tooltip: 'Show QR for new members',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') _leaveGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'leave',
                child: Text('Leave Group'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: nearby == members.length && members.isNotEmpty
                ? Colors.green[50]
                : Colors.orange[50],
            child: Row(
              children: [
                Icon(
                  nearby == members.length && members.isNotEmpty
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: nearby == members.length && members.isNotEmpty
                      ? Colors.green
                      : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  members.isEmpty
                      ? 'No members yet'
                      : '$nearby / ${members.length} members nearby',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Scan controls.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: scanState.status == ScanStatus.scanning
                        ? null
                        : () => ref.read(scanProvider.notifier).scan(),
                    icon: scanState.status == ScanStatus.scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(
                      scanState.status == ScanStatus.scanning
                          ? 'Scanning...'
                          : 'Check Now',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Auto'),
                  selected: _autoScan,
                  onSelected: (_) => _toggleAutoScan(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Member list.
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No members yet.\nTap the QR icon to let people join.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _MemberTile(member: member);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (member.isNearby) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = member.distanceLabel.isNotEmpty
          ? member.distanceLabel
          : 'Nearby';
    } else if (member.lastSeen != null &&
        DateTime.now().difference(member.lastSeen!).inMinutes < 5) {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      statusText = 'Seen recently';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = member.lastSeen != null ? 'Not detected' : 'Never seen';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(member.name),
      subtitle: Text(
        statusText,
        style: TextStyle(color: statusColor),
      ),
      trailing: Icon(statusIcon, color: statusColor),
    );
  }
}
