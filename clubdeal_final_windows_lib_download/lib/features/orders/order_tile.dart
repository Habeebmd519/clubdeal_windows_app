import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../../core/services/printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class OrderTile extends StatefulWidget {
  final RestaurantOrder order;
  const OrderTile({super.key, required this.order});

  @override
  State<OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<OrderTile> {
  bool expanded = false;
  bool printing = false;

  Future<void> _print(BuildContext context) async {
    setState(() => printing = true);
    try {
      await context.read<PrinterService>().printOrder(widget.order);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill sent to printer.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final next = _nextStatus(order.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      '#${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length)}',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(order.customerName,
                        style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: 100, child: Text(order.table, style: const TextStyle(color: AppColors.cream2), overflow: TextOverflow.ellipsis)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${order.items.length} item(s) • ${DateFormat('hh:mm a').format(order.createdAt ?? DateTime.now())}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(text: order.status.name.toUpperCase(), color: _statusColor(order.status)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text('₹${order.total.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Print bill',
                    visualDensity: VisualDensity.compact,
                    onPressed: printing ? null : () => _print(context),
                    icon: printing
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 18),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      Text('Customer: ${order.customerName}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                      Text('Phone: ${order.phone.isEmpty ? '—' : order.phone}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                      Text('Table: ${order.table}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                    ],
                  ),
                  if (order.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('Note: ${order.note}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text(item.emoji),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name, style: const TextStyle(color: AppColors.cream, fontSize: 12))),
                      Text('x${item.qty}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                      const SizedBox(width: 20),
                      SizedBox(width: 90, child: Text('₹${item.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.cream2, fontSize: 12))),
                    ]),
                  )),
                  const Divider(color: AppColors.border),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: printing ? null : () => _print(context),
                        icon: printing
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.print_outlined, size: 17),
                        label: Text(printing ? 'Printing…' : 'Print Bill'),
                      ),
                      const Spacer(),
                      if (next != null)
                        FilledButton.icon(
                          onPressed: () => context.read<OrderBloc>().add(OrderStatusChanged(order.id, next)),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text('Mark ${next.name}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  OrderStatus? _nextStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return OrderStatus.preparing;
      case OrderStatus.preparing: return OrderStatus.ready;
      case OrderStatus.ready: return OrderStatus.delivered;
      case OrderStatus.delivered:
      case OrderStatus.cancelled: return null;
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return AppColors.warning;
      case OrderStatus.preparing: return AppColors.info;
      case OrderStatus.ready: return AppColors.success;
      case OrderStatus.delivered: return AppColors.green;
      case OrderStatus.cancelled: return AppColors.error;
    }
  }
}
