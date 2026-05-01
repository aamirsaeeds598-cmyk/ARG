import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/firestore_paths.dart';
import '../quotes/quote_details_screen.dart';

/// Same form as CreateQuoteScreen but the client is pre-filled from the
/// request — no client dropdown needed.
class ConvertToQuoteScreen extends StatefulWidget {
  const ConvertToQuoteScreen({
    super.key,
    required this.teamId,
    required this.requestId,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.serviceDescription,
    required this.notes,
    this.lineItems = const [],
  });

  final String teamId;
  final String requestId;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String serviceDescription;
  final String notes;
  final List<Map<String, dynamic>> lineItems;

  @override
  State<ConvertToQuoteScreen> createState() => _ConvertToQuoteScreenState();
}

class _ConvertToQuoteScreenState extends State<ConvertToQuoteScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final List<_ItemInput> _items = [_ItemInput()];

  bool _isSaving = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    _titleController = TextEditingController(text: widget.serviceDescription);
    _descriptionController = TextEditingController(text: widget.notes);

    if (widget.lineItems.isNotEmpty) {
      _items.clear();
      for (final item in widget.lineItems) {
        final i = _ItemInput();
        i.nameController.text = (item['name'] ?? '').toString();
        i.descriptionController.text = (item['description'] ?? '').toString();
        final cents = (item['priceCents'] as int?) ?? 0;
        i.priceController.text =
        cents > 0 ? (cents / 100).toStringAsFixed(2) : '';
        _items.add(i);
      }
    } else {
      _items[0].nameController.text = widget.serviceDescription;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int _parseCents(String value) {
    final parsed = double.tryParse(value.trim()) ?? 0;
    return (parsed * 100).round();
  }

  int get _totalCents {
    return _items.fold(0, (acc, item) {
      return acc + _parseCents(item.priceController.text);
    });
  }

  String _formatAmount(int cents) {
    final amount = cents / 100;
    return '\$${amount.toStringAsFixed(2)}';
  }

  Future<void> _createQuote() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final preparedItems = _items
          .map(
            (i) => {
          'name': i.nameController.text.trim(),
          'description': i.descriptionController.text.trim(),
          'priceCents': _parseCents(i.priceController.text),
        },
      )
          .where((e) => (e['name'] as String).isNotEmpty)
          .toList();

      if (preparedItems.isEmpty) {
        throw Exception('Add at least one service/item.');
      }

      final totalCents = preparedItems.fold<int>(
        0,
            (acc, item) => acc + (item['priceCents'] as int),
      );

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final quoteRef = FirebaseFirestore.instance
          .collection(FirestorePaths.teamQuotes(widget.teamId))
          .doc();

      await quoteRef.set({
        'title': _titleController.text.trim().isEmpty
            ? 'Quote ${DateTime.now().millisecondsSinceEpoch}'
            : _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'clientId': widget.clientId,
        'clientName': widget.clientName,
        'clientEmail': widget.clientEmail,
        'clientPhone': widget.clientPhone,
        'items': preparedItems,
        'totalCents': totalCents,
        'status': 'draft',
        'sourceRequestId': widget.requestId,
        'createdByUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .doc(FirestorePaths.teamRequest(widget.teamId, widget.requestId))
          .update({'status': 'converted', 'convertedQuoteId': quoteRef.id});

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              QuoteDetailsScreen(teamId: widget.teamId, quoteId: quoteRef.id),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: _buildAppBar(theme, colorScheme),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              _buildSectionLabel(theme, 'CLIENT'),
              const SizedBox(height: 8),
              _buildClientCard(theme, colorScheme),
              const SizedBox(height: 24),

              _buildSectionLabel(theme, 'QUOTE DETAILS'),
              const SizedBox(height: 8),
              _buildDetailsCard(theme, colorScheme),
              const SizedBox(height: 24),

              _buildSectionLabel(theme, 'SERVICES & ITEMS'),
              const SizedBox(height: 8),
              ..._buildItemCards(theme, colorScheme),
              const SizedBox(height: 10),
              _buildAddItemButton(colorScheme),
              const SizedBox(height: 20),

              _buildTotalCard(theme, colorScheme),
              const SizedBox(height: 16),

              if (_error != null) _buildErrorBanner(theme, colorScheme),

              _buildSubmitButton(theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
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
            'Convert to Quote',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Review and confirm details',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
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

  Widget _buildClientCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                widget.clientName.isNotEmpty
                    ? widget.clientName[0].toUpperCase()
                    : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.clientEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        widget.clientEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.clientPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        widget.clientPhone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pre-filled',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStyledTextField(
            controller: _titleController,
            label: 'Quote title',
            icon: Icons.title_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 14),
          _buildStyledTextField(
            controller: _descriptionController,
            label: 'Description',
            icon: Icons.notes_rounded,
            colorScheme: colorScheme,
            theme: theme,
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemCards(ThemeData theme, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      widgets.add(
        _QuoteItemCard(
          index: i + 1,
          item: _items[i],
          canRemove: _items.length > 1,
          colorScheme: colorScheme,
          theme: theme,
          onRemove: () {
            setState(() {
              _items[i].dispose();
              _items.removeAt(i);
            });
          },
          onChanged: () => setState(() {}),
        ),
      );
      if (i < _items.length - 1) widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _buildAddItemButton(ColorScheme colorScheme) {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _items.add(_ItemInput())),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
        foregroundColor: colorScheme.primary,
      ),
      icon: const Icon(Icons.add_circle_outline_rounded),
      label: const Text('Add another item',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTotalCard(ThemeData theme, ColorScheme colorScheme) {
    final total = _totalCents;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.75),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_items.where((i) => i.nameController.text.trim().isNotEmpty).length} item(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.6),
                ),
              ),
            ],
          ),
          Text(
            _formatAmount(total),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme, ColorScheme colorScheme) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: _isSaving ? null : _createQuote,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: colorScheme.primary,
          disabledBackgroundColor: colorScheme.primary.withOpacity(0.5),
        ),
        child: _isSaving
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: colorScheme.onPrimary,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_outlined,
                color: colorScheme.onPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Review Quote',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    required ThemeData theme,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
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
    );
  }
}

// ── Item Input Model ──────────────────────────────────────────────────────────

class _ItemInput {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}

// ── Quote Item Card ───────────────────────────────────────────────────────────

class _QuoteItemCard extends StatelessWidget {
  const _QuoteItemCard({
    required this.index,
    required this.item,
    required this.canRemove,
    required this.colorScheme,
    required this.theme,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _ItemInput item;
  final bool canRemove;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:   Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
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
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withOpacity(0.6),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Item $index',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Fields
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildField(
                  controller: item.nameController,
                  label: 'Service / item name',
                  icon: Icons.label_outline_rounded,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 10),
                _buildField(
                  controller: item.descriptionController,
                  label: 'Description (optional)',
                  icon: Icons.short_text_rounded,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 10),
                _buildField(
                  controller: item.priceController,
                  label: 'Price',
                  icon: Icons.attach_money_rounded,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        labelStyle:
        TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}