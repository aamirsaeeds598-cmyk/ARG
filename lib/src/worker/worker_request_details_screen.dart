import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/jobs/line_items_screen.dart';
import '../data/firestore_paths.dart';

// ── Design tokens (same as worker job details) ────────────────────────────────
class _C {
  static const ink         = Color(0xFF0F1117);
  static const surface     = Color(0xFFF7F8FA);
  static const card        = Color(0xFFFFFFFF);
  static const accent      = Color(0xFF2563EB);
  static const accentSoft  = Color(0xFFEFF4FF);
  static const muted       = Color(0xFF6B7280);
  static const border      = Color(0xFFE5E7EB);
  static const success     = Color(0xFF16A34A);
}

class WorkerRequestDetailsScreen extends StatelessWidget {
  const WorkerRequestDetailsScreen({
    super.key,
    required this.teamId,
    required this.requestId,
  });

  final String teamId;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .doc(FirestorePaths.teamRequest(teamId, requestId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _C.accent),
            ),
          );
        }
        final d = snapshot.data!.data() ?? {};
        return _Body(
            teamId: teamId, requestId: requestId, data: d, ref: ref);
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.teamId,
    required this.requestId,
    required this.data,
    required this.ref,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> ref;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _completing = false;
  bool _scheduling = false;

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _completeAssessment() async {
    setState(() => _completing = true);
    try {
      await widget.ref.update({'assessment.status': 'completed'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment completed.')));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _scheduleAssessment() async {
    final now = DateTime.now();

    // Pick date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _C.accent,
              ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    // Pick time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _C.accent,
              ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final scheduledAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _scheduling = true);
    try {
      final existing = widget.data['assessment'];
      final Map<String, dynamic> assessmentData =
          existing is Map ? Map<String, dynamic>.from(existing) : {};

      assessmentData['scheduledAt'] = Timestamp.fromDate(scheduledAt);
      assessmentData['status'] = 'scheduled';
      assessmentData['scheduledByWorker'] = true;

      await widget.ref.update({
        'assessment': assessmentData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Assessment scheduled successfully.'),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  Future<void> _sendConfirmation() async {
    final d = widget.data;
    String email = (d['clientEmail'] as String?)?.trim() ?? '';
    if (email.isEmpty) email = 'aamirsaeed598@gmail.com';

    final clientName = (d['clientName'] as String?) ?? 'Client';
    final service    = (d['serviceDescription'] as String?) ?? 'service';
    final scheduledTs = d['scheduledAt'];
    String dateStr = 'To be confirmed';
    if (scheduledTs is Timestamp) {
      final dt = scheduledTs.toDate();
      dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }

    final subject = Uri.encodeComponent('Booking Confirmation');
    final body = Uri.encodeComponent(
      'Dear $clientName,\n\n'
      'Your booking has been confirmed.\n\n'
      'Service: $service\n'
      'Date: $dateStr\n\n'
      'Please reply if you have any questions.\n\nThank you.',
    );
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')));
    }
  }

  // ── Section wrapper ───────────────────────────────────────────────────────
  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                color: _C.accentSoft,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Row(children: [
                Icon(icon, size: 15, color: _C.accent),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: _C.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _C.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: _C.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _C.muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: _C.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    if (filled) {
      return SizedBox(
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onTap == null
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: onTap == null ? _C.border : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: _C.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ElevatedButton.icon(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(icon, color: Colors.white, size: 18),
            label: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _C.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _C.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _C.accent),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: _C.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final clientName  = (d['clientName']  as String?) ?? '—';
    final clientEmail = (d['clientEmail'] as String?) ?? '';
    final clientPhone = (d['clientPhone'] as String?) ?? '';
    final service     = (d['serviceDescription'] as String?) ?? '—';
    final location    = (d['location']    as String?) ?? '';
    final notes       = (d['notes']       as String?) ?? '';
    final priority    = (d['priority']    as String?) ?? 'normal';
    final status      = (d['status']      as String?) ?? 'new';
    final scheduledTs = d['scheduledAt'];

    // Line items
    final lineItemsRaw = d['lineItems'];
    final lineItems = lineItemsRaw is List
        ? lineItemsRaw.cast<Map>()
        : const <Map>[];
    final subtotalCents = lineItems.fold<int>(
        0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));

    // Assessment
    final assessment = d['assessment'] is Map
        ? Map<String, dynamic>.from(d['assessment'] as Map)
        : null;
    final assessmentStatus = (assessment?['status'] as String?) ?? '';
    final assessmentTs     = assessment?['scheduledAt'] ?? d['scheduledAt'];
    final instructions     = (assessment?['instructions'] as String?) ?? '';
    final assignedEmail    = (assessment?['assignedMemberEmail'] as String?) ?? '';
    final hasAssessment    = assessment != null || d['scheduledAt'] != null;
    final isCompleted      = assessmentStatus == 'completed';
    final assessColor      = isCompleted ? _C.success : _C.accent;

    // Worker self-scheduling: show if request is assigned but no scheduledAt set
    final assignedWorkerEmail = (d['assignedWorkerEmail'] as String?) ?? '';
    final hasNoScheduledTime  = assessmentTs == null;
    final scheduledByWorker   = (assessment?['scheduledByWorker'] as bool?) ?? false;
    // Show schedule-by-worker card when:
    //  - request is assigned (has assessment map OR assignedWorkerEmail set)
    //  - no time has been set yet by admin
    final showWorkerSchedule  = !isCompleted &&
        hasNoScheduledTime &&
        (assessment != null || assignedWorkerEmail.isNotEmpty);

    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        backgroundColor: _C.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _C.ink),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request details',
                style: TextStyle(
                    color: _C.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Assessment & service info',
                style: TextStyle(color: _C.muted, fontSize: 11)),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // ── Client ────────────────────────────────────────────────
            _section(
              title: 'Client',
              icon: Icons.person_outline,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(clientName, clientEmail.isNotEmpty ? clientEmail : '—',
                        Icons.person_rounded),
                    if (clientPhone.isNotEmpty)
                      _infoRow('Phone', clientPhone, Icons.phone_rounded),
                  ],
                ),
              ),
            ),

            // ── Service details ───────────────────────────────────────
            _section(
              title: 'Service details',
              icon: Icons.home_repair_service_outlined,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Service', service, Icons.build_outlined),
                    if (location.isNotEmpty)
                      _infoRow('Location', location, Icons.location_on_outlined),
                    _infoRow('Priority', priority, Icons.flag_outlined),
                    _infoRow('Status', status, Icons.info_outline),
                    if (scheduledTs is Timestamp)
                      _infoRow('Scheduled', _fmt(scheduledTs),
                          Icons.calendar_today_outlined),
                    if (notes.isNotEmpty)
                      _infoRow('Notes', notes, Icons.notes_rounded),
                  ],
                ),
              ),
            ),

            // ── Products / Services ───────────────────────────────────
            _section(
              title: 'Products & Services',
              icon: Icons.receipt_long_outlined,
              child: InkWell(
                onTap: () async {
                  final current = lineItems
                      .map((m) => LineItem(
                            name: (m['name'] ?? '').toString(),
                            priceCents: (m['priceCents'] as int?) ?? 0,
                            description:
                                (m['description'] ?? '').toString(),
                          ))
                      .toList();
                  final result = await Navigator.of(context)
                      .push<List<LineItem>>(MaterialPageRoute(
                    builder: (_) => LineItemsScreen(initial: current),
                  ));
                  if (result != null) {
                    await widget.ref.update({
                      'lineItems': result
                          .map((i) => {
                                'name': i.name,
                                'priceCents': i.priceCents,
                                'description': i.description,
                              })
                          .toList(),
                      'subtotalCents': result.fold<int>(
                          0, (acc, i) => acc + i.priceCents),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: lineItems.isEmpty
                      ? Row(children: [
                          const Icon(Icons.add_circle_outline,
                              size: 16, color: _C.accent),
                          const SizedBox(width: 8),
                          const Text('Tap to select products / services',
                              style: TextStyle(
                                  color: _C.accent, fontSize: 13)),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              size: 16, color: _C.muted),
                        ])
                      : Column(
                          children: [
                            for (final item in lineItems)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5),
                                child: Row(children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                        color: _C.accent,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(
                                          (item['name'] ?? '').toString(),
                                          style: const TextStyle(
                                              color: _C.ink,
                                              fontSize: 13))),
                                  Text(
                                    (item['priceCents'] as int? ?? 0) == 0
                                        ? 'Free'
                                        : '\$${((item['priceCents'] as int) / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: _C.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right,
                                      size: 14, color: _C.muted),
                                ]),
                              ),
                            Container(
                                height: 1,
                                color: _C.border,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8)),
                            Row(children: [
                              const Text('Subtotal',
                                  style: TextStyle(
                                      color: _C.muted, fontSize: 13)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _C.accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '\$${(subtotalCents / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: _C.accent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ]),
                          ],
                        ),
                ),
              ),
            ),

            // ── Assessment ────────────────────────────────────────────
            if (hasAssessment || showWorkerSchedule)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: assessColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: assessColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(13),
                            topRight: Radius.circular(13),
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.assignment_turned_in_outlined,
                              size: 15, color: assessColor),
                          const SizedBox(width: 8),
                          Text('Assessment',
                              style: TextStyle(
                                  color: assessColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: assessColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              showWorkerSchedule
                                  ? 'PENDING'
                                  : assessmentStatus.toUpperCase(),
                              style: TextStyle(
                                  color: assessColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ]),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── No time set yet → worker can schedule ──
                            if (showWorkerSchedule) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.schedule_rounded,
                                        size: 15,
                                        color: Color(0xFFEA580C)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'No assessment time has been set yet. You can schedule it yourself.',
                                      style: TextStyle(
                                          color: Color(0xFFEA580C),
                                          fontSize: 12,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _actionBtn(
                                icon: Icons.calendar_month_outlined,
                                label: _scheduling
                                    ? 'Scheduling...'
                                    : 'Schedule assessment',
                                onTap: _scheduling ? null : _scheduleAssessment,
                                filled: true,
                              ),
                            ],

                            // ── Time is set → show details ──────────────
                            if (!showWorkerSchedule) ...[
                              if (assessmentTs is Timestamp)
                                _infoRow('Date', _fmt(assessmentTs),
                                    Icons.calendar_today_outlined),
                              if (scheduledByWorker) ...[
                                const SizedBox(height: 6),
                                _infoRow('Scheduled by', 'You (worker)',
                                    Icons.person_pin_outlined),
                              ],
                              if (assignedEmail.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _infoRow('Assigned to', assignedEmail,
                                    Icons.badge_outlined),
                              ],
                              if (instructions.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _infoRow('Instructions', instructions,
                                    Icons.notes_rounded),
                              ],
                              if (!isCompleted) ...[
                                const SizedBox(height: 12),
                                // Allow worker to reschedule if they set the time
                                if (scheduledByWorker) ...[
                                  _actionBtn(
                                    icon: Icons.edit_calendar_outlined,
                                    label: _scheduling
                                        ? 'Rescheduling...'
                                        : 'Reschedule',
                                    onTap: _scheduling
                                        ? null
                                        : _scheduleAssessment,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                _actionBtn(
                                  icon: Icons.check_circle_outline,
                                  label: _completing
                                      ? 'Completing...'
                                      : 'Complete assessment',
                                  onTap: _completing
                                      ? null
                                      : _completeAssessment,
                                  filled: true,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Send booking confirmation ──────────────────────────────
            if (!isCompleted)
              _actionBtn(
                icon: Icons.mark_email_read_outlined,
                label: 'Send booking confirmation',
                onTap: _sendConfirmation,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
