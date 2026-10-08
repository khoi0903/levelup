import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/shell_controller.dart';

/// Khung ứng dụng với thanh điều hướng dưới 5 tab dùng StatefulShellRoute:
/// Trang chủ, Tập, Coach, Dinh dưỡng, Tôi.
class AppShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appShellCurrentBranchProvider.notifier).state =
            widget.navigationShell.currentIndex;
      }
    });
  }

  @override
  void didUpdateWidget(AppShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      // didUpdateWidget chạy trong lúc build: không được sửa provider ngay, đợi hết khung hình
      final index = widget.navigationShell.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(appShellCurrentBranchProvider.notifier).state = index;
        }
      });
    }
  }

  void _onItemTapped(int index) {
    ref.read(appShellCurrentBranchProvider.notifier).state = index;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      body: widget.navigationShell,
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
