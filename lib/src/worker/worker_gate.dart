import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore_paths.dart';
import 'worker_home_screen.dart';

class WorkerGate extends StatelessWidget {
  const WorkerGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = FirebaseFirestore.instance.doc(FirestorePaths.user(uid));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (snapshot.hasError) {
          return _ErrorScaffold(message: snapshot.error.toString());
        }

        final data = snapshot.data?.data();
        final teamId = data?['currentTeamId'] as String?;

        // If no team assigned yet, try to find one from assigned jobs
        if (teamId == null || teamId.isEmpty) {
          return _TeamAutoResolver(uid: uid);
        }

        return WorkerHomeScreen(teamId: teamId);
      },
    );
  }
}

// ── Auto-resolve team for workers without currentTeamId ──────────────────────

class _TeamAutoResolver extends StatefulWidget {
  const _TeamAutoResolver({required this.uid});
  final String uid;

  @override
  State<_TeamAutoResolver> createState() => _TeamAutoResolverState();
}

class _TeamAutoResolverState extends State<_TeamAutoResolver> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final email = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
      if (email.isEmpty) return;

      // Find any job assigned to this worker to discover the teamId
      // Jobs are stored at teams/{teamId}/jobs
      // We need to search across all teams — query the collectionGroup
      final jobsSnap = await FirebaseFirestore.instance
          .collectionGroup('jobs')
          .where('assignedWorkerEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (jobsSnap.docs.isNotEmpty) {
        // Path: teams/{teamId}/jobs/{jobId}
        final path = jobsSnap.docs.first.reference.path;
        final parts = path.split('/');
        if (parts.length >= 2) {
          final teamId = parts[1]; // teams/{teamId}/jobs/{jobId}
          await FirebaseFirestore.instance
              .doc(FirestorePaths.user(widget.uid))
              .update({'currentTeamId': teamId});
          return;
        }
      }

      // Fallback: assign to first available team
      final teamsSnap = await FirebaseFirestore.instance
          .collection('teams')
          .limit(1)
          .get();
      if (teamsSnap.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .doc(FirestorePaths.user(widget.uid))
            .update({'currentTeamId': teamsSnap.docs.first.id});
      }
    } catch (_) {
      // silent — will show JoinTeamScreen as fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while resolving, then WorkerGate will rebuild via stream
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
        child: Text(message),
      ),
    );
  }
}

