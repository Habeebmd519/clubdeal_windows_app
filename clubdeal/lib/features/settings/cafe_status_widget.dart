import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

  Future<void> _changeStatus(BuildContext context, bool open) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(open ? 'Open the shop?' : 'Close the shop?'),
        content: Text(
          open ? 'The shop will start accepting new orders.' : 'The shop will stop accepting new orders. Existing orders will remain available.',
        ),
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
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update shop status: $e')),
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
