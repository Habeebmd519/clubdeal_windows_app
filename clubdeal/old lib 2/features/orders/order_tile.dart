import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class OrderTile extends StatelessWidget {
  final RestaurantOrder order;

  const OrderTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus(order.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '#${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length)}',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order.customerName,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              order.table,
              style: const TextStyle(color: AppColors.cream2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${order.items.length} item(s)  •  ${DateFormat('hh:mm a').format(order.createdAt ?? DateTime.now())}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StatusPill(
            text: order.status.name.toUpperCase(),
            color: _statusColor(order.status),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 90,
            child: Text(
              '₹${order.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Mark ${next.name}',
              onPressed: () {
                context.read<OrderBloc>().add(
                      OrderStatusChanged(order.id, next),
                    );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  OrderStatus? _nextStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.delivered;
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return null;
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivered:
        return AppColors.green;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}
