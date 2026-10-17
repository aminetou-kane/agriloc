import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  static Future<void> signaler({
    required String sujet,
    required String description,
    String? materielId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Vous devez être connecté.');
    await FirebaseFirestore.instance.collection('signalements').add({
      'auteurId': user.uid,
      'sujet': sujet,
      'description': description.trim(),
      'materielId': materielId,
      'statut': 'nouveau',
      'dateCreation': FieldValue.serverTimestamp(),
    });
  }
}
