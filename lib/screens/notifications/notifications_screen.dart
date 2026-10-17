import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _date(dynamic valeur) {
    if (valeur is! Timestamp) return 'À l’instant';
    final d = valeur.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _marquerLue(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.update({'lu': true});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de mettre à jour : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Connectez-vous.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('destinataireId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Impossible de charger les notifications. Vérifiez les règles Firestore.',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final da = a.data()['dateCreation'];
              final db = b.data()['dateCreation'];
              final ta = da is Timestamp ? da.millisecondsSinceEpoch : 0;
              final tb = db is Timestamp ? db.millisecondsSinceEpoch : 0;
              return tb.compareTo(ta);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Vous n’avez aucune notification.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final lu = data['lu'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: lu
                        ? Colors.grey.shade200
                        : Colors.green.shade100,
                    child: Icon(
                      lu
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: lu ? Colors.grey : Colors.green.shade800,
                    ),
                  ),
                  title: Text(
                    data['titre']?.toString() ?? 'Notification AgriLoc',
                    style: TextStyle(
                      fontWeight: lu ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${data['message'] ?? ''}\n${_date(data['dateCreation'])}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: lu
                      ? const Icon(Icons.done, color: Colors.grey)
                      : IconButton(
                          tooltip: 'Marquer comme lue',
                          icon: const Icon(
                            Icons.mark_email_read,
                            color: Colors.green,
                          ),
                          onPressed: () => _marquerLue(context, doc.reference),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
