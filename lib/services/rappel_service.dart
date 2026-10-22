import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Rappels avant la date de location.
///
/// À chaque ouverture de l'application, on crée (une seule fois par location et
/// par utilisateur) une notification de rappel pour les locations acceptées qui
/// débutent aujourd'hui ou dans les 2 prochains jours. L'identifiant du document
/// est déterministe : un rappel déjà créé n'est jamais dupliqué.
class RappelService {
  static const _joursAvant = 2;

  static Future<void> verifier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = FirebaseFirestore.instance;

    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final limite = aujourdhui.add(const Duration(days: _joursAvant + 1));

    for (final champ in const ['agriculteurId', 'proprietaireId']) {
      final snap = await firestore
          .collection('demandes')
          .where(champ, isEqualTo: user.uid)
          .where('statut', isEqualTo: 'acceptee')
          .get();

      for (final doc in snap.docs) {
        final debut = doc.data()['dateDebut'];
        if (debut is! Timestamp) continue;
        final jour = debut.toDate();
        if (jour.isBefore(aujourdhui) || !jour.isBefore(limite)) continue;

        final ref = firestore
            .collection('notifications')
            .doc('rappel_${doc.id}_${user.uid}');
        if ((await ref.get()).exists) continue;

        final nom = doc.data()['nomMateriel'] ?? 'le matériel';
        final quand = jour.isAtSameMomentAs(aujourdhui)
            ? 'aujourd’hui'
            : 'le ${jour.day.toString().padLeft(2, '0')}/${jour.month.toString().padLeft(2, '0')}';
        await ref.set({
          'destinataireId': user.uid,
          'titre': 'Rappel de location',
          'message': 'La location de $nom commence $quand.',
          'type': 'rappel',
          'demandeId': doc.id,
          'lu': false,
          'dateCreation': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
