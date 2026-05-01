import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import 'job_status.dart';
import 'line_items_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class _AppColors {
  static const ink        = Color(0xFF0F1117);
  static const surface    = Color(0xFFF7F8FA);
  static const card       = Color(0xFFFFFFFF);
  static const accent     = Color(0xFF2563EB);   // electric blue
  static const accentSoft = Color(0xFFEFF4FF);
  static const muted      = Color(0xFF6B7280);
  static const border     = Color(0xFFE5E7EB);
  static const success    = Color(0xFF16A34A);
  static const error      = Color(0xFFDC2626);
}

// ─────────────────────────────────────────────────────────────────────────────

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({
    super.key,
    required this.teamId,
    this.preselectedClientId,
    this.prefilledTitle,
    this.prefilledDescription,
    this.prefilledPriceCents,
    this.sourceQuoteId,
  });

  final String teamId;
  final String? preselectedClientId;
  final String? prefilledTitle;
  final String? prefilledDescription;
  final int? prefilledPriceCents;
  final String? sourceQuoteId;

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen>
    with SingleTickerProviderStateMixin {
  // ── Client ────────────────────────────────────────────────────────────────
  String? _selectedClientId;

  // ── New client fields ─────────────────────────────────────────────────────
  final _firstNameCtrl       = TextEditingController();
  final _lastNameCtrl        = TextEditingController();
  final _propertyAddressCtrl = TextEditingController();
  final _phoneCtrl           = TextEditingController();
  final _emailCtrl           = TextEditingController();

  // ── Job details ───────────────────────────────────────────────────────────
  final _titleCtrl        = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  // ── Sales person ──────────────────────────────────────────────────────────
  String? _salesPersonUid;
  String? _salesPersonName;
  String? _salesPersonEmail;
  List<Map<String, dynamic>> _admins = [];
  String? _assignedWorkerUid; // ← add this
  // ── Line items ────────────────────────────────────────────────────────────
  List<LineItem> _lineItems = [];

  // ── Schedule ──────────────────────────────────────────────────────────────
  DateTime? _scheduledAt;
  TimeOfDay? _endTime;

  // ── Team member assignment ────────────────────────────────────────────────
  String? _assignedWorkerEmail;
  List<Map<String, String>> _workers = []; // {uid, email}

  bool _isSaving = false;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
    if (widget.prefilledTitle != null)       _titleCtrl.text = widget.prefilledTitle!;
    if (widget.prefilledDescription != null) _instructionsCtrl.text = widget.prefilledDescription!;

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _loadCurrentUser();
    _loadAdmins();
    _loadWorkers();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .doc(FirestorePaths.user(user.uid))
        .get();
    final data = snap.data() ?? {};
    final name = (data['name'] as String?)?.trim();
    setState(() {
      _salesPersonUid   = user.uid;
      _salesPersonEmail = user.email ?? '';
      _salesPersonName  = (name != null && name.isNotEmpty) ? name : 'Admin';
    });
  }

  Future<void> _loadAdmins() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .where('currentTeamId', isEqualTo: widget.teamId)
        .get();
    setState(() {
      _admins = snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    });
  }

  Future<void> _loadWorkers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .get();
    setState(() {
      _workers = snap.docs
          .where((d) => (d.data()['email'] as String?)?.isNotEmpty == true)
          .map((d) => {
        'uid':   d.id,
        'email': (d.data()['email'] as String?)!.trim().toLowerCase(),
      })
          .toList();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _propertyAddressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  int get _subtotalCents =>
      _lineItems.fold<int>(0, (acc, i) => acc + i.priceCents);

  Future<void> _create() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      final title = _titleCtrl.text.trim();
      if (title.isEmpty) throw Exception('Job title is required.');

      // ── Resolve worker UID from state (set at dropdown selection time) ──────
      final String? assignedWorkerUid = _assignedWorkerUid; // ✅ replaces the old email query block

      // ── Resolve / create client ────────────────────────────────────────────
      String? clientId = _selectedClientId;
      if (clientId == null) {
        final firstName = _firstNameCtrl.text.trim();
        final lastName  = _lastNameCtrl.text.trim();
        final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
        if (fullName.isNotEmpty) {
          final clientRef = FirebaseFirestore.instance
              .collection(FirestorePaths.teamClients(widget.teamId))
              .doc();
          await clientRef.set({
            'name':      fullName,
            'firstName': firstName,
            'lastName':  lastName,
            'phone':     _phoneCtrl.text.trim(),
            'email':     _emailCtrl.text.trim().toLowerCase(),
            'address':   _propertyAddressCtrl.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          clientId = clientRef.id;
        }
      }

      // ── Create job with all data in one write ──────────────────────────────
      final uid    = FirebaseAuth.instance.currentUser!.uid;
      final jobRef = FirebaseFirestore.instance
          .collection(FirestorePaths.teamJobs(widget.teamId))
          .doc();
      final priceCents = _subtotalCents > 0 ? _subtotalCents : null;
      final isAssigned = assignedWorkerUid != null;

      await jobRef.set({
        'title':               title,
        'description':         _instructionsCtrl.text.trim(),
        'propertyAddress':     _propertyAddressCtrl.text.trim(),
        'phone':               _phoneCtrl.text.trim(),
        'email':               _emailCtrl.text.trim().toLowerCase(),
        'lineItems':           _lineItems
            .map((i) => {'name': i.name, 'priceCents': i.priceCents})
            .toList(),
        'adminLineItems':      _lineItems
            .map((i) => {'name': i.name, 'priceCents': i.priceCents})
            .toList(),
        'status':              isAssigned
            ? JobStatus.assigned.value
            : JobStatus.open.value,
        'assignedWorkerId':    assignedWorkerUid,   // ✅ now correctly set
        'assignedWorkerEmail': _assignedWorkerEmail,
        'clientId':            clientId,
        'salesPersonUid':      _salesPersonUid,
        'salesPersonName':     _salesPersonName ?? '',
        'salesPersonEmail':    _salesPersonEmail ?? '',
        'scheduledAt':         _scheduledAt == null
            ? null
            : Timestamp.fromDate(_scheduledAt!),
        'scheduledEndTime':    _endTime == null || _scheduledAt == null
            ? null
            : Timestamp.fromDate(DateTime(
            _scheduledAt!.year, _scheduledAt!.month, _scheduledAt!.day,
            _endTime!.hour, _endTime!.minute)),
        'priceCents':          priceCents,
        'paymentStatus':       priceCents == null ? null : 'unpaid',
        'createdByUid':        uid,
        'createdAt':           FieldValue.serverTimestamp(),
        'updatedAt':           FieldValue.serverTimestamp(),
        if (widget.sourceQuoteId != null) 'sourceQuoteId': widget.sourceQuoteId,
      });

      // ── Always set worker's currentTeamId to this team ────────────────────
      if (assignedWorkerUid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(assignedWorkerUid)
            .update({'currentTeamId': widget.teamId});
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clientsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamClients(widget.teamId))
        .orderBy('createdAt', descending: true);
    final newClientSelected = _selectedClientId == null;

    return Theme(
      data: _buildTheme(context),
      child: Scaffold(
        backgroundColor:  Color(0xFFF5F7FA),
        appBar: _buildAppBar(context),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _buildSection(
                  step: '01',
                  title: 'Client',
                  icon: Icons.person_rounded,
                  child: _buildClientSection(clientsQuery, newClientSelected),
                ),
                _buildSection(
                  step: '02',
                  title: 'Job Details',
                  icon: Icons.work_rounded,
                  child: _buildJobDetailsSection(),
                ),
                _buildSection(
                  step: '03',
                  title: 'Sales Person',
                  icon: Icons.badge_rounded,
                  child: _buildSalesPersonSection(),
                ),
                _buildSection(
                  step: '04',
                  title: 'Products & Services',
                  icon: Icons.receipt_long_rounded,
                  child: _buildLineItemsSection(),
                ),
                _buildSection(
                  step: '05',
                  title: 'Schedule',
                  icon: Icons.calendar_month_rounded,
                  child: _buildScheduleSection(),
                ),
                _buildSection(
                  step: '06',
                  title: 'Assign Team Member',
                  icon: Icons.group_rounded,
                  child: _buildTeamSection(),
                ),
                const SizedBox(height: 8),
                if (_error != null) _buildErrorBanner(),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _AppColors.border,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _AppColors.ink,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Job',
            style: TextStyle(
              color: _AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),

        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: _isSaving ? null : _create,
            style: TextButton.styleFrom(
              backgroundColor: _AppColors.accentSoft,
              foregroundColor: _AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _isSaving ? 'Saving…' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection({
    required String step,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header row
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: _AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: _AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: _AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          // Card
          Container(
            decoration: BoxDecoration(
              color: _AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── 1. Client ─────────────────────────────────────────────────────────────

  Widget _buildClientSection(
      Query<Map<String, dynamic>> clientsQuery, bool newClientSelected) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: clientsQuery.snapshots(),
            builder: (context, snapshot) {
              final docs   = snapshot.data?.docs ?? const [];
              final ids    = docs.map((d) => d.id).toSet();
              final safeValue = ids.contains(_selectedClientId)
                  ? _selectedClientId
                  : null;
              return _styledDropdown<String>(
                value:       safeValue,
                labelText:   'Select existing client',
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('— New client —')),
                  for (final d in docs)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                          (d.data()['name'] as String?) ?? 'Client'),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedClientId = v),
              );
            },
          ),
          if (newClientSelected) ...[
            const SizedBox(height: 16),
            _subsectionLabel('New client details'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _styledTextField(
                    controller: _firstNameCtrl, label: 'First name')),
                const SizedBox(width: 12),
                Expanded(child: _styledTextField(
                    controller: _lastNameCtrl, label: 'Last name')),
              ],
            ),
            const SizedBox(height: 12),
            _styledTextField(
              controller:  _propertyAddressCtrl,
              label:       'Property address',
              prefixIcon:  Icons.home_rounded,
              minLines:    2,
              maxLines:    3,
            ),
            const SizedBox(height: 12),
            _styledTextField(
              controller:    _phoneCtrl,
              label:         'Phone number',
              prefixIcon:    Icons.phone_rounded,
              keyboardType:  TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _styledTextField(
              controller:   _emailCtrl,
              label:        'Email',
              prefixIcon:   Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ],
      ),
    );
  }

  // ── 2. Job Details ────────────────────────────────────────────────────────

  Widget _buildJobDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _styledTextField(controller: _titleCtrl, label: 'Job title'),
          const SizedBox(height: 12),
          _styledTextField(
            controller: _instructionsCtrl,
            label:      'Instructions / notes',
            minLines:   3,
            maxLines:   6,
          ),
        ],
      ),
    );
  }

  // ── 3. Sales Person ───────────────────────────────────────────────────────

  Widget _buildSalesPersonSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _styledDropdown<String>(
        value:     _salesPersonUid,
        labelText: 'Select sales person',
        items: [
          if (_salesPersonUid != null)
            DropdownMenuItem(
              value: _salesPersonUid,
              child: Text(_salesPersonName ?? 'Me'),
            ),
          for (final m in _admins)
            if (m['uid'] != _salesPersonUid)
              DropdownMenuItem(
                value: m['uid'] as String?,
                child: Text(
                  (m['name'] as String?)?.isNotEmpty == true
                      ? m['name'] as String
                      : 'Admin',
                ),
              ),
        ],
        onChanged: (uid) {
          if (uid == null || uid == _salesPersonUid) return;
          final m = _admins.firstWhere(
                  (a) => a['uid'] == uid, orElse: () => {});
          setState(() {
            _salesPersonUid   = uid;
            _salesPersonName  =
            (m['name'] as String?)?.isNotEmpty == true
                ? m['name'] as String
                : 'Admin';
            _salesPersonEmail = (m['email'] as String?) ?? '';
          });
        },
      ),
    );
  }

  // ── 4. Line Items ─────────────────────────────────────────────────────────

  Widget _buildLineItemsSection() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final result = await Navigator.of(context).push<List<LineItem>>(
            MaterialPageRoute(
                builder: (_) => LineItemsScreen(initial: _lineItems)));
        if (result != null) setState(() => _lineItems = result);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _lineItems.isEmpty
                      ? Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 18, color: _AppColors.accent),
                      const SizedBox(width: 8),
                      const Text('Tap to add line items',
                          style: TextStyle(
                              color: _AppColors.muted, fontSize: 14)),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in _lineItems)
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                  color: _AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: _AppColors.ink))),
                              Text(
                                item.priceCents == 0
                                    ? 'Free'
                                    : '\$${(item.priceCents / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _AppColors.ink),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: _AppColors.accent),
                ),
              ],
            ),
            if (_lineItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: _AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  const Text('Subtotal',
                      style: TextStyle(
                          color: _AppColors.muted, fontSize: 13)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${(_subtotalCents / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _AppColors.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 5. Schedule ───────────────────────────────────────────────────────────

  Widget _buildScheduleSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date picker tile
          _schedulePickerTile(
            icon:    Icons.calendar_today_rounded,
            label:   _scheduledAt == null ? 'Select date' : _formatDate(_scheduledAt!),
            isEmpty: _scheduledAt == null,
            onTap: () async {
              final date = await showDatePicker(
                context:     context,
                firstDate:   DateTime.now().subtract(const Duration(days: 365)),
                lastDate:    DateTime.now().add(const Duration(days: 365 * 5)),
                initialDate: _scheduledAt ?? DateTime.now(),
              );
              if (date == null) return;
              setState(() {
                _scheduledAt = _scheduledAt == null
                    ? DateTime(date.year, date.month, date.day, 9, 0)
                    : DateTime(date.year, date.month, date.day,
                    _scheduledAt!.hour, _scheduledAt!.minute);
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _schedulePickerTile(
                  icon:    Icons.play_arrow_rounded,
                  label:   _scheduledAt == null
                      ? 'Start time'
                      : _formatTime(_scheduledAt!.hour, _scheduledAt!.minute),
                  isEmpty: _scheduledAt == null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context:     context,
                      initialTime: _scheduledAt != null
                          ? TimeOfDay.fromDateTime(_scheduledAt!)
                          : const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time == null) return;
                    final base = _scheduledAt ?? DateTime.now();
                    setState(() {
                      _scheduledAt = DateTime(
                          base.year, base.month, base.day,
                          time.hour, time.minute);
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _schedulePickerTile(
                  icon:    Icons.stop_rounded,
                  label:   _endTime == null
                      ? 'End time'
                      : _formatTime(_endTime!.hour, _endTime!.minute),
                  isEmpty: _endTime == null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context:     context,
                      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (time == null) return;
                    setState(() => _endTime = time);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schedulePickerTile({
    required IconData icon,
    required String   label,
    required bool     isEmpty,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        isEmpty ? _AppColors.surface : _AppColors.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: isEmpty ? _AppColors.border : _AppColors.accent.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size:  16,
                color: isEmpty ? _AppColors.muted : _AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:      isEmpty ? _AppColors.muted : _AppColors.ink,
                  fontSize:   13,
                  fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Team Assignment ────────────────────────────────────────────────────

  Widget _buildTeamSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'worker')
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final workers = docs
              .where((d) =>
                  (d.data()['email'] as String?)?.isNotEmpty == true)
              .map((d) => {
                    'uid': d.id,
                    'email': ((d.data()['email'] as String?) ?? '').trim().toLowerCase(),
                    'name': ((d.data()['name'] as String?) ?? '').trim(),
                  })
              .toList();

          if (workers.isEmpty) {
            return Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _AppColors.border),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    size: 16, color: _AppColors.muted),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No workers registered yet.',
                  style: TextStyle(color: _AppColors.muted, fontSize: 13),
                ),
              ),
            ]);
          }

          return _styledDropdown<String>(
            value: _assignedWorkerEmail,
            labelText: 'Select worker',
            items: [
              const DropdownMenuItem<String>(
                  value: null, child: Text('Unassigned')),
              for (final w in workers)
                DropdownMenuItem(
                  value: w['email'],
                  child: Text(w['name']!.isNotEmpty
                      ? w['name']!
                      : w['email']!),
                ),
            ],
            onChanged: (email) {
              final worker = workers.firstWhere(
                (w) => w['email'] == email,
                orElse: () => {},
              );
              setState(() {
                _assignedWorkerEmail = email;
                _assignedWorkerUid = worker['uid'];
              });
            },
          );
        },
      ),
    );
  }

  // ── Error + Save ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        _AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: _AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                  color: _AppColors.error, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _isSaving
              ? null
              : const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          color: _isSaving ? _AppColors.border : null,
          boxShadow: _isSaving
              ? null
              : [
            BoxShadow(
              color:  _AppColors.accent.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _create,
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
              : const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 20),
          label: Text(
            _isSaving ? 'Saving…' : 'Save Job',
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      minLines:     minLines,
      maxLines:     maxLines,
      style: const TextStyle(
          color: _AppColors.ink, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:   label,
        labelStyle:  const TextStyle(color: _AppColors.muted, fontSize: 13),
        prefixIcon:  prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: _AppColors.muted)
            : null,
        filled:      true,
        fillColor:   _AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: _AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _styledDropdown<T>({
    required T? value,
    required String labelText,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value:     value,
      items:     items,
      onChanged: onChanged,
      style: const TextStyle(
          color: _AppColors.ink, fontSize: 14, fontWeight: FontWeight.w500),
      dropdownColor: _AppColors.card,
      decoration: InputDecoration(
        labelText:  labelText,
        labelStyle: const TextStyle(color: _AppColors.muted, fontSize: 13),
        filled:     true,
        fillColor:  _AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: _AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _subsectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color:      _AppColors.accent,
        fontSize:   12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  ThemeData _buildTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary:   _AppColors.accent,
        surface:   _AppColors.surface,
        onSurface: _AppColors.ink,
      ),
    );
  }
}