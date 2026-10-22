import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../utils/periode.dart';

class DemandesLocationScreen extends StatelessWidget {
  const DemandesLocationScreen({super.key});

  Future<void> changerStatut(
    BuildContext context,
    String demandeId,
    String nouveauStatut,
    String materielId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message(context, 'Vous devez être connecté.');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final demandeRef = firestore.collection('demandes').doc(demandeId);
      final reservationRef = firestore.collection('reservations').doc(demandeId);

      // Période demandée (absente sur les anciennes demandes).
      DateTime? debut;
      DateTime? fin;

      // Calendrier : on vérifie qu'aucune réservation acceptée ne chevauche
      // la période demandée avant d'accepter.
      if (nouveauStatut == 'acceptee') {
        final snap = await demandeRef.get();
        final d = snap.data()?['dateDebut'];
        final f = snap.data()?['dateFin'];
        if (d is Timestamp && f is Timestamp) {
          debut = d.toDate();
          fin = f.toDate();
          final reservations = await firestore
              .collection('reservations')
              .where('materielId', isEqualTo: materielId)
              .where('proprietaireId', isEqualTo: user.uid)
              .get();
          for (final r in reservations.docs) {
            final rd = r.data()['dateDebut'];
            final rf = r.data()['dateFin'];
            if (rd is Timestamp &&
                rf is Timestamp &&
                periodesSeChevauchent(debut, fin, rd.toDate(), rf.toDate())) {
              throw Exception(
                'Cette période chevauche une location déjà acceptée '
                '(${formaterPeriode(rd.toDate(), rf.toDate())}).',
              );
            }
          }
        }
      }

      await firestore.runTransaction((transaction) async {
        final demandeSnapshot = await transaction.get(demandeRef);

        if (!demandeSnapshot.exists) {
          throw Exception('Demande introuvable.');
        }

        final demande = demandeSnapshot.data() as Map<String, dynamic>;

        if (demande['proprietaireId'] != user.uid) {
          throw Exception('Vous n’êtes pas autorisé à modifier cette demande.');
        }

        final statutActuel = demande['statut']?.toString() ?? 'en_attente';

        if (nouveauStatut == 'acceptee') {
          if (statutActuel != 'en_attente') {
            throw Exception('Cette demande a déjà été traitée.');
          }

          transaction.update(demandeRef, {
            'statut': 'acceptee',
            'dateModification': FieldValue.serverTimestamp(),
          });

          // Réservation visible de tous : alimente le calendrier du matériel.
          if (debut != null && fin != null) {
            transaction.set(reservationRef, {
              'demandeId': demandeId,
              'materielId': materielId,
              'proprietaireId': user.uid,
              'agriculteurId': demande['agriculteurId'],
              'nomMateriel': demande['nomMateriel'] ?? '',
              'dateDebut': Timestamp.fromDate(debut!),
              'dateFin': Timestamp.fromDate(fin!),
              'dateCreation': FieldValue.serverTimestamp(),
            });
          }
        } else if (nouveauStatut == 'refusee') {
          if (statutActuel != 'en_attente') {
            throw Exception('Cette demande a déjà été traitée.');
          }

          transaction.update(demandeRef, {
            'statut': 'refusee',
            'dateModification': FieldValue.serverTimestamp(),
          });
        } else if (nouveauStatut == 'terminee') {
          if (statutActuel != 'acceptee') {
            throw Exception('Cette location ne peut pas être terminée.');
          }

          transaction.update(demandeRef, {
            'statut': 'terminee',
            'dateModification': FieldValue.serverTimestamp(),
          });
          // Les dates se libèrent dans le calendrier du matériel.
          transaction.delete(reservationRef);
        } else {
          throw Exception('Statut de demande invalide.');
        }
      });

      // Après une acceptation, les autres demandes en attente dont la période
      // chevauche celle-ci sont refusées. Une erreur ici ne doit pas faire
      // croire que l'acceptation a échoué (déjà enregistrée).
      if (nouveauStatut == 'acceptee' && debut != null && fin != null) {
        try {
          final autres = await firestore
              .collection('demandes')
              .where('proprietaireId', isEqualTo: user.uid)
              .where('materielId', isEqualTo: materielId)
              .where('statut', isEqualTo: 'en_attente')
              .get();

          final conflits = autres.docs.where((doc) {
            final d = doc.data()['dateDebut'];
            final f = doc.data()['dateFin'];
            return d is Timestamp &&
                f is Timestamp &&
                periodesSeChevauchent(debut!, fin!, d.toDate(), f.toDate());
          }).toList();

          if (conflits.isNotEmpty) {
            final batch = firestore.batch();
            for (final doc in conflits) {
              batch.update(doc.reference, {
                'statut': 'refusee',
                'dateModification': FieldValue.serverTimestamp(),
                'motif': 'Ces dates sont déjà réservées par un autre agriculteur.',
              });
            }
            await batch.commit();

            for (final doc in conflits) {
              final agriculteurId = doc.data()['agriculteurId']?.toString() ?? '';
              if (agriculteurId.isEmpty) continue;
              try {
                await NotificationService.creer(
                  destinataireId: agriculteurId,
                  titre: 'Demande refusée',
                  message:
                      'Ces dates ont été réservées par un autre agriculteur. Vous pouvez choisir une autre période.',
                  type: 'refusee',
                  demandeId: doc.id,
                );
              } catch (_) {}
            }
          }
        } on FirebaseException catch (_) {}
      }

      try {
        final demandeActualisee = await demandeRef.get();
        final demandeData = demandeActualisee.data() ?? <String, dynamic>{};
        final agriculteurId = demandeData['agriculteurId']?.toString() ?? '';
        final (titreNotification, texteNotification) = switch (nouveauStatut) {
          'acceptee' => (
            'Demande acceptée',
            'Votre demande pour ${demandeData['nomMateriel'] ?? 'le matériel'} a été acceptée.',
          ),
          'refusee' => (
            'Demande refusée',
            'Votre demande pour ${demandeData['nomMateriel'] ?? 'le matériel'} a été refusée.',
          ),
          _ => (
            'Location terminée',
            'La location de ${demandeData['nomMateriel'] ?? 'votre matériel'} est terminée. Vous pouvez maintenant laisser un avis.',
          ),
        };
        await NotificationService.creer(
          destinataireId: agriculteurId,
          titre: titreNotification,
          message: texteNotification,
          type: nouveauStatut,
          demandeId: demandeId,
        );
      } catch (_) {
        // La modification du statut reste valide si la notification échoue.
      }

      if (!context.mounted) return;

      String message;

      if (nouveauStatut == 'acceptee') {
        message = 'Demande acceptée. Les dates sont réservées dans le calendrier.';
      } else if (nouveauStatut == 'refusee') {
        message = 'Demande refusée.';
      } else {
        message = 'Location terminée. Les dates sont libérées.';
      }

      _message(context, message);
    } on FirebaseException catch (e) {
      if (context.mounted) {
        _message(context, 'Erreur Firebase : ${e.message ?? e.code}');
      }
    } catch (e) {
      if (context.mounted) {
        _message(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  static void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===========================================================
  // CONDITIONS DE PAIEMENT
  // ===========================================================

  String _conditionsPaiement(Map<String, dynamic> data) {
    final mode = data['modePaiement']?.toString();

    // Paiement en argent
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

    // Paiement en sacs de riz
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

    // Paiement négocié
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

  // ===========================================================
  // DATE
  // ===========================================================

  String _date(Object? value) {
    if (value is! Timestamp) {
      return 'Date non disponible';
    }

    final d = value.toDate();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} à '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ===========================================================
  // TEXTE DU STATUT
  // ===========================================================

  String _texteStatut(String statut) {
    switch (statut) {
      case 'acceptee':
        return 'En location';

      case 'refusee':
        return 'Refusée';

      case 'terminee':
        return 'Terminée';

      default:
        return 'En attente';
    }
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'acceptee':
        return Colors.green;

      case 'refusee':
        return Colors.red;

      case 'terminee':
        return Colors.blue;

      default:
        return Colors.orange;
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'acceptee':
        return Icons.agriculture;

      case 'refusee':
        return Icons.cancel;

      case 'terminee':
        return Icons.check_circle;

      default:
        return Icons.hourglass_top;
    }
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
      appBar: AppBar(title: const Text('Demandes de location')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('demandes')
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
                child: Text('Impossible de charger les demandes.'),
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
                      'Vous n’avez reçu aucune demande de location.',
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

              final nom =
                  data['nomMateriel']?.toString() ?? 'Matériel sans nom';

              final type = data['typeMateriel']?.toString() ?? 'Type inconnu';

              final localisation = data['localisation']?.toString() ?? '';

              final statut = data['statut']?.toString() ?? 'en_attente';

              final materielId = data['materielId']?.toString();

              final attente = statut == 'en_attente';

              final enLocation = statut == 'acceptee';

              final couleur = _couleurStatut(statut);

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =================================================
                      // MATÉRIEL
                      // =================================================
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

                      Text('Type : $type'),

                      // =================================================
                      // LOCALISATION
                      // =================================================
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

                      // =================================================
                      // PAIEMENT
                      // =================================================
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

                      if (data['dateDebut'] is Timestamp &&
                          data['dateFin'] is Timestamp) ...[
                        Row(
                          children: [
                            const Icon(Icons.event, size: 20, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Location ${formaterPeriode((data['dateDebut'] as Timestamp).toDate(), (data['dateFin'] as Timestamp).toDate())}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                      ],

                      // =================================================
                      // DATE
                      // =================================================
                      Text(
                        'Demandée le : '
                        '${_date(data['dateDemande'])}',
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 12),

                      // =================================================
                      // STATUT
                      // =================================================
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
                          ],
                        ),
                      ),

                      // =================================================
                      // BOUTONS EN ATTENTE
                      // =================================================
                      if (attente) ...[
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: materielId == null
                                    ? null
                                    : () => changerStatut(
                                        context,
                                        doc.id,
                                        'acceptee',
                                        materielId,
                                      ),
                                icon: const Icon(Icons.check),
                                label: const Text('Accepter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: materielId == null
                                    ? null
                                    : () => changerStatut(
                                        context,
                                        doc.id,
                                        'refusee',
                                        materielId,
                                      ),
                                icon: const Icon(Icons.close),
                                label: const Text('Refuser'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // =================================================
                      // BOUTON TERMINER LA LOCATION
                      // =================================================
                      if (enLocation) ...[
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: materielId == null
                                ? null
                                : () => _confirmerFinLocation(
                                    context,
                                    doc.id,
                                    materielId,
                                  ),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Terminer la location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],

                      // =================================================
                      // ID MATÉRIEL MANQUANT
                      // =================================================
                      if ((attente || enLocation) && materielId == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Identifiant du matériel introuvable.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),

                      // =================================================
                      // MOTIF REFUS
                      // =================================================
                      if (statut == 'refusee' && data['motif'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Motif : ${data['motif']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      // =================================================
                      // MESSAGE LOCATION TERMINÉE
                      // =================================================
                      if (statut == 'terminee') ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Cette location est terminée. '
                          'Les dates seront libérées dans le calendrier.',
                          style: TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('avis')
                              .doc(doc.id)
                              .snapshots(),
                          builder: (context, avisSnapshot) {
                            if (avisSnapshot.hasError) {
                              return const Text(
                                'Impossible de charger l’avis pour le moment.',
                                style: TextStyle(color: Colors.grey),
                              );
                            }
                            if (!avisSnapshot.hasData ||
                                avisSnapshot.data?.exists != true) {
                              return const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.star_outline, color: Colors.grey),
                                title: Text('Aucun avis reçu pour cette location.'),
                              );
                            }
                            final avis = avisSnapshot.data!.data()!;
                            final note = avis['note']?.toString() ?? '-';
                            final commentaire =
                                avis['commentaire']?.toString().trim() ?? '';
                            return Card(
                              color: const Color(0xFFF1F8E9),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Avis de l’agriculteur',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber),
                                        const SizedBox(width: 5),
                                        Text('$note / 5',
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    if (commentaire.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(commentaire),
                                    ] else ...[
                                      const SizedBox(height: 5),
                                      const Text('Aucun commentaire écrit.'),
                                    ],
                                  ],
                                ),
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

  // =============================================================
  // CONFIRMATION AVANT DE TERMINER
  // =============================================================

  Future<void> _confirmerFinLocation(
    BuildContext context,
    String demandeId,
    String materielId,
  ) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Terminer la location'),
          content: const Text(
            'Voulez-vous confirmer que cette location est terminée ?\n\n'
            'Les dates seront libérées pour une nouvelle location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (confirmer != true) return;

    await changerStatut(context, demandeId, 'terminee', materielId);
  }
}
