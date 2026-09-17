import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';
import 'order_tile.dart';

class OrdersPage extends StatefulWidget {
  final bool activeOnly;

  const OrdersPage({super.key, this.activeOnly = false});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String query = '';
  OrderStatus? filter;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        final source = widget.activeOnly
            ? state.orders.where(
                (o) => o.status != OrderStatus.delivered &&
                    o.status != OrderStatus.cancelled,
              )
            : state.orders;

        final orders = source.where((order) {
          final q = query.toLowerCase().trim();
          final matchesQuery = q.isEmpty ||
              order.customerName.toLowerCase().contains(q) ||
              order.id.toLowerCase().contains(q) ||
              order.phone.toLowerCase().contains(q) ||
              order.table.toLowerCase().contains(q);

          final matchesStatus =
              filter == null || order.status == filter;

          return matchesQuery && matchesStatus;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              PageTitle(
                title: widget.activeOnly ? 'Active Orders' : 'Orders',
                subtitle: 'Manage order status from the desktop',
                trailing: SizedBox(
                  width: 280,
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search order, name, phone, table',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Filter(
                    label: 'All',
                    selected: filter == null,
                    onTap: () => setState(() => filter = null),
                  ),
                  ...OrderStatus.values.map(
                    (status) => _Filter(
                      label: status.name,
                      selected: filter == status,
                      onTap: () => setState(() => filter = status),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${orders.length} orders',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : orders.isEmpty
                        ? const EmptyPanel(
                            title: 'No orders found',
                            message: 'Try another search or filter.',
                          )
                        : ListView.builder(
                            itemCount: orders.length,
                            itemBuilder: (_, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OrderTile(order: orders[index]),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Filter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 11,
          color: selected ? AppColors.cream : AppColors.cream2,
        ),
      ),
    );
  }
}
