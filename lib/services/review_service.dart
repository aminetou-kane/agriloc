import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  static Future<void> ajouter({
    required String demandeId,
    required String materielId,
    required String agriculteurId,
    required String proprietaireId,
    required String nomMateriel,
    required int note,
    required String commentaire,
  }) async {
    if (note < 1 || note > 5) {
      throw ArgumentError('La note doit être comprise entre 1 et 5.');
    }
    final firestore = FirebaseFirestore.instance;
    final demandeRef = firestore.collection('demandes').doc(demandeId);
    final avisRef = firestore.collection('avis').doc(demandeId);

    await firestore.runTransaction((transaction) async {
      final demandeSnapshot = await transaction.get(demandeRef);
      if (!demandeSnapshot.exists) {
        throw Exception('Demande introuvable.');
      }
      final demande = demandeSnapshot.data()!;
      if (demande['agriculteurId'] != agriculteurId) {
        throw Exception('Vous ne pouvez pas évaluer cette location.');
      }
      if (demande['statut'] != 'terminee') {
        throw Exception('Vous pourrez noter après la fin de la location.');
      }
      final ancienAvis = await transaction.get(avisRef);
      if (ancienAvis.exists) {
        throw Exception('Vous avez déjà noté cette location.');
      }
      transaction.set(avisRef, {
        'demandeId': demandeId,
        'materielId': materielId,
        'agriculteurId': agriculteurId,
        'proprietaireId': proprietaireId,
        'nomMateriel': nomMateriel,
        'note': note,
        'commentaire': commentaire.trim(),
        'dateCreation': FieldValue.serverTimestamp(),
      });
    });
  }
}
