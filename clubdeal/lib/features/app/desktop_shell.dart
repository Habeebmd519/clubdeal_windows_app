import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/app_bloc.dart';
import '../dashboard/dashboard_page.dart';
import '../expenses/expense_page.dart';
import '../inventory/inventory_page.dart';
import '../menu/menu_page.dart';
import '../orders/all_orders_page.dart';
import '../orders/orders_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.f1): AppPageIntent(DesktopPage.dashboard),
          SingleActivator(LogicalKeyboardKey.f2): AppPageIntent(DesktopPage.activeOrders),
          SingleActivator(LogicalKeyboardKey.f3): AppPageIntent(DesktopPage.allOrders),
          SingleActivator(LogicalKeyboardKey.f4): AppPageIntent(DesktopPage.menu),
          SingleActivator(LogicalKeyboardKey.f5): AppPageIntent(DesktopPage.expenses),
          SingleActivator(LogicalKeyboardKey.f6): AppPageIntent(DesktopPage.inventory),
          SingleActivator(LogicalKeyboardKey.f10): AppPageIntent(DesktopPage.settings),
        },
        child: Actions(
          actions: {
            AppPageIntent: CallbackAction<AppPageIntent>(
              onInvoke: (intent) {
                context.read<AppBloc>().add(AppPageChanged(intent.page));
                return null;
              },
            ),
          },
          child: Scaffold(
            body: Row(children: [
              _Sidebar(state: state),
              Expanded(child: ColoredBox(
                color: AppColors.background,
                child: _PageBody(page: state.page),
              )),
            ]),
          ),
        ),
      ),
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
  Widget build(BuildContext context) => Container(
    width: 210,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Column(children: [
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          Icon(Icons.restaurant, color: AppColors.gold),
          SizedBox(width: 10),
          Text('CLUB DEAL', style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ]),
      ),
      const SizedBox(height: 28),
      _item(context, Icons.dashboard_outlined, 'Dashboard', 'F1', DesktopPage.dashboard),
      _item(context, Icons.receipt_long_outlined, 'Active Orders', 'F2', DesktopPage.activeOrders),
      _item(context, Icons.history_outlined, 'All Orders', 'F3', DesktopPage.allOrders),
      _item(context, Icons.restaurant_menu_outlined, 'Menu', 'F4', DesktopPage.menu),
      _item(context, Icons.payments_outlined, 'Expenses', 'F5', DesktopPage.expenses),
      _item(context, Icons.inventory_2_outlined, 'Inventory', 'F6', DesktopPage.inventory),
      const Spacer(),
      _item(context, Icons.settings_outlined, 'Settings', 'F10', DesktopPage.settings),
      const SizedBox(height: 16),
    ]),
  );

  Widget _item(BuildContext context, IconData icon, String label, String shortcut, DesktopPage page) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        selected: state.page == page,
        selectedTileColor: AppColors.green2.withValues(alpha: 0.18),
        leading: Icon(icon, size: 19, color: state.page == page ? AppColors.green : AppColors.muted),
        title: Text(label, style: TextStyle(color: state.page == page ? AppColors.cream : AppColors.cream2, fontSize: 12, fontWeight: state.page == page ? FontWeight.w700 : FontWeight.w500)),
        trailing: Text(shortcut, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
        onTap: () => context.read<AppBloc>().add(AppPageChanged(page)),
      ),
    );
}

class _PageBody extends StatelessWidget {
  final DesktopPage page;
  const _PageBody({required this.page});

  @override
  Widget build(BuildContext context) {
    switch (page) {
      case DesktopPage.dashboard: return const DashboardPage();
      case DesktopPage.activeOrders: return const OrdersPage(activeOnly: true);
      case DesktopPage.allOrders: return const AllOrdersPage();
      case DesktopPage.menu: return const MenuPage();
      case DesktopPage.expenses: return const ExpensePage();
      case DesktopPage.inventory: return const InventoryPage();
      case DesktopPage.settings: return const SettingsPage();
    }
  }
}
