import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/firestore_paths.dart';
import '../jobs/create_job_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quote Details Screen
// ─────────────────────────────────────────────────────────────────────────────

class QuoteDetailsScreen extends StatelessWidget {
  const QuoteDetailsScreen({
    super.key,
    required this.teamId,
    required this.quoteId,
  });

  final String teamId;
  final String quoteId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .doc(FirestorePaths.teamQuote(teamId, quoteId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final quote  = snapshot.data!.data() ?? {};
        final title  = (quote['title'] as String?) ?? 'Quote';
        final status = (quote['status'] as String?) ?? 'draft';
        final colorScheme = Theme.of(context).colorScheme;

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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.description_outlined,
                      size: 16, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 17, color: colorScheme.error),
                  ),
                  tooltip: 'Delete quote',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Delete quote'),
                        content: const Text(
                            'This will permanently delete the quote.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error),
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await ref.delete();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: _QuoteBody(
              teamId: teamId,
              quoteId: quoteId,
              quote: quote,
              status: status,
              docRef: ref,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteBody extends StatelessWidget {
  const _QuoteBody({
    required this.teamId,
    required this.quoteId,
    required this.quote,
    required this.status,
    required this.docRef,
  });

  final String teamId;
  final String quoteId;
  final Map<String, dynamic> quote;
  final String status;
  final DocumentReference<Map<String, dynamic>> docRef;

  bool get isApproved => status == 'approved';

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  int get _subtotalCents {
    final itemsRaw = quote['items'];
    final items = itemsRaw is List ? itemsRaw.cast<Map>() : const <Map>[];
    return items.fold<int>(
        0, (acc, i) => acc + ((i['priceCents'] as int?) ?? 0));
  }

  int get _discountCents => (quote['discountCents'] as int?) ?? 0;
  int get _taxCents      => (quote['taxCents'] as int?) ?? 0;
  int get _depositCents  => (quote['depositCents'] as int?) ?? 0;
  int get _totalCents    => _subtotalCents - _discountCents + _taxCents;

  String _fmt(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Future<void> _sendEmail(BuildContext context) async {
    final email = (quote['clientEmail'] as String?)?.trim() ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client has no email saved.')));
      return;
    }
    final title   = (quote['title'] as String?) ?? 'Quote';
    final subject = Uri.encodeComponent('Quote: $title');
    final body    = Uri.encodeComponent(
        'Total: ${_fmt(_totalCents)}\nPlease review your quote.');
    final uri    = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')));
      return;
    }
    final ts = FieldValue.serverTimestamp();
    await docRef.update({'status': 'sent', 'sentAt': ts, 'updatedAt': ts});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme  = Theme.of(context).colorScheme;
    final clientName   = (quote['clientName'] as String?) ?? '-';
    final clientEmail  = (quote['clientEmail'] as String?) ?? '';
    final clientPhone  = (quote['clientPhone'] as String?) ?? '';
    final createdAt    = quote['createdAt'];
    final itemsRaw     = quote['items'];
    final items = itemsRaw is List ? itemsRaw.cast<Map>() : const <Map>[];
    final attachments  = (quote['attachments'] as List?)
        ?.map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList() ?? [];
    final images       = (quote['images'] as List?)
        ?.map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList() ?? [];
    final review        = (quote['review'] as String?) ?? '';
    final clientMessage = (quote['clientMessage'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Status badge row ─────────────────────────────────────────
        Row(
          children: [
            _StatusBadge(status: status),
            if (isApproved) ...[
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.check_circle_outline_rounded,
                label: 'Approved ${_fmtDate(quote['approvedAt'])}',
                color: const Color(0xFF2E7D32),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── Client card ───────────────────────────────────────────────
        _SectionCard(
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFF5B7FFF),
          title: 'Client',
          child: Column(
            children: [
              _InfoRow(icon: Icons.person_rounded, label: 'Name', value: clientName),
              if (clientEmail.isNotEmpty)
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: clientEmail),
              if (clientPhone.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: clientPhone),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Created',
                value: _fmtDate(createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Services / items ──────────────────────────────────────────
        _SectionCard(
          icon: Icons.list_alt_outlined,
          iconColor: const Color(0xFF00BFA5),
          title: 'Services / Items',
          child: items.isEmpty
              ? Text('No items added.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant))
              : Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _ItemRow(item: items[i], fmtFn: _fmt),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withOpacity(0.4),
                  ),
              ],
              Divider(
                  height: 20,
                  color: colorScheme.outlineVariant.withOpacity(0.4)),
              _TotalLine(
                  label: 'Subtotal',
                  value: _fmt(_subtotalCents),
                  bold: false),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Pricing ───────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.calculate_outlined,
          iconColor: const Color(0xFF7C4DFF),
          title: 'Pricing',
          child: Column(
            children: [
              _TotalLine(
                  label: 'Subtotal', value: _fmt(_subtotalCents)),
              const SizedBox(height: 10),
              _EditableAmountRow(
                label: 'Discount',
                icon: Icons.local_offer_outlined,
                currentCents: _discountCents,
                accentColor: const Color(0xFF00897B),
                onSave: (c) => docRef.update({
                  'discountCents': c,
                  'updatedAt': FieldValue.serverTimestamp()
                }),
              ),
              const SizedBox(height: 10),
              _EditableAmountRow(
                label: 'Tax',
                icon: Icons.percent_rounded,
                currentCents: _taxCents,
                accentColor: const Color(0xFFE65100),
                onSave: (c) => docRef.update({
                  'taxCents': c,
                  'updatedAt': FieldValue.serverTimestamp()
                }),
              ),
              Divider(
                  height: 20,
                  color: colorScheme.outlineVariant.withOpacity(0.4)),
              _TotalLine(
                  label: 'Total', value: _fmt(_totalCents), bold: true),
              const SizedBox(height: 10),
              _EditableAmountRow(
                label: 'Required deposit',
                icon: Icons.account_balance_wallet_outlined,
                currentCents: _depositCents,
                accentColor: const Color(0xFF5B7FFF),
                onSave: (c) => docRef.update({
                  'depositCents': c,
                  'updatedAt': FieldValue.serverTimestamp()
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Client message ────────────────────────────────────────────
        _EditableTextCard(
          icon: Icons.message_outlined,
          iconColor: const Color(0xFFFF6D3B),
          title: 'Client message',
          value: clientMessage,
          hint: 'Add a message for the client…',
          onSave: (v) => docRef.update(
              {'clientMessage': v, 'updatedAt': FieldValue.serverTimestamp()}),
        ),
        const SizedBox(height: 12),

        // ── Review / notes ─────────────────────────────────────────────
        _EditableTextCard(
          icon: Icons.rate_review_outlined,
          iconColor: const Color(0xFF607D8B),
          title: 'Review / Notes',
          value: review,
          hint: 'Add internal review notes…',
          onSave: (v) => docRef.update(
              {'review': v, 'updatedAt': FieldValue.serverTimestamp()}),
        ),
        const SizedBox(height: 12),

        // ── Photos ────────────────────────────────────────────────────
        _PhotosCard(
          photos: [
            ...attachments,
            ...images,
            ...((quote['photos'] as List?)
                    ?.map((e) => e.toString())
                    .where((e) => e.isNotEmpty)
                    .toList() ??
                []),
          ],
          onSave: (list) => docRef.update(
              {'photos': list, 'updatedAt': FieldValue.serverTimestamp()}),
        ),
        const SizedBox(height: 20),

        // ── Actions ───────────────────────────────────────────────────
        if (!isApproved) ...[
          _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Approve & schedule',
            color: const Color(0xFF2E7D32),
            filled: true,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  _ApproveDialog(teamId: teamId, quoteId: quoteId),
            ),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.send_rounded,
            label: 'Send to client via email',
            color: colorScheme.primary,
            filled: false,
            onPressed: () => _sendEmail(context),
          ),
        ] else ...[
          _ActionButton(
            icon: Icons.work_outline_rounded,
            label: 'Create job from quote',
            color: const Color(0xFF5B7FFF),
            filled: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateJobScreen(
                  teamId: teamId,
                  preselectedClientId: quote['clientId'] as String?,
                  prefilledTitle: quote['title'] as String?,
                  prefilledDescription: quote['description'] as String?,
                  prefilledPriceCents: _totalCents,
                  sourceQuoteId: quoteId,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item Row
// ─────────────────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.fmtFn});
  final Map item;
  final String Function(int) fmtFn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name  = (item['name'] ?? '').toString();
    final desc  = (item['description'] ?? '').toString();
    final cents = (item['priceCents'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF00BFA5),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            cents == 0 ? 'Free' : fmtFn(cents),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: 0.1)),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Total Line
// ─────────────────────────────────────────────────────────────────────────────

class _TotalLine extends StatelessWidget {
  const _TotalLine(
      {required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = bold
        ? theme.textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant);
    final valueStyle = bold
        ? theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF00897B),
        letterSpacing: -0.3)
        : theme.textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        if (bold)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: valueStyle),
          )
        else
          Text(value, style: valueStyle),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable Amount Row
// ─────────────────────────────────────────────────────────────────────────────

class _EditableAmountRow extends StatefulWidget {
  const _EditableAmountRow({
    required this.label,
    required this.icon,
    required this.currentCents,
    required this.onSave,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final int currentCents;
  final Color accentColor;
  final Future<void> Function(int cents) onSave;

  @override
  State<_EditableAmountRow> createState() => _EditableAmountRowState();
}

class _EditableAmountRowState extends State<_EditableAmountRow> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentCents == 0
          ? ''
          : (widget.currentCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val   = double.tryParse(_ctrl.text.trim()) ?? 0;
    final cents = (val * 100).round();
    await widget.onSave(cents);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_editing) {
      return Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
            Icon(widget.icon, size: 14, color: widget.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(

              controller: _ctrl,
              autofocus: true,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.label,
                prefixText: '\$ ',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest
                    .withOpacity(0.4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color:
                      colorScheme.outlineVariant.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: widget.accentColor, width: 1.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                  foregroundColor: widget.accentColor,
                  visualDensity: VisualDensity.compact),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () => setState(() => _editing = false),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              child: const Text('Cancel')),
        ],
      );
    }

    return InkWell(
      onTap: () => setState(() => _editing = true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
              Icon(widget.icon, size: 14, color: widget.accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Text(
              widget.currentCents == 0
                  ? 'Tap to add'
                  : '\$${(widget.currentCents / 100).toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: widget.currentCents == 0
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined,
                size: 13, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editable Text Card
// ─────────────────────────────────────────────────────────────────────────────

class _EditableTextCard extends StatefulWidget {
  const _EditableTextCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.hint,
    required this.onSave,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String hint;
  final Future<void> Function(String) onSave;

  @override
  State<_EditableTextCard> createState() => _EditableTextCardState();
}

class _EditableTextCardState extends State<_EditableTextCard> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave(_ctrl.text.trim());
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
        border:
        Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
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
                    color: widget.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                  Icon(widget.icon, size: 16, color: widget.iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1)),
                ),
                if (!_editing)
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 13),
                    label: Text(widget.value.isEmpty ? 'Add' : 'Edit'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: widget.iconColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.4)),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: _editing
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withOpacity(0.4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: colorScheme.outlineVariant
                              .withOpacity(0.7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: widget.iconColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _editing = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.iconColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            )
                : widget.value.isNotEmpty
                ? Text(widget.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5))
                : Text(widget.hint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URL List Card
// ── Photos card ───────────────────────────────────────────────────────────────

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.photos, required this.onSave});
  final List<String> photos;
  final Future<void> Function(List<String>) onSave;

  bool _isBase64(String s) {
    if (s.length < 100) return false;
    try { base64Decode(s); return true; } catch (_) { return false; }
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final file = await ImagePicker().pickImage(
        source: source, imageQuality: 70, maxWidth: 1024);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await onSave([...photos, base64Encode(bytes)]);
  }

  Future<void> _remove(int i) async {
    final updated = [...photos]..removeAt(i);
    await onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Photos', style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Gallery'),
                ),
              ),
            ]),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _isBase64(photos[i])
                              ? Image.memory(
                                  base64Decode(photos[i]),
                                  width: 90, height: 90, fit: BoxFit.cover)
                              : Image.network(
                                  photos[i],
                                  width: 90, height: 90, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 90, height: 90,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image_outlined,
                                        color: Colors.grey),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => _remove(i),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UrlListCard extends StatefulWidget {
  const _UrlListCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.hint,
    required this.onSave,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final String hint;
  final Future<void> Function(List<String>) onSave;

  @override
  State<_UrlListCard> createState() => _UrlListCardState();
}

class _UrlListCardState extends State<_UrlListCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    await widget.onSave([...widget.items, url]);
    _ctrl.clear();
  }

  Future<void> _remove(int index) async {
    final updated = [...widget.items]..removeAt(index);
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),

        borderRadius: BorderRadius.circular(18),
        border:
        Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.iconColor),
                ),
                const SizedBox(width: 10),
                Text(widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: 0.1)),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.items.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: colorScheme.outlineVariant
                              .withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(widget.icon,
                            size: 14, color: widget.iconColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.items[i],
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: () => _remove(i),
                          child: Icon(Icons.close_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withOpacity(0.4),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: widget.iconColor, width: 1.5),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _add,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.iconColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, letterSpacing: 0.1)),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: child)
          : OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'approved' => ('APPROVED', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'sent'     => ('SENT', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'draft'    => ('DRAFT',
      Theme.of(context).colorScheme.surfaceContainerHighest,
      Theme.of(context).colorScheme.onSurfaceVariant),
      _          => (status.toUpperCase(),
      Theme.of(context).colorScheme.surfaceContainerHighest,
      Theme.of(context).colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Pill (inline metadata chip)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  const _InfoPill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approve Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.teamId, required this.quoteId});
  final String teamId;
  final String quoteId;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _sigCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_sigCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a signature to approve.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final ts = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamQuote(widget.teamId, widget.quoteId))
          .update({
        'status': 'approved',
        'approvedAt': ts,
        'approvedSignature': _sigCtrl.text.trim(),
        'updatedAt': ts,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quote approved.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AlertDialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.verified_outlined,
                size: 17, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 10),
          const Text('Approve quote'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Type your full name as a signature to approve this quote.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sigCtrl,
            decoration: InputDecoration(
              labelText: 'Signature (full name)',
              prefixIcon:
              const Icon(Icons.draw_outlined, size: 18),
              filled: true,
              fillColor:
              colorScheme.surfaceContainerHighest.withOpacity(0.4),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF2E7D32), width: 1.5),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _approve,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_saving ? 'Approving…' : 'Approve',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}