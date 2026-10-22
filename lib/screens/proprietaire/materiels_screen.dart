import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/photos_materiel.dart';

import 'modifier_materiel_screen.dart';

class MaterielsScreen extends StatelessWidget {
  const MaterielsScreen({super.key});

  Future<void> changerDisponibilite(
    BuildContext context,
    String materielId,
    bool nouvelleValeur,
  ) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw Exception('Vous devez être connecté.');
      }

      await FirebaseFirestore.instance
          .collection('materiels')
          .doc(materielId)
          .update({
            'disponible': nouvelleValeur,
            'dateModification': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nouvelleValeur
                  ? 'Matériel disponible.'
                  : 'Matériel indisponible.',
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Firebase : ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _supprimer(
    BuildContext context,
    String materielId,
    String nom,
  ) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le matériel'),
        content: Text('Voulez-vous vraiment supprimer « $nom » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('materiels')
          .doc(materielId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matériel supprimé avec succès.')),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Firebase : ${e.message ?? e.code}')),
        );
      }
    }
  }

  // Affichage des conditions de paiement
  Widget _conditionsPaiement(Map<String, dynamic> data) {
    final mode = data['modePaiement']?.toString();

    // Nouveau système : paiement en argent
    if (mode == 'argent') {
      final montant = data['montant'];

      if (montant is num) {
        final valeur = montant.toStringAsFixed(
          montant.truncateToDouble() == montant ? 0 : 2,
        );

        return Row(
          children: [
            const Icon(Icons.money, size: 20, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              '$valeur FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      }

      return const Text(
        '💵 Paiement en argent',
        style: TextStyle(fontWeight: FontWeight.bold),
      );
    }

    // Nouveau système : paiement en sacs de riz
    if (mode == 'riz') {
      final sacs = data['nombreSacs'];

      if (sacs is num) {
        return Row(
          children: [
            const Icon(Icons.grain, size: 20, color: Colors.orange),
            const SizedBox(width: 6),
            Text(
              '${sacs.toInt()} sac${sacs.toInt() > 1 ? 's' : ''} de riz',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      }

      return const Text(
        '🌾 Paiement en sacs de riz',
        style: TextStyle(fontWeight: FontWeight.bold),
      );
    }

    // Nouveau système : négociation
    if (mode == 'negociation') {
      return const Row(
        children: [
          Icon(Icons.handshake, size: 20, color: Colors.orange),
          SizedBox(width: 6),
          Text(
            'Prix à négocier',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    // Compatibilité avec les anciens matériels
    final ancienPrix = data['prix'];

    if (ancienPrix is num) {
      final valeur = ancienPrix.toStringAsFixed(
        ancienPrix.truncateToDouble() == ancienPrix ? 0 : 2,
      );

      return Row(
        children: [
          const Icon(Icons.money, size: 20, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            '$valeur FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return const Text(
      'Conditions de paiement non renseignées',
      style: TextStyle(fontWeight: FontWeight.bold),
    );
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
      appBar: AppBar(title: const Text('Mes matériels')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('materiels')
            .where('proprietaireId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Impossible de charger vos matériels.'),
              ),
            );
          }

          final documents = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) {
              final da = a.data()['dateAjout'];
              final db = b.data()['dateAjout'];

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
                    Icon(Icons.agriculture, size: 80, color: Colors.grey),
                    SizedBox(height: 18),
                    Text(
                      'Aucun matériel',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ajoutez votre premier matériel depuis l’espace propriétaire.',
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
              final doc = documents[index];
              final data = doc.data();

              final nom = data['nom']?.toString() ?? 'Matériel sans nom';

              final type = data['type']?.toString() ?? 'Type inconnu';

              final description = data['description']?.toString() ?? '';

              final localisation = data['localisation']?.toString() ?? '';

              final disponible = data['disponible'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PhotoMateriel(data: data, taille: 56),
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
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'modifier') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModifierMaterielScreen(
                                      materielId: doc.id,
                                      materiel: data,
                                    ),
                                  ),
                                );
                              } else if (value == 'supprimer') {
                                _supprimer(context, doc.id, nom);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'modifier',
                                child: Text('Modifier'),
                              ),
                              PopupMenuItem(
                                value: 'supprimer',
                                child: Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text('Type : $type'),

                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(description),
                      ],

                      if (localisation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 5),
                            Expanded(child: Text(localisation)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),

                      // CONDITIONS DE PAIEMENT
                      _conditionsPaiement(data),

                      const SizedBox(height: 10),

                      // DISPONIBILITÉ
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(disponible ? 'Disponible' : 'Indisponible'),
                        subtitle: Text(
                          disponible
                              ? 'Visible pour les agriculteurs.'
                              : 'Non proposé à la location.',
                        ),
                        value: disponible,
                        onChanged: (value) =>
                            changerDisponibilite(context, doc.id, value),
                      ),
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
