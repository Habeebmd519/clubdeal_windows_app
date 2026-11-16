import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

  String _legacyDayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _changeStatus(BuildContext context, bool open) async {
    final db = FirebaseFirestore.instance;
    final statusRef = db.collection('app_config').doc('cafe_status');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(open ? 'Open the shop?' : 'Close the shop?'),
        content: Text(
          open
              ? 'A new business session will start. Dashboard daily figures will start from zero, and current remaining stock will be recorded as opening stock.'
              : 'The current business session will be closed. Sales, expenses, cash and remaining stock will be saved. Remaining stock will carry forward; inventory will not be erased.',
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
      final statusSnapshot = await statusRef.get();
      final statusData = statusSnapshot.data() ?? <String, dynamic>{};
      final currentlyOpen = statusData['status'] != false;
      if (currentlyOpen == open) return;

      final now = DateTime.now();

      if (!open) {
        final sessionId = (statusData['activeSessionId'] ?? '').toString();
        final storedStart = statusData['sessionStartedAt'];
        final sessionStart = storedStart is Timestamp
            ? storedStart.toDate()
            : DateTime(now.year, now.month, now.day);
        final reportId = sessionId.isNotEmpty ? sessionId : _legacyDayKey(now);

        final orderSnapshot = await db
            .collection('orders')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sessionStart),
            )
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .get();

        double cashSales = 0;
        double cardSales = 0;
        double onlineSales = 0;
        int deliveredOrderCount = 0;

        for (final doc in orderSnapshot.docs) {
          final data = doc.data();
          if (data['status'] != 'delivered') continue;
          final amount = (data['total'] as num? ?? 0).toDouble();
          deliveredOrderCount++;
          switch ((data['paymentMethod'] ?? '').toString().toLowerCase()) {
            case 'cash':
              cashSales += amount;
              break;
            case 'card':
              cardSales += amount;
              break;
            case 'online':
            case 'upi':
              onlineSales += amount;
              break;
          }
        }

        final expenseSnapshot = await db
            .collection('expenses')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sessionStart),
            )
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .get();
        final totalExpenses = expenseSnapshot.docs.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data()['amount'] as num?) ?? 0).toDouble(),
        );

        final ingredientSnapshot = await db.collection('ingredients').get();
        final closingStock = <String, dynamic>{};
        for (final doc in ingredientSnapshot.docs) {
          final data = doc.data();
          closingStock[doc.id] = {
            'name': data['name'] ?? '',
            'quantity': (data['stockQuantity'] as num? ?? 0).toDouble(),
            'unit': data['baseUnit'] ?? '',
          };
        }

        final cashRef = db.collection('cash_sessions').doc(reportId);
        final cashSnapshot = await cashRef.get();
        final openingCash = (cashSnapshot.data()?['openingCash'] as num? ?? 0)
            .toDouble();

        final report = <String, dynamic>{
          'sessionId': reportId,
          'status': 'closed',
          'dateKey': _legacyDayKey(now),
          'sessionStartedAt': Timestamp.fromDate(sessionStart),
          'closedAt': FieldValue.serverTimestamp(),
          'orderCount': deliveredOrderCount,
          'cashSales': cashSales,
          'cardSales': cardSales,
          'onlineSales': onlineSales,
          'totalSales': cashSales + cardSales + onlineSales,
          'totalExpenses': totalExpenses,
          'openingCash': openingCash,
          'stockSnapshot': closingStock,
        };

        final batch = db.batch();
        batch.set(
          db.collection('daily_closings').doc(reportId),
          report,
          SetOptions(merge: true),
        );
        batch.set(cashRef, {
          'closedAt': FieldValue.serverTimestamp(),
          'isClosed': true,
          'sessionId': reportId,
        }, SetOptions(merge: true));
        batch.set(statusRef, {
          'status': false,
          'lastClosedSessionId': reportId,
          'activeSessionId': FieldValue.delete(),
          'sessionStartedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
      } else {
        // Start a distinct session. The live stock balance is NOT changed:
        // it becomes the opening stock snapshot for this new session.
        final sessionRef = db.collection('daily_closings').doc();
        final ingredientSnapshot = await db.collection('ingredients').get();
        final openingStock = <String, dynamic>{};
        for (final doc in ingredientSnapshot.docs) {
          final data = doc.data();
          openingStock[doc.id] = {
            'name': data['name'] ?? '',
            'quantity': (data['stockQuantity'] as num? ?? 0).toDouble(),
            'unit': data['baseUnit'] ?? '',
          };
        }

        final batch = db.batch();
        batch.set(sessionRef, {
          'sessionId': sessionRef.id,
          'status': 'open',
          'sessionStartedAt': FieldValue.serverTimestamp(),
          'openingStock': openingStock,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(statusRef, {
          'status': true,
          'activeSessionId': sessionRef.id,
          'sessionStartedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            open
                ? 'Shop opened. New dashboard session started; current stock saved as opening stock.'
                : 'Shop closed. Session report and closing stock saved.',
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
                        if (value == true && !isOpen) {
                          _changeStatus(context, true);
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
                        if (value == false && isOpen) {
                          _changeStatus(context, false);
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
