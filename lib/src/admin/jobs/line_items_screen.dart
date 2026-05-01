import 'package:flutter/material.dart';

import 'create_line_item_screen.dart';

// Color Palette - Professional
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const success = Color(0xFF059669);
  static const surface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

class LineItem {
  LineItem({
    required this.name,
    required this.priceCents,
    this.description = '',
    this.type = 'Service',
    this.quantity = 1,
    this.unitPriceCents = 0,
  });

  final String name;
  final String description;
  final String type;
  final double quantity;
  final int unitPriceCents;
  int priceCents;
}

class LineItemsScreen extends StatefulWidget {
  const LineItemsScreen({
    super.key,
    required this.initial,
  });

  /// Pass in already-selected items so selections persist when re-opening.
  final List<LineItem> initial;

  @override
  State<LineItemsScreen> createState() => _LineItemsScreenState();
}

class _LineItemsScreenState extends State<LineItemsScreen>
    with SingleTickerProviderStateMixin {
  // Default catalogue
  static final List<LineItem> _catalogue = [
    LineItem(name: 'Free Assessment', priceCents: 0, type: 'Service'),
    LineItem(name: 'Exterior Window Cleaning', priceCents: 0, type: 'Service'),
    LineItem(name: 'Interior Window Cleaning', priceCents: 0, type: 'Service'),
    LineItem(name: 'Skylight Cleaning', priceCents: 0, type: 'Service'),
    LineItem(name: 'Screen Cleaning', priceCents: 0, type: 'Service'),
    LineItem(name: 'Gutter Cleaning', priceCents: 0, type: 'Service'),
    LineItem(name: 'Hang Christmas Lights', priceCents: 0, type: 'Seasonal'),
    LineItem(name: 'Remove Christmas Lights', priceCents: 0, type: 'Seasonal'),
    LineItem(name: 'Power Washing', priceCents: 0, type: 'Service'),
    LineItem(name: 'Frame Cleaning', priceCents: 0, type: 'Service'),
  ];

  late final List<LineItem> _items;
  late final List<LineItem> _filteredItems;
  final Set<int> _selected = {};

  late TextEditingController _searchController;
  late AnimationController _fadeController;
  String _selectedType = 'All';

  // Filter types
  late final List<String> _filterTypes;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _items = List.of(_catalogue.map((c) => LineItem(
      name: c.name,
      priceCents: c.priceCents,
      type: c.type,
      description: c.description,
    )));

    _filteredItems = List.of(_items);

    // Extract unique types
    _filterTypes = ['All', ..._items.map((i) => i.type).toSet()];

    // Restore previous selections
    for (final prev in widget.initial) {
      final idx = _items.indexWhere((it) => it.name == prev.name);
      if (idx != -1) {
        _selected.add(idx);
      }
    }

    _fadeController.forward();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _filteredItems.clear();

      final query = _searchController.text.toLowerCase();

      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];

        // Apply search filter
        final matchesSearch = item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query);

        // Apply type filter
        final matchesType = _selectedType == 'All' || item.type == _selectedType;

        if (matchesSearch && matchesType) {
          _filteredItems.add(item);
        }
      }
    });
  }

  void _confirm() {
    final result = _selected.map((i) => _items[i]).toList();
    Navigator.of(context).pop(result);
  }

  void _clearSearch() {
    _searchController.clear();
    _selectedType = 'All';
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final total = _selected.fold<int>(
        0, (acc, i) => acc + _items[i].priceCents);
    final selectedCount = _selected.length;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text(
          'Products / Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Tooltip(
            message: 'Create custom item',
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<LineItem>(MaterialPageRoute(
                  builder: (_) => const CreateLineItemScreen(),
                ));
                if (result != null) {
                  setState(() {
                    _items.add(result);
                    _selected.add(_items.length - 1);
                  });
                  _applyFilters();
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          _buildSearchAndFilterBar(context),

          // Item List
          Expanded(
            child: FadeTransition(
              opacity: _fadeController,
              child: _buildItemsList(context),
            ),
          ),

          // Footer with Total & Actions
          _buildFooter(context, selectedCount, total),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clearSearch,
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = _filterTypes[index];
                final isSelected = _selectedType == type;

                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : 'All';
                      _applyFilters();
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.accent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.secondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: 1,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppColors.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final itemIndex = _items.indexOf(item);
        final isSelected = _selected.contains(itemIndex);

        return _buildLineItemTile(
          context,
          item,
          isSelected,
              () => setState(() {
            if (isSelected) {
              _selected.remove(itemIndex);
            } else {
              _selected.add(itemIndex);
            }
          }),
        );
      },
    );
  }

  Widget _buildLineItemTile(
      BuildContext context,
      LineItem item,
      bool isSelected,
      VoidCallback onToggle,
      ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Checkbox with animation
                AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: isSelected ? 1.0 : 0.9,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    side: BorderSide(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: 2,
                    ),
                    activeColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),

                // Name + Type + Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Price
                if (item.priceCents > 0) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${(item.priceCents / 100).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  Text(
                    'Free',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, int selectedCount, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$selectedCount item${selectedCount == 1 ? '' : 's'} selected',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: \$${(total / 100).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    onPressed: selectedCount == 0
                        ? null
                        : () {
                      setState(() {
                        _selected.clear();
                      });
                    },
                    child: const Text('Clear selection'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: selectedCount == 0 ? null : _confirm,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text('Add to job'),
                      ],
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