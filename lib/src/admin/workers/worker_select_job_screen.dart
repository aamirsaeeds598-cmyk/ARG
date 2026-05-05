import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../jobs/create_job_screen.dart';

class WorkerSelectJobScreen extends StatelessWidget {
  const WorkerSelectJobScreen({
    super.key,
    required this.teamId,
    required this.workerUid,
    required this.workerEmail,
  });

  final String teamId;
  final String workerUid;
  final String? workerEmail;

  Future<void> _assignExistingJob(
      BuildContext context, {
        required String jobId,
      }) async {
    final db = FirebaseFirestore.instance;
    final jobRef = db.doc(FirestorePaths.teamJob(teamId, jobId));
    final userRef = db.doc(FirestorePaths.user(workerUid));
    final memberRef = db.doc(FirestorePaths.teamMember(teamId, workerUid));

    await db.runTransaction((tx) async {
      tx.update(jobRef, {
        'assignedWorkerId': workerUid,
        'assignedWorkerEmail': workerEmail,
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef,
        {
          'currentTeamId': teamId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        memberRef,
        {
          'uid': workerUid,
          'email': workerEmail,
          'role': 'worker',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final jobsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .orderBy('updatedAt', descending: true)
        .limit(100);

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Assign Job',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Worker info + create job card ──
            _WorkerCard(
              workerUid: workerUid,
              workerEmail: workerEmail,
              onCreateJob: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateJobScreen(teamId: teamId),
                  ),
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Section header ──
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Unassigned Jobs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Jobs stream ──
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: jobsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingState();
                }

                if (snapshot.hasError) {
                  log(snapshot.error.toString());
                  return _ErrorState(message: snapshot.error.toString());
                }

                final docs = (snapshot.data?.docs ?? []).where((d) {
                  final assignedId = d.data()['assignedWorkerId'];
                  return assignedId == null || (assignedId as String).isEmpty;
                }).toList();

                if (docs.isEmpty) {
                  return const _EmptyState();
                }

                return Column(
                  children: [
                    for (final d in docs)
                      _JobCard(
                        jobId: d.id,
                        title: (d.data()['title'] as String?) ?? 'Untitled Job',
                        onAssign: () =>
                            _assignExistingJob(context, jobId: d.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Worker info + create job card
// ─────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.workerUid,
    required this.workerEmail,
    required this.onCreateJob,
  });

  final String workerUid;
  final String? workerEmail;
  final VoidCallback onCreateJob;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + identity row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerEmail ?? 'Worker',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: colorScheme.outlineVariant.withOpacity(0.4), height: 1),
          const SizedBox(height: 20),

          // Create job button
          FilledButton.icon(
            onPressed: onCreateJob,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create New Job'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Hint text
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'After creating a job, pick it from the list below to assign.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual job card
// ─────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.jobId,
    required this.title,
    required this.onAssign,
  });

  final String jobId;
  final String title;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.work_outline_rounded,
            size: 20,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            jobId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: onAssign,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loading state
// ─────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading jobs…',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 28,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No unassigned jobs',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a new job above and it will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}