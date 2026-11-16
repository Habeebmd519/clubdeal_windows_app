import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

  Future<void> _changeStatus(BuildContext context, bool open) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(open ? 'Open the shop?' : 'Close the shop?'),
        content: Text(open
            ? 'The shop will start accepting new orders.'
            : 'The shop will stop accepting new orders. Existing orders will remain available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(open ? 'Yes, open shop' : 'Yes, close shop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('cafe_status')
          .set({
        'status': open,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update shop status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance
        .collection('app_config')
        .doc('cafe_status');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snapshot) {
        final isOpen = snapshot.data?.data()?['status'] != false;
        if (snapshot.hasError) {
          return const Text('Shop status unavailable');
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Shop', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Radio<bool>(
              value: true,
              groupValue: isOpen,
              activeColor: Colors.green,
              onChanged: snapshot.connectionState == ConnectionState.waiting
                  ? null
                  : (_) => _changeStatus(context, true),
            ),
            const Text('ON', style: TextStyle(fontSize: 11)),
            Radio<bool>(
              value: false,
              groupValue: isOpen,
              activeColor: Colors.red,
              onChanged: snapshot.connectionState == ConnectionState.waiting
                  ? null
                  : (_) => _changeStatus(context, false),
            ),
            const Text('OFF', style: TextStyle(fontSize: 11)),
          ],
        );
      },
    );
  }
}
