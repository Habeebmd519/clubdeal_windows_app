import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/app_bloc.dart';
import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../orders/order_tile.dart';
import '../widgets/desktop_widgets.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        final orders = state.orders;
        final active = orders.where(
          (o) => o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled,
        ).toList();

        final pending = orders.where(
          (o) => o.status == OrderStatus.pending,
        ).length;

        final revenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.total,
        );

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const PageTitle(
              title: 'Dashboard',
              subtitle: 'Live restaurant order overview',
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  label: 'Total Orders',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_outlined,
                ),
                MetricCard(
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.schedule_outlined,
                ),
                MetricCard(
                  label: 'Active',
                  value: '${active.length}',
                  icon: Icons.local_fire_department_outlined,
                ),
                MetricCard(
                  label: 'Order Value',
                  value: '₹${revenue.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Live Orders',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${active.length} active',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.loading)
              const LinearProgressIndicator(minHeight: 2)
            else if (active.isEmpty)
              const SizedBox(
                height: 260,
                child: EmptyPanel(
                  title: 'No active orders',
                  message: 'New orders will appear here automatically.',
                ),
              )
            else
              ...active.take(8).map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OrderTile(order: order),
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                context.read<AppBloc>().add(
                      const AppPageChanged(DesktopPage.activeOrders),
                    );
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 17),
              label: const Text('Open Active Orders'),
            ),
          ],
        );
      },
    );
  }
}
