import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/firestore_paths.dart';
import '../invoices/invoice_details_screen.dart';
import '../jobs/job_details_screen.dart';
import '../quotes/quote_details_screen.dart';
import '../requests/request_details_screen.dart';
import 'dashboard_detail_screen.dart';

// ── Brand colours (light theme) ───────────────────────────────────────────────
const _kBg        = Color(0xFFF5F7FA);
const _kCard      = Colors.white;
const _kBlue1     = Color(0xFF2563EB);
const _kBlue2     = Color(0xFF1D4ED8);
const _kAccent    = Color(0xFF0EA5E9);
const _kText      = Color(0xFF0F172A);
const _kSubText   = Color(0xFF64748B);
const _kDivider   = Color(0xFFE2E8F0);
const _kSurface   = Color(0xFFEFF6FF);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.teamId});
  final String teamId;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Container(
      color: _kBg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 32.h),
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: _kBlue1,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.dashboard_rounded,
                      color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard',
                        style: TextStyle(
                            color: _kText,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    Text('Overview of your business',
                        style:
                        TextStyle(color: _kSubText, fontSize: 12.sp)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // ── Revenue hero ─────────────────────────────────────────────
            _RevenueCard(
              teamId: teamId,
              onTapCollected: () => _push(
                  context,
                  DashboardDetailScreen(
                    title: 'Collected invoices',
                    query: db
                        .collection(FirestorePaths.teamInvoices(teamId))
                        .where('status', isEqualTo: 'paid'),
                    emptyText: 'No paid invoices.',
                    itemBuilder: (ctx, doc) =>
                        _invoiceTile(ctx, doc, teamId),
                  )),
              onTapOutstanding: () => _push(
                  context,
                  DashboardDetailScreen(
                    title: 'Outstanding invoices',
                    query: db
                        .collection(FirestorePaths.teamInvoices(teamId))
                        .where('status', whereNotIn: ['paid']),
                    emptyText: 'No outstanding invoices.',
                    itemBuilder: (ctx, doc) =>
                        _invoiceTile(ctx, doc, teamId),
                  )),
            ),
            SizedBox(height: 28.h),

            // ── Jobs ─────────────────────────────────────────────────────
            _SectionLabel('Jobs', Icons.work_outline),
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(
                  child: _StatCard(
                    label: 'Total',
                    icon: Icons.work_outline,
                    color: _kBlue1,
                    bgColor: _kSurface,
                    stream: db
                        .collection(FirestorePaths.teamJobs(teamId))
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'All jobs',
                          query:
                          db.collection(FirestorePaths.teamJobs(teamId)),
                          emptyText: 'No jobs.',
                          itemBuilder: (ctx, doc) =>
                              _jobTile(ctx, doc, teamId),
                        )),
                  )),
              SizedBox(width: 10.w),
              Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    stream: db
                        .collection(FirestorePaths.teamJobs(teamId))
                        .where('status', isEqualTo: 'done')
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Completed jobs',
                          query: db
                              .collection(FirestorePaths.teamJobs(teamId))
                              .where('status', isEqualTo: 'done'),
                          emptyText: 'No completed jobs.',
                          itemBuilder: (ctx, doc) =>
                              _jobTile(ctx, doc, teamId),
                        )),
                  )),
            ]),
            SizedBox(height: 10.h),
            Row(children: [
              Expanded(
                  child: _StatCard(
                    label: 'Closed & paid',
                    icon: Icons.lock_outline,
                    color: const Color(0xFF0891B2),
                    bgColor: const Color(0xFFECFEFF),
                    stream: db
                        .collection(FirestorePaths.teamJobs(teamId))
                        .where('status', isEqualTo: 'done')
                        .where('paymentStatus', isEqualTo: 'paid')
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Closed & paid',
                          query: db
                              .collection(FirestorePaths.teamJobs(teamId))
                              .where('status', isEqualTo: 'done')
                              .where('paymentStatus', isEqualTo: 'paid'),
                          emptyText: 'No closed jobs.',
                          itemBuilder: (ctx, doc) =>
                              _jobTile(ctx, doc, teamId),
                        )),
                  )),
              SizedBox(width: 10.w),
              Expanded(
                  child: _StatCard(
                    label: 'Invoice pending',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    stream: db
                        .collection(FirestorePaths.teamJobs(teamId))
                        .where('status', isEqualTo: 'done')
                        .where('paymentStatus', whereNotIn: ['paid'])
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Invoice pending',
                          query: db
                              .collection(FirestorePaths.teamJobs(teamId))
                              .where('status', isEqualTo: 'done')
                              .where('paymentStatus', whereNotIn: ['paid']),
                          emptyText: 'No pending.',
                          itemBuilder: (ctx, doc) =>
                              _jobTile(ctx, doc, teamId),
                        )),
                  )),
            ]),
            SizedBox(height: 28.h),

            // ── Workers ──────────────────────────────────────────────────
            _SectionLabel('Workers', Icons.badge_outlined),
            SizedBox(height: 12.h),
            _StatCard(
              label: 'Registered workers',
              icon: Icons.badge_outlined,
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              stream: db
                  .collection('users')
                  .where('role', isEqualTo: 'worker')
                  .where('currentTeamId', isEqualTo: teamId)
                  .snapshots(),
              count: (s) => s.docs.length,
              onTap: () => _push(
                  context,
                  DashboardDetailScreen(
                    title: 'Workers',
                    query: db
                        .collection('users')
                        .where('role', isEqualTo: 'worker')
                        .where('currentTeamId', isEqualTo: teamId),
                    emptyText: 'No workers.',
                    itemBuilder: (ctx, doc) {
                      final d = doc.data();
                      return _LightListTile(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        title:
                        (d['name'] as String?)?.isNotEmpty == true
                            ? d['name'] as String
                            : (d['email'] as String?) ?? doc.id,
                        subtitle: (d['email'] as String?) ?? '',
                      );
                    },
                  )),
            ),
            SizedBox(height: 28.h),

            // ── Invoices ─────────────────────────────────────────────────
            _SectionLabel('Invoices', Icons.receipt_long_outlined),
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(
                  child: _StatCard(
                    label: 'Total',
                    icon: Icons.receipt_long_outlined,
                    color: _kBlue1,
                    bgColor: _kSurface,
                    stream: db
                        .collection(FirestorePaths.teamInvoices(teamId))
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'All invoices',
                          query: db.collection(
                              FirestorePaths.teamInvoices(teamId)),
                          emptyText: 'No invoices.',
                          itemBuilder: (ctx, doc) =>
                              _invoiceTile(ctx, doc, teamId),
                        )),
                  )),
              SizedBox(width: 10.w),
              Expanded(
                  child: _StatCard(
                    label: 'Paid',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    stream: db
                        .collection(FirestorePaths.teamInvoices(teamId))
                        .where('status', isEqualTo: 'paid')
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Paid invoices',
                          query: db
                              .collection(
                              FirestorePaths.teamInvoices(teamId))
                              .where('status', isEqualTo: 'paid'),
                          emptyText: 'No paid invoices.',
                          itemBuilder: (ctx, doc) =>
                              _invoiceTile(ctx, doc, teamId),
                        )),
                  )),
            ]),
            SizedBox(height: 10.h),
            _StatCard(
              label: 'Unpaid invoices',
              icon: Icons.money_off_outlined,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              stream: db
                  .collection(FirestorePaths.teamInvoices(teamId))
                  .where('status', whereNotIn: ['paid'])
                  .snapshots(),
              count: (s) => s.docs.length,
              onTap: () => _push(
                  context,
                  DashboardDetailScreen(
                    title: 'Unpaid invoices',
                    query: db
                        .collection(FirestorePaths.teamInvoices(teamId))
                        .where('status', whereNotIn: ['paid']),
                    emptyText: 'No unpaid invoices.',
                    itemBuilder: (ctx, doc) =>
                        _invoiceTile(ctx, doc, teamId),
                  )),
            ),
            SizedBox(height: 28.h),

            // ── Quotes ───────────────────────────────────────────────────
            _SectionLabel('Quotes', Icons.request_quote_outlined),
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(
                  child: _StatCard(
                    label: 'Approved',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    stream: db
                        .collection(FirestorePaths.teamQuotes(teamId))
                        .where('status', isEqualTo: 'approved')
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Approved quotes',
                          query: db
                              .collection(FirestorePaths.teamQuotes(teamId))
                              .where('status', isEqualTo: 'approved'),
                          emptyText: 'No approved quotes.',
                          itemBuilder: (ctx, doc) =>
                              _quoteTile(ctx, doc, teamId),
                        )),
                  )),
              SizedBox(width: 10.w),
              Expanded(
                  child: _StatCard(
                    label: 'Unapproved',
                    icon: Icons.pending_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    stream: db
                        .collection(FirestorePaths.teamQuotes(teamId))
                        .where('status', whereNotIn: ['approved'])
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'Unapproved quotes',
                          query: db
                              .collection(FirestorePaths.teamQuotes(teamId))
                              .where('status', whereNotIn: ['approved']),
                          emptyText: 'No unapproved quotes.',
                          itemBuilder: (ctx, doc) =>
                              _quoteTile(ctx, doc, teamId),
                        )),
                  )),
            ]),
            SizedBox(height: 28.h),

            // ── Requests ─────────────────────────────────────────────────
            _SectionLabel('Requests', Icons.inbox_outlined),
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(
                  child: _StatCard(
                    label: 'Total',
                    icon: Icons.inbox_outlined,
                    color: _kSubText,
                    bgColor: const Color(0xFFF8FAFC),
                    stream: db
                        .collection(FirestorePaths.teamRequests(teamId))
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'All requests',
                          query: db.collection(
                              FirestorePaths.teamRequests(teamId)),
                          emptyText: 'No requests.',
                          itemBuilder: (ctx, doc) =>
                              _requestTile(ctx, doc, teamId),
                        )),
                  )),
              SizedBox(width: 10.w),
              Expanded(
                  child: _StatCard(
                    label: 'New',
                    icon: Icons.fiber_new_outlined,
                    color: _kBlue1,
                    bgColor: _kSurface,
                    stream: db
                        .collection(FirestorePaths.teamRequests(teamId))
                        .where('status', isEqualTo: 'new')
                        .snapshots(),
                    count: (s) => s.docs.length,
                    onTap: () => _push(
                        context,
                        DashboardDetailScreen(
                          title: 'New requests',
                          query: db
                              .collection(
                              FirestorePaths.teamRequests(teamId))
                              .where('status', isEqualTo: 'new'),
                          emptyText: 'No new requests.',
                          itemBuilder: (ctx, doc) =>
                              _requestTile(ctx, doc, teamId),
                        )),
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Tile builders ─────────────────────────────────────────────────────────

  Widget _jobTile(BuildContext ctx,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String teamId) {
    final d = doc.data();
    return _LightListTile(
      icon: Icons.work_outline,
      iconColor: _kBlue1,
      title: (d['title'] as String?) ?? 'Job',
      subtitle: (d['status'] as String?) ?? '-',
      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) =>
            JobDetailsScreen(teamId: teamId, jobId: doc.id),
      )),
    );
  }

  Widget _invoiceTile(BuildContext ctx,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String teamId) {
    final d = doc.data();
    final total = (d['totalCents'] as int?) ?? 0;
    final status = (d['status'] as String?) ?? 'draft';
    return _LightListTile(
      icon: Icons.receipt_long_outlined,
      iconColor: status == 'paid'
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626),
      title: (d['clientName'] as String?) ?? '—',
      subtitle: '\$${(total / 100).toStringAsFixed(2)}  •  $status',
      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) =>
            InvoiceDetailsScreen(teamId: teamId, invoiceId: doc.id),
      )),
    );
  }

  Widget _quoteTile(BuildContext ctx,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String teamId) {
    final d = doc.data();
    final total = (d['totalCents'] as int?) ?? 0;
    return _LightListTile(
      icon: Icons.request_quote_outlined,
      iconColor: _kBlue1,
      title: (d['clientName'] as String?) ?? '—',
      subtitle: '\$${(total / 100).toStringAsFixed(2)}',
      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) =>
            QuoteDetailsScreen(teamId: teamId, quoteId: doc.id),
      )),
    );
  }

  Widget _requestTile(BuildContext ctx,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String teamId) {
    final d = doc.data();
    return _LightListTile(
      icon: Icons.inbox_outlined,
      iconColor: _kBlue1,
      title: (d['clientName'] as String?) ?? 'Client',
      subtitle: (d['serviceDescription'] as String?) ?? '',
      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(
            teamId: teamId, requestId: doc.id),
      )),
    );
  }
}

// ── Revenue hero card ─────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.teamId,
    required this.onTapCollected,
    required this.onTapOutstanding,
  });
  final String teamId;
  final VoidCallback onTapCollected;
  final VoidCallback onTapOutstanding;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(FirestorePaths.teamInvoices(teamId))
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        int totalCents = 0, paidCents = 0, unpaidCents = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data();
            final amount = (d['totalCents'] as int?) ?? 0;
            totalCents += amount;
            if ((d['status'] as String?) == 'paid') {
              paidCents += amount;
            } else {
              unpaidCents += amount;
            }
          }
        }
        String fmt(int c) => '\$${(c / 100).toStringAsFixed(2)}';

        return Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 18.sp),
                  ),
                  SizedBox(width: 10.w),
                  Text('Total Revenue',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                snap.hasData ? fmt(totalCents) : '—',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1),
              ),
              SizedBox(height: 20.h),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTapCollected,
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5.w),
                            Text('Collected',
                                style: TextStyle(
                                    color:
                                    Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11.sp)),
                          ]),
                          SizedBox(height: 6.h),
                          Text(snap.hasData ? fmt(paidCents) : '—',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: GestureDetector(
                    onTap: onTapOutstanding,
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.pending_outlined,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5.w),
                            Text('Outstanding',
                                style: TextStyle(
                                    color:
                                    Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11.sp)),
                          ]),
                          SizedBox(height: 6.h),
                          Text(snap.hasData ? fmt(unpaidCents) : '—',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.stream,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(QuerySnapshot<Map<String, dynamic>>) count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _kDivider, width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: EdgeInsets.all(9.w),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: color, size: 18.sp),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.arrow_forward_ios,
                    size: 10.sp, color: _kSubText),
              ),
            ]),
            SizedBox(height: 14.h),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                final n =
                snap.hasData ? count(snap.data!) : null;
                return Text(
                  n == null ? '—' : '$n',
                  style: TextStyle(
                      color: _kText,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                );
              },
            ),
            SizedBox(height: 3.h),
            Text(label,
                style: TextStyle(
                    color: _kSubText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14.sp, color: _kBlue1),
      SizedBox(width: 6.w),
      Text(
        text.toUpperCase(),
        style: TextStyle(
            color: _kBlue1,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0),
      ),
    ],
  );
}

// ── Light list tile (used in detail screens) ───────────────────────────────────

class _LightListTile extends StatelessWidget {
  const _LightListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? _kBlue1;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _kDivider),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        leading: Container(
          padding: EdgeInsets.all(9.w),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: effectiveColor, size: 18.sp),
        ),
        title: Text(title,
            style: TextStyle(
                color: _kText,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp)),
        subtitle: Text(subtitle,
            style: TextStyle(color: _kSubText, fontSize: 12.sp)),
        trailing: Icon(Icons.chevron_right, color: _kSubText, size: 18.sp),
        onTap: onTap,
      ),
    );
  }
}