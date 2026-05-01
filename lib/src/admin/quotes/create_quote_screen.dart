import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/firestore_paths.dart';
import '../jobs/line_items_screen.dart';
import 'quote_details_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class _C {
  static const ink        = Color(0xFF0F1117);
  static const surface    = Color(0xFFF7F8FA);
  static const card       = Color(0xFFFFFFFF);
  static const accent     = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEFF4FF);
  static const muted      = Color(0xFF6B7280);
  static const border     = Color(0xFFE5E7EB);
  static const error      = Color(0xFFDC2626);
  static const errorSoft  = Color(0xFFFEF2F2);
}

// ─────────────────────────────────────────────────────────────────────────────

class CreateQuoteScreen extends StatefulWidget {
  const CreateQuoteScreen({
    super.key,
    required this.teamId,
    this.preselectedClientId,
  });

  final String teamId;
  final String? preselectedClientId;

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl       = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final List<_ItemInput> _items = [_ItemInput()];

  // ── New client fields ──────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _clientEmailCtrl = TextEditingController();

  String? _selectedClientId;
  bool    _isSaving = false;
  String? _error;
  List<String> _photos = [];

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  int _parseCents(String value) {
    final parsed = double.tryParse(value.trim()) ?? 0;
    return (parsed * 100).round();
  }

  int get _totalCents => _items.fold<int>(
    0,
        (sum, i) => sum + _parseCents(i.priceController.text),
  );

  Future<void> _createQuote() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      if (_selectedClientId == null) {
        // Create new client from fields
        final firstName = _firstNameCtrl.text.trim();
        final lastName  = _lastNameCtrl.text.trim();
        final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
        if (fullName.isEmpty) throw Exception('Enter client first name or select an existing client.');
        final clientRef = FirebaseFirestore.instance
            .collection(FirestorePaths.teamClients(widget.teamId))
            .doc();
        await clientRef.set({
          'name':      fullName,
          'firstName': firstName,
          'lastName':  lastName,
          'phone':     _phoneCtrl.text.trim(),
          'email':     _clientEmailCtrl.text.trim().toLowerCase(),
          'address':   _addressCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        _selectedClientId = clientRef.id;
      }

      final clientSnap = await FirebaseFirestore.instance
          .doc(FirestorePaths.teamClient(widget.teamId, _selectedClientId!))
          .get();
      final clientData = clientSnap.data();
      if (clientData == null) throw Exception('Selected client not found.');

      final preparedItems = _items
          .map((i) => {
        'name':        i.nameController.text.trim(),
        'description': i.descriptionController.text.trim(),
        'priceCents':  _parseCents(i.priceController.text),
      })
          .where((e) => (e['name'] as String).isNotEmpty)
          .toList();

      if (preparedItems.isEmpty) throw Exception('Add at least one service/item.');

      final totalCents = preparedItems.fold<int>(
          0, (sum, item) => sum + (item['priceCents'] as int));

      final uid      = FirebaseAuth.instance.currentUser!.uid;
      final quoteRef = FirebaseFirestore.instance
          .collection(FirestorePaths.teamQuotes(widget.teamId))
          .doc();

      await quoteRef.set({
        'title': _titleCtrl.text.trim().isEmpty
            ? 'Quote ${DateTime.now().millisecondsSinceEpoch}'
            : _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'clientId':    _selectedClientId,
        'clientName':  clientData['name'],
        'clientEmail': clientData['email'],
        'clientPhone': clientData['phone'],
        'items':       preparedItems,
        'totalCents':  totalCents,
        'status':      'draft',
        'photos':      _photos,
        'createdByUid': uid,
        'createdAt':   FieldValue.serverTimestamp(),
        'updatedAt':   FieldValue.serverTimestamp(),
      });

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── 01 Client ────────────────────────────────────────────────
              _buildSection(
                step:  '01',
                title: 'Client',
                icon:  Icons.person_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestorePaths.teamClients(widget.teamId))
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? const [];
                      final ids = docs.map((d) => d.id).toSet();
                      final safeValue = ids.contains(_selectedClientId)
                          ? _selectedClientId
                          : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _styledDropdown<String>(
                            value: safeValue,
                            labelText: 'Select existing client',
                            items: [
                              const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('— New client —')),
                              for (final d in docs)
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                      (d.data()['name'] as String?) ?? 'Client'),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedClientId = v),
                          ),
                          // New client fields when none selected
                          if (_selectedClientId == null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _C.accentSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _C.accent.withValues(alpha: 0.2)),
                              ),
                              child: const Text('New client details',
                                  style: TextStyle(
                                      color: _C.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: _styledTextField(
                                  controller: _firstNameCtrl,
                                  label: 'First name',
                                  prefixIcon: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _styledTextField(
                                  controller: _lastNameCtrl,
                                  label: 'Last name',
                                  prefixIcon: Icons.person_outline,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            _styledTextField(
                              controller: _addressCtrl,
                              label: 'Property address',
                              prefixIcon: Icons.home_outlined,
                              minLines: 2,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 10),
                            _styledTextField(
                              controller: _phoneCtrl,
                              label: 'Phone number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 10),
                            _styledTextField(
                              controller: _clientEmailCtrl,
                              label: 'Email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ── 02 Quote Info ────────────────────────────────────────────
              _buildSection(
                step:  '02',
                title: 'Quote Info',
                icon:  Icons.description_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _styledTextField(
                        controller:  _titleCtrl,
                        label:       'Quote title',
                        prefixIcon:  Icons.title_rounded,
                      ),
                      const SizedBox(height: 12),
                      _styledTextField(
                        controller: _descriptionCtrl,
                        label:      'Quote description',
                        minLines:   3,
                        maxLines:   5,
                      ),
                    ],
                  ),
                ),
              ),

              // ── 03 Products & Services ──────────────────────────────────
              _buildSection(
                step:  '03',
                title: 'Products & Services',
                icon:  Icons.list_alt_rounded,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  onTap: () async {
                    final current = _items.map((i) => LineItem(
                      name: i.nameController.text.trim(),
                      priceCents: (double.tryParse(i.priceController.text.trim()) ?? 0 * 100).round(),
                      description: i.descriptionController.text.trim(),
                    )).where((i) => i.name.isNotEmpty).toList();

                    final result = await Navigator.of(context)
                        .push<List<LineItem>>(MaterialPageRoute(
                      builder: (_) => LineItemsScreen(initial: current),
                    ));

                    if (result != null) {
                      setState(() {
                        _items.clear();
                        for (final r in result) {
                          final item = _ItemInput();
                          item.nameController.text = r.name;
                          item.descriptionController.text = r.description;
                          item.priceController.text =
                              (r.priceCents / 100).toStringAsFixed(2);
                          _items.add(item);
                        }
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_items.isEmpty ||
                            _items.every((i) =>
                                i.nameController.text.trim().isEmpty))
                          Row(children: [
                            const Icon(Icons.add_circle_outline,
                                size: 16, color: _C.accent),
                            const SizedBox(width: 8),
                            const Text('Tap to select products / services',
                                style: TextStyle(
                                    color: _C.accent, fontSize: 13)),
                            const Spacer(),
                            const Icon(Icons.chevron_right,
                                size: 16, color: _C.muted),
                          ])
                        else ...[
                          for (final item in _items)
                            if (item.nameController.text.trim().isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                        color: _C.accent,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(
                                          item.nameController.text.trim(),
                                          style: const TextStyle(
                                              color: _C.ink, fontSize: 13))),
                                  Text(
                                    double.tryParse(item.priceController.text
                                                .trim()) ==
                                            null
                                        ? 'Free'
                                        : '\$${item.priceController.text.trim()}',
                                    style: const TextStyle(
                                        color: _C.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right,
                                      size: 14, color: _C.muted),
                                ]),
                              ),
                          Container(
                              height: 1,
                              color: _C.border,
                              margin:
                                  const EdgeInsets.symmetric(vertical: 8)),
                          Row(children: [
                            const Text('Subtotal',
                                style: TextStyle(
                                    color: _C.muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _C.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '\$${(_totalCents / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: _C.accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              // ── 04 Photos ────────────────────────────────────────────────
              _buildSection(
                step:  '04',
                title: 'Photos',
                icon:  Icons.photo_library_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _QuotePhotoPicker(
                    photos: _photos,
                    onPhotosChanged: (p) => setState(() => _photos = p),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              if (_error != null) _buildErrorBanner(),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor:      _C.card,
      surfaceTintColor:     Colors.transparent,
      elevation:            0,
      scrolledUnderElevation: 1,
      shadowColor:          _C.border,
      leading: IconButton(
        icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _C.ink,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Quote',
            style: TextStyle(
              color:       _C.ink,
              fontSize:    17,
              fontWeight:  FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Fill in the details below',
            style: TextStyle(
              color:    _C.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: _isSaving ? null : _createQuote,
            style: TextButton.styleFrom(
              backgroundColor: _C.accentSoft,
              foregroundColor: _C.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _isSaving ? 'Saving…' : 'Review',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────

  Widget _buildSection({
    required String   step,
    required String   title,
    required IconData icon,
    required Widget   child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Container(
                  width:  26,
                  height: 26,
                  decoration: const BoxDecoration(
                      color: _C.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(step,
                        style: const TextStyle(
                          color:       Colors.white,
                          fontSize:    9,
                          fontWeight:  FontWeight.w800,
                          letterSpacing: 0.2,
                        )),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: _C.accent),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                      color:       _C.ink,
                      fontSize:    13,
                      fontWeight:  FontWeight.w700,
                      letterSpacing: -0.1,
                    )),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color:        _C.card,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Total row ─────────────────────────────────────────────────────────────

  Widget _buildTotalRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        _C.surface,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          const Text('Total',
              style: TextStyle(
                  color: _C.muted, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:        _C.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '\$${(_totalCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                color:       _C.accent,
                fontSize:    15,
                fontWeight:  FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        _C.errorSoft,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _C.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: _C.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                    color: _C.error, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
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
          color: _isSaving ? _C.border : null,
          boxShadow: _isSaving
              ? null
              : [
            BoxShadow(
              color:      _C.accent.withOpacity(0.35),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _createQuote,
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
              : const Icon(Icons.visibility_rounded,
              color: Colors.white, size: 20),
          label: Text(
            _isSaving ? 'Creating…' : 'Review Quote',
            style: const TextStyle(
              color:       Colors.white,
              fontSize:    15,
              fontWeight:  FontWeight.w700,
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
          color: _C.ink, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: _C.muted)
            : null,
        filled:     true,
        fillColor:  _C.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.accent, width: 1.5),
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
      value:        value,
      items:        items,
      onChanged:    onChanged,
      dropdownColor: _C.card,
      style: const TextStyle(
          color: _C.ink, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  labelText,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 13),
        filled:     true,
        fillColor:  _C.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Item Input Model ──────────────────────────────────────────────────────────

class _ItemInput {
  final nameController        = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController       = TextEditingController();

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
    required this.onRemove,
    required this.onChanged,
  });

  final int           index;
  final _ItemInput    item;
  final bool          canRemove;
  final VoidCallback  onRemove;
  final VoidCallback  onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color:        _C.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Item header ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _C.accentSoft,
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width:  22,
                  height: 22,
                  decoration: const BoxDecoration(
                      color: _C.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Item',
                  style: TextStyle(
                    color:      _C.accent,
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color:        _C.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: _C.error),
                    ),
                  ),
              ],
            ),
          ),

          // ── Fields ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _itemField(
                  controller: item.nameController,
                  label:      'Service / item name',
                  prefixIcon: Icons.label_outline_rounded,
                  onChanged:  onChanged,
                ),
                const SizedBox(height: 10),
                _itemField(
                  controller: item.descriptionController,
                  label:      'Description (optional)',
                  prefixIcon: Icons.notes_rounded,
                  onChanged:  onChanged,
                ),
                const SizedBox(height: 10),
                _itemField(
                  controller:   item.priceController,
                  label:        'Price (\$)',
                  prefixIcon:   Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged:    onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemField({
    required TextEditingController controller,
    required String                label,
    required IconData              prefixIcon,
    TextInputType?                 keyboardType,
    required VoidCallback          onChanged,
  }) {
    return TextField(
      controller:    controller,
      keyboardType:  keyboardType,
      onChanged:     (_) => onChanged(),
      style: const TextStyle(
          color: _C.ink, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 12),
        prefixIcon: Icon(prefixIcon, size: 16, color: _C.muted),
        filled:     true,
        fillColor:  _C.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:   const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:   const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:   const BorderSide(color: _C.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Quote Photo Picker ────────────────────────────────────────────────────────

class _QuotePhotoPicker extends StatelessWidget {
  const _QuotePhotoPicker({
    required this.photos,
    required this.onPhotosChanged,
  });

  final List<String> photos;
  final void Function(List<String>) onPhotosChanged;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    onPhotosChanged([...photos, base64Encode(bytes)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Share images related to this quote',
          style: TextStyle(
              color: _C.muted, fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.accent,
                side: const BorderSide(color: _C.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.accent,
                side: const BorderSide(color: _C.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
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
                      child: Image.memory(
                        base64Decode(photos[i]),
                        width: 80,
                        height: 80,
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
