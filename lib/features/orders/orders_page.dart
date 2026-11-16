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
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.activeOnly != widget.activeOnly) {
      query = '';
      filter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        // Active orders exclude delivered and cancelled orders.
        // Normal orders page includes every order.
        final source = widget.activeOnly
            ? state.orders.where((o) {
                // When Cancelled filter is selected, show cancelled orders.
                if (filter == OrderStatus.cancelled) {
                  return o.status == OrderStatus.cancelled;
                }

                // Normal Active Orders.
                return o.status != OrderStatus.delivered &&
                    o.status != OrderStatus.cancelled;
              })
            : state.orders;

        // Search and status filtering.
        final orders =
            source.where((order) {
              final q = query.toLowerCase().trim();

              final matchesQuery =
                  q.isEmpty ||
                  order.customerName.toLowerCase().contains(q) ||
                  order.id.toLowerCase().contains(q) ||
                  order.phone.toLowerCase().contains(q) ||
                  order.table.toLowerCase().contains(q);

              final matchesStatus = filter == null || order.status == filter;

              return matchesQuery && matchesStatus;
            }).toList()..sort((a, b) {
              final dateA = a.createdAt ?? DateTime(2000);
              final dateB = b.createdAt ?? DateTime(2000);

              return dateB.compareTo(dateA);
            });

        return Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              // PAGE HEADER
              PageTitle(
                title: widget.activeOnly ? 'Active Orders' : 'Orders',

                subtitle: widget.activeOnly
                    ? 'Manage ongoing orders'
                    : 'Manage and track all orders',

                trailing: SizedBox(
                  width: 300,

                  child: TextField(
                    onChanged: (value) {
                      setState(() => query = value);
                    },

                    decoration: InputDecoration(
                      hintText: 'Search order, name, phone, table',

                      prefixIcon: const Icon(Icons.search, size: 18),

                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // STATUS FILTERS
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,

                      child: Row(
                        children: [
                          _Filter(
                            label: 'All',
                            selected: filter == null,
                            icon: Icons.list_alt,
                            onTap: () {
                              setState(() => filter = null);
                            },
                          ),

                          ...OrderStatus.values.map((status) {
                            return _Filter(
                              label: _statusName(status),

                              selected: filter == status,

                              icon: _statusIcon(status),

                              onTap: () {
                                setState(() {
                                  filter = status;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    '${orders.length} orders',

                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ORDER LIST
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : orders.isEmpty
                    ? EmptyPanel(title: _emptyTitle(), message: _emptyMessage())
                    : ListView.builder(
                        itemCount: orders.length,

                        itemBuilder: (context, index) {
                          final order = orders[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),

                            child: OrderTile(order: order),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // STATUS LABEL
  String _statusName(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';

      case OrderStatus.preparing:
        return 'Preparing';

      case OrderStatus.ready:
        return 'Ready';

      case OrderStatus.delivered:
        return 'Delivered';

      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  // STATUS ICON
  IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;

      case OrderStatus.preparing:
        return Icons.restaurant;

      case OrderStatus.ready:
        return Icons.check_circle_outline;

      case OrderStatus.delivered:
        return Icons.done_all;

      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  // EMPTY STATE TITLE
  String _emptyTitle() {
    if (filter == OrderStatus.cancelled) {
      return 'No cancelled orders';
    }

    if (filter == OrderStatus.delivered) {
      return 'No delivered orders';
    }

    if (filter == OrderStatus.pending) {
      return 'No pending orders';
    }

    if (filter == OrderStatus.preparing) {
      return 'No orders preparing';
    }

    if (filter == OrderStatus.ready) {
      return 'No orders ready';
    }

    return 'No orders found';
  }

  // EMPTY STATE MESSAGE
  String _emptyMessage() {
    if (query.isNotEmpty) {
      return 'No orders match "$query". Try another search.';
    }

    return 'Orders matching this filter will appear here.';
  }
}

// ======================================================
// ORDER STATUS FILTER CHIP
// ======================================================

class _Filter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),

      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 15,
          color: selected ? AppColors.cream : AppColors.cream2,
        ),

        label: Text(label),

        selected: selected,

        onSelected: (_) => onTap(),

        labelStyle: TextStyle(
          fontSize: 11,

          fontWeight: selected ? FontWeight.bold : FontWeight.normal,

          color: selected ? AppColors.cream : AppColors.cream2,
        ),
      ),
    );
  }
}
