import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'worker_profile_screen.dart';

// ── Brand colours (matches dashboard & jobs light theme) ──────────────────────
const _kBg      = Color(0xFFF5F7FA);
const _kCard    = Colors.white;
const _kBlue1   = Color(0xFF2563EB);
const _kText    = Color(0xFF0F172A);
const _kSubText = Color(0xFF64748B);
const _kDivider = Color(0xFFE2E8F0);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleBg = Color(0xFFF5F3FF);

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .limit(200);

    return Scaffold(
      body: Container(
        color: _kBg,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 32.h),
            children: [
              // ── Header ────────────────────────────────────────────────
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
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.badge_outlined,
                        color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workers',
                          style: TextStyle(
                              color: _kText,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      Text('Assign jobs without invitation',
                          style: TextStyle(
                              color: _kSubText, fontSize: 12.sp)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
      
              // ── Search bar ────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _kDivider),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: TextStyle(color: _kText, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    hintStyle:
                    TextStyle(color: _kSubText, fontSize: 14.sp),
                    prefixIcon:
                    Icon(Icons.search, color: _kSubText, size: 20.sp),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.close,
                          color: _kSubText, size: 18.sp),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 13.h),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
      
              // ── Worker list ───────────────────────────────────────────
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: workersQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: CircularProgressIndicator(
                          color: _kPurple,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  }
      
                  final allDocs = snapshot.data?.docs ?? [];
      
                  // Client-side search filter
                  final docs = _searchQuery.isEmpty
                      ? allDocs
                      : allDocs.where((d) {
                    final email = ((d.data()['email'] as String?) ?? '')
                        .toLowerCase();
                    final name = ((d.data()['name'] as String?) ?? '')
                        .toLowerCase();
                    return email.contains(_searchQuery) ||
                        name.contains(_searchQuery);
                  }).toList();
      
                  if (allDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(20.w),
                              decoration: const BoxDecoration(
                                color: _kPurpleBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.badge_outlined,
                                  color: _kPurple, size: 40.sp),
                            ),
                            SizedBox(height: 16.h),
                            Text('No workers yet',
                                style: TextStyle(
                                    color: _kText,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 4.h),
                            Text('Registered workers will appear here',
                                style: TextStyle(
                                    color: _kSubText, fontSize: 13.sp)),
                          ],
                        ),
                      ),
                    );
                  }
      
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: Column(
                          children: [
                            Icon(Icons.search_off,
                                color: _kSubText, size: 36.sp),
                            SizedBox(height: 12.h),
                            Text('No results for "$_searchQuery"',
                                style: TextStyle(
                                    color: _kSubText, fontSize: 14.sp)),
                          ],
                        ),
                      ),
                    );
                  }
      
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Count badge
                      Row(
                        children: [
                          Text(
                            '${docs.length} worker${docs.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: _kSubText,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            Text(' matching ',
                                style: TextStyle(
                                    color: _kSubText, fontSize: 12.sp)),
                            Text('"$_searchQuery"',
                                style: TextStyle(
                                    color: _kPurple,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      SizedBox(height: 10.h),
      
                      for (final d in docs)
                        _WorkerCard(
                          teamId: widget.teamId,
                          doc: d,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Worker card ───────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.teamId, required this.doc});
  final String teamId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final email = (d['email'] as String?) ?? doc.id;
    final name = (d['name'] as String?) ?? '';
    final currentTeamId = (d['currentTeamId'] as String?) ?? '';
    final isOnThisTeam = currentTeamId == teamId;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : email.isNotEmpty
        ? email[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WorkerProfileScreen(
          teamId: teamId,
          workerUid: doc.id,
          workerEmail: email,
        ),
      )),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: _kCard,
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
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              // ── Avatar ─────────────────────────────────────────────
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: _kPurpleBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                      color: _kPurple,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 14.w),

              // ── Info ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty) ...[
                      Text(name,
                          style: TextStyle(
                              color: _kText,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2.h),
                      Text(email,
                          style: TextStyle(
                              color: _kSubText, fontSize: 12.sp)),
                    ] else
                      Text(email,
                          style: TextStyle(
                              color: _kText,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700)),
                    SizedBox(height: 6.h),
                    // Row(
                    //   children: [
                    //     Container(
                    //       padding: EdgeInsets.symmetric(
                    //           horizontal: 8.w, vertical: 3.h),
                    //       decoration: BoxDecoration(
                    //         color: isOnThisTeam
                    //             ? const Color(0xFFECFDF5)
                    //             : const Color(0xFFF8FAFC),
                    //         borderRadius: BorderRadius.circular(8.r),
                    //       ),
                    //       child: Row(
                    //         mainAxisSize: MainAxisSize.min,
                    //         children: [
                    //           Container(
                    //             width: 6.w,
                    //             height: 6.w,
                    //             decoration: BoxDecoration(
                    //               color: isOnThisTeam
                    //                   ? const Color(0xFF059669)
                    //                   : _kSubText,
                    //               shape: BoxShape.circle,
                    //             ),
                    //           ),
                    //           SizedBox(width: 5.w),
                    //           // Text(
                    //           //   isOnThisTeam
                    //           //       ? 'On your team'
                    //           //       : currentTeamId.isEmpty
                    //           //       ? 'Unassigned'
                    //           //       : 'Other team',
                    //           //   style: TextStyle(
                    //           //       color: isOnThisTeam
                    //           //           ? const Color(0xFF059669)
                    //           //           : _kSubText,
                    //           //       fontSize: 11.sp,
                    //           //       fontWeight: FontWeight.w600),
                    //           // ),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),

              // ── Arrow ───────────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.arrow_forward_ios,
                    size: 11.sp, color: _kSubText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}