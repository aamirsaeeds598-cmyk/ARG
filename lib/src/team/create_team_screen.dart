import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../data/firestore_paths.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _teamNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _createTeam() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final teamName = _teamNameController.text.trim();
      if (teamName.isEmpty) throw Exception('Team name is required.');

      final db = FirebaseFirestore.instance;
      final teamRef = db.collection('teams').doc();
      final userRef = db.doc(FirestorePaths.user(user.uid));

      final now = FieldValue.serverTimestamp();

      await db.runTransaction((tx) async {
        tx.set(teamRef, {
          'name': teamName,
          'ownerUid': user.uid,
          'createdAt': now,
        });

        tx.set(
          userRef,
          {
            'email': user.email,
            'role': 'admin',
            'currentTeamId': teamRef.id,
            'createdAt': now,
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminHomeScreen(teamId: teamRef.id)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Team'),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set up your admin team',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can invite workers and create jobs after this.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _teamNameController,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _createTeam(),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _createTeam,
                    icon: const Icon(Icons.group_add),
                    label: _isLoading
                        ? const Text('Creating...')
                        : const Text('Create team'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

