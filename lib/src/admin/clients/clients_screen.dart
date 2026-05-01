import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/firestore_paths.dart';

// ── Brand colours (matches light theme) ──────────────────────────────────────
const _kBg       = Color(0xFFF5F7FA);
const _kCard     = Colors.white;
const _kBlue1    = Color(0xFF2563EB);
const _kBlue2    = Color(0xFF1D4ED8);
const _kText     = Color(0xFF0F172A);
const _kSubText  = Color(0xFF64748B);
const _kDivider  = Color(0xFFE2E8F0);
const _kGreen    = Color(0xFF059669);
const _kGreenBg  = Color(0xFFECFDF5);
const _kRed      = Color(0xFFDC2626);
const _kRedBg    = Color(0xFFFEF2F2);
const _kTeal     = Color(0xFF0E7490);
const _kTealBg   = Color(0xFFECFEFF);

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isSaving   = false;
  bool _showForm   = false;
  String? _error;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createClient() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) throw Exception('Client name is required.');

      final ref = FirebaseFirestore.instance
          .collection(FirestorePaths.teamClients(widget.teamId))
          .doc();

      await ref.set({
        'name': name,
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      if (mounted) setState(() => _showForm = false);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection(FirestorePaths.teamClients(widget.teamId))
        .orderBy('createdAt', descending: true);

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
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: _kTeal,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.people_outline,
                        color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clients',
                            style: TextStyle(
                                color: _kText,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        Text('Manage your client list',
                            style: TextStyle(
                                color: _kSubText, fontSize: 12.sp)),
                      ],
                    ),
                  ),
                  // Add / collapse toggle
                  GestureDetector(
                    onTap: () => setState(() {
                      _showForm = !_showForm;
                      _error = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 9.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kBlue2, _kBlue1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: _kBlue1.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showForm ? Icons.close : Icons.person_add_outlined,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _showForm ? 'Cancel' : 'Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
      
              // ── Add client form (collapsible) ─────────────────────────
              if (_showForm) ...[
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: _kBlue1.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _kBlue1.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_add_outlined,
                              color: _kBlue1, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text('NEW CLIENT',
                              style: TextStyle(
                                  color: _kBlue1,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0)),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _FormField(
                        controller: _nameController,
                        label: 'Client name',
                        hint: 'e.g. John Smith',
                        icon: Icons.person_outline,
                        required: true,
                      ),
                      SizedBox(height: 12.h),
                      _FormField(
                        controller: _phoneController,
                        label: 'Phone',
                        hint: 'Optional',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 12.h),
                      _FormField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Optional',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: _kRedBg,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                                color: _kRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: _kRed, size: 16.sp),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: _kRed, fontSize: 12.sp)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _isSaving ? null : _createClient,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              gradient: _isSaving
                                  ? null
                                  : const LinearGradient(
                                colors: [_kBlue2, _kBlue1],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              color: _isSaving ? _kDivider : null,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: _isSaving
                                  ? null
                                  : [
                                BoxShadow(
                                  color: _kBlue1.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSaving)
                                  SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _kSubText,
                                    ),
                                  )
                                else
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 18.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  _isSaving ? 'Saving…' : 'Save client',
                                  style: TextStyle(
                                      color: _isSaving
                                          ? _kSubText
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.sp),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
      
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
                    hintText: 'Search clients…',
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
      
              // ── Client list ───────────────────────────────────────────
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: CircularProgressIndicator(
                          color: _kTeal,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  }
      
                  if (snapshot.hasError) {
                    return Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: _kRed, size: 18.sp),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(snapshot.error.toString(),
                                style: TextStyle(
                                    color: _kRed, fontSize: 13.sp)),
                          ),
                        ],
                      ),
                    );
                  }
      
                  final allDocs = snapshot.data?.docs ?? [];
                  final docs = _searchQuery.isEmpty
                      ? allDocs
                      : allDocs.where((d) {
                    final name = ((d.data()['name'] as String?) ?? '')
                        .toLowerCase();
                    final email =
                    ((d.data()['email'] as String?) ?? '')
                        .toLowerCase();
                    final phone =
                    ((d.data()['phone'] as String?) ?? '')
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
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
                                color: _kTealBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.people_outline,
                                  color: _kTeal, size: 40.sp),
                            ),
                            SizedBox(height: 16.h),
                            Text('No clients yet',
                                style: TextStyle(
                                    color: _kText,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 4.h),
                            Text('Tap Add to create your first client',
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
                      // Count row
                      Row(
                        children: [
                          Text(
                            '${docs.length} client${docs.length == 1 ? '' : 's'}',
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
                                    color: _kTeal,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      SizedBox(height: 10.h),
      
                      for (final d in docs) _ClientCard(doc: d),
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

// ── Client card ───────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final name  = (d['name']  as String?) ?? 'Client';
    final phone = (d['phone'] as String?)?.trim() ?? '';
    final email = (d['email'] as String?)?.trim() ?? '';

    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
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
            // ── Avatar ───────────────────────────────────────────────
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: _kTealBg,
                borderRadius: BorderRadius.circular(14.r),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                    color: _kTeal,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(width: 14.w),

            // ── Info ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: _kText,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700)),
                  if (phone.isNotEmpty || email.isNotEmpty) ...[
                    SizedBox(height: 5.h),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 4.h,
                      children: [
                        if (phone.isNotEmpty)
                          _InfoChip(
                            icon: Icons.phone_outlined,
                            label: phone,
                          ),
                        if (email.isNotEmpty)
                          _InfoChip(
                            icon: Icons.email_outlined,
                            label: email,
                          ),
                      ],
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
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.sp, color: _kSubText),
        SizedBox(width: 4.w),
        Text(label,
            style: TextStyle(color: _kSubText, fontSize: 12.sp)),
      ],
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _kDivider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: _kText, fontSize: 14.sp),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(color: _kSubText, fontSize: 13.sp),
          hintText: hint,
          hintStyle: TextStyle(
              color: _kSubText.withValues(alpha: 0.5), fontSize: 13.sp),
          prefixIcon: Icon(icon, color: _kSubText, size: 18.sp),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        ),
      ),
    );
  }
}