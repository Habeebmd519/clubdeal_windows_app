import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/app_bloc.dart';
import '../../core/bloc/expense_bloc.dart';
import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../../core/utils/currency_utils.dart';
import '../orders/order_tile.dart';
import '../widgets/desktop_widgets.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _setOpeningCash(BuildContext context, String sessionId) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opening cash in counter'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cash float at start of day (₹)',
              hintText: 'e.g. 2000',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n == null || n < 0 ? 'Enter a valid amount' : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => form.currentState?.validate() == true
                ? Navigator.pop(ctx, double.parse(controller.text))
                : null,
            child: const Text('Save opening cash'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (sessionId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('cash_sessions')
        .doc(sessionId)
        .set({
          'sessionId': sessionId,
          'openingCash': value,
          'openedAt': FieldValue.serverTimestamp(),
          'isClosed': false,
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('cafe_status')
          .snapshots(),
      builder: (context, sessionSnapshot) {
        final sessionData = sessionSnapshot.data?.data() ?? {};
        final storedStart = sessionData['sessionStartedAt'];
        final start = storedStart is Timestamp
            ? storedStart.toDate()
            : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final sessionId = (sessionData['activeSessionId'] ?? '').toString();
        final now = DateTime.now();
        final key = sessionId.isNotEmpty
            ? sessionId
            : '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, ordersState) => BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, expenseState) {
          final todays = ordersState.orders
              .where(
                (o) =>
                    o.createdAt != null &&
                    !o.createdAt!.isBefore(start) &&
                    !o.createdAt!.isAfter(now),
              )
              .toList();
          final paid = ordersState.orders
              .where(
                (o) =>
                    o.status == OrderStatus.delivered &&
                    o.paymentMethod != null &&
                    (o.deliveredAt ?? o.createdAt) != null &&
                    !(o.deliveredAt ?? o.createdAt)!.isBefore(start) &&
                    !(o.deliveredAt ?? o.createdAt)!.isAfter(now),
              )
              .toList();
          double sum(PaymentMethod m) => paid
              .where((o) => o.paymentMethod == m)
              .fold(0.0, (a, o) => a + o.total);
          final cash = sum(PaymentMethod.cash),
              card = sum(PaymentMethod.card),
              online = sum(PaymentMethod.online);
          final income = cash + card + online;
          final expenses = expenseState.items
              .where(
                (e) =>
                    !e.createdAt.isBefore(start) &&
                    !e.createdAt.isAfter(now),
              )
              .fold<double>(0, (a, e) => a + e.amount);
          final active = ordersState.orders
              .where(
                (o) =>
                    o.status != OrderStatus.delivered &&
                    o.status != OrderStatus.cancelled,
              )
              .toList();
          final pending = active
              .where((o) => o.status == OrderStatus.pending)
              .length;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const PageTitle(
                title: 'Dashboard',
                subtitle:
                    'Today at a glance — orders, collections and expenses',
              ),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('cash_sessions')
                    .doc(key)
                    .snapshots(),
                builder: (context, snapshot) {
                  final opening =
                      (snapshot.data?.data()?['openingCash'] as num? ?? 0)
                          .toDouble();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.point_of_sale,
                            color: AppColors.gold,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Opening cash in counter',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatInr(opening),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.cream,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (snapshot.data?.exists != true)
                            OutlinedButton.icon(
                              onPressed: sessionId.isEmpty ? null : () => _setOpeningCash(context, sessionId),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Set opening cash'),
                            )
                          else
                            const Chip(
                              avatar: Icon(Icons.lock_outline, size: 15),
                              label: Text('Opening cash set'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (sessionId.isNotEmpty)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('daily_closings')
                      .doc(sessionId)
                      .snapshots(),
                  builder: (context, stockSessionSnapshot) {
                    final raw = stockSessionSnapshot.data?.data()?['openingStock'];
                    final stock = raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : <String, dynamic>{};
                    final entries = stock.entries.toList()
                      ..sort((a, b) {
                        final aName = a.value is Map
                            ? (a.value['name'] ?? '').toString()
                            : a.key;
                        final bName = b.value is Map
                            ? (b.value['name'] ?? '').toString()
                            : b.key;
                        return aName.compareTo(bName);
                      });
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined,
                                    color: AppColors.gold),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text('Opening stock for this session',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Text('${entries.length} items',
                                    style: const TextStyle(color: AppColors.muted)),
                              ],
                            ),
                            if (stockSessionSnapshot.connectionState ==
                                ConnectionState.waiting)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: LinearProgressIndicator(minHeight: 2),
                              )
                            else if (entries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('No opening stock snapshot found.',
                                    style: TextStyle(color: AppColors.muted)),
                              )
                            else
                              ...entries.map((entry) {
                                final value = entry.value is Map
                                    ? Map<String, dynamic>.from(entry.value as Map)
                                    : <String, dynamic>{};
                                final quantity =
                                    (value['quantity'] as num? ?? 0).toDouble();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (value['name'] ?? entry.key).toString(),
                                          style: const TextStyle(color: AppColors.cream2),
                                        ),
                                      ),
                                      Text(
                                        '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} ${(value['unit'] ?? '').toString()}',
                                        style: const TextStyle(
                                            color: AppColors.cream,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MetricCard(
                    label: 'Orders today',
                    value: '${todays.length}',
                    icon: Icons.receipt_long_outlined,
                  ),
                  MetricCard(
                    label: 'Active orders',
                    value: '${active.length}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  MetricCard(
                    label: 'Total income',
                    value: formatInr(income),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  MetricCard(
                    label: 'Expenses today',
                    value: formatInr(expenses),
                    icon: Icons.money_off_outlined,
                  ),
                  MetricCard(
                    label: 'Cash sales',
                    value: formatInr(cash),
                    icon: Icons.payments_outlined,
                  ),
                  MetricCard(
                    label: 'Card sales',
                    value: formatInr(card),
                    icon: Icons.credit_card_outlined,
                  ),
                  MetricCard(
                    label: 'Online / UPI',
                    value: formatInr(online),
                    icon: Icons.qr_code_2_outlined,
                  ),
                  MetricCard(
                    label: 'Income after expenses',
                    value: formatInr(income - expenses),
                    icon: Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('cash_sessions')
                    .doc(key)
                    .snapshots(),
                builder: (context, snapshot) {
                  final opening =
                      (snapshot.data?.data()?['openingCash'] as num? ?? 0)
                          .toDouble();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Opening float + cash sales',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            formatInr(opening + cash),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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
                    '$pending waiting • ${active.length} active',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (ordersState.loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (active.isEmpty)
                const SizedBox(
                  height: 180,
                  child: EmptyPanel(
                    title: 'No active orders',
                    message: 'New orders will appear here automatically.',
                  ),
                )
              else
                ...active
                    .take(8)
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderTile(order: order),
                      ),
                    ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<AppBloc>().add(
                  const AppPageChanged(DesktopPage.activeOrders),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('Open Active Orders'),
              ),
            ],
          );
        },
      ),
      );
    },
  );
  }
}
