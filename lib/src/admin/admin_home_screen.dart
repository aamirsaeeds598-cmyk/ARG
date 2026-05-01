import 'package:flutter/material.dart';

import 'dashboard/dashboard_screen.dart';
import 'home/home_menu_screen.dart';
import 'settings/settings_screen.dart';

// Professional Color Palette
class AppColors {
  static const primary = Color(0xFF1F2937);
  static const secondary = Color(0xFF6B7280);
  static const accent = Color(0xFF3B82F6);

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFF59E0B);

  static const surface = Color(0xFFF9FAFB);
  static const background = Colors.white;
  static const border = Color(0xFFE5E7EB);
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _navigationController;
  late List<AnimationController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;

    _navigationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _itemControllers = List.generate(
      3,
          (_) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _itemControllers[0].forward();
  }

  @override
  void dispose() {
    _navigationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (index == _currentIndex) return;

    _itemControllers[_currentIndex].reverse();

    setState(() => _currentIndex = index);

    _itemControllers[_currentIndex].forward();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(teamId: widget.teamId),
      HomeMenuScreen(teamId: widget.teamId),
      SettingsScreen(teamId: widget.teamId),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildCustomBottomNavigation(),
    );
  }

  Widget _buildCustomBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCustomNavItem(
                index: 0,
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                label: 'Dashboard',
                controller: _itemControllers[0],
              ),
              _buildCustomNavItem(
                index: 1,
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view,
                label: 'Modules',
                controller: _itemControllers[1],
              ),
              _buildCustomNavItem(
                index: 2,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                controller: _itemControllers[2],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required AnimationController controller,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final backgroundColor = Color.lerp(
            Colors.transparent,
            AppColors.accent.withValues(alpha: 0.1),
            controller.value,
          ) ?? Colors.transparent;

          final borderColor = Color.lerp(
            AppColors.border,
            AppColors.accent.withValues(alpha: 0.3),
            controller.value,
          ) ?? AppColors.border;

          final iconColor = Color.lerp(
            AppColors.secondary,
            AppColors.accent,
            controller.value,
          ) ?? AppColors.secondary;

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 + (8 * controller.value),
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Icon
                    Icon(
                      isSelected ? selectedIcon : icon,
                      size: 24,
                      color: iconColor,
                    ),
                    // Ripple Effect
                    if (controller.value > 0)
                      Container(
                        width: 28 + (4 * controller.value),
                        height: 28 + (4 * controller.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent
                                .withValues(alpha: 0.2 * (1 - controller.value)),
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0)
                      .animate(CurvedAnimation(
                    parent: controller,
                    curve: Curves.easeInOut,
                  )),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}