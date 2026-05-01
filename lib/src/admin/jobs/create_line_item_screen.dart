import 'package:flutter/material.dart';

import 'line_items_screen.dart';

// Color Palette - Professional
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const success = Color(0xFF059669);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  static const surface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

class CreateLineItemScreen extends StatefulWidget {
  const CreateLineItemScreen({super.key});

  @override
  State<CreateLineItemScreen> createState() => _CreateLineItemScreenState();
}

class _CreateLineItemScreenState extends State<CreateLineItemScreen>
    with SingleTickerProviderStateMixin {
  String _type = 'Service'; // 'Service' or 'Product'

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;

  late AnimationController _fadeController;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _unitCtrl = TextEditingController(text: '0.00');
    _qtyCtrl = TextEditingController(text: '1');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController.forward();

    _nameCtrl.addListener(() => setState(() => _error = null));
    _unitCtrl.addListener(() => setState(() => _error = null));
    _qtyCtrl.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  double get _unitPrice => double.tryParse(_unitCtrl.text.trim()) ?? 0;
  double get _quantity => double.tryParse(_qtyCtrl.text.trim()) ?? 1;
  double get _total => _unitPrice * _quantity;

  bool get _isFormValid {
    final name = _nameCtrl.text.trim();
    return name.isNotEmpty && _unitPrice >= 0 && _quantity > 0;
  }

  String _validateForm() {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      return 'Item name is required';
    }

    if (_unitPrice < 0) {
      return 'Unit price cannot be negative';
    }

    if (_quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    if (name.length > 100) {
      return 'Item name must be less than 100 characters';
    }

    return '';
  }

  Future<void> _save() async {
    final error = _validateForm();

    if (error.isNotEmpty) {
      setState(() => _error = error);
      return;
    }

    setState(() => _isSaving = true);

    // Simulate a brief delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    final item = LineItem(
      name: _nameCtrl.text.trim(),
      priceCents: (_total * 100).round(),
      description: _descCtrl.text.trim(),
      type: _type,
      quantity: _quantity,
      unitPriceCents: (_unitPrice * 100).round(),
    );

    if (mounted) {
      Navigator.of(context).pop(item);
    }
  }

  void _clearForm() {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear form'),
        content: const Text('Are you sure you want to clear all fields?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _nameCtrl.clear();
          _descCtrl.clear();
          _unitCtrl.text = '0.00';
          _qtyCtrl.text = '1';
          _type = 'Service';
          _error = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text(
          'Create line item',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type Selection
              _buildTypeSelector(),
              const SizedBox(height: 20),

              // Form Fields
              _buildNameField(),
              const SizedBox(height: 12),

              _buildDescriptionField(),
              const SizedBox(height: 12),

              _buildPricingSection(),
              const SizedBox(height: 16),

              // Total Summary
              _buildTotalSummary(),
              const SizedBox(height: 16),

              // Error Message
              if (_error != null) ...[
                _buildErrorMessage(),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Type',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'Service',
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.miscellaneous_services_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Service'),
                ],
              ),
            ),
            ButtonSegment(
              value: 'Product',
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Product'),
                ],
              ),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (s) {
            setState(() => _type = s.first);
          },
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return AppColors.accent;
              }
              return AppColors.surface;
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              return AppColors.secondary;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    final charCount = _nameCtrl.text.length;
    final maxChars = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Name',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          maxLength: maxChars,
          decoration: InputDecoration(

            labelText: 'e.g., Window Cleaning Service',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            counterText: '$charCount / $maxChars',
            counterStyle: TextStyle(
              color: charCount > maxChars * 0.8
                  ? AppColors.warning
                  : AppColors.secondary,
              fontSize: 12,
            ),
            prefixIcon: Icon(
              _type == 'Service'
                  ? Icons.miscellaneous_services_outlined
                  : Icons.inventory_2_outlined,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Add details about this item...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            helperText: 'Keep descriptions concise and clear',
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pricing',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPriceField(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuantityField(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _unitCtrl,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: InputDecoration(
        labelText: 'Unit price',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '\$',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: '0.00',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildQuantityField() {
    return TextField(
      controller: _qtyCtrl,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: InputDecoration(
        labelText: 'Quantity',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        prefixIcon: const Icon(Icons.numbers, size: 20, color: AppColors.accent),
        hintText: '1',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTotalSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Total price',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '\$${_total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_quantity > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_quantity.toStringAsFixed(2)} × \$${_unitPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border, width: 1),
            ),
            onPressed: _isSaving ? null : _clearForm,
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isSaving || !_isFormValid ? null : _save,
            child: _isSaving
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text('Save item'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}