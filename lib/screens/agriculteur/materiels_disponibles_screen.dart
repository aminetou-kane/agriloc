import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../utils/constantes.dart';
import '../../utils/periode.dart';

class MaterielsDisponiblesScreen extends StatefulWidget {
  const MaterielsDisponiblesScreen({super.key});

  @override
  State<MaterielsDisponiblesScreen> createState() =>
      _MaterielsDisponiblesScreenState();
}

class _MaterielsDisponiblesScreenState
    extends State<MaterielsDisponiblesScreen> {
  final _rechercheController = TextEditingController();

  String _recherche = '';
  String? _typeFiltre;
  bool _prixFiltreSeulementArgent = false;
  bool _demandeEnCours = false;
  String? _nouvelleDemandeId;

  @override
  void initState() {
    super.initState();

    _rechercheController.addListener(() {
      setState(() {
        _recherche = _rechercheController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> demanderLocation(
    BuildContext context,
    String materielId,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Vous devez être connecté.');
      return;
    }

    if (data['proprietaireId']?.toString() == user.uid) {
      _message('Vous ne pouvez pas louer votre propre matériel.');
      return;
    }

    final aujourdhui = jourSeul(DateTime.now());
    final periode = await showDateRangePicker(
      context: context,
      firstDate: aujourdhui,
      lastDate: aujourdhui.add(const Duration(days: 365)),
      helpText: 'Choisissez la période de location',
      saveText: 'Valider',
      cancelText: 'Annuler',
    );
    if (periode == null) return;
    final debut = jourSeul(periode.start);
    final fin = jourSeul(periode.end);

    setState(() => _demandeEnCours = true);

    try {
      _nouvelleDemandeId = null;

      // Le calendrier du matériel : refuser une période déjà réservée.
      final reservations = await FirebaseFirestore.instance
          .collection('reservations')
          .where('materielId', isEqualTo: materielId)
          .get();
      for (final r in reservations.docs) {
        final d = r.data()['dateDebut'];
        final f = r.data()['dateFin'];
        if (d is Timestamp &&
            f is Timestamp &&
            periodesSeChevauchent(debut, fin, d.toDate(), f.toDate())) {
          _message(
            'Ce matériel est déjà réservé ${formaterPeriode(d.toDate(), f.toDate())}. '
            'Choisissez d’autres dates.',
          );
          return;
        }
      }

      final demandes = await FirebaseFirestore.instance
          .collection('demandes')
          .where('agriculteurId', isEqualTo: user.uid)
          .where('materielId', isEqualTo: materielId)
          .where('statut', isEqualTo: 'en_attente')
          .limit(1)
          .get();

      if (demandes.docs.isNotEmpty) {
        _message('Vous avez déjà une demande en attente pour ce matériel.');
        return;
      }

      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((transaction) async {
        final materielRef = firestore.collection('materiels').doc(materielId);

        final materielSnapshot = await transaction.get(materielRef);

        if (!materielSnapshot.exists) {
          throw Exception('Ce matériel n’existe plus.');
        }

        final materiel = materielSnapshot.data() ?? {};

        if (materiel['disponible'] != true) {
          throw Exception('Ce matériel n’est plus disponible.');
        }

        final requestRef = firestore.collection('demandes').doc();
        _nouvelleDemandeId = requestRef.id;

        final Map<String, dynamic> demande = {
          'agriculteurId': user.uid,
          'materielId': materielId,
          'proprietaireId':
              materiel['proprietaireId'] ?? data['proprietaireId'],
          'nomMateriel': materiel['nom'] ?? data['nom'] ?? '',
          'typeMateriel': materiel['type'] ?? data['type'] ?? '',
          'localisation':
              materiel['localisation'] ?? data['localisation'] ?? '',
          'statut': 'en_attente',
          'dateDebut': Timestamp.fromDate(debut),
          'dateFin': Timestamp.fromDate(fin),
          'dateDemande': FieldValue.serverTimestamp(),
        };

        // -----------------------------
        // INFORMATIONS DE PAIEMENT
        // -----------------------------

        final modePaiement = materiel['modePaiement'] ?? data['modePaiement'];

        if (modePaiement != null) {
          demande['modePaiement'] = modePaiement;
        }

        // Paiement en argent
        if (modePaiement == 'argent') {
          final montant = materiel['montant'] ?? data['montant'];

          if (montant != null) {
            demande['montant'] = montant;
          }
        }

        // Paiement en sacs de riz
        if (modePaiement == 'riz') {
          final nombreSacs = materiel['nombreSacs'] ?? data['nombreSacs'];

          if (nombreSacs != null) {
            demande['nombreSacs'] = nombreSacs;
          }
        }

        // Compatibilité avec les anciens matériels
        if (modePaiement == null) {
          final ancienPrix = materiel['prix'] ?? data['prix'];

          if (ancienPrix != null) {
            demande['prix'] = ancienPrix;
          }
        }

        transaction.set(requestRef, demande);
      });

      final proprietaireId = data['proprietaireId']?.toString() ?? '';
      if (proprietaireId.isNotEmpty && _nouvelleDemandeId != null) {
        try {
          await NotificationService.creer(
            destinataireId: proprietaireId,
            titre: 'Nouvelle demande de location',
            message:
                'Un agriculteur a demandé le matériel ${data['nom'] ?? 'agricole'} ${formaterPeriode(debut, fin)}.',
            type: 'nouvelle_demande',
            demandeId: _nouvelleDemandeId,
          );
        } catch (_) {
          // La demande est conservée même si la notification échoue.
        }
      }

      _message('Demande de location envoyée avec succès !');
    } on FirebaseException catch (e) {
      _message('Erreur Firebase : ${e.message ?? e.code}');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _demandeEnCours = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _correspond(Map<String, dynamic> data) {
    if (_typeFiltre != null && data['type']?.toString() != _typeFiltre) {
      return false;
    }
    if (_prixFiltreSeulementArgent && data['modePaiement'] == 'negociation') {
      return false;
    }
    if (_recherche.isEmpty) return true;

    final texte = [
      data['nom'],
      data['type'],
      data['localisation'],
      data['description'],
    ].whereType<Object>().join(' ').toLowerCase();

    return texte.contains(_recherche);
  }

  // ----------------------------------------
  // AFFICHAGE DES CONDITIONS DE PAIEMENT
  // ----------------------------------------

  Widget _conditionsPaiement(Map<String, dynamic> data) {
    final mode = data['modePaiement']?.toString();

    // Paiement en argent
    if (mode == 'argent') {
      final montant = data['montant'];

      if (montant is num) {
        final valeur = montant.toStringAsFixed(
          montant.truncateToDouble() == montant ? 0 : 2,
        );

        return Row(
          children: [
            const Icon(Icons.money, size: 21, color: Colors.green),
            const SizedBox(width: 7),
            Text(
              '$valeur FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        );
      }

      return const Row(
        children: [
          Icon(Icons.money, size: 21, color: Colors.green),
          SizedBox(width: 7),
          Text(
            'Paiement en argent',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    // Paiement en sacs de riz
    if (mode == 'riz') {
      final sacs = data['nombreSacs'];

      if (sacs is num) {
        final nombre = sacs.toInt();

        return Row(
          children: [
            const Icon(Icons.grain, size: 21, color: Colors.orange),
            const SizedBox(width: 7),
            Text(
              '$nombre sac${nombre > 1 ? 's' : ''} de riz',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        );
      }

      return const Row(
        children: [
          Icon(Icons.grain, size: 21, color: Colors.orange),
          SizedBox(width: 7),
          Text(
            'Paiement en sacs de riz',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    // Paiement à négocier
    if (mode == 'negociation') {
      return const Row(
        children: [
          Icon(Icons.handshake, size: 21, color: Colors.orange),
          SizedBox(width: 7),
          Text(
            'Prix à négocier',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          const Icon(Icons.money, size: 21, color: Colors.green),
          const SizedBox(width: 7),
          Text(
            '$valeur FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Matériels disponibles')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('materiels')
            .where('disponible', isEqualTo: true)
            .where('visible', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _etatErreur('Impossible de charger les matériels.');
          }

          final documents =
              snapshot.data?.docs
                  .where(
                    (doc) =>
                        doc.data()['visible'] != false &&
                        _correspond(doc.data()),
                  )
                  .toList() ??
              [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
                child: TextField(
                  controller: _rechercheController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un matériel...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _recherche.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _rechercheController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),

              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Prix fixe uniquement'),
                        selected: _prixFiltreSeulementArgent,
                        onSelected: (v) =>
                            setState(() => _prixFiltreSeulementArgent = v),
                      ),
                    ),
                    for (final t in typesMateriel)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t),
                          selected: _typeFiltre == t,
                          onSelected: (v) =>
                              setState(() => _typeFiltre = v ? t : null),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: documents.isEmpty
                    ? _etatVide(
                        _recherche.isEmpty
                            ? 'Aucun matériel disponible'
                            : 'Aucun résultat',
                        _recherche.isEmpty
                            ? 'Aucun matériel n’est actuellement disponible à la location.'
                            : 'Essayez un autre nom, type ou localisation.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final document = documents[index];

                          final data = document.data();

                          final nom =
                              data['nom']?.toString() ?? 'Matériel sans nom';

                          final type =
                              data['type']?.toString() ?? 'Type inconnu';

                          final description =
                              data['description']?.toString() ?? '';

                          final localisation =
                              data['localisation']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 15),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.agriculture,
                                        size: 45,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Text(
                                          nom,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('avis')
                                        .where(
                                          'materielId',
                                          isEqualTo: document.id,
                                        )
                                        .snapshots(),
                                    builder: (context, avisSnapshot) {
                                      final avisDocs =
                                          avisSnapshot.data?.docs ?? [];
                                      if (avisDocs.isEmpty) {
                                        return const Row(
                                          children: [
                                            Icon(
                                              Icons.star_border,
                                              size: 18,
                                              color: Colors.amber,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'Pas encore d’avis',
                                              style: TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      final notes = avisDocs
                                          .map((a) => a.data()['note'])
                                          .whereType<num>()
                                          .toList();
                                      if (notes.isEmpty) {
                                        return const Text(
                                          'Pas encore de note.',
                                        );
                                      }
                                      final moyenne =
                                          notes.fold<double>(
                                            0,
                                            (total, note) =>
                                                total + note.toDouble(),
                                          ) /
                                          notes.length;
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 18,
                                            color: Colors.amber.shade700,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${moyenne.toStringAsFixed(1)} / 5 (${notes.length} avis)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 8),

                                  Text('Type : $type'),

                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Text('Description : $description'),
                                  ],

                                  if (localisation.isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 20,
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

                                  const SizedBox(height: 12),

                                  _periodesReservees(document.id),

                                  // DISPONIBLE
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Disponible',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 15),

                                  // DEMANDE
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _demandeEnCours
                                          ? null
                                          : () => demanderLocation(
                                              context,
                                              document.id,
                                              data,
                                            ),
                                      icon: const Icon(Icons.assignment),
                                      label: const Text('Demander la location'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Calendrier : périodes déjà réservées pour ce matériel.
  Widget _periodesReservees(String materielId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('materielId', isEqualTo: materielId)
          .snapshots(),
      builder: (context, snapshot) {
        final periodes = <(DateTime, DateTime)>[];
        for (final r in snapshot.data?.docs ?? const []) {
          final d = r.data()['dateDebut'];
          final f = r.data()['dateFin'];
          if (d is Timestamp && f is Timestamp && !f.toDate().isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
            periodes.add((d.toDate(), f.toDate()));
          }
        }
        if (periodes.isEmpty) return const SizedBox.shrink();
        periodes.sort((a, b) => a.$1.compareTo(b.$1));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_busy, size: 20, color: Colors.redAccent),
                  SizedBox(width: 6),
                  Text(
                    'Déjà réservé :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              for (final p in periodes)
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 2),
                  child: Text(formaterPeriode(p.$1, p.$2)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _etatVide(String titre, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.agriculture, size: 75, color: Colors.grey),
            const SizedBox(height: 18),
            Text(
              titre,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _etatErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 65, color: Colors.red),
            const SizedBox(height: 15),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
