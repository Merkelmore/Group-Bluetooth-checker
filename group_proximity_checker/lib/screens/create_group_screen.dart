import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/group_provider.dart';
import 'dashboard_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  bool _groupCreated = false;
  StreamSubscription? _joinSubscription;
  final Set<int> _knownMemberIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _stopListening();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(groupProvider.notifier).createGroup(name);
    setState(() => _groupCreated = true);
    _startListeningForMembers();
  }

  void _startListeningForMembers() {
    final group = ref.read(groupProvider);
    if (group == null) return;

    final gattService = ref.read(bleGattServiceProvider);
    _joinSubscription = gattService.listenForJoiningMembers(
      groupId: group.groupId,
      knownMemberIds: _knownMemberIds,
      onMemberFound: (member) {
        ref.read(groupProvider.notifier).addMember(member);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.name} joined!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Future<void> _stopListening() async {
    final gattService = ref.read(bleGattServiceProvider);
    await gattService.stopListening(_joinSubscription);
    _joinSubscription = null;
  }

  void _proceedToDashboard() {
    _stopListening();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider);

    if (!_groupCreated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Group')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_add, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g. Europe Trip 2026',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _createGroup(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _createGroup,
                  child: const Text(
                    'Create Group',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group created — show QR code and member list.
    final qrData = jsonEncode({
      'groupId': group!.groupId,
      'groupName': group.groupName,
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(group.groupName),
        actions: [
          TextButton(
            onPressed: _proceedToDashboard,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Have members scan this QR code to join:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${group.members.length} member${group.members.length == 1 ? '' : 's'} joined',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: group.members.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting for members to scan the QR code...',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: group.members.length,
                      itemBuilder: (context, index) {
                        final member = group.members[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(member.name),
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
