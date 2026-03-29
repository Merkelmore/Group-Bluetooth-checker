import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_provider.dart';
import 'home_screen.dart';

class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key});

  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureAdvertising();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-start advertising when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      _ensureAdvertising();
    }
  }

  Future<void> _ensureAdvertising() async {
    final group = ref.read(groupProvider);
    if (group == null) return;

    final advertiser = ref.read(bleAdvertiserProvider);
    if (!advertiser.isAdvertising) {
      // Use the persisted name, or fall back to member list / default.
      final myName = group.myName ??
          group.members
              .where((m) => m.memberId == group.myMemberId)
              .map((m) => m.name)
              .firstOrNull;
      await advertiser.startAdvertising(
        groupId: group.groupId,
        memberId: group.myMemberId,
        memberName: myName,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'You will stop broadcasting and leave the group.',
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
    final advertiser = ref.watch(bleAdvertiserProvider);

    if (group == null) return const HomeScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(group.groupName),
        automaticallyImplyLeading: false,
        actions: [
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                advertiser.isAdvertising
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                size: 80,
                color: advertiser.isAdvertising ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                advertiser.isAdvertising
                    ? 'Broadcasting'
                    : 'Not Broadcasting',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: advertiser.isAdvertising ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                advertiser.isAdvertising
                    ? 'Your coordinator can see you nearby.'
                    : 'Trying to start Bluetooth...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Group',
                      value: group.groupName,
                    ),
                    const Divider(height: 16),
                    _InfoRow(
                      label: 'Your ID',
                      value: '#${group.myMemberId}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!advertiser.isAdvertising)
                FilledButton.icon(
                  onPressed: _ensureAdvertising,
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Retry Broadcasting'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
