import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import 'line_items_screen.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({
    super.key,
    required this.teamId,
    required this.jobId,
    required this.jobData,
  });

  final String teamId;
  final String jobId;
  final Map<String, dynamic> jobData;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen>
    with SingleTickerProviderStateMixin {
  late List<_InvoiceItem> _items;
  late final TextEditingController _titleCtrl;
  DateTime _issueDate = DateTime.now();
  bool _previewing = false;
  bool _emailSent = false;
  String? _existingInvoiceId;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _titleCtrl = TextEditingController(
      text: 'Invoice — ${(widget.jobData['title'] as String?) ?? 'Job'}',
    );
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSave());
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _loadItems() {
    final raw = widget.jobData['lineItems'];
    final list = raw is List ? raw.cast<Map>() : const <Map>[];
    _items = list
        .map((m) => _InvoiceItem(
      name: (m['name'] ?? '').toString(),
      priceCents: (m['priceCents'] as int?) ?? 0,
      description: (m['description'] ?? '').toString(),
    ))
        .toList();
  }

  int get _subtotalCents =>
      _items.fold<int>(0, (acc, i) => acc + i.priceCents);

  String _formatAmount(int cents) =>
      '\$${(cents / 100).toStringAsFixed(2)}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _buildTemplate(Map<String, dynamic> clientData) {
    final jobTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : (widget.jobData['title'] as String?) ?? 'Job';
    final clientName = (clientData['name'] as String?) ?? 'Client';
    final clientEmail = (clientData['email'] as String?) ?? '';
    final salesPerson = (widget.jobData['salesPersonName'] as String?) ?? '';
    final dateStr = _formatDate(_issueDate);

    final buf = StringBuffer();
    buf.writeln(
        _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'INVOICE');
    buf.writeln('Date: $dateStr');
    if (salesPerson.isNotEmpty) buf.writeln('Sales person: $salesPerson');
    buf.writeln('');
    buf.writeln('Bill To:');
    buf.writeln(clientName);
    if (clientEmail.isNotEmpty) buf.writeln(clientEmail);
    buf.writeln('');
    buf.writeln('Job: $jobTitle');
    buf.writeln('');
    buf.writeln('Services / Items:');
    for (final item in _items) {
      final price =
      item.priceCents == 0 ? 'Free' : _formatAmount(item.priceCents);
      buf.writeln('  - ${item.name}: $price');
      if (item.description.isNotEmpty) buf.writeln('    ${item.description}');
    }
    buf.writeln('');
    buf.writeln('Total: ${_formatAmount(_subtotalCents)}');
    return buf.toString();
  }

  Future<void> _autoSave({Map<String, dynamic>? clientData}) async {
    try {
      if (_existingInvoiceId == null) {
        final existing = await FirebaseFirestore.instance
            .collection(FirestorePaths.teamInvoices(widget.teamId))
            .where('jobId', isEqualTo: widget.jobId)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          setState(() => _existingInvoiceId = existing.docs.first.id);
        }
      }

      final ref = _existingInvoiceId != null
          ? FirebaseFirestore.instance.doc(
          FirestorePaths.teamInvoice(widget.teamId, _existingInvoiceId!))
          : FirebaseFirestore.instance
          .collection(FirestorePaths.teamInvoices(widget.teamId))
          .doc();

      await ref.set({
        'jobId': widget.jobId,
        'title': _titleCtrl.text.trim(),
        'issueDate': Timestamp.fromDate(_issueDate),
        'jobTitle': (widget.jobData['title'] as String?) ?? '',
        'clientId': widget.jobData['clientId'],
        'clientName': (clientData?['name'] as String?) ??
            (widget.jobData['clientName'] as String?) ??
            '',
        'clientEmail': (clientData?['email'] as String?) ??
            (widget.jobData['email'] as String?) ??
            '',
        'salesPersonName':
        (widget.jobData['salesPersonName'] as String?) ?? '',
        'items': _items
            .map((i) => {
          'name': i.name,
          'priceCents': i.priceCents,
          'description': i.description,
        })
            .toList(),
        'totalCents': _subtotalCents,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => _existingInvoiceId = ref.id);
    } catch (_) {}
  }

  Future<void> _sendEmail(Map<String, dynamic> clientData) async {
    await _autoSave(clientData: clientData);
    String email = (clientData['email'] as String?)?.trim() ?? '';
    if (email.isEmpty) email = (widget.jobData['email'] as String?)?.trim() ?? '';
    if (email.isEmpty) email = 'aamirsaeeds588@gmail.com';

    final jobTitle = (widget.jobData['title'] as String?) ?? 'Job';
    final subject = Uri.encodeComponent('Invoice: $jobTitle');
    final body = Uri.encodeComponent(_buildTemplate(clientData));
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')));
      return;
    }
    if (mounted) setState(() => _emailSent = true);
  }

  Future<void> _collectPayment() async {
    if (_existingInvoiceId != null) {
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamInvoice(widget.teamId, _existingInvoiceId!))
          .update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
    }
    await FirebaseFirestore.instance
        .doc(FirestorePaths.teamJob(widget.teamId, widget.jobId))
        .update({
      'paymentStatus': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment collected. Job closed.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clientId = widget.jobData['clientId'] as String?;

    return Scaffold(
      backgroundColor:  Color(0xFFF5F7FA),
      appBar: _buildAppBar(theme, colorScheme),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: clientId != null && clientId.isNotEmpty
            ? FirebaseFirestore.instance
            .doc(FirestorePaths.teamClient(widget.teamId, clientId))
            .get()
            : null,
        builder: (context, clientSnap) {
          final clientData = clientSnap.data?.data() ?? {};
          final clientName = (clientData['name'] as String?) ?? 'Client';
          final clientEmail = (clientData['email'] as String?) ?? '';

          return FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // ── Hero total banner ───────────────────────────────
                  _buildTotalBanner(theme, colorScheme, clientName),
                  const SizedBox(height: 24),

                  // ── Overview ────────────────────────────────────────
                  _buildSectionLabel(theme, 'OVERVIEW'),
                  const SizedBox(height: 8),
                  _buildOverviewCard(theme, colorScheme),
                  const SizedBox(height: 20),

                  // ── Job & Client details ────────────────────────────
                  _buildSectionLabel(theme, 'JOB & CLIENT'),
                  const SizedBox(height: 8),
                  _buildJobDetailsCard(
                      theme, colorScheme, clientName, clientEmail),
                  const SizedBox(height: 20),

                  // ── Services ────────────────────────────────────────
                  _buildSectionLabel(theme, 'SERVICES & ITEMS'),
                  const SizedBox(height: 8),
                  _buildServicesCard(theme, colorScheme),
                  const SizedBox(height: 20),

                  // ── Preview ─────────────────────────────────────────
                  if (_previewing) ...[
                    _buildSectionLabel(theme, 'PREVIEW'),
                    const SizedBox(height: 8),
                    _buildPreviewCard(theme, colorScheme, clientData),
                    const SizedBox(height: 20),
                  ],

                  // ── Actions ─────────────────────────────────────────
                  _buildActions(theme, colorScheme, clientData),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: colorScheme.onSurface),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Draft • Auto-saved',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 7, color: Colors.amber.shade600),
                const SizedBox(width: 5),
                Text(
                  'Draft',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
            height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildTotalBanner(
      ThemeData theme, ColorScheme colorScheme, String clientName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Due',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(_subtotalCents),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: colorScheme.onPrimary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      clientName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: colorScheme.onPrimary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(_issueDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: colorScheme.onPrimary, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme, ColorScheme colorScheme) {
    return _StyledCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invoice title field
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Invoice title',
              prefixIcon: Icon(Icons.title_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Issue date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _issueDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _issueDate = picked);
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Issue date',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                      Text(
                        _formatDate(_issueDate),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_outlined,
                      size: 16, color: colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sales person row
          if ((widget.jobData['salesPersonName'] as String?)?.isNotEmpty ==
              true)
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Sales person',
              value: widget.jobData['salesPersonName'] as String,
              colorScheme: colorScheme,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard(ThemeData theme, ColorScheme colorScheme,
      String clientName, String clientEmail) {
    return _StyledCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.work_outline_rounded,
            label: 'Job',
            value: (widget.jobData['title'] as String?) ?? '—',
            colorScheme: colorScheme,
            theme: theme,
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Client',
            value: clientName,
            colorScheme: colorScheme,
            theme: theme,
          ),
          if (clientEmail.isNotEmpty)
            _InfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: clientEmail,
              colorScheme: colorScheme,
              theme: theme,
            ),
          if ((widget.jobData['salesPersonName'] as String?)?.isNotEmpty ==
              true)
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Sales person',
              value: widget.jobData['salesPersonName'] as String,
              colorScheme: colorScheme,
              theme: theme,
            ),
          if ((widget.jobData['propertyAddress'] as String?)?.isNotEmpty ==
              true)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: widget.jobData['propertyAddress'] as String,
              colorScheme: colorScheme,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _buildServicesCard(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final initial = _items
            .map((i) => LineItem(
          name: i.name,
          priceCents: i.priceCents,
          description: i.description,
        ))
            .toList();
        final result = await Navigator.of(context).push<List<LineItem>>(
          MaterialPageRoute(
              builder: (_) => LineItemsScreen(initial: initial)),
        );
        if (result != null) {
          setState(() {
            _items = result
                .map((r) => _InvoiceItem(
              name: r.name,
              priceCents: r.priceCents,
              description: r.description,
            ))
                .toList();
          });
          await _autoSave();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.04),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.list_alt_outlined,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Services & Items',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Edit',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: _items.isEmpty
                  ? Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to add services or products',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant),
                  ),
                ],
              )
                  : Column(
                children: [
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                      fontWeight: FontWeight.w500),
                                ),
                                if (item.description.isNotEmpty)
                                  Text(
                                    item.description,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                        color: colorScheme
                                            .onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.priceCents == 0
                                ? 'Free'
                                : _formatAmount(item.priceCents),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(
                      color:
                      colorScheme.outlineVariant.withOpacity(0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        _formatAmount(_subtotalCents),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme, ColorScheme colorScheme,
      Map<String, dynamic> clientData) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withOpacity(0.6),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.preview_outlined,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Invoice Preview',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _previewing = false),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _buildTemplate(clientData),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.6,
                color: colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, ColorScheme colorScheme,
      Map<String, dynamic> clientData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview toggle
        OutlinedButton.icon(
          onPressed: () => setState(() => _previewing = !_previewing),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
                color: colorScheme.outline.withOpacity(0.4), width: 1.5),
            foregroundColor: colorScheme.onSurface,
          ),
          icon: Icon(_previewing
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          label: Text(
            _previewing ? 'Hide preview' : 'Preview invoice',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),

        // Send email
        OutlinedButton.icon(
          onPressed: () => _sendEmail(clientData),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
                color: colorScheme.primary.withOpacity(0.4), width: 1.5),
            foregroundColor: colorScheme.primary,
          ),
          icon: Icon(_emailSent
              ? Icons.refresh_rounded
              : Icons.send_outlined),
          label: Text(
            _emailSent ? 'Resend email' : 'Send via email',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        // Collect payment — shown after email sent
        if (_emailSent) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _collectPayment,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E8B5A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.payments_outlined, color: Colors.white),
              label: const Text(
                'Collect payment',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _StyledCard extends StatelessWidget {
  const _StyledCard({required this.child, required this.colorScheme});
  final Widget child;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceItem {
  _InvoiceItem({
    required this.name,
    required this.priceCents,
    this.description = '',
  });
  final String name;
  final int priceCents;
  final String description;
}