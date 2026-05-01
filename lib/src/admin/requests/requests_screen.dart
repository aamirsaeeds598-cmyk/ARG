import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/firestore_paths.dart';
import '../jobs/line_items_screen.dart';
import 'request_details_screen.dart';

// ── Brand colours (matches light theme) ──────────────────────────────────────
const _kBg        = Color(0xFFF5F7FA);
const _kCard      = Colors.white;
const _kBlue1     = Color(0xFF2563EB);
const _kBlue2     = Color(0xFF1D4ED8);
const _kText      = Color(0xFF0F172A);
const _kSubText   = Color(0xFF64748B);
const _kDivider   = Color(0xFFE2E8F0);
const _kRed       = Color(0xFFDC2626);
const _kRedBg     = Color(0xFFFEF2F2);
const _kGreen     = Color(0xFF059669);
const _kGreenBg   = Color(0xFFECFDF5);
const _kAmber     = Color(0xFFD97706);
const _kAmberBg   = Color(0xFFFFFBEB);
const _kOrange    = Color(0xFFEA580C);
const _kOrangeBg  = Color(0xFFFFF7ED);

// Priority helpers
Color _priorityColor(String p) =>
    p == 'urgent' ? _kRed : _kGreen;
Color _priorityBg(String p) =>
    p == 'urgent' ? _kRedBg : _kGreenBg;
IconData _priorityIcon(String p) =>
    p == 'urgent' ? Icons.bolt : Icons.radio_button_unchecked;

// Status helpers
Color _statusColor(String s) {
  switch (s) {
    case 'new':        return _kBlue1;
    case 'in_progress': return _kAmber;
    case 'done':       return _kGreen;
    default:           return _kSubText;
  }
}
Color _statusBg(String s) {
  switch (s) {
    case 'new':        return const Color(0xFFEFF6FF);
    case 'in_progress': return _kAmberBg;
    case 'done':       return _kGreenBg;
    default:           return const Color(0xFFF8FAFC);
  }
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.teamId,
    this.preselectedClientId,
  });

  final String teamId;
  final String? preselectedClientId;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _serviceDescriptionController = TextEditingController();
  final _locationController           = TextEditingController();
  final _notesController              = TextEditingController();
  final _newClientNameController      = TextEditingController();
  final _newClientPhoneController     = TextEditingController();
  final _newClientEmailController     = TextEditingController();

  DateTime? _scheduledAt;
  List<String> _photos = []; // base64 encoded images
  String  _priority        = 'normal';
  String  _serviceCategory = '';
  String? _selectedClientId;
  String? _assignedWorkerEmail;
  List<LineItem> _lineItems = [];
  bool _createNewClient = false;
  bool _showForm        = false;
  bool _isSaving        = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
  }

  @override
  void dispose() {
    _serviceDescriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _newClientNameController.dispose();
    _newClientPhoneController.dispose();
    _newClientEmailController.dispose();
    super.dispose();
  }

  Future<String> _resolveClientId() async {
    final db = FirebaseFirestore.instance;
    if (_createNewClient) {
      final name = _newClientNameController.text.trim();
      if (name.isEmpty) throw Exception('New client name is required.');
      final ref =
      db.collection(FirestorePaths.teamClients(widget.teamId)).doc();
      await ref.set({
        'name': name,
        'phone': _newClientPhoneController.text.trim(),
        'email': _newClientEmailController.text.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      throw Exception('Select an existing client or create a new one.');
    }
    return _selectedClientId!;
  }

  Future<void> _createRequest() async {
    // Guard: require scheduled date & time before doing anything
    if (_scheduledAt == null) {
      setState(() => _error = 'Scheduled date & time is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error    = null;
    });

    try {
      final serviceDescription = _serviceDescriptionController.text.trim();
      final location           = _locationController.text.trim();
      if (serviceDescription.isEmpty) throw Exception('Service description is required.');
      if (location.isEmpty) throw Exception('Location/address is required.');

      final clientId = await _resolveClientId();
      final clientSnap = await FirebaseFirestore.instance
          .doc(FirestorePaths.teamClient(widget.teamId, clientId))
          .get();
      final client = clientSnap.data();
      if (client == null) throw Exception('Selected client not found.');

      final requestRef = FirebaseFirestore.instance
          .collection(FirestorePaths.teamRequests(widget.teamId))
          .doc();

      await requestRef.set({
        'clientId'            : clientId,
        'clientName'          : client['name'],
        'clientEmail'         : client['email'],
        'clientPhone'         : client['phone'],
        'serviceDescription'  : serviceDescription,
        'location'            : location,
        'preferredAt'         : null,
        'scheduledAt'         : Timestamp.fromDate(_scheduledAt!),
        'notes'               : _notesController.text.trim(),
        'photoUrls'           : _photos,
        'serviceCategory'     : _serviceCategory,
        'priority'            : _priority,
        'status'              : 'new',
        'assignedWorkerEmail' : _assignedWorkerEmail ?? '',
        'lineItems'           : _lineItems
            .map((i) => {'name': i.name, 'priceCents': i.priceCents})
            .toList(),
        'subtotalCents'       : _lineItems.fold<int>(0, (a, i) => a + i.priceCents),
        'createdByUid'        : FirebaseAuth.instance.currentUser!.uid,
        'createdAt'           : FieldValue.serverTimestamp(),
        'updatedAt'           : FieldValue.serverTimestamp(),
      });

      // Always assign worker to this team when request is created
      if (_assignedWorkerEmail != null && _assignedWorkerEmail!.isNotEmpty) {
        final workerSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _assignedWorkerEmail)
            .limit(1)
            .get();
        if (workerSnap.docs.isNotEmpty) {
          await workerSnap.docs.first.reference
              .update({'currentTeamId': widget.teamId});
        }
      }

      _resetForm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request created successfully.'),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r)),
        ),
      );
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(
          teamId: widget.teamId,
          requestId: requestRef.id,
        ),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _serviceDescriptionController.clear();
    _locationController.clear();
    _notesController.clear();
    setState(() {
      _photos = [];
    });
    _newClientNameController.clear();
    _newClientPhoneController.clear();
    _newClientEmailController.clear();
    setState(() {
      _scheduledAt         = null;
      _priority            = 'normal';
      _serviceCategory     = '';
      _selectedClientId    = null;
      _assignedWorkerEmail = null;
      _lineItems           = [];
      _createNewClient     = false;
      _showForm            = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamRequests(widget.teamId))
        .orderBy('createdAt', descending: true);
    final clientsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamClients(widget.teamId))
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: Container(
        color: Color(0xFFF5F7FA),
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
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.inbox_outlined,
                        color: Colors.white, size: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Requests',
                            style: TextStyle(
                                color: _kText,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        Text('Create and manage service requests',
                            style: TextStyle(
                                color: _kSubText, fontSize: 12.sp)),
                      ],
                    ),
                  ),
                  // Add / collapse toggle
                  GestureDetector(
                    onTap: () => setState(() {
                      _showForm = !_showForm;
                      _error    = null;
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
                            _showForm ? Icons.close : Icons.add_task,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _showForm ? 'Cancel' : 'New',
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
      
              // ── Create request form (collapsible) ─────────────────────
              if (_showForm) ...[
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                        color: _kOrange.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form section label
                      Row(children: [
                        Icon(Icons.add_task, color: _kOrange, size: 15.sp),
                        SizedBox(width: 6.w),
                        Text('NEW REQUEST',
                            style: TextStyle(
                                color: _kOrange,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0)),
                      ]),
                      SizedBox(height: 16.h),
      
                      // ── Client section ────────────────────────────────
                      _FormSectionLabel(
                          'Client', Icons.person_outline),
                      SizedBox(height: 10.h),
      
                      // New client toggle
                      GestureDetector(
                        onTap: () => setState(
                                () => _createNewClient = !_createNewClient),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: _createNewClient
                                ? const Color(0xFFEFF6FF)
                                : _kBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: _createNewClient
                                  ? _kBlue1.withValues(alpha: 0.4)
                                  : _kDivider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _createNewClient
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: _createNewClient
                                    ? _kBlue1
                                    : _kSubText,
                                size: 18.sp,
                              ),
                              SizedBox(width: 10.w),
                              Text('Create new client',
                                  style: TextStyle(
                                      color: _createNewClient
                                          ? _kBlue1
                                          : _kText,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
      
                      if (_createNewClient) ...[
                        _FormField(
                            controller: _newClientNameController,
                            label: 'Client name',
                            hint: 'e.g. John Smith',
                            icon: Icons.person_outline,
                            required: true),
                        SizedBox(height: 10.h),
                        _FormField(
                            controller: _newClientPhoneController,
                            label: 'Phone',
                            hint: 'Optional',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone),
                        SizedBox(height: 10.h),
                        _FormField(
                            controller: _newClientEmailController,
                            label: 'Email',
                            hint: 'Optional',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress),
                      ] else
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: clientsQuery.snapshots(),
                          builder: (context, snapshot) {
                            final docs = snapshot.data?.docs ?? [];
                            return _StyledDropdown<String>(
                              value: _selectedClientId,
                              hint: 'Select existing client',
                              icon: Icons.person_outline,
                              items: [
                                for (final d in docs)
                                  DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      (d.data()['name'] as String?) ?? 'Client',
                                      style: TextStyle(
                                          color: _kText,
                                          fontSize: 14.sp),
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedClientId = v),
                            );
                          },
                        ),
      
                      SizedBox(height: 18.h),
                      _Divider(),
      
                      // ── Service details ───────────────────────────────
                      _FormSectionLabel(
                          'Service Details', Icons.build_outlined),
                      SizedBox(height: 10.h),
                      _FormField(
                        controller: _serviceDescriptionController,
                        label: 'Service description',
                        hint: 'Describe what needs to be done…',
                        icon: Icons.description_outlined,
                        minLines: 2,
                        maxLines: 4,
                        required: true,
                      ),
                      SizedBox(height: 10.h),
                      _FormField(
                        controller: _locationController,
                        label: 'Location / address',
                        hint: 'e.g. 123 Main St',
                        icon: Icons.location_on_outlined,
                        required: true,
                      ),
                      SizedBox(height: 10.h),
      
                      // Category dropdown
                      _StyledDropdown<String>(
                        value: _serviceCategory.isEmpty
                            ? null
                            : _serviceCategory,
                        hint: 'Service category (optional)',
                        icon: Icons.category_outlined,
                        items: const [
                          DropdownMenuItem(
                              value: 'cleaning',
                              child: Text('Cleaning')),
                          DropdownMenuItem(
                              value: 'repair', child: Text('Repair')),
                          DropdownMenuItem(
                              value: 'installation',
                              child: Text('Installation')),
                          DropdownMenuItem(
                              value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) =>
                            setState(() => _serviceCategory = v ?? ''),
                      ),
                      SizedBox(height: 10.h),
      
                      // Priority
                      _StyledDropdown<String>(
                        value: _priority,
                        hint: 'Priority',
                        icon: Icons.bolt_outlined,
                        items: [
                          DropdownMenuItem(
                            value: 'normal',
                            child: Row(children: [
                              Icon(Icons.radio_button_unchecked,
                                  color: _kGreen, size: 14.sp),
                              SizedBox(width: 8.w),
                              const Text('Normal'),
                            ]),
                          ),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Row(children: [
                              Icon(Icons.bolt, color: _kRed, size: 14.sp),
                              SizedBox(width: 8.w),
                              const Text('Urgent'),
                            ]),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'normal'),
                      ),
      
                      SizedBox(height: 18.h),
                      _Divider(),
      
                      // ── Scheduling ────────────────────────────────────
                      _FormSectionLabel(
                          'Scheduling', Icons.calendar_today_outlined),
                      SizedBox(height: 10.h),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                            initialDate: _scheduledAt ?? DateTime.now(),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                                _scheduledAt ?? DateTime.now()),
                          );
                          if (time == null) return;
                          setState(() {
                            _scheduledAt = DateTime(date.year, date.month,
                                date.day, time.hour, time.minute);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 13.h),
                          decoration: BoxDecoration(
                            color: _scheduledAt != null
                                ? const Color(0xFFEFF6FF)
                                : _kBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: _scheduledAt != null
                                  ? _kBlue1.withValues(alpha: 0.4)
                                  : _kDivider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  color: _scheduledAt != null
                                      ? _kBlue1
                                      : _kSubText,
                                  size: 18.sp),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  _scheduledAt == null
                                      ? 'Schedule time'
                                      : '${_scheduledAt!.day.toString().padLeft(2, '0')}/'
                                      '${_scheduledAt!.month.toString().padLeft(2, '0')}/'
                                      '${_scheduledAt!.year}  '
                                      '${_scheduledAt!.hour.toString().padLeft(2, '0')}:'
                                      '${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      color: _scheduledAt != null
                                          ? _kBlue1
                                          : _kSubText,
                                      fontSize: 14.sp,
                                      fontWeight: _scheduledAt != null
                                          ? FontWeight.w600
                                          : FontWeight.w400),
                                ),
                              ),
                              if (_scheduledAt != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _scheduledAt = null),
                                  child: Icon(Icons.close,
                                      color: _kSubText, size: 16.sp),
                                ),
                            ],
                          ),
                        ),
                      ),
      
                      SizedBox(height: 18.h),
                      _Divider(),
      
                      // ── Notes & Photos ────────────────────────────────
                      _FormSectionLabel(
                          'Notes & Attachments', Icons.notes_outlined),
                      SizedBox(height: 10.h),
                      _FormField(
                        controller: _notesController,
                        label: 'Notes / details',
                        hint: 'Any additional information…',
                        icon: Icons.notes_outlined,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      SizedBox(height: 10.h),
                      _PhotoPickerField(
                        label: 'Share images of the work to be done',
                        photos: _photos,
                        onPhotosChanged: (p) => setState(() => _photos = p),
                      ),

                      SizedBox(height: 18.h),
                      _Divider(),
      
                      // ── Products / Services ───────────────────────────
                      _FormSectionLabel(
                          'Products / Services', Icons.list_alt_outlined),
                      SizedBox(height: 10.h),
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .push<List<LineItem>>(MaterialPageRoute(
                            builder: (_) =>
                                LineItemsScreen(initial: _lineItems),
                          ));
                          if (result != null) {
                            setState(() => _lineItems = result);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: _kBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: _kDivider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius:
                                  BorderRadius.circular(8.r),
                                ),
                                child: Icon(Icons.list_alt_outlined,
                                    color: _kBlue1, size: 16.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text('Select products / services',
                                        style: TextStyle(
                                            color: _kText,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _lineItems.isEmpty
                                          ? 'Tap to select'
                                          : _lineItems
                                          .map((i) => i.name)
                                          .join(', '),
                                      style: TextStyle(
                                          color: _kSubText,
                                          fontSize: 12.sp),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (_lineItems.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: _kGreenBg,
                                    borderRadius:
                                    BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '\$${(_lineItems.fold<int>(0, (a, i) => a + i.priceCents) / 100).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: _kGreen,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                              SizedBox(width: 8.w),
                              Icon(Icons.chevron_right,
                                  color: _kSubText, size: 18.sp),
                            ],
                          ),
                        ),
                      ),
      
                      SizedBox(height: 18.h),
                      _Divider(),
      
                      // ── Assign worker ─────────────────────────────────
                      _FormSectionLabel(
                          'Assign Worker', Icons.badge_outlined),
                      SizedBox(height: 10.h),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'worker')
                            .snapshots(),
                        builder: (context, invSnap) {
                          final docs = invSnap.data?.docs ?? [];
                          final workers = docs.map((d) => (
                            email: (d.data()['email'] as String?) ?? '',
                            name: (d.data()['name'] as String?)?.trim() ?? '',
                          )).where((w) => w.email.isNotEmpty).toList();
                          if (workers.isEmpty) {
                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: _kBg,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: _kDivider),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: _kSubText, size: 16.sp),
                                  SizedBox(width: 8.w),
                                  Text('No workers available to assign',
                                      style: TextStyle(
                                          color: _kSubText,
                                          fontSize: 13.sp)),
                                ],
                              ),
                            );
                          }
                          return _StyledDropdown<String>(
                            value: _assignedWorkerEmail,
                            hint: 'Unassigned',
                            icon: Icons.badge_outlined,
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text('Unassigned',
                                    style: TextStyle(
                                        color: _kSubText,
                                        fontSize: 14.sp)),
                              ),
                              for (final w in workers)
                                DropdownMenuItem(
                                  value: w.email,
                                  child: Text(
                                    w.name.isNotEmpty ? w.name : w.email,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _assignedWorkerEmail = v),
                          );
                        },
                      ),
      
                      // ── Error banner ──────────────────────────────────
                      if (_error != null) ...[
                        SizedBox(height: 14.h),
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
      
                      SizedBox(height: 18.h),
      
                      // ── Submit button ─────────────────────────────────
                      GestureDetector(
                        onTap: _isSaving ? null : _createRequest,
                        child: Container(
                          width: double.infinity,
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
                                color:
                                _kBlue1.withValues(alpha: 0.3),
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
                                      color: _kSubText),
                                )
                              else
                                Icon(Icons.add_task,
                                    color: Colors.white, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                _isSaving ? 'Saving…' : 'Create request',
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
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
      
              // ── Section label: requests list ──────────────────────────
              Row(children: [
                Icon(Icons.inbox_outlined, size: 14.sp, color: _kOrange),
                SizedBox(width: 6.w),
                Text('ALL REQUESTS',
                    style: TextStyle(
                        color: _kOrange,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
              ]),
              SizedBox(height: 12.h),
      
              // ── Request list ──────────────────────────────────────────
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: requestsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: CircularProgressIndicator(
                          color: _kOrange,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                            color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline,
                            color: _kRed, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                            child: Text(snapshot.error.toString(),
                                style: TextStyle(
                                    color: _kRed, fontSize: 13.sp))),
                      ]),
                    );
                  }
      
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.h),
                        child: Column(children: [
                          Container(
                            padding: EdgeInsets.all(20.w),
                            decoration: const BoxDecoration(
                              color: _kOrangeBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.inbox_outlined,
                                color: _kOrange, size: 40.sp),
                          ),
                          SizedBox(height: 16.h),
                          Text('No requests yet',
                              style: TextStyle(
                                  color: _kText,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 4.h),
                          Text('Tap New to create your first request',
                              style: TextStyle(
                                  color: _kSubText, fontSize: 13.sp)),
                        ]),
                      ),
                    );
                  }
      
                  return Column(
                    children: [
                      for (final d in docs)
                        _RequestCard(
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

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.teamId, required this.doc});
  final String teamId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d           = doc.data();
    final clientName  = (d['clientName']         as String?) ?? 'Client';
    final description = (d['serviceDescription'] as String?) ?? '';
    final priority    = (d['priority']           as String?) ?? 'normal';
    final status      = (d['status']             as String?) ?? 'new';
    final location    = (d['location']           as String?) ?? '';
    final assignedEmail = (d['assignedWorkerEmail'] as String?) ?? '';
    final initials    = clientName.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            RequestDetailsScreen(teamId: teamId, requestId: doc.id),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left accent bar
                  Container(
                    width: 4.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: _priorityColor(priority),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Client avatar
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: _kOrangeBg,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: TextStyle(
                            color: _kOrange,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName,
                            style: TextStyle(
                                color: _kText,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700)),
                        if (description.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: _kSubText, fontSize: 12.sp)),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Status chip
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: _statusBg(status),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: _statusColor(status)
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4)),
                  ),
                ],
              ),
            ),

            // ── Footer meta row ───────────────────────────────────────
            Divider(height: 1, color: _kDivider),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 9.h),
              child: Row(
                children: [
                  if (location.isNotEmpty) ...[
                    Icon(Icons.location_on_outlined,
                        size: 12.sp, color: _kSubText),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _kSubText, fontSize: 12.sp)),
                    ),
                  ],
                  if (assignedEmail.isNotEmpty) ...[
                    if (location.isNotEmpty) SizedBox(width: 8.w),
                    Icon(Icons.badge_outlined,
                        size: 12.sp, color: _kSubText),
                    SizedBox(width: 4.w),
                    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where('email', isEqualTo: assignedEmail)
                          .limit(1)
                          .get(),
                      builder: (context, snap) {
                        final name = snap.data?.docs.firstOrNull
                            ?.data()['name'] as String?;
                        final display = (name != null && name.trim().isNotEmpty)
                            ? name.trim()
                            : assignedEmail.split('@').first;
                        return Text(display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: _kSubText,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600));
                      },
                    ),
                  ],
                  const Spacer(),
                  // Priority badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: _priorityBg(priority),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_priorityIcon(priority),
                            size: 11.sp,
                            color: _priorityColor(priority)),
                        SizedBox(width: 3.w),
                        Text(priority.toUpperCase(),
                            style: TextStyle(
                                color: _priorityColor(priority),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4)),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.chevron_right,
                      color: _kSubText, size: 16.sp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13.sp, color: _kSubText),
    SizedBox(width: 6.w),
    Text(text.toUpperCase(),
        style: TextStyle(
            color: _kSubText,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    Divider(color: _kDivider, height: 1),
    SizedBox(height: 16.h),
  ]);
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
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
        minLines: minLines,
        maxLines: maxLines,
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

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _kDivider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(children: [
            Icon(icon, color: _kSubText, size: 18.sp),
            SizedBox(width: 10.w),
            Text(hint,
                style: TextStyle(color: _kSubText, fontSize: 14.sp)),
          ]),
          icon: Icon(Icons.keyboard_arrow_down,
              color: _kSubText, size: 20.sp),
          dropdownColor: _kCard,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Photo picker field ────────────────────────────────────────────────────────

class _PhotoPickerField extends StatelessWidget {
  const _PhotoPickerField({
    required this.photos,
    required this.onPhotosChanged,
    this.label,
  });

  final List<String> photos;
  final void Function(List<String>) onPhotosChanged;
  final String? label;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    onPhotosChanged([...photos, b64]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        // Pick buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
        ]),

        // Preview grid
        if (photos.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (var i = 0; i < photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.memory(
                        base64Decode(photos[i]),
                        width: 80.w,
                        height: 80.w,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          final updated = [...photos]..removeAt(i);
                          onPhotosChanged(updated);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
