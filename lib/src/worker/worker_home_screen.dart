import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore_paths.dart';
import '../admin/jobs/job_status.dart';
import 'worker_job_details_screen.dart';
import 'worker_request_details_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class _C {
  static const ink        = Color(0xFF0F1117);
  static const surface    = Color(0xFFF7F8FA);
  static const card       = Color(0xFFFFFFFF);
  static const accent     = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEFF4FF);
  static const muted      = Color(0xFF6B7280);
  static const border     = Color(0xFFE5E7EB);
  static const error      = Color(0xFFDC2626);
  static const errorSoft  = Color(0xFFFEF2F2);
}

// ── Status style helpers ──────────────────────────────────────────────────────

(Color bg, Color fg, IconData icon) _statusStyle(JobStatus status) {
  switch (status.value.toLowerCase()) {
    case 'open':
      return (const Color(0xFFDCEDFF), const Color(0xFF1D4ED8),
      Icons.radio_button_unchecked_rounded);
    case 'in_progress':
    case 'inprogress':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E),
      Icons.timelapse_rounded);
    case 'completed':
    case 'done':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534),
      Icons.check_circle_rounded);
    case 'cancelled':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B),
      Icons.cancel_rounded);
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF374151),
      Icons.help_outline_rounded);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    final user       = FirebaseAuth.instance.currentUser;
    final userEmail  = (user?.email ?? '').trim().toLowerCase();
    final userName   = user?.displayName ?? userEmail.split('@').first;

    final jobsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .where('assignedWorkerEmail', isEqualTo: userEmail)
        .limit(100);

    final requestsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamRequests(teamId))
        .where('assignedWorkerEmail', isEqualTo: userEmail)
        .limit(50);

    return Scaffold(
      backgroundColor:  Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header(userName: userName, userEmail: userEmail)),

            // ── Requests section ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: requestsQuery.snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 2),
                          child: Text('Assigned Requests',
                              style: TextStyle(
                                  color: _C.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                        for (final d in docs)
                          _RequestTile(
                            teamId: teamId,
                            requestId: d.id,
                            data: d.data(),
                          ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 2),
                          child: Text('Assigned Jobs',
                              style: TextStyle(
                                  color: _C.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ── Jobs list ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: jobsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: _LoadingState());
                  }

                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: _ErrorCard(message: snapshot.error.toString()),
                    );
                  }

                  final docs = [...(snapshot.data?.docs ?? const [])]
                    ..sort((a, b) {
                      final aTs = a.data()['updatedAt'];
                      final bTs = b.data()['updatedAt'];
                      final aT = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
                      final bT = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
                      return bT.compareTo(aT);
                    });

                  if (docs.isEmpty) {
                    return const SliverToBoxAdapter(child: _EmptyState());
                  }

                  return SliverList.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return _WorkerJobTile(
                          teamId: teamId, jobId: d.id, data: d.data());
                    },
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.userName, required this.userEmail});
  final String userName;
  final String userEmail;

  @override
  Widget build(BuildContext context) {
    final initial =
    userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : '?';

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          // Avatar
          Container(
            width:  48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      _C.accent.withOpacity(0.30),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          const SizedBox(width: 14),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $userName',
                  style: const TextStyle(
                    color:       _C.ink,
                    fontSize:    16,
                    fontWeight:  FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(userEmail,
                    style: const TextStyle(color: _C.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Sign out
          GestureDetector(
            onTap: () => FirebaseAuth.instance.signOut(),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color:        _C.errorSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.error.withOpacity(0.15)),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 18, color: _C.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.count});
  final String text;
  final int    count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                color:       _C.ink,
                fontSize:    13,
                fontWeight:  FontWeight.w700,
                letterSpacing: -0.1,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:        _C.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color:      _C.accent,
                fontSize:   11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worker Job Tile ───────────────────────────────────────────────────────────

class _WorkerJobTile extends StatelessWidget {
  const _WorkerJobTile({
    required this.teamId,
    required this.jobId,
    required this.data,
  });

  final String             teamId;
  final String             jobId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title       = (data['title']    as String?) ?? 'Untitled job';
    final address     = (data['propertyAddress'] as String?)
        ?? (data['location'] as String?) ?? '';
    final status      = JobStatus.fromValue(data['status'] as String?);
    final ts          = data['scheduledAt'];
    final scheduledAt = ts is Timestamp ? ts.toDate() : null;

    final (statusBg, statusFg, statusIcon) = _statusStyle(status);

    String scheduleText;
    if (scheduledAt == null) {
      scheduleText = 'Not scheduled';
    } else {
      scheduleText =
      '${scheduledAt.year}-'
          '${scheduledAt.month.toString().padLeft(2, '0')}-'
          '${scheduledAt.day.toString().padLeft(2, '0')}  '
          '${scheduledAt.hour.toString().padLeft(2, '0')}:'
          '${scheduledAt.minute.toString().padLeft(2, '0')}';
    }

    return Material(
      color:        _C.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                WorkerJobDetailsScreen(teamId: teamId, jobId: jobId),
          ),
        ),
        splashColor:    _C.accentSoft,
        highlightColor: _C.accentSoft.withOpacity(0.5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top: title + status ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job icon badge
                    Container(
                      width:  40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:        _C.accentSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.assignment_rounded,
                          size: 20, color: _C.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color:       _C.ink,
                              fontSize:    14,
                              fontWeight:  FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 12, color: _C.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(
                                        color: _C.muted, fontSize: 12),
                                    maxLines:  1,
                                    overflow:  TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color:        statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusFg),
                          const SizedBox(width: 4),
                          Text(
                            status.value.toUpperCase(),
                            style: TextStyle(
                              color:       statusFg,
                              fontSize:    10,
                              fontWeight:  FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────
              Container(height: 1, color: _C.border),

              // ── Bottom: schedule + chevron ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color:        scheduledAt == null
                            ? _C.surface
                            : _C.accentSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size:  12,
                        color: scheduledAt == null ? _C.muted : _C.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      scheduleText,
                      style: TextStyle(
                        color:      scheduledAt == null
                            ? _C.muted
                            : _C.ink,
                        fontSize:   12,
                        fontWeight: scheduledAt == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width:  26,
                      height: 26,
                      decoration: BoxDecoration(
                        color:        _C.accentSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: _C.accent, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Request Tile ──────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.teamId,
    required this.requestId,
    required this.data,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final clientName = (data['clientName'] as String?) ?? 'Client';
    final service    = (data['serviceDescription'] as String?) ?? '';
    final status     = (data['status'] as String?) ?? 'new';
    final assessment = data['assessment'] as Map?;
    final assessmentStatus = (assessment?['status'] as String?) ?? '';
    final hasAssessment = assessment != null;
    final isCompleted = assessmentStatus == 'completed';

    final chipColor = isCompleted
        ? Colors.green
        : hasAssessment
            ? _C.accent
            : _C.muted;
    final chipLabel = isCompleted
        ? 'DONE'
        : hasAssessment
            ? 'SCHEDULED'
            : status.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorkerRequestDetailsScreen(
              teamId: teamId,
              requestId: requestId,
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.inbox_outlined,
                      size: 20, color: _C.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              color: _C.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (service.isNotEmpty)
                        Text(service,
                            style: const TextStyle(
                                color: _C.muted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(chipLabel,
                      style: TextStyle(
                          color: chipColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _C.accent, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.accent),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color:        _C.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width:  68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF4FF), Color(0xFFDBEAFE)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: _C.accent.withOpacity(0.15), width: 1.5),
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 28, color: _C.accent),
          ),
          const SizedBox(height: 18),
          const Text(
            'No jobs assigned',
            style: TextStyle(
              color:       _C.ink,
              fontSize:    16,
              fontWeight:  FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jobs assigned to you will\nappear here.',
            style: TextStyle(
                color: _C.muted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _C.errorSoft,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _C.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        _C.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: _C.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: _C.error, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}