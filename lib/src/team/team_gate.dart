import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../data/firestore_paths.dart';
import '../worker/worker_gate.dart';
import 'create_team_screen.dart';

class TeamGate extends StatelessWidget {
  const TeamGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc(FirestorePaths.user(uid))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        if (snapshot.hasError) {
          return _ErrorScaffold(message: snapshot.error.toString());
        }

        final data = snapshot.data?.data();
        final role = (data?['role'] ?? '').toString().trim().toLowerCase();
        if (role == 'worker') return const WorkerGate();
        if (role != 'admin') return const _InvalidRoleScaffold();

        final currentTeamId = data?['currentTeamId'] as String?;

        if (currentTeamId == null || currentTeamId.isEmpty) {
          return const CreateTeamScreen();
        }

        return AdminHomeScreen(teamId: currentTeamId);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup error'),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Could not read your user record from Firestore.',
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidRoleScaffold extends StatelessWidget {
  const _InvalidRoleScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invalid role'),
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This account does not have a valid role. '
          'Expected "admin" or "worker".',
        ),
      ),
    );
  }
}

