import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CafeStatusWidget extends StatelessWidget {
  const CafeStatusWidget({super.key});

  Future<void> _updateStatus(bool status) async {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('cafe_status')
        .set({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance
        .collection('app_config')
        .doc('cafe_status');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load cafe status');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data();
        final isOpen = data?['status'] == true;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cafe Availability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                RadioListTile<bool>(
                  value: true,
                  groupValue: isOpen,
                  activeColor: Colors.green,
                  title: const Text('Open'),
                  subtitle: const Text('Accepting new orders'),
                  onChanged: (value) async {
                    if (value != null) {
                      await _updateStatus(value);
                    }
                  },
                ),

                RadioListTile<bool>(
                  value: false,
                  groupValue: isOpen,
                  activeColor: Colors.red,
                  title: const Text('Closed'),
                  subtitle: const Text('Not accepting new orders'),
                  onChanged: (value) async {
                    if (value != null) {
                      await _updateStatus(value);
                    }
                  },
                ),

                const Divider(),

                Row(
                  children: [
                    Icon(
                      isOpen ? Icons.check_circle : Icons.cancel,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOpen ? 'Cafe is OPEN' : 'Cafe is CLOSED',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOpen ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
