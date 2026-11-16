import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

  Future<void> _changeStatus(BuildContext context, bool open) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    final dayKey =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(open ? 'Open the shop?' : 'Close the shop?'),
        content: Text(
          open
              ? 'The shop will start accepting new orders.'
              : 'Closing will save today’s sales, expenses, cash session '
                    'and remaining stock. Stock will carry forward to the '
                    'next day. Previous records will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(open ? 'Open Shop' : 'Close Shop'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!open) {
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));

        // Fetch today's orders.
        final orderSnapshot = await db
            .collection('orders')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .get();

        double cashSales = 0;
        double cardSales = 0;
        double onlineSales = 0;
        int orderCount = orderSnapshot.docs.length;

        for (final doc in orderSnapshot.docs) {
          final data = doc.data();

          if (data['status'] != 'delivered') continue;

          final amount = (data['total'] as num? ?? 0).toDouble();

          switch (data['paymentMethod']) {
            case 'cash':
              cashSales += amount;
              break;
            case 'card':
              cardSales += amount;
              break;
            case 'online':
              onlineSales += amount;
              break;
          }
        }

        // Fetch today's expenses.
        final expenseSnapshot = await db
            .collection('expenses')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .get();

        final totalExpenses = expenseSnapshot.docs.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data()['amount'] as num?) ?? 0).toDouble(),
        );

        // Capture current ingredient balances without changing them.
        final ingredientSnapshot = await db.collection('ingredients').get();

        final stockSnapshot = <String, dynamic>{};

        for (final doc in ingredientSnapshot.docs) {
          final data = doc.data();

          stockSnapshot[doc.id] = {
            'name': data['name'] ?? '',
            'quantity': data['stockQuantity'] ?? 0,
            'unit': data['baseUnit'] ?? '',
          };
        }

        // Read opening cash for today.
        final cashRef = db.collection('cash_sessions').doc(dayKey);
        final cashDoc = await cashRef.get();

        final openingCash = (cashDoc.data()?['openingCash'] as num? ?? 0)
            .toDouble();

        // Save the daily closing report.
        await db.collection('daily_closings').doc(dayKey).set({
          'dateKey': dayKey,
          'closedAt': FieldValue.serverTimestamp(),
          'orderCount': orderCount,
          'cashSales': cashSales,
          'cardSales': cardSales,
          'onlineSales': onlineSales,
          'totalSales': cashSales + cardSales + onlineSales,
          'totalExpenses': totalExpenses,
          'openingCash': openingCash,
          'stockSnapshot': stockSnapshot,
        }, SetOptions(merge: true));

        // Close today's cash session.
        await cashRef.set({
          'closedAt': FieldValue.serverTimestamp(),
          'isClosed': true,
        }, SetOptions(merge: true));
      }

      // Change shop status only after the closing report is saved.
      await db.collection('app_config').doc('cafe_status').set({
        'status': open,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            open
                ? 'Shop opened successfully.'
                : 'Shop closed. Daily report and stock snapshot saved.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not ${open ? 'open' : 'close'} shop: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusRef = FirebaseFirestore.instance
        .collection('app_config')
        .doc('cafe_status');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: statusRef.snapshots(),
      builder: (context, snapshot) {
        final isOpen = snapshot.data?.data()?['status'] != false;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        if (snapshot.hasError) {
          return const Text('Shop status unavailable');
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 17),
              const SizedBox(width: 5),
              const Text('SHOP'),
              Radio<bool>(
                value: true,
                groupValue: isOpen,
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null && value != isOpen) {
                          _changeStatus(context, value);
                        }
                      },
              ),
              const Text('ON'),
              Radio<bool>(
                value: false,
                groupValue: isOpen,
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null && value != isOpen) {
                          _changeStatus(context, value);
                        }
                      },
              ),
              const Text('OFF'),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}
