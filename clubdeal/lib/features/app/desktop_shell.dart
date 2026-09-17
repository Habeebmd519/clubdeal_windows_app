import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/app_bloc.dart';
import '../../core/bloc/order_bloc.dart';
import '../dashboard/dashboard_page.dart';
import '../orders/orders_page.dart';
import '../orders/all_orders_page.dart';
import '../menu/menu_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.f1): AppPageIntent(DesktopPage.dashboard),
            SingleActivator(LogicalKeyboardKey.f2): AppPageIntent(DesktopPage.activeOrders),
            SingleActivator(LogicalKeyboardKey.f3): AppPageIntent(DesktopPage.allOrders),
            SingleActivator(LogicalKeyboardKey.f4): AppPageIntent(DesktopPage.menu),
            SingleActivator(LogicalKeyboardKey.f10): AppPageIntent(DesktopPage.settings),
          },
          child: Actions(
            actions: {
              AppPageIntent: CallbackAction<AppPageIntent>(
                onInvoke: (intent) {
                  context.read<AppBloc>().add(
                        AppPageChanged(intent.page),
                      );
                  return null;
                },
              ),
            },
            child: Scaffold(
              body: Row(
                children: [
                  _Sidebar(state: state),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.background,
                      child: _PageBody(page: state.page),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppPageIntent extends Intent {
  final DesktopPage page;
  const AppPageIntent(this.page);
}

class _Sidebar extends StatelessWidget {
  final AppState state;

  const _Sidebar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.restaurant, color: AppColors.gold),
                SizedBox(width: 10),
                Text(
                  'CLUB DEAL',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            shortcut: 'F1',
            selected: state.page == DesktopPage.dashboard,
            onTap: () => _go(context, DesktopPage.dashboard),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Active Orders',
            shortcut: 'F2',
            selected: state.page == DesktopPage.activeOrders,
            onTap: () => _go(context, DesktopPage.activeOrders),
          ),
          _NavItem(
            icon: Icons.history_outlined,
            label: 'All Orders',
            shortcut: 'F3',
            selected: state.page == DesktopPage.allOrders,
            onTap: () => _go(context, DesktopPage.allOrders),
          ),
          _NavItem(
            icon: Icons.restaurant_menu_outlined,
            label: 'Menu',
            shortcut: 'F4',
            selected: state.page == DesktopPage.menu,
            onTap: () => _go(context, DesktopPage.menu),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            shortcut: 'F10',
            selected: state.page == DesktopPage.settings,
            onTap: () => _go(context, DesktopPage.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _go(BuildContext context, DesktopPage page) {
    context.read<AppBloc>().add(AppPageChanged(page));
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
        selected: selected,
        selectedTileColor: AppColors.green2.withValues(alpha: 0.18),
        leading: Icon(
          icon,
          size: 19,
          color: selected ? AppColors.green : AppColors.muted,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cream : AppColors.cream2,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Text(
          shortcut,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  final DesktopPage page;

  const _PageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    switch (page) {
      case DesktopPage.dashboard:
        return const DashboardPage();
      case DesktopPage.activeOrders:
        return const OrdersPage(activeOnly: true);
      case DesktopPage.allOrders:
        return const AllOrdersPage();
      case DesktopPage.menu:
        return const MenuPage();
      case DesktopPage.settings:
        return const SettingsPage();
    }
  }
}
