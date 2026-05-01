import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import '../jobs/line_items_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Create Invoice Screen
// ─────────────────────────────────────────────────────────────────────────────

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  // ── Client ────────────────────────────────────────────────────────────────
  String? _selectedClientId;
  final _firstNameCtrl   = TextEditingController();
  final _lastNameCtrl    = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _clientEmailCtrl = TextEditingController();

  // ── Overview ──────────────────────────────────────────────────────────────
  final _titleCtrl       = TextEditingController(text: 'Invoice');
  DateTime _issueDate    = DateTime.now();
  String? _salesPersonName;
  String? _salesPersonUid;

  // ── Line items ────────────────────────────────────────────────────────────
  List<LineItem> _items  = [];

  // ── Client message ────────────────────────────────────────────────────────
  final _messageCtrl     = TextEditingController();

  bool _previewing       = false;
  bool _sending          = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .doc(FirestorePaths.user(user.uid))
        .get();
    final name = (snap.data()?['name'] as String?)?.trim();
    setState(() {
      _salesPersonUid  = user.uid;
      _salesPersonName = (name != null && name.isNotEmpty) ? name : 'Admin';
    });
  }

  int get _subtotalCents =>
      _items.fold<int>(0, (acc, i) => acc + i.priceCents);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateDisplay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<Map<String, String>> _resolveClient() async {
    if (_selectedClientId != null) {
      final snap = await FirebaseFirestore.instance
          .doc(FirestorePaths.teamClient(widget.teamId, _selectedClientId!))
          .get();
      final d = snap.data() ?? {};
      return {
        'id':    _selectedClientId!,
        'name':  (d['name'] as String?) ?? '',
        'email': (d['email'] as String?) ?? '',
        'phone': (d['phone'] as String?) ?? '',
      };
    }
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final email     = _clientEmailCtrl.text.trim().toLowerCase();
    final phone     = _phoneCtrl.text.trim();
    final address   = _addressCtrl.text.trim();

    String clientId = '';
    if (fullName.isNotEmpty) {
      final ref = FirebaseFirestore.instance
          .collection(FirestorePaths.teamClients(widget.teamId))
          .doc();
      await ref.set({
        'name':      fullName,
        'firstName': firstName,
        'lastName':  lastName,
        'email':     email,
        'phone':     phone,
        'address':   address,
        'createdAt': FieldValue.serverTimestamp(),
      });
      clientId = ref.id;
    }
    return {
      'id':    clientId,
      'name':  fullName,
      'email': email.isNotEmpty ? email : 'aamirsaeed598@gmail.com',
      'phone': phone,
    };
  }

  String _buildTemplate(Map<String, String> client) {
    final buf = StringBuffer();
    buf.writeln(_titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'INVOICE');
    buf.writeln('Date: ${_fmtDate(_issueDate)}');
    if (_salesPersonName != null) buf.writeln('Sales person: $_salesPersonName');
    buf.writeln('');
    buf.writeln('Bill To:');
    if (client['name']!.isNotEmpty) buf.writeln(client['name']);
    if (client['email']!.isNotEmpty) buf.writeln(client['email']);
    if (client['phone']!.isNotEmpty) buf.writeln(client['phone']);
    buf.writeln('');
    buf.writeln('Services / Items:');
    for (final item in _items) {
      final price = item.priceCents == 0
          ? 'Free'
          : '\$${(item.priceCents / 100).toStringAsFixed(2)}';
      buf.writeln('  - ${item.name}: $price');
    }
    buf.writeln('');
    buf.writeln('Subtotal: \$${(_subtotalCents / 100).toStringAsFixed(2)}');
    if (_messageCtrl.text.trim().isNotEmpty) {
      buf.writeln('');
      buf.writeln(_messageCtrl.text.trim());
    }
    return buf.toString();
  }

  Future<void> _saveAndSend() async {
    setState(() { _sending = true; _error = null; });
    try {
      final client = await _resolveClient();
      final ref = FirebaseFirestore.instance
          .collection(FirestorePaths.teamInvoices(widget.teamId))
          .doc();
      await ref.set({
        'title':           _titleCtrl.text.trim(),
        'issueDate':       Timestamp.fromDate(_issueDate),
        'clientId':        client['id'],
        'clientName':      client['name'],
        'clientEmail':     client['email'],
        'clientPhone':     client['phone'],
        'salesPersonUid':  _salesPersonUid,
        'salesPersonName': _salesPersonName ?? '',
        'items': _items.map((i) => {
          'name':        i.name,
          'priceCents':  i.priceCents,
          'description': i.description,
        }).toList(),
        'totalCents':    _subtotalCents,
        'clientMessage': _messageCtrl.text.trim(),
        'status':        'sent',
        'sentAt':        FieldValue.serverTimestamp(),
        'createdAt':     FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      final email = client['email']!.isNotEmpty
          ? client['email']!
          : 'aamirsaeed598@gmail.com';
      final subject = Uri.encodeComponent(
          _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Invoice');
      final body = Uri.encodeComponent(_buildTemplate(client));
      final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
      await launchUrl(uri);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice sent.')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clientsQuery = FirebaseFirestore.instance
        .collection(FirestorePaths.teamClients(widget.teamId))
        .orderBy('createdAt', descending: true);
    final newClient = _selectedClientId == null;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.receipt_long_rounded,
                  size: 16, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Text(
              'Create Invoice',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [

            // ── 1. CLIENT ─────────────────────────────────────────────────
            _SectionCard(

              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF5B7FFF),
              title: 'Client',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: clientsQuery.snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      final ids = docs.map((d) => d.id).toSet();
                      final safeVal = ids.contains(_selectedClientId)
                          ? _selectedClientId
                          : null;
                      return _StyledDropdown<String>(

                        value: safeVal,
                        hint: '— New client —',
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
                        onChanged: (v) =>
                            setState(() => _selectedClientId = v),
                      );
                    },
                  ),
                  if (newClient) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(label: 'New client details'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: _StyledTextField(
                          controller: _firstNameCtrl,
                          label: 'First name',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StyledTextField(
                          controller: _lastNameCtrl,
                          label: 'Last name',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _StyledTextField(
                      controller: _addressCtrl,
                      label: 'Property address',
                      prefixIcon: Icons.home_outlined,
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    _StyledTextField(
                      controller: _phoneCtrl,
                      label: 'Phone number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _StyledTextField(
                      controller: _clientEmailCtrl,
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. OVERVIEW ────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF7C4DFF),
              title: 'Overview',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StyledTextField(
                    controller: _titleCtrl,
                    label: 'Invoice title',
                    prefixIcon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Date picker row
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _issueDate,
                        firstDate: DateTime(2020),
                        lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _issueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color:  Colors.white,

                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date sent',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _fmtDateDisplay(_issueDate),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sales person row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color:
                      Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sales person',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _salesPersonName ?? '—',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 3. PRODUCTS / SERVICES ─────────────────────────────────────
            _SectionCard(
              icon: Icons.list_alt_outlined,
              iconColor: const Color(0xFF00BFA5),
              title: 'Products / Services',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final result = await Navigator.of(context)
                        .push<List<LineItem>>(MaterialPageRoute(
                      builder: (_) => LineItemsScreen(initial: _items),
                    ));
                    if (result != null) setState(() => _items = result);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:  Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.7),
                      ),
                    ),
                    child: _items.isEmpty
                        ? Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Text(
                          'Tap to add services / products',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant),
                      ],
                    )
                        : Column(
                      children: [
                        for (final item in _items)
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                  const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BFA5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style:
                                    theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  item.priceCents == 0
                                      ? 'Free'
                                      : '\$${(item.priceCents / 100).toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        Divider(
                          height: 20,
                          color: colorScheme.outlineVariant
                              .withOpacity(0.5),
                        ),
                        Row(
                          children: [
                            Text('Subtotal',
                                style:
                                theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BFA5)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '\$${(_subtotalCents / 100).toStringAsFixed(2)}',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF00897B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .push<List<LineItem>>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LineItemsScreen(initial: _items),
                                  ));
                              if (result != null) {
                                setState(() => _items = result);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined,
                                size: 14),
                            label: const Text('Edit items'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 4. CLIENT MESSAGE ──────────────────────────────────────────
            _SectionCard(
              icon: Icons.message_outlined,
              iconColor: const Color(0xFFFF6D3B),
              title: 'Client message',
              child: _StyledTextField(
                controller: _messageCtrl,
                label: 'Add a message for the client…',
                minLines: 3,
                maxLines: 6,
              ),
            ),
            const SizedBox(height: 14),

            // ── 5. PREVIEW ─────────────────────────────────────────────────
            if (_previewing) ...[
              Container(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.6),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color:
                            colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.visibility_outlined,
                              size: 14, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Text('Preview',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: colorScheme.onSurfaceVariant),
                          onPressed: () =>
                              setState(() => _previewing = false),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _buildTemplate({
                          'name': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
                          'email': _clientEmailCtrl.text.trim(),
                          'phone': _phoneCtrl.text.trim(),
                          'id': '',
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Error ──────────────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: colorScheme.onErrorContainer, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Actions ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _previewing = !_previewing),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    icon: Icon(
                      _previewing
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                    ),
                    label: Text(
                      _previewing ? 'Hide' : 'Preview',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _saveAndSend,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _sending
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      _sending ? 'Sending…' : 'Send Invoice',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 0.2),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section Card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color:  Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled TextField
// ─────────────────────────────────────────────────────────────────────────────

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        filled: true,
        fillColor:  Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled Dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor:  Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Label
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}