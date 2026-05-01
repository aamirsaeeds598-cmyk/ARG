import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/firestore_paths.dart';
import 'line_items_screen.dart';

const _kBg      = Color(0xFFF5F7FA);
const _kCard    = Colors.white;
const _kBlue1   = Color(0xFF2563EB);
const _kBlue2   = Color(0xFF1D4ED8);
const _kText    = Color(0xFF0F172A);
const _kSubText = Color(0xFF64748B);
const _kDivider = Color(0xFFE2E8F0);
const _kGreen   = Color(0xFF059669);
const _kGreenBg = Color(0xFFECFDF5);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEF2F2);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFFFBEB);

Color _statusColor(String s) {
  switch (s) {
    case 'completed':   return _kGreen;
    case 'in_progress': return _kAmber;
    default:            return _kSubText;
  }
}
Color _statusBg(String s) {
  switch (s) {
    case 'completed':   return _kGreenBg;
    case 'in_progress': return _kAmberBg;
    default:            return const Color(0xFFF8FAFC);
  }
}
IconData _statusIcon(String s) {
  switch (s) {
    case 'completed':   return Icons.check_circle_outline;
    case 'in_progress': return Icons.pending_outlined;
    default:            return Icons.calendar_today_outlined;
  }
}

class VisitDetailsScreen extends StatelessWidget {
  const VisitDetailsScreen({
    super.key,
    required this.teamId,
    required this.jobId,
    required this.visitId,
  });
  final String teamId;
  final String jobId;
  final String visitId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .doc(FirestorePaths.jobVisit(teamId, jobId, visitId));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor:  Color(0xFFF5F7FA),
            body: Center(child: CircularProgressIndicator(color: _kBlue1, strokeWidth: 2.5)),
          );
        }
        final data = snapshot.data!.data() ?? {};
        return _VisitBody(teamId: teamId, jobId: jobId, visitId: visitId, data: data, docRef: ref);
      },
    );
  }
}

class _VisitBody extends StatefulWidget {
  const _VisitBody({
    required this.teamId,
    required this.jobId,
    required this.visitId,
    required this.data,
    required this.docRef,
  });
  final String teamId;
  final String jobId;
  final String visitId;
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> docRef;

  @override
  State<_VisitBody> createState() => _VisitBodyState();
}

class _VisitBodyState extends State<_VisitBody> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _resumeTimerIfRunning();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _resumeTimerIfRunning() {
    final startTs = widget.data['timerStartedAt'];
    if (startTs is Timestamp && widget.data['timerRunning'] == true) {
      final started = startTs.toDate();
      _elapsed = DateTime.now().difference(started);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed = DateTime.now().difference(started));
      });
    }
  }

  Future<void> _startTimer() async {
    _ticker?.cancel();
    final now = DateTime.now();
    await widget.docRef.update({'timerStartedAt': Timestamp.fromDate(now), 'timerRunning': true});
    setState(() => _elapsed = Duration.zero);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(now));
    });
  }

  Future<void> _stopTimer() async {
    _ticker?.cancel();
    _ticker = null;
    final startTs = widget.data['timerStartedAt'];
    int prev = (widget.data['totalSeconds'] as int?) ?? 0;
    if (startTs is Timestamp) prev += DateTime.now().difference(startTs.toDate()).inSeconds;
    await widget.docRef.update({'timerRunning': false, 'timerStartedAt': null, 'totalSeconds': prev});
  }

  Future<void> _completeVisit() async {
    if (widget.data['timerRunning'] == true) await _stopTimer();
    await widget.docRef.update({'status': 'completed'});
    await FirebaseFirestore.instance
        .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
        .update({'status': 'done', 'updatedAt': FieldValue.serverTimestamp()});
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteVisit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete visit'),
        content: const Text('This will permanently delete this visit.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.docRef.delete();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openLineItems(BuildContext context, List<Map> visitItems, bool isCompleted) async {
    if (isCompleted) return;
    final initial = visitItems.map((m) => LineItem(
      name: (m['name'] ?? '').toString(),
      priceCents: (m['priceCents'] as int?) ?? 0,
      description: (m['description'] ?? '').toString(),
    )).toList();

    final result = await Navigator.of(context).push<List<LineItem>>(
      MaterialPageRoute(builder: (_) => LineItemsScreen(initial: initial)),
    );

    if (result != null) {
      final visitItemsList = result.map((i) => {
        'name': i.name, 'priceCents': i.priceCents, 'description': i.description,
      }).toList();

      await widget.docRef.update({'lineItems': visitItemsList});

      final jobRef = FirebaseFirestore.instance.doc(FirestorePaths.teamJob(widget.teamId, widget.jobId));
      final jobSnap = await jobRef.get();
      final jobData = jobSnap.data() ?? {};
      final adminRaw = jobData['adminLineItems'] ?? jobData['lineItems'];
      final adminItems = adminRaw is List ? (adminRaw as List).cast<Map>() : const <Map>[];
      final allItems = [...adminItems, ...visitItemsList];
      final totalCents = allItems.fold<int>(0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));
      await jobRef.update({'workerLineItems': visitItemsList, 'lineItems': allItems, 'priceCents': totalCents});
    }
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _itemTile(Map item, {required bool isAdmin}) {
    final cents = (item['priceCents'] as int?) ?? 0;
    final color = isAdmin ? _kBlue1 : _kAmber;
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _kDivider),
      ),
      child: Row(children: [
        Container(width: 6.w, height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 8.w),
        Expanded(child: Text((item['name'] ?? '').toString(),
            style: TextStyle(color: _kText, fontSize: 13.sp, fontWeight: FontWeight.w600))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: cents == 0 ? _kBg : _kGreenBg,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            cents == 0 ? 'Free' : '\$${(cents / 100).toStringAsFixed(2)}',
            style: TextStyle(color: cents == 0 ? _kSubText : _kGreen,
                fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final isRunning = d['timerRunning'] == true;
    final totalSeconds = (d['totalSeconds'] as int?) ?? 0;
    final displaySeconds = isRunning ? _elapsed.inSeconds : totalSeconds;
    final status = (d['status'] as String?) ?? 'scheduled';
    final isCompleted = status == 'completed';
    final instructions = (d['instructions'] as String?) ?? '';
    final workerName = (d['workerName'] as String?) ?? (d['workerEmail'] as String?) ?? '—';
    final workerEmail = (d['workerEmail'] as String?) ?? '';
    final visitItemsRaw = d['lineItems'];
    final visitItems = visitItemsRaw is List ? visitItemsRaw.cast<Map>() : const <Map>[];
    final scheduledTs = d['scheduledAt'];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _kText, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Visit Details', style: TextStyle(color: _kText, fontSize: 17.sp, fontWeight: FontWeight.w700)),
        actions: [
          if (!isCompleted)
            GestureDetector(
              onTap: _completeVisit,
              child: Container(
                margin: EdgeInsets.only(right: 6.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, color: _kGreen, size: 15.sp),
                  SizedBox(width: 5.w),
                  Text('Complete', style: TextStyle(color: _kGreen, fontSize: 12.sp, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          IconButton(icon: Icon(Icons.delete_outline, color: _kRed, size: 20.sp), onPressed: _deleteVisit),
        ],
        bottom: PreferredSize(preferredSize: Size.fromHeight(1.h), child: Divider(color: _kDivider, height: 1)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 32.h),
        children: [
          // ── Status ────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: _statusColor(status).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(_statusIcon(status), color: _statusColor(status), size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  status == 'completed' ? 'Visit Completed' : status == 'in_progress' ? 'In Progress' : 'Scheduled',
                  style: TextStyle(color: _statusColor(status), fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2.h),
                Text(
                  isCompleted ? 'This visit has been completed' : 'Tap Complete when finished',
                  style: TextStyle(color: _statusColor(status).withValues(alpha: 0.7), fontSize: 12.sp),
                ),
              ]),
            ]),
          ),
          SizedBox(height: 16.h),

          // ── Visit info ────────────────────────────────────────────────
          _SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CardHeader(icon: Icons.info_outline, label: 'Visit Info'),
            SizedBox(height: 14.h),
            _InfoRow(icon: Icons.calendar_today_outlined, label: 'Scheduled',
                value: _fmtTs(scheduledTs is Timestamp ? scheduledTs : null)),
            SizedBox(height: 10.h),
            _InfoRow(icon: Icons.badge_outlined, label: 'Worker', value: workerName),
            if (workerEmail.isNotEmpty && workerEmail != workerName) ...[
              SizedBox(height: 6.h),
              Padding(padding: EdgeInsets.only(left: 28.w),
                  child: Text(workerEmail, style: TextStyle(color: _kSubText, fontSize: 12.sp))),
            ],
          ])),
          SizedBox(height: 12.h),

          // ── Timer ─────────────────────────────────────────────────────
          _SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CardHeader(icon: Icons.timer_outlined, label: 'Time Tracking'),
            SizedBox(height: 20.h),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 18.h),
                decoration: BoxDecoration(
                  color: isRunning ? const Color(0xFFEFF6FF) : _kBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: isRunning ? _kBlue1.withValues(alpha: 0.3) : _kDivider),
                ),
                child: Column(children: [
                  Text(_fmtDuration(displaySeconds),
                      style: TextStyle(color: isRunning ? _kBlue1 : _kText, fontSize: 40.sp,
                          fontWeight: FontWeight.w800, letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  if (isRunning) ...[
                    SizedBox(height: 6.h),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 7.w, height: 7.w,
                          decoration: const BoxDecoration(color: _kBlue1, shape: BoxShape.circle)),
                      SizedBox(width: 5.w),
                      Text('Running', style: TextStyle(color: _kBlue1, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ]),
              ),
            ),
            SizedBox(height: 16.h),
            if (!isCompleted)
              isRunning
                  ? _ActionButton(label: 'Stop Timer', icon: Icons.stop_circle_outlined,
                      color: _kRed, bgColor: _kRedBg, borderColor: _kRed.withValues(alpha: 0.3), onTap: _stopTimer)
                  : _ActionButton(label: 'Start Timer', icon: Icons.play_circle_outline,
                      color: _kBlue1, bgColor: const Color(0xFFEFF6FF),
                      borderColor: _kBlue1.withValues(alpha: 0.3), onTap: _startTimer,
                      gradient: const LinearGradient(colors: [_kBlue2, _kBlue1],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      textColor: Colors.white, iconColor: Colors.white),
          ])),
          SizedBox(height: 12.h),

          // ── Instructions ──────────────────────────────────────────────
          if (instructions.isNotEmpty) ...[
            _SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardHeader(icon: Icons.notes_outlined, label: 'Instructions'),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: _kDivider)),
                child: Text(instructions, style: TextStyle(color: _kText, fontSize: 14.sp, height: 1.5)),
              ),
            ])),
            SizedBox(height: 12.h),
          ],

          // ── Products / Services ───────────────────────────────────────
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
                .get(),
            builder: (context, jobSnap) {
              final jobData = jobSnap.data?.data() ?? {};
              final adminRaw = jobData['adminLineItems'] ?? jobData['lineItems'];
              final adminItems = adminRaw is List ? (adminRaw as List).cast<Map>() : const <Map>[];
              final allItems = [...adminItems, ...visitItems];
              final totalCents = allItems.fold<int>(0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));

              return _SectionCard(
                child: GestureDetector(
                  onTap: isCompleted ? null : () => _openLineItems(context, visitItems, isCompleted),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _CardHeader(icon: Icons.list_alt_outlined, label: 'Products / Services'),
                      const Spacer(),
                      if (!isCompleted)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: _kDivider)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_outlined, size: 12.sp, color: _kSubText),
                            SizedBox(width: 4.w),
                            Text('Add items', style: TextStyle(color: _kSubText, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
                    SizedBox(height: 14.h),

                    // Admin items (from job)
                    if (adminItems.isNotEmpty) ...[
                      Text('From job', style: TextStyle(color: _kSubText, fontSize: 10.sp,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      SizedBox(height: 6.h),
                      for (final item in adminItems) _itemTile(item, isAdmin: true),
                      SizedBox(height: 10.h),
                    ],

                    // Visit items (worker-added)
                    if (visitItems.isNotEmpty) ...[
                      Text('Added during visit', style: TextStyle(color: _kSubText, fontSize: 10.sp,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      SizedBox(height: 6.h),
                      for (final item in visitItems) _itemTile(item, isAdmin: false),
                      SizedBox(height: 10.h),
                    ],

                    if (allItems.isEmpty)
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: _kDivider)),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline, color: _kSubText, size: 16.sp),
                          SizedBox(width: 8.w),
                          Text(isCompleted ? 'No items recorded' : 'Tap to add products / services',
                              style: TextStyle(color: _kSubText, fontSize: 13.sp)),
                        ]),
                      ),

                    if (allItems.isNotEmpty) ...[
                      Divider(color: _kDivider, height: 16.h),
                      Row(children: [
                        Text('Total', style: TextStyle(color: _kSubText, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(8.r)),
                          child: Text('\$${(totalCents / 100).toStringAsFixed(2)}',
                              style: TextStyle(color: _kGreen, fontSize: 15.sp, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ],
                  ]),
                ),
              );
            },
          ),
          SizedBox(height: 20.h),

          // ── Actions ───────────────────────────────────────────────────
          if (!isCompleted) ...[
            _ActionButton(label: 'Complete Visit', icon: Icons.check_circle_outline,
                color: _kGreen, bgColor: _kGreenBg, borderColor: _kGreen.withValues(alpha: 0.3),
                onTap: _completeVisit,
                gradient: const LinearGradient(colors: [Color(0xFF047857), _kGreen],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                textColor: Colors.white, iconColor: Colors.white),
            SizedBox(height: 10.h),
          ],
          _ActionButton(label: 'Delete Visit', icon: Icons.delete_outline,
              color: _kRed, bgColor: _kRedBg, borderColor: _kRed.withValues(alpha: 0.3), onTap: _deleteVisit),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kDivider),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 2))]),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: EdgeInsets.all(7.w),
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: _kDivider)),
        child: Icon(icon, size: 14.sp, color: _kBlue1)),
    SizedBox(width: 10.w),
    Text(label, style: TextStyle(color: _kText, fontSize: 14.sp, fontWeight: FontWeight.w700)),
  ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 15.sp, color: _kSubText),
    SizedBox(width: 8.w),
    SizedBox(width: 80.w, child: Text(label, style: TextStyle(color: _kSubText, fontSize: 12.sp))),
    Expanded(child: Text(value, style: TextStyle(color: _kText, fontSize: 13.sp, fontWeight: FontWeight.w600))),
  ]);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label, required this.icon, required this.color,
    required this.bgColor, required this.borderColor, required this.onTap,
    this.gradient, this.textColor, this.iconColor,
  });
  final String label; final IconData icon; final Color color;
  final Color bgColor; final Color borderColor; final VoidCallback onTap;
  final Gradient? gradient; final Color? textColor; final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? color; final ic = iconColor ?? color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          gradient: gradient, color: gradient == null ? bgColor : null,
          borderRadius: BorderRadius.circular(12.r),
          border: gradient == null ? Border.all(color: borderColor) : null,
          boxShadow: gradient != null ? [BoxShadow(color: color.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: ic, size: 18.sp),
          SizedBox(width: 8.w),
          Text(label, style: TextStyle(color: tc, fontSize: 14.sp, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
