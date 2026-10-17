import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../avis/laisser_avis_dialog.dart';

class MesDemandesScreen extends StatelessWidget {
  const MesDemandesScreen({super.key});

  Color _couleurStatut(String statut) => switch (statut) {
    'acceptee' => Colors.green,
    'refusee' => Colors.red,
    'terminee' => Colors.blue,
    _ => Colors.orange,
  };

  String _texteStatut(String statut) => switch (statut) {
    'acceptee' => 'Acceptée',
    'refusee' => 'Refusée',
    'terminee' => 'Terminée',
    _ => 'En attente',
  };

  IconData _iconeStatut(String statut) => switch (statut) {
    'acceptee' => Icons.check_circle,
    'refusee' => Icons.cancel,
    'terminee' => Icons.task_alt,
    _ => Icons.hourglass_top,
  };

  // Affichage des conditions de paiement
  String _conditionsPaiement(Map<String, dynamic> data) {
    final mode = data['modePaiement']?.toString();

    // Nouveau système : paiement en argent
    if (mode == 'argent') {
      final montant = data['montant'];

      final value = montant is num
          ? montant
          : double.tryParse(montant?.toString() ?? '');

      if (value == null) {
        return 'Montant non renseigné';
      }

      final texte = value.toStringAsFixed(
        value.truncateToDouble() == value ? 0 : 2,
      );

      return '$texte FCFA';
    }

    // Nouveau système : paiement en sacs de riz
    if (mode == 'riz') {
      final sacs = data['nombreSacs'];

      final value = sacs is num
          ? sacs
          : double.tryParse(sacs?.toString() ?? '');

      if (value == null) {
        return 'Nombre de sacs non renseigné';
      }

      final texte = value.toStringAsFixed(
        value.truncateToDouble() == value ? 0 : 2,
      );

      return '$texte sac${value == 1 ? '' : 's'} de riz';
    }

    // Nouveau système : négociation
    if (mode == 'negociation') {
      return 'Prix à négocier';
    }

    // Compatibilité avec les anciennes demandes
    final ancienPrix = data['prix'];

    final value = ancienPrix is num
        ? ancienPrix
        : double.tryParse(ancienPrix?.toString() ?? '');

    if (value != null) {
      final texte = value.toStringAsFixed(
        value.truncateToDouble() == value ? 0 : 2,
      );

      return '$texte FCFA';
    }

    return 'Conditions de paiement non renseignées';
  }

  String _date(Object? value) {
    if (value is! Timestamp) return 'Date non disponible';

    final d = value.toDate();

    final jour = d.day.toString().padLeft(2, '0');
    final mois = d.month.toString().padLeft(2, '0');

    return '$jour/$mois/${d.year} à '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes demandes')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('demandes')
            .where('agriculteurId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Impossible de charger vos demandes.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final documents = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) {
              final da = a.data()['dateDemande'];
              final db = b.data()['dateDemande'];

              final ta = da is Timestamp ? da.millisecondsSinceEpoch : 0;

              final tb = db is Timestamp ? db.millisecondsSinceEpoch : 0;

              return tb.compareTo(ta);
            });

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 80, color: Colors.grey),
                    SizedBox(height: 18),
                    Text(
                      'Aucune demande',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Vous n’avez pas encore envoyé de demande de location.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final demande = documents[index];
              final data = demande.data();

              final nom =
                  data['nomMateriel']?.toString() ?? 'Matériel sans nom';

              final type = data['typeMateriel']?.toString() ?? 'Type inconnu';

              final localisation = data['localisation']?.toString() ?? '';

              final statut = data['statut']?.toString() ?? 'en_attente';

              final couleur = _couleurStatut(statut);

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom du matériel
                      Row(
                        children: [
                          const Icon(
                            Icons.agriculture,
                            size: 40,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              nom,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Type
                      Text('Type : $type'),

                      // Localisation
                      if (localisation.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 19,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 5),
                            Expanded(child: Text(localisation)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 7),

                      // Conditions de paiement
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.payments,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _conditionsPaiement(data),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      // Date de la demande
                      Text(
                        'Demandée le : ${_date(data['dateDemande'])}',
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 12),

                      const Divider(),

                      const SizedBox(height: 8),

                      // Statut
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(_iconeStatut(statut), color: couleur),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _texteStatut(statut),
                                style: TextStyle(
                                  color: couleur,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (statut == 'acceptee')
                              const Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: 20,
                              ),
                          ],
                        ),
                      ),

                      // Message si acceptée
                      if (statut == 'acceptee') ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Votre demande a été acceptée. '
                          'Le matériel est réservé pour cette location.',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                      if (statut == 'terminee') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Cette location est terminée. Vous pouvez maintenant évaluer votre expérience.',
                          style: TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('avis')
                              .doc(demande.id)
                              .snapshots(),
                          builder: (context, avisSnapshot) {
                            if (avisSnapshot.data?.exists == true) {
                              final avis = avisSnapshot.data!.data()!;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  'Votre note : ${avis['note'] ?? '-'} / 5',
                                ),
                                subtitle: Text(
                                  (avis['commentaire']?.toString().isNotEmpty ??
                                          false)
                                      ? avis['commentaire'].toString()
                                      : 'Vous avez déjà évalué cette location.',
                                ),
                              );
                            }
                            return OutlinedButton.icon(
                              icon: const Icon(Icons.star_rate),
                              label: const Text('Noter cette location'),
                              onPressed: () => afficherDialogueAvis(
                                context,
                                demandeId: demande.id,
                                materielId:
                                    data['materielId']?.toString() ?? '',
                                proprietaireId:
                                    data['proprietaireId']?.toString() ?? '',
                                nomMateriel: nom,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
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
