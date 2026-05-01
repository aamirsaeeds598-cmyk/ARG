import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/jobs/job_status.dart';
import '../admin/jobs/line_items_screen.dart';
import '../admin/jobs/visit_details_screen.dart';
import '../data/firestore_paths.dart';

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
  static const success    = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
}

(Color bg, Color fg) _statusColors(JobStatus s) {
  switch (s.value.toLowerCase()) {
    case 'open':
      return (const Color(0xFFDCEDFF), const Color(0xFF1D4ED8));
    case 'in_progress':
    case 'inprogress':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'done':
    case 'completed':
      return (_C.successSoft, _C.success);
    case 'cancelled':
      return (_C.errorSoft, _C.error);
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF374151));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class WorkerJobDetailsScreen extends StatefulWidget {
  const WorkerJobDetailsScreen({
    super.key,
    required this.teamId,
    required this.jobId,
  });

  final String teamId;
  final String jobId;

  @override
  State<WorkerJobDetailsScreen> createState() => _WorkerJobDetailsScreenState();
}

class _WorkerJobDetailsScreenState extends State<WorkerJobDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
          .update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendConfirmation(Map<String, dynamic> data) async {
    final clientId = data['clientId'] as String?;
    String clientEmail = (data['email'] as String?)?.trim() ?? '';
    if (clientEmail.isEmpty && clientId != null && clientId.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .doc(FirestorePaths.teamClient(widget.teamId, clientId))
          .get();
      clientEmail = (snap.data()?['email'] as String?)?.trim() ?? '';
    }
    if (clientEmail.isEmpty) clientEmail = 'aamirsaeed598@gmail.com';

    final title = (data['title'] as String?) ?? 'Job';
    final scheduledTs = data['scheduledAt'];
    String dateStr = 'To be confirmed';
    if (scheduledTs is Timestamp) {
      final d = scheduledTs.toDate();
      dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    final salesPerson = (data['salesPersonName'] as String?) ?? '';
    final subject = Uri.encodeComponent('Booking Confirmation: $title');
    final body = Uri.encodeComponent(
      'Dear Client,\n\n'
      'Your booking has been confirmed.\n\n'
      'Job: $title\n'
      'Date: $dateStr\n'
      '${salesPerson.isNotEmpty ? 'Sales person: $salesPerson\n' : ''}'
      '\nPlease reply if you have any questions.\n\nThank you.',
    );
    final uri = Uri.parse('mailto:$clientEmail?subject=$subject&body=$body');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')));
    }
  }

  Future<void> _completeAssessment() async {
    await FirebaseFirestore.instance
        .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
        .update({'assessment.status': 'completed'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment completed.')));
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final jobRef = FirebaseFirestore.instance
        .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: jobRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor:  Color(0xFFF5F7FA),
            body: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _C.accent),
            ),
          );
        }

        final data             = snapshot.data!.data() ?? {};
        final title            = (data['title']           as String?) ?? 'Job';
        final description      = (data['description']     as String?) ?? '';
        final location         = (data['location']        as String?) ?? '';
        final propertyAddress  = (data['propertyAddress'] as String?) ?? '';
        final phone            = (data['phone']           as String?) ?? '';
        final email            = (data['email']           as String?) ?? '';
        final salesPerson      = (data['salesPersonName'] as String?) ?? '';
        final status           = JobStatus.fromValue(data['status'] as String?);
        final isClosed         = status == JobStatus.done;
        final fromQuote        = data['sourceQuoteId'] != null;
        final scheduledTs      = data['scheduledAt'];
        final scheduledAt      = scheduledTs is Timestamp ? scheduledTs.toDate() : null;
        final endTs            = data['scheduledEndTime'];
        final endTime          = endTs is Timestamp ? endTs.toDate() : null;
        final priceCents       = data['priceCents'] as int?;
        final signature        = data['signature']  as String?;
        final lineItemsRaw     = data['lineItems'];
        final lineItems        = lineItemsRaw is List
            ? lineItemsRaw.cast<Map>()
            : const <Map>[];
        final subtotalCents    = lineItems.fold<int>(
            0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));

        final (statusBg, statusFg) = _statusColors(status);

        return Scaffold(
          backgroundColor:  Color(0xFFF5F7FA),
          appBar: _buildAppBar(title, fromQuote, isClosed, statusBg, statusFg, status),
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [

                  // ── Job Details ──────────────────────────────────────
                  _buildSection(
                    title: 'Job Details',
                    icon:  Icons.work_rounded,
                    child: _buildInfoGrid(
                      entries: [
                        if (salesPerson.isNotEmpty)
                          _InfoEntry('Sales person', salesPerson,
                              Icons.badge_rounded),
                        if (description.isNotEmpty)
                          _InfoEntry('Instructions', description,
                              Icons.notes_rounded),
                        if (propertyAddress.isNotEmpty)
                          _InfoEntry('Address', propertyAddress,
                              Icons.location_on_rounded),
                        if (location.isNotEmpty)
                          _InfoEntry('Location', location,
                              Icons.map_rounded),
                        if (phone.isNotEmpty)
                          _InfoEntry('Phone', phone,
                              Icons.phone_rounded),
                        if (email.isNotEmpty)
                          _InfoEntry('Email', email,
                              Icons.email_rounded),
                      ],
                    ),
                  ),

                  // ── Status ───────────────────────────────────────────
                  _buildSection(
                    title: 'Status',
                    icon:  Icons.flag_rounded,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:        statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.value.toUpperCase(),
                              style: TextStyle(
                                color:       statusFg,
                                fontSize:    12,
                                fontWeight:  FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (isClosed) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.check_circle_rounded,
                                color: _C.success, size: 18),
                            const SizedBox(width: 6),
                            const Text('Job completed',
                                style: TextStyle(
                                  color:      _C.success,
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Schedule ─────────────────────────────────────────
                  _buildSection(
                    title: 'Schedule',
                    icon:  Icons.calendar_month_rounded,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _scheduleRow(
                            icon:     Icons.play_arrow_rounded,
                            label:    'Start',
                            value:    scheduledAt != null
                                ? _fmtDate(scheduledAt)
                                : 'Not scheduled',
                            hasValue: scheduledAt != null,
                          ),
                          if (endTime != null) ...[
                            const SizedBox(height: 10),
                            _scheduleRow(
                              icon:     Icons.stop_rounded,
                              label:    'End',
                              value:    _fmtDate(endTime),
                              hasValue: true,
                            ),
                          ],
                          // Worker can set schedule if not set
                          if (!isClosed && scheduledAt == null) ...[
                            const SizedBox(height: 12),
                            _outlinedActionBtn(
                              icon: Icons.event,
                              label: 'Set schedule time',
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                      const Duration(days: 365)),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365 * 5)),
                                );
                                if (date == null || !context.mounted) return;
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time == null) return;
                                await _update({
                                  'scheduledAt': Timestamp.fromDate(DateTime(
                                      date.year, date.month, date.day,
                                      time.hour, time.minute)),
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Products / Services ──────────────────────────────
                  _buildSection(
                    title: 'Products & Services',
                    icon:  Icons.receipt_long_rounded,
                    child: isClosed
                        ? _buildLineItems(lineItems, subtotalCents, priceCents)
                        : InkWell(
                            onTap: () async {
                              // Only show worker-added items in the picker                              // (admin items are shown read-only above)
                              final workerItemsRaw = data['workerLineItems'];
                              final workerItems = workerItemsRaw is List
                                  ? workerItemsRaw.cast<Map>()
                                  : const <Map>[];
                              final current = workerItems
                                  .map((m) => LineItem(
                                        name: (m['name'] ?? '').toString(),
                                        priceCents:
                                            (m['priceCents'] as int?) ?? 0,
                                        description:
                                            (m['description'] ?? '').toString(),
                                      ))
                                  .toList();
                              final result = await Navigator.of(context)
                                  .push<List<LineItem>>(MaterialPageRoute(
                                builder: (_) =>
                                    LineItemsScreen(initial: current),
                              ));
                              if (result != null) {
                                // Save worker items separately
                                final workerItemsList = result
                                    .map((i) => {
                                          'name': i.name,
                                          'priceCents': i.priceCents,
                                          'description': i.description,
                                        })
                                    .toList();
                                // Use adminLineItems (original) + worker items
                                // adminLineItems is set when admin creates job
                                final adminItemsRaw = data['adminLineItems'] ?? data['lineItems'];
                                final adminOriginal = adminItemsRaw is List
                                    ? (adminItemsRaw as List).cast<Map>()
                                    : const <Map>[];
                                final allItems = [
                                  ...adminOriginal,
                                  ...workerItemsList,
                                ];
                                final totalCents = allItems.fold<int>(
                                    0,
                                    (acc, i) =>
                                        acc + ((i['priceCents'] as int?) ?? 0));
                                await _update({
                                  'workerLineItems': workerItemsList,
                                  'lineItems': allItems,
                                  'priceCents': totalCents,
                                });
                              }
                            },
                            child: _buildLineItems(
                                lineItems, subtotalCents, priceCents,
                                workerItems: (data['workerLineItems'] as List?)
                                        ?.cast<Map>() ??
                                    []),
                          ),
                  ),

                  // ── Visit ────────────────────────────────────────────
                  _WorkerVisitCard(
                    teamId:      widget.teamId,
                    jobId:       widget.jobId,
                    scheduledAt: scheduledAt,
                    jobData:     data,
                  ),
                  const SizedBox(height: 16),

                  // ── Signature ────────────────────────────────────────
                  _buildSection(
                    title: 'Signature',
                    icon:  Icons.draw_rounded,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (signature != null && signature.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color:        _C.successSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _C.success.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: _C.success, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Signed by: $signature',
                                      style: const TextStyle(
                                        color:      _C.success,
                                        fontSize:   13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!isClosed)
                            _outlinedActionBtn(
                              icon:    Icons.draw_rounded,
                              label:   signature != null && signature.isNotEmpty
                                  ? 'Update signature'
                                  : 'Collect signature',
                              onTap:   () =>
                                  _showSignatureDialog(context, signature),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Assessment ───────────────────────────────────────
                  _buildAssessmentSection(data),

                  // ── Action buttons ───────────────────────────────────
                  // Send booking confirmation
                  if (!isClosed) ...[
                    _outlinedActionBtn(
                      icon: Icons.mark_email_read_outlined,
                      label: 'Send booking confirmation',
                      onTap: () => _sendConfirmation(data),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildActions(status, isClosed),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      String title,
      bool fromQuote,
      bool isClosed,
      Color statusBg,
      Color statusFg,
      JobStatus status,
      ) {
    return AppBar(
      backgroundColor:      _C.card,
      surfaceTintColor:     Colors.transparent,
      elevation:            0,
      scrolledUnderElevation: 1,
      shadowColor:          _C.border,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon:  const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _C.ink),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color:       _C.ink,
                    fontSize:    16,
                    fontWeight:  FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (fromQuote) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:        _C.successSoft,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: _C.success.withOpacity(0.4)),
                  ),
                  child: const Text('From quote',
                      style: TextStyle(
                        fontSize:   9,
                        color:      _C.success,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ],
          ),
          const Text(
            'Job details',
            style: TextStyle(color: _C.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection({
    required String   title,
    required IconData icon,
    required Widget   child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color:        _C.card,
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
            // Section header strip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: _C.accentSoft,
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: _C.accent),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                        color:       _C.accent,
                        fontSize:    12,
                        fontWeight:  FontWeight.w700,
                        letterSpacing: 0.1,
                      )),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  // ── Info grid ─────────────────────────────────────────────────────────────

  Widget _buildInfoGrid(
      {required List<_InfoEntry> entries}) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No details available.',
            style: TextStyle(color: _C.muted, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _infoRowWidget(entries[i]),
            if (i < entries.length - 1)
              Container(
                  height: 1,
                  color:  _C.border,
                  margin: const EdgeInsets.symmetric(vertical: 8)),
          ],
        ],
      ),
    );
  }

  Widget _infoRowWidget(_InfoEntry e) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width:  32,
          height: 32,
          decoration: BoxDecoration(
            color:        _C.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(e.icon, size: 15, color: _C.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.label,
                  style: const TextStyle(
                      color: _C.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(e.value,
                  style: const TextStyle(
                    color:      _C.ink,
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                    height:     1.4,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Schedule row ──────────────────────────────────────────────────────────

  Widget _scheduleRow({
    required IconData icon,
    required String   label,
    required String   value,
    required bool     hasValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        hasValue ? _C.accentSoft : _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hasValue
                ? _C.accent.withOpacity(0.25)
                : _C.border),
      ),
      child: Row(
        children: [
          Icon(icon,
              size:  16,
              color: hasValue ? _C.accent : _C.muted),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    color:    hasValue ? _C.accent : _C.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    color:      hasValue ? _C.ink : _C.muted,
                    fontSize:   13,
                    fontWeight: hasValue
                        ? FontWeight.w700
                        : FontWeight.w400,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  // ── Line items ────────────────────────────────────────────────────────────

  Widget _buildLineItems(
      List<Map> lineItems, int subtotalCents, int? priceCents,
      {List<Map> workerItems = const []}) {
    // Admin items = lineItems minus workerItems
    final adminItems = workerItems.isEmpty
        ? lineItems
        : lineItems
            .where((i) => !workerItems.any((w) => w['name'] == i['name']))
            .toList();
    if (lineItems.isEmpty) {
      if (priceCents != null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: _C.muted, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color:        _C.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${(priceCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color:       _C.accent,
                    fontSize:    15,
                    fontWeight:  FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: _C.muted),
            SizedBox(width: 8),
            Text('No line items.',
                style: TextStyle(color: _C.muted, fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final item in lineItems) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: _C.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (item['name'] ?? '').toString(),
                      style: const TextStyle(
                          color: _C.ink, fontSize: 13),
                    ),
                  ),
                  Text(
                    (item['priceCents'] as int? ?? 0) == 0
                        ? 'Free'
                        : '\$${((item['priceCents'] as int) / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color:      _C.ink,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(height: 1, color: _C.border,
              margin: const EdgeInsets.symmetric(vertical: 8)),
          Row(
            children: [
              const Text('Subtotal',
                  style: TextStyle(
                    color:      _C.muted,
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color:        _C.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${(subtotalCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color:       _C.accent,
                    fontSize:    15,
                    fontWeight:  FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Assessment section ────────────────────────────────────────────────────

  Widget _buildAssessmentSection(Map<String, dynamic> data) {
    final assessment = data['assessment'];
    if (assessment == null) return const SizedBox.shrink();
    final a = Map<String, dynamic>.from(assessment as Map);
    final status = (a['status'] as String?) ?? 'scheduled';
    final isCompleted = status == 'completed';
    final scheduledTs = a['scheduledAt'];
    final instructions = (a['instructions'] as String?) ?? '';
    final assignedEmail = (a['assignedMemberEmail'] as String?) ?? '';

    final statusColor = isCompleted ? _C.success : _C.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: statusColor.withValues(alpha: 0.3)),
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Row(children: [
                Icon(Icons.assignment_turned_in_outlined,
                    size: 15, color: statusColor),
                const SizedBox(width: 8),
                Text('Assessment',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (scheduledTs is Timestamp)
                    _infoRowWidget(_InfoEntry(
                        'Date',
                        _fmtDate(scheduledTs.toDate()),
                        Icons.calendar_today_outlined)),
                  if (assignedEmail.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRowWidget(_InfoEntry(
                        'Assigned to', assignedEmail, Icons.badge_outlined)),
                  ],
                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRowWidget(_InfoEntry(
                        'Instructions', instructions, Icons.notes_rounded)),
                  ],
                  if (!isCompleted) ...[
                    const SizedBox(height: 12),
                    _outlinedActionBtn(
                      icon: Icons.check_circle_outline,
                      label: 'Complete assessment',
                      onTap: _completeAssessment,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Widget _buildActions(JobStatus status, bool isClosed) {
    if (isClosed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        _C.successSoft,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: _C.success.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _C.success, size: 22),
            SizedBox(width: 12),
            Text('Job completed',
                style: TextStyle(
                  color:      _C.success,
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      );
    }

    if (status == JobStatus.open || status == JobStatus.assigned) {
      return _gradientBtn(
        icon:    Icons.play_arrow_rounded,
        label:   'Start Job',
        colors:  [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
        shadow:  _C.accent,
        onTap:   _isSaving
            ? null
            : () => _update({'status': JobStatus.inProgress.value}),
      );
    }

    if (status == JobStatus.inProgress) {
      return _gradientBtn(
        icon:   Icons.check_circle_rounded,
        label:  'Complete Job',
        colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
        shadow: _C.success,
        onTap:  _isSaving
            ? null
            : () => _update({'status': JobStatus.done.value}),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _gradientBtn({
    required IconData   icon,
    required String     label,
    required List<Color> colors,
    required Color      shadow,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onTap == null
              ? null
              : LinearGradient(
            colors: colors,
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          color: onTap == null ? _C.border : null,
          boxShadow: onTap == null
              ? null
              : [
            BoxShadow(
              color:      shadow.withOpacity(0.35),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor:     Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isSaving
              ? const SizedBox(
              width:  18,
              height: 18,
              child:  CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Icon(icon, color: Colors.white, size: 20),
          label: Text(
            _isSaving ? 'Saving…' : label,
            style: const TextStyle(
              color:       Colors.white,
              fontSize:    15,
              fontWeight:  FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinedActionBtn({
    required IconData  icon,
    required String    label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        _C.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: _C.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _C.accent),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                  color:      _C.accent,
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  void _showSignatureDialog(BuildContext context, String? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _SignatureDialog(
        existing: existing,
        onSave:   (sig) => _update({'signature': sig}),
      ),
    );
  }
}

// ── Worker visit card ─────────────────────────────────────────────────────────

class _WorkerVisitCard extends StatelessWidget {
  const _WorkerVisitCard({
    required this.teamId,
    required this.jobId,
    required this.scheduledAt,
    required this.jobData,
  });

  final String             teamId;
  final String             jobId;
  final DateTime?          scheduledAt;
  final Map<String, dynamic> jobData;

  String get _fmtScheduled {
    if (scheduledAt == null) return 'Not scheduled';
    final d = scheduledAt!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openVisit(BuildContext context) async {
    if (scheduledAt == null) return;

    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.jobVisits(teamId, jobId))
        .orderBy('createdAt', descending: false)
        .limit(1)
        .get();

    String visitId;
    if (snap.docs.isNotEmpty) {
      visitId = snap.docs.first.id;
    } else {
      final lineItemsRaw = jobData['lineItems'];
      final lineItems    = lineItemsRaw is List ? lineItemsRaw : [];
      final workerEmail  = (jobData['assignedWorkerEmail'] as String?) ?? '';
      String workerName  = workerEmail;
      if (workerEmail.isNotEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: workerEmail)
            .limit(1)
            .get();
        final name =
        (userSnap.docs.firstOrNull?.data()['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) workerName = name;
      }
      final ref = await FirebaseFirestore.instance
          .collection(FirestorePaths.jobVisits(teamId, jobId))
          .add({
        'scheduledAt':    jobData['scheduledAt'],
        'status':         'scheduled',
        'workerEmail':    workerEmail,
        'workerName':     workerName.isNotEmpty ? workerName : 'Test Name',
        'instructions':   (jobData['description'] as String?) ?? '',
        'lineItems':      lineItems,
        'timerRunning':   false,
        'timerStartedAt': null,
        'totalSeconds':   0,
        'createdAt':      FieldValue.serverTimestamp(),
      });
      visitId = ref.id;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VisitDetailsScreen(
        teamId:  teamId,
        jobId:   jobId,
        visitId: visitId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isScheduled = scheduledAt != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        decoration: BoxDecoration(
          color:        _C.card,
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
        child: Material(
          color:        Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:           isScheduled ? () => _openVisit(context) : null,
            splashColor:     _C.accentSoft,
            highlightColor:  _C.accentSoft.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: const BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.only(
                      topLeft:  Radius.circular(13),
                      topRight: Radius.circular(13),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 15, color: _C.accent),
                      SizedBox(width: 8),
                      Text('Visit',
                          style: TextStyle(
                            color:       _C.accent,
                            fontSize:    12,
                            fontWeight:  FontWeight.w700,
                          )),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width:  36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isScheduled
                              ? _C.accentSoft
                              : _C.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isScheduled
                                ? _C.accent.withOpacity(0.25)
                                : _C.border,
                          ),
                        ),
                        child: Icon(
                          isScheduled
                              ? Icons.event_available_rounded
                              : Icons.event_busy_rounded,
                          size:  18,
                          color: isScheduled ? _C.accent : _C.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isScheduled
                                  ? 'Scheduled visit'
                                  : 'No visit scheduled',
                              style: const TextStyle(
                                color:      _C.ink,
                                fontSize:   13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fmtScheduled,
                              style: TextStyle(
                                color:      isScheduled ? _C.accent : _C.muted,
                                fontSize:   12,
                                fontWeight: isScheduled
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isScheduled)
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
      ),
    );
  }
}

// ── Signature dialog ──────────────────────────────────────────────────────────

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({required this.existing, required this.onSave});
  final String? existing;
  final Future<void> Function(String) onSave;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  late final TextEditingController _ctrl;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ctrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a signature.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave(_ctrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:    const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        _C.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_rounded,
                      size: 18, color: _C.accent),
                ),
                const SizedBox(width: 12),
                const Text('Collect Signature',
                    style: TextStyle(
                      color:       _C.ink,
                      fontSize:    16,
                      fontWeight:  FontWeight.w800,
                      letterSpacing: -0.2,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Type the full name of the person signing off.',
              style: TextStyle(color: _C.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Field
            TextField(
              controller: _ctrl,
              autofocus:  true,
              style: const TextStyle(
                  color: _C.ink, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText:  'Full name',
                labelStyle: const TextStyle(color: _C.muted, fontSize: 13),
                prefixIcon: const Icon(Icons.person_rounded,
                    size: 18, color: _C.muted),
                filled:     true,
                fillColor:  _C.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   const BorderSide(color: _C.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color:        _C.errorSoft,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: _C.error.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 14, color: _C.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: _C.error, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color:        _C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: _C.border),
                      ),
                      child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                              color:      _C.muted,
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: _saving
                            ? null
                            : const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF1D4ED8)
                          ],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        color: _saving ? _C.border : null,
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor:     Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Save',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info entry model ──────────────────────────────────────────────────────────

class _InfoEntry {
  const _InfoEntry(this.label, this.value, this.icon);
  final String   label;
  final String   value;
  final IconData icon;
}