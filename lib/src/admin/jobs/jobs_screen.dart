import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/firestore_paths.dart';
import 'create_job_screen.dart';
import 'job_details_screen.dart';
import 'job_status.dart';

// ── Brand colours (matches dashboard light theme) ─────────────────────────────
const _kBg      = Color(0xFFF5F7FA);
const _kCard    = Colors.white;
const _kBlue1   = Color(0xFF2563EB);
const _kBlue2   = Color(0xFF1D4ED8);
const _kText    = Color(0xFF0F172A);
const _kSubText = Color(0xFF64748B);
const _kDivider = Color(0xFFE2E8F0);

// ── Status colour map ─────────────────────────────────────────────────────────
Color _statusColor(JobStatus s) {
  switch (s) {
    case JobStatus.open:       return _kBlue1;
    case JobStatus.assigned:   return const Color(0xFF7C3AED);
    case JobStatus.inProgress: return const Color(0xFFD97706);
    case JobStatus.done:       return const Color(0xFF059669);
  }
}

Color _statusBgColor(JobStatus s) {
  switch (s) {
    case JobStatus.open:       return const Color(0xFFEFF6FF);
    case JobStatus.assigned:   return const Color(0xFFF5F3FF);
    case JobStatus.inProgress: return const Color(0xFFFFFBEB);
    case JobStatus.done:       return const Color(0xFFECFDF5);
  }
}

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final jobsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamJobs(teamId))
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: Container(
        color:  Color(0xFFF5F7FA),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 100.h),
                children: [
                  // ── Header ───────────────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: (){
                          Navigator.pop(context);
                        },
                          child: Icon(Icons.arrow_back_ios_new)),
                      SizedBox(
                        width: 15.w,
                      ),
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: _kBlue1,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.work_outline,
                            color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jobs',
                              style: TextStyle(
                                  color: _kText,
                                  decoration: TextDecoration.none, // add this
      
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                          Text('Manage and track all your jobs',
                              style: TextStyle(
                                  color: _kSubText, fontSize: 12.sp)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
      
                  // ── Job list ─────────────────────────────────────────
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: jobsQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.h),
                            child: CircularProgressIndicator(
                              color: _kBlue1,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.h),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.work_outline,
                                      color: _kBlue1, size: 40.sp),
                                ),
                                SizedBox(height: 16.h),
                                Text('No jobs yet',
                                    style: TextStyle(
                                        color: _kText,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 4.h),
                                Text('Tap + to create your first job',
                                    style: TextStyle(
                                        color: _kSubText,
                                        fontSize: 13.sp)),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final d in docs)
                            _JobCard(
                              teamId: teamId,
                              jobId: d.id,
                              data: d.data(),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
      
              // ── FAB ───────────────────────────────────────────────────
              Positioned(
                right: 16.w,
                bottom: 16.h,
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CreateJobScreen(teamId: teamId),
                      )),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: _kBlue1.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add,
                            color: Colors.white, size: 20.sp),
                        SizedBox(width: 6.w),
                        Text('Create job',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Job card ──────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.teamId,
    required this.jobId,
    required this.data,
  });

  final String teamId;
  final String jobId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Untitled job';
    final status = JobStatus.fromValue(data['status'] as String?);
    final assignedEmail =
        (data['assignedWorkerEmail'] as String?) ?? '';
    final workerName = (data['salesPersonName'] as String?) ?? '';
    final fromQuote = data['sourceQuoteId'] != null;
    final priceCents = (data['priceCents'] as int?);
    final scheduledTs = data['scheduledAt'];
    final scheduledAt =
    scheduledTs is Timestamp ? scheduledTs.toDate() : null;
    final color = _statusColor(status);
    final bgColor = _statusBgColor(status);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            JobDetailsScreen(teamId: teamId, jobId: jobId),
      )),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _kDivider),
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
            // ── Top section ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator bar
                  Container(
                    width: 4.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: _kText,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2)),
                        SizedBox(height: 4.h),
                        if (assignedEmail.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 12.sp, color: _kSubText),
                              SizedBox(width: 4.w),
                              Text(
                                workerName.isNotEmpty
                                    ? workerName
                                    : assignedEmail,
                                style: TextStyle(
                                    color: _kSubText,
                                    fontSize: 12.sp),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Status chip
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      status.value.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider + meta row ───────────────────────────────────
            if (scheduledAt != null ||
                priceCents != null ||
                fromQuote) ...[
              Divider(height: 1, color: _kDivider),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 10.h),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    if (scheduledAt != null)
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label:
                        '${scheduledAt.day.toString().padLeft(2, '0')}/'
                            '${scheduledAt.month.toString().padLeft(2, '0')}/'
                            '${scheduledAt.year}',
                      ),
                    if (priceCents != null)
                      _MetaChip(
                        icon: Icons.attach_money,
                        label:
                        '\$${(priceCents / 100).toStringAsFixed(2)}',
                        color: const Color(0xFF059669),
                        bgColor: const Color(0xFFECFDF5),
                      ),
                    if (fromQuote)
                      _MetaChip(
                        icon: Icons.request_quote_outlined,
                        label: 'From quote',
                        color: _kBlue1,
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.bgColor,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kSubText;
    final bg = bgColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: bg != null
          ? BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: c),
          SizedBox(width: 4.w),
          Text(label,
              style: TextStyle(
                  color: c,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}