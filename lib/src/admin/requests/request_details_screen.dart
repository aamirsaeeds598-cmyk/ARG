import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import '../jobs/create_job_screen.dart';
import '../jobs/line_items_screen.dart';
import 'convert_to_quote_screen.dart';
import 'schedule_assessment_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Request Details Screen
// ─────────────────────────────────────────────────────────────────────────────

class RequestDetailsScreen extends StatelessWidget {
  const RequestDetailsScreen({
    super.key,
    required this.teamId,
    required this.requestId,
  });

  final String teamId;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.doc(
      FirestorePaths.teamRequest(teamId, requestId),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor:  Color(0xFFF5F7FA),
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
                  child: Icon(Icons.inbox_outlined,
                      size: 16, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Text(
                  'Request Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 17, color: colorScheme.error),
                  ),
                  tooltip: 'Delete request',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Delete request'),
                        content: const Text(
                            'This will permanently delete the request.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await ref.delete();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: _RequestDetailsBody(
              teamId: teamId,
              requestId: requestId,
              data: data,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _RequestDetailsBody extends StatefulWidget {
  const _RequestDetailsBody({
    required this.teamId,
    required this.requestId,
    required this.data,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic> data;

  @override
  State<_RequestDetailsBody> createState() => _RequestDetailsBodyState();
}

class _RequestDetailsBodyState extends State<_RequestDetailsBody> {
  bool _scheduling = false;

  String _fmt(Timestamp? ts) {
    if (ts == null) return 'Not provided';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openConvertToQuote() {
    final d = widget.data;
    final lineItemsRaw = d['lineItems'];
    final lineItems = lineItemsRaw is List
        ? lineItemsRaw.cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConvertToQuoteScreen(
        teamId: widget.teamId,
        requestId: widget.requestId,
        clientId: (d['clientId'] as String?) ?? '',
        clientName: (d['clientName'] as String?) ?? '',
        clientEmail: (d['clientEmail'] as String?) ?? '',
        clientPhone: (d['clientPhone'] as String?) ?? '',
        serviceDescription: (d['serviceDescription'] as String?) ?? '',
        notes: (d['notes'] as String?) ?? '',
        lineItems: lineItems,
      ),
    ));
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final scheduled = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);

    setState(() => _scheduling = true);
    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamRequest(widget.teamId, widget.requestId))
          .update({'scheduledAt': Timestamp.fromDate(scheduled)});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scheduled for ${_fmt(Timestamp.fromDate(scheduled))}'),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final preferredAtTs = d['preferredAt'];
    final scheduledAtTs = d['scheduledAt'];
    final photoUrlsRaw = d['photoUrls'];
    final photoUrls = photoUrlsRaw is List
        ? photoUrlsRaw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList()
        : const <String>[];

    final clientName  = (d['clientName'] as String?) ?? '-';
    final clientEmail = (d['clientEmail'] as String?) ?? '';
    final clientPhone = (d['clientPhone'] as String?) ?? '';
    final clientId    = (d['clientId'] as String?) ?? '';
    final status      = (d['status'] as String?) ?? 'new';
    final priority    = (d['priority'] as String?) ?? 'normal';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Status + priority badges ────────────────────────────────────
        Row(
          children: [
            _StatusBadge(status: status),
            const SizedBox(width: 8),
            _PriorityBadge(priority: priority),
          ],
        ),
        const SizedBox(height: 16),

        // ── Client card ─────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFF5B7FFF),
          title: 'Client',
          trailing: clientId.isNotEmpty
              ? Icon(Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
          onTap: clientId.isNotEmpty
              ? () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ClientProfileScreen(
              teamId: widget.teamId,
              clientId: clientId,
            ),
          ))
              : null,
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.person_rounded,
                label: 'Name',
                value: clientName,
              ),
              if (clientEmail.isNotEmpty)
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: clientEmail,
                ),
              if (clientPhone.isNotEmpty)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: clientPhone,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Service details ─────────────────────────────────────────────
        _SectionCard(
          icon: Icons.handyman_outlined,
          iconColor: const Color(0xFF7C4DFF),
          title: 'Service Details',
          child: Column(
            children: [
              if ((d['serviceDescription'] as String?)?.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.miscellaneous_services_outlined,
                  label: 'Service',
                  value: d['serviceDescription'] as String,
                ),
              if ((d['serviceCategory'] as String?)?.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: d['serviceCategory'] as String,
                ),
              if ((d['location'] as String?)?.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: d['location'] as String,
                ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Preferred date',
                value: _fmt(preferredAtTs is Timestamp ? preferredAtTs : null),
              ),
              if (scheduledAtTs != null)
                _InfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Scheduled',
                  value: _fmt(scheduledAtTs is Timestamp ? scheduledAtTs : null),
                ),
              if ((d['notes'] as String?)?.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: d['notes'] as String,
                  multiline: true,
                ),
              if ((d['assignedWorkerEmail'] as String?)?.isNotEmpty == true)
                _AssignedWorkerRow(
                  email: d['assignedWorkerEmail'] as String,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Photos ──────────────────────────────────────────────────────
        if (photoUrls.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.photo_library_outlined,
            iconColor: const Color(0xFF00BFA5),
            title: 'Photos / Attachments',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final photo in photoUrls)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _isBase64(photo)
                          ? Image.memory(
                              base64Decode(photo),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              photo,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: Colors.grey),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Assessment ──────────────────────────────────────────────────
        _AssessmentCard(
          teamId: widget.teamId,
          requestId: widget.requestId,
          assessment: d['assessment'] is Map
              ? Map<String, dynamic>.from(d['assessment'] as Map)
              : null,
          fmtTs: _fmt,
        ),
        const SizedBox(height: 12),

        // ── Products / Services ─────────────────────────────────────────
        _ProductsCard(
          teamId: widget.teamId,
          requestId: widget.requestId,
          data: d,
        ),
        const SizedBox(height: 12),

        // ── Actions ─────────────────────────────────────────────────────
        _RequestActions(
          teamId: widget.teamId,
          requestId: widget.requestId,
          data: d,
          onConvertToQuote: _openConvertToQuote,
          onSchedule: _scheduling ? null : _pickSchedule,
        ),
      ],
    );
  }
}

// ── Products card ─────────────────────────────────────────────────────────────

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
    required this.teamId,
    required this.requestId,
    required this.data,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic> data;

  int get _subtotalCents {
    final raw = data['lineItems'];
    final items = raw is List ? raw.cast<Map>() : const <Map>[];
    return items.fold<int>(0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = data['lineItems'];
    final lineItems = raw is List ? raw.cast<Map>() : const <Map>[];

    return Card(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final current = lineItems
              .map((m) => LineItem(
                    name: (m['name'] ?? '').toString(),
                    priceCents: (m['priceCents'] as int?) ?? 0,
                    description: (m['description'] ?? '').toString(),
                  ))
              .toList();
          final result = await Navigator.of(context)
              .push<List<LineItem>>(MaterialPageRoute(
            builder: (_) => LineItemsScreen(initial: current),
          ));
          if (result != null) {
            await FirebaseFirestore.instance
                .doc(FirestorePaths.teamRequest(teamId, requestId))
                .update({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.list_alt_outlined, size: 18),
                const SizedBox(width: 6),
                Text('Products / Services',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 18),
              ]),
              const SizedBox(height: 8),
              if (lineItems.isEmpty)
                Text('Tap to select products / services',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant))
              else ...[
                for (final item in lineItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                          child: Text((item['name'] ?? '').toString())),
                      Text((item['priceCents'] as int? ?? 0) == 0
                          ? 'Free'
                          : '\$${((item['priceCents'] as int) / 100).toStringAsFixed(2)}'),
                    ]),
                  ),
                const Divider(height: 20),
                Row(children: [
                  Text('Subtotal',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    '\$${(_subtotalCents / 100).toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Actions
// ─────────────────────────────────────────────────────────────────────────────

class _RequestActions extends StatefulWidget {
  const _RequestActions({
    required this.teamId,
    required this.requestId,
    required this.data,
    required this.onConvertToQuote,
    required this.onSchedule,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic> data;
  final VoidCallback onConvertToQuote;
  final VoidCallback? onSchedule;

  @override
  State<_RequestActions> createState() => _RequestActionsState();
}

class _RequestActionsState extends State<_RequestActions> {
  bool _savingWorker = false;

  bool get _hasAssessment =>
      widget.data['assessment'] != null ||
          widget.data['scheduledAt'] != null;

  bool get _assessmentCompleted =>
      (widget.data['assessment']?['status'] as String?) == 'completed';

  Future<void> _sendConfirmation() async {
    final clientEmail =
        (widget.data['clientEmail'] as String?)?.trim() ?? '';
    final email =
    clientEmail.isNotEmpty ? clientEmail : 'aamirsaeed598@gmail.com';
    final clientName = (widget.data['clientName'] as String?) ?? 'Client';
    final service =
        (widget.data['serviceDescription'] as String?) ?? 'service';
    final assessment = widget.data['assessment'] as Map?;
    final scheduledTs = assessment?['scheduledAt'];
    String dateStr = 'To be confirmed';
    if (scheduledTs is Timestamp) {
      final d = scheduledTs.toDate();
      dateStr =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    final subject = Uri.encodeComponent('Booking Confirmation');
    final body = Uri.encodeComponent(
      'Dear $clientName,\n\n'
          'Your booking has been confirmed.\n\n'
          'Service: $service\n'
          'Date: $dateStr\n\n'
          'Please reply if you have any questions.\n\n'
          'Thank you.',
    );
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _saveWorker(String email) async {
    setState(() => _savingWorker = true);
    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamRequest(widget.teamId, widget.requestId))
          .update({
        'assignedWorkerEmail': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker assigned.')),
      );
    } finally {
      if (mounted) setState(() => _savingWorker = false);
    }
  }

  Future<void> _completeAssessment() async {
    await FirebaseFirestore.instance
        .doc(FirestorePaths.teamRequest(widget.teamId, widget.requestId))
        .update({'assessment.status': 'completed'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assessment completed.')),
    );
  }

  void _convertToJob() {
    final d = widget.data;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateJobScreen(
        teamId: widget.teamId,
        preselectedClientId: d['clientId'] as String?,
        prefilledTitle: d['serviceDescription'] as String?,
        prefilledDescription: d['notes'] as String?,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentWorker =
        (widget.data['assignedWorkerEmail'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ─────────────────────────────────────────────
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 12),
        //   child: Row(
        //     children: [
        //       Container(
        //         width: 30,
        //         height: 30,
        //         decoration: BoxDecoration(
        //           color: colorScheme.primaryContainer,
        //           borderRadius: BorderRadius.circular(9),
        //         ),
        //         child: Icon(Icons.bolt_rounded,
        //             size: 16, color: colorScheme.onPrimaryContainer),
        //       ),
        //       const SizedBox(width: 10),
        //       Text(
        //         'Actions',
        //         style: Theme.of(context).textTheme.titleSmall?.copyWith(
        //           fontWeight: FontWeight.w700,
        //           letterSpacing: 0.1,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        // if (!_hasAssessment) ...[
        //   _ActionButton(
        //     icon: Icons.assignment_turned_in_outlined,
        //     label: 'Schedule assessment',
        //     color: colorScheme.primary,
        //     filled: false,
        //     onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        //       builder: (_) => ScheduleAssessmentScreen(
        //         teamId: widget.teamId,
        //         requestId: widget.requestId,
        //       ),
        //     )),
        //   ),
        //   const SizedBox(height: 8),
        //   _ActionButton(
        //     icon: Icons.calendar_month_rounded,
        //     label: 'Schedule',
        //     color: colorScheme.primary,
        //     filled: false,
        //     onPressed: widget.onSchedule,
        //   ),
        // ] else ...[
        //   _ActionButton(
        //     icon: Icons.mark_email_read_outlined,
        //     label: 'Confirm booking via email',
        //     color: colorScheme.primary,
        //     filled: true,
        //     onPressed: _sendConfirmation,
        //   ),
        //   const SizedBox(height: 8),
        //
        //   // Assign worker dropdown
        //   StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        //     stream: FirebaseFirestore.instance
        //         .collection('users')
        //         .where('role', isEqualTo: 'worker')
        //         .where('currentTeamId', isEqualTo: widget.teamId)
        //         .snapshots(),
        //     builder: (context, snap) {
        //       final docs = snap.data?.docs ?? [];
        //       final workers = docs.map((d) => (
        //         email: (d.data()['email'] as String?) ?? '',
        //         name: (d.data()['name'] as String?)?.trim() ?? '',
        //       )).where((w) => w.email.isNotEmpty).toList();
        //       if (workers.isEmpty) return const SizedBox.shrink();
        //       return Padding(
        //         padding: const EdgeInsets.only(bottom: 8),
        //         child: DropdownButtonFormField<String>(
        //           initialValue:
        //           currentWorker.isNotEmpty ? currentWorker : null,
        //           decoration: InputDecoration(
        //             labelText: 'Assign worker',
        //             prefixIcon:
        //             const Icon(Icons.badge_outlined, size: 18),
        //             filled: true,
        //             fillColor: colorScheme.surfaceContainerHighest
        //                 .withValues(alpha: 0.4),
        //             border: OutlineInputBorder(
        //               borderRadius: BorderRadius.circular(12),
        //               borderSide: BorderSide(
        //                   color: colorScheme.outlineVariant
        //                       .withValues(alpha: 0.7)),
        //             ),
        //             enabledBorder: OutlineInputBorder(
        //               borderRadius: BorderRadius.circular(12),
        //               borderSide: BorderSide(
        //                   color: colorScheme.outlineVariant
        //                       .withValues(alpha: 0.7)),
        //             ),
        //             focusedBorder: OutlineInputBorder(
        //               borderRadius: BorderRadius.circular(12),
        //               borderSide: BorderSide(
        //                   color: colorScheme.primary, width: 1.5),
        //             ),
        //             contentPadding: const EdgeInsets.symmetric(
        //                 horizontal: 14, vertical: 13),
        //           ),
        //           items: [
        //             const DropdownMenuItem<String>(
        //                 value: null, child: Text('Unassigned')),
        //             for (final w in workers)
        //               DropdownMenuItem(
        //                 value: w.email,
        //                 child: Text(w.name.isNotEmpty ? w.name : w.email),
        //               ),
        //           ],
        //           onChanged: _savingWorker
        //               ? null
        //               : (v) {
        //             if (v != null) _saveWorker(v);
        //           },
        //         ),
        //       );
        //     },
        //   ),
        //
        //   if (!_assessmentCompleted) ...[
        //     _ActionButton(
        //       icon: Icons.check_circle_outline_rounded,
        //       label: 'Complete assessment',
        //       color: const Color(0xFF00897B),
        //       filled: false,
        //       onPressed: _completeAssessment,
        //     ),
        //     const SizedBox(height: 8),
        //   ],
        //
          _ActionButton(
            icon: Icons.work_outline_rounded,
            label: 'Convert to job',
            color: const Color(0xFF7C4DFF),
            filled: false,
            onPressed: _convertToJob,
          ),
          const SizedBox(height: 8),
        // ],

        // Always visible
        _ActionButton(
          icon: Icons.request_quote_rounded,
          label: 'Convert to quote',
          color: const Color(0xFFFF6D3B),
          filled: true,
          onPressed: widget.onConvertToQuote,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assessment Card
// ─────────────────────────────────────────────────────────────────────────────

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.teamId,
    required this.requestId,
    required this.assessment,
    required this.fmtTs,
  });

  final String teamId;
  final String requestId;
  final Map<String, dynamic>? assessment;
  final String Function(Timestamp?) fmtTs;

  Future<void> _complete(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamRequest(teamId, requestId))
          .update({'assessment.status': 'completed'});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment marked as completed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (assessment == null) return const SizedBox.shrink();

    final status       = (assessment!['status'] as String?) ?? 'scheduled';
    final scheduledAtTs = assessment!['scheduledAt'];
    final instructions = (assessment!['instructions'] as String?) ?? '';
    final assignedEmail =
        (assessment!['assignedMemberEmail'] as String?) ?? '-';

    final isCompleted = status == 'completed';
    final isScheduled = status == 'scheduled';

    final (badgeLabel, badgeBg, badgeFg) = isCompleted
        ? ('COMPLETED', const Color(0xFFE8F5E9), const Color(0xFF2E7D32))
        : isScheduled
        ? ('SCHEDULED', const Color(0xFFE3F2FD), const Color(0xFF1565C0))
        : ('PENDING',
    Theme.of(context).colorScheme.surfaceContainerHighest,
    Theme.of(context).colorScheme.onSurfaceVariant);

    final accentColor = isCompleted
        ? const Color(0xFF2E7D32)
        : isScheduled
        ? const Color(0xFF1565C0)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return _SectionCard(
      icon: Icons.assignment_turned_in_outlined,
      iconColor: accentColor,
      title: 'Assessment',
      titleTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(badgeLabel,
            style: TextStyle(
                color: badgeFg,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: fmtTs(
                scheduledAtTs is Timestamp ? scheduledAtTs : null),
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Assigned to',
            value: assignedEmail,
          ),
          if (instructions.isNotEmpty)
            _InfoRow(
              icon: Icons.notes_rounded,
              label: 'Instructions',
              value: instructions,
              multiline: true,
            ),
          if (isScheduled) ...[
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Complete assessment',
              color: const Color(0xFF00897B),
              filled: true,
              onPressed: () => _complete(context),
            ),
          ],
        ],
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
    this.trailing,
    this.titleTrailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? titleTrailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
                    const Spacer(),
                    if (titleTrailing != null) titleTrailing!,
                    if (trailing != null) trailing!,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────────────

class _AssignedWorkerRow extends StatelessWidget {
  const _AssignedWorkerRow({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(),
      builder: (context, snap) {
        final name = snap.data?.docs.firstOrNull?.data()['name'] as String?;
        final display = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : email;
        return _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Assigned to',
          value: display,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
        multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
              maxLines: multiline ? 6 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    )
        : OutlinedButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: BorderSide(color: color.withOpacity(0.5)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, letterSpacing: 0.1)),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status & Priority Badges
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'new'         => ('NEW', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'in_progress' => ('IN PROGRESS', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'completed'   => ('COMPLETED', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'cancelled'   => ('CANCELLED', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _             => ('${status.toUpperCase()}',
      Theme.of(context).colorScheme.surfaceContainerHighest,
      Theme.of(context).colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (priority.toLowerCase()) {
      'high'   => ('HIGH', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      'urgent' => ('URGENT', const Color(0xFFFFEBEE), const Color(0xFF7F0000)),
      'low'    => ('LOW', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      _        => ('NORMAL', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Profile Screen (inline)
// ── Base64 helper ─────────────────────────────────────────────────────────────

bool _isBase64(String s) {
  if (s.length < 100) return false;
  try {
    base64Decode(s);
    return true;
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ClientProfileScreen extends StatelessWidget {
  const _ClientProfileScreen({
    required this.teamId,
    required this.clientId,
  });

  final String teamId;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.doc(
      FirestorePaths.teamClient(teamId, clientId),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Client Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snapshot.data!.data() ?? {};
          final name  = (d['name'] as String?) ?? 'Client';
          final email = (d['email'] as String?) ?? '';
          final phone = (d['phone'] as String?) ?? '';
          final createdAtTs = d['createdAt'];
          final createdAt = createdAtTs is Timestamp
              ? createdAtTs.toDate()
              : null;

          const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          final createdText = createdAt == null
              ? '-'
              : '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';

          final initials = name.trim().isNotEmpty
              ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
              : '?';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Hero banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colorScheme.onPrimary.withOpacity(0.3),
                            width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(initials,
                          style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text('Client since $createdText',
                              style: TextStyle(
                                  color: colorScheme.onPrimary.withOpacity(0.75),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Contact info
              _SectionCard(
                icon: Icons.contact_phone_outlined,
                iconColor: const Color(0xFF5B7FFF),
                title: 'Contact',
                child: Column(
                  children: [
                    if (email.isNotEmpty)
                      _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email),
                    if (phone.isNotEmpty)
                      _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone),
                    if (email.isEmpty && phone.isEmpty)
                      Text('No contact info on file.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Jobs
              _ClientJobsCard(teamId: teamId, clientId: clientId),
            ],
          );
        },
      ),
    );
  }
}

class _ClientJobsCard extends StatelessWidget {
  const _ClientJobsCard({required this.teamId, required this.clientId});
  final String teamId;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .where('clientId', isEqualTo: clientId)
        .limit(20);

    return _SectionCard(
      icon: Icons.work_outline_rounded,
      iconColor: const Color(0xFF7C4DFF),
      title: 'Jobs',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          final colorScheme = Theme.of(context).colorScheme;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Text(
              snapshot.error.toString(),
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort by updatedAt descending in Dart to avoid composite index requirement
          final sortedDocs = [...docs];
          sortedDocs.sort((a, b) {
            final aVal = a.data()['updatedAt'];
            final bVal = b.data()['updatedAt'];
            if (aVal == null && bVal == null) return 0;
            if (aVal == null) return 1;
            if (bVal == null) return -1;
            final aTs = aVal is Timestamp ? aVal.millisecondsSinceEpoch : 0;
            final bTs = bVal is Timestamp ? bVal.millisecondsSinceEpoch : 0;
            return bTs.compareTo(aTs); // descending
          });

          if (sortedDocs.isEmpty) {
            return Text(
              'No jobs for this client yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          }

          return Column(
            children: [
              for (int i = 0; i < sortedDocs.length; i++) ...[
                _InfoRow(
                  icon: Icons.work_outline_rounded,
                  label: (sortedDocs[i].data()['status'] as String?) ?? '-',
                  value: (sortedDocs[i].data()['title'] as String?) ?? 'Job',
                ),
                if (i < sortedDocs.length - 1)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}