import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/firestore_paths.dart';
import '../jobs/job_details_screen.dart';
import 'worker_select_job_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Worker Profile Screen
// ─────────────────────────────────────────────────────────────────────────────

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({
    super.key,
    required this.teamId,
    required this.workerUid,
    required this.workerEmail,
  });

  final String teamId;
  final String workerUid;
  final String? workerEmail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workerRef =
    FirebaseFirestore.instance.doc(FirestorePaths.user(workerUid));

    final jobsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .where('assignedWorkerId', isEqualTo: workerUid)
        .orderBy('updatedAt', descending: true);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 18, color: colorScheme.onSurface),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.badge_outlined,
                  size: 16, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Text(
              'Worker Profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: workerRef.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final email =
                (data?['email'] as String?) ?? workerEmail ?? workerUid;
            final name = (data?['name'] as String?)?.trim() ?? '';
            final displayName =
            name.isNotEmpty ? name : email.split('@').first;
            final currentTeam =
                (data?['currentTeamId'] as String?) ?? 'Not assigned';
            final role = (data?['role'] as String?) ?? 'worker';

            final initials = displayName.trim().isNotEmpty
                ? displayName
                .trim()
                .split(' ')
                .map((e) => e[0])
                .take(2)
                .join()
                .toUpperCase()
                : 'W';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Hero banner ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C4DFF),
                        const Color(0xFF7C4DFF).withOpacity(0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Worker info card ───────────────────────────────────
                _SectionCard(
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF7C4DFF),
                  title: 'Worker Details',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.tag_rounded,
                        label: 'Worker ID',
                        value: workerUid,
                        copyable: true,
                      ),
                      _InfoRow(
                        icon: Icons.groups_2_outlined,
                        label: 'Current team',
                        value: currentTeam,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Assign job button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkerSelectJobScreen(
                            teamId: teamId,
                            workerUid: workerUid,
                            workerEmail: email,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.assignment_ind_rounded, size: 18),
                    label: const Text(
                      'Assign Job',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Assigned jobs ──────────────────────────────────────
                _SectionCard(
                  icon: Icons.work_outline_rounded,
                  iconColor: const Color(0xFF5B7FFF),
                  title: 'Assigned Jobs',
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: jobsQuery.snapshots(),
                    builder: (context, snapshot) {
                      final colorScheme =
                          Theme.of(context).colorScheme;

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final docs =
                          snapshot.data?.docs ?? const [];

                      if (docs.isEmpty) {
                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No jobs assigned yet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                color:
                                colorScheme.onSurfaceVariant),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < docs.length; i++) ...[
                            _JobRow(
                              doc: docs[i],
                              teamId: teamId,
                              index: i,
                            ),
                            if (i < docs.length - 1)
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.3),
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job Row
// ─────────────────────────────────────────────────────────────────────────────

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.doc,
    required this.teamId,
    required this.index,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String teamId;
  final int index;

  static const _accentColors = [
    Color(0xFF5B7FFF),
    Color(0xFF7C4DFF),
    Color(0xFF00BFA5),
    Color(0xFFFF6D3B),
    Color(0xFFFF4081),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final data = doc.data();

    final title = (data['title'] as String?) ?? 'Job';
    final status = (data['status'] as String?) ?? 'pending';
    final accent = _accentColors[index % _accentColors.length];

    final (badgeLabel, badgeBg, badgeFg) = switch (status.toLowerCase()) {
      'done'        => ('DONE', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'in_progress' => ('IN PROGRESS', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'cancelled'   => ('CANCELLED', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _             => ('PENDING', colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                JobDetailsScreen(teamId: teamId, jobId: doc.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.work_outline_rounded,
                    size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy_rounded,
                    size: 13, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}