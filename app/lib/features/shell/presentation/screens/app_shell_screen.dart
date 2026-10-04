import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Khung ứng dụng với thanh điều hướng dưới 5 tab dùng StatefulShellRoute:
/// Trang chủ, Tập, Coach, Dinh dưỡng, Tôi.
class AppShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A283569),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  key: const ValueKey('tab-home'),
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  isSelected: currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('tab-workout'),
                  icon: Icons.fitness_center_rounded,
                  label: 'Tập',
                  isSelected: currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('tab-coach'),
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Coach',
                  isSelected: currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('tab-nutrition'),
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Dinh dưỡng',
                  isSelected: currentIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
              ),
              Expanded(
                child: _NavItem(
                  key: const ValueKey('tab-profile'),
                  icon: Icons.person_rounded,
                  label: 'Tôi',
                  isSelected: currentIndex == 4,
                  onTap: () => _onItemTapped(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
