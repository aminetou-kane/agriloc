import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> creer({
    required String destinataireId,
    required String titre,
    required String message,
    required String type,
    String? demandeId,
  }) async {
    if (destinataireId.trim().isEmpty) return;
    final donnees = <String, dynamic>{
      'destinataireId': destinataireId,
      'titre': titre,
      'message': message,
      'type': type,
      'lu': false,
      'dateCreation': FieldValue.serverTimestamp(),
    };
    if (demandeId != null && demandeId.isNotEmpty) {
      donnees['demandeId'] = demandeId;
    }
    await FirebaseFirestore.instance.collection('notifications').add(donnees);
  }
}
