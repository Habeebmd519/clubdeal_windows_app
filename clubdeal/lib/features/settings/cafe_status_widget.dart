import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD

import '../theme/app_theme.dart';
=======
>>>>>>> e14afa1 (final 001)

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

<<<<<<< HEAD
  Future<void> _updateStatus(BuildContext context, bool isOpen) async {
=======
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

>>>>>>> e14afa1 (final 001)
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('cafe_status')
          .set({
<<<<<<< HEAD
            'status': isOpen,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update shop status: $error')),
      );
=======
        'status': open,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update shop status: $e')),
        );
      }
>>>>>>> e14afa1 (final 001)
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
<<<<<<< HEAD
        final isOpen = snapshot.data?.data()?['status'] == true;
        final loading = !snapshot.hasData && !snapshot.hasError;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: isOpen ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'SHOP STATUS',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        color: isOpen ? AppColors.success : AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'Could not load shop status',
                    style: TextStyle(color: AppColors.error, fontSize: 10),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _StatusChoice(
                        label: 'Open',
                        value: true,
                        groupValue: isOpen,
                        color: AppColors.success,
                        onChanged: loading
                            ? null
                            : (value) => _updateStatus(context, value),
                      ),
                    ),
                    Expanded(
                      child: _StatusChoice(
                        label: 'Closed',
                        value: false,
                        groupValue: isOpen,
                        color: AppColors.error,
                        onChanged: loading
                            ? null
                            : (value) => _updateStatus(context, value),
                      ),
                    ),
                  ],
                ),
            ],
          ),
=======
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
>>>>>>> e14afa1 (final 001)
        );
      },
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool groupValue;
  final Color color;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(value),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged == null
                ? null
                : (value) {
                    if (value != null) onChanged!(value);
                  },
            activeColor: color,
            visualDensity: const VisualDensity(
              horizontal: VisualDensity.minimumDensity,
              vertical: VisualDensity.minimumDensity,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: groupValue == value ? color : AppColors.cream2,
                fontSize: 11,
                fontWeight: groupValue == value
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
