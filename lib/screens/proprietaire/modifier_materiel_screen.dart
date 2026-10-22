import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/constantes.dart';
import '../../widgets/photos_materiel.dart';

class ModifierMaterielScreen extends StatefulWidget {
  final String materielId;
  final Map<String, dynamic> materiel;

  const ModifierMaterielScreen({
    super.key,
    required this.materielId,
    required this.materiel,
  });

  @override
  State<ModifierMaterielScreen> createState() => _ModifierMaterielScreenState();
}

class _ModifierMaterielScreenState extends State<ModifierMaterielScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _montantController;
  late final TextEditingController _nombreSacsController;
  late final TextEditingController _localisationController;

  String? _typeMateriel;
  String _modePaiement = 'argent';

  bool _disponible = true;
  List<String> _photos = [];
  bool _chargement = false;

  static const _types = typesMateriel;

  @override
  void initState() {
    super.initState();

    _nomController = TextEditingController(
      text: widget.materiel['nom']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.materiel['description']?.toString() ?? '',
    );

    _montantController = TextEditingController(
      text:
          widget.materiel['montant']?.toString() ??
          widget.materiel['prix']?.toString() ??
          '',
    );

    _nombreSacsController = TextEditingController(
      text: widget.materiel['nombreSacs']?.toString() ?? '',
    );

    _localisationController = TextEditingController(
      text: widget.materiel['localisation']?.toString() ?? '',
    );

    final type = widget.materiel['type']?.toString();

    _typeMateriel = _types.contains(type) ? type : null;

    final mode = widget.materiel['modePaiement']?.toString();

    if (mode == 'argent' || mode == 'riz' || mode == 'negociation') {
      _modePaiement = mode!;
    } else {
      // Compatibilité avec les anciens matériels
      // qui utilisaient encore le champ "prix".
      _modePaiement = 'argent';
    }

    _disponible = widget.materiel['disponible'] != false;
    _photos = photosDe(widget.materiel);
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _montantController.dispose();
    _nombreSacsController.dispose();
    _localisationController.dispose();
    super.dispose();
  }

  Future<void> modifierMateriel() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Vous devez être connecté.');
      return;
    }

    double? montant;
    int? nombreSacs;

    // Paiement en argent
    if (_modePaiement == 'argent') {
      montant = double.tryParse(_montantController.text.trim());

      if (montant == null || montant <= 0) {
        _message('Veuillez entrer un montant valide.');
        return;
      }
    }

    // Paiement en sacs de riz
    if (_modePaiement == 'riz') {
      nombreSacs = int.tryParse(_nombreSacsController.text.trim());

      if (nombreSacs == null || nombreSacs <= 0) {
        _message('Veuillez entrer un nombre de sacs valide.');
        return;
      }
    }

    setState(() => _chargement = true);

    try {
      final Map<String, dynamic> donnees = {
        'nom': _nomController.text.trim(),
        'type': _typeMateriel,
        'description': _descriptionController.text.trim(),
        'modePaiement': _modePaiement,
        'localisation': _localisationController.text.trim(),
        'disponible': _disponible,
        'photos': _photos,
        'dateModification': FieldValue.serverTimestamp(),
      };

      // Paiement en argent
      if (_modePaiement == 'argent') {
        donnees['montant'] = montant;

        // On supprime les anciennes informations concernant le riz
        donnees['nombreSacs'] = FieldValue.delete();
      }

      // Paiement en sacs de riz
      if (_modePaiement == 'riz') {
        donnees['nombreSacs'] = nombreSacs;

        // On supprime l'ancien montant
        donnees['montant'] = FieldValue.delete();
      }

      // Paiement à négocier
      if (_modePaiement == 'negociation') {
        donnees['montant'] = FieldValue.delete();
        donnees['nombreSacs'] = FieldValue.delete();
      }

      // Suppression de l'ancien champ "prix"
      // pour ne plus utiliser "prix par jour".
      donnees['prix'] = FieldValue.delete();

      await FirebaseFirestore.instance
          .collection('materiels')
          .doc(widget.materielId)
          .update(donnees);

      if (!mounted) return;

      _message('Matériel modifié avec succès !');

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (mounted) {
        _message('Erreur Firebase : ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) {
        _message('Erreur : $e');
      }
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le matériel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.edit, size: 70, color: Colors.green),

                  const SizedBox(height: 15),

                  const Text(
                    'Modifier le matériel',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 28),

                  // NOM
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du matériel',
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Veuillez entrer le nom du matériel.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // TYPE
                  DropdownButtonFormField<String>(
                    initialValue: _typeMateriel,
                    decoration: const InputDecoration(
                      labelText: 'Type de matériel',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _types
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: _chargement
                        ? null
                        : (value) {
                            setState(() {
                              _typeMateriel = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez choisir un type.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // DESCRIPTION
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Veuillez entrer une description.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // MODE DE PAIEMENT
                  DropdownButtonFormField<String>(
                    initialValue: _modePaiement,
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      prefixIcon: Icon(Icons.payments),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'argent',
                        child: Text('💵 Argent (FCFA)'),
                      ),
                      DropdownMenuItem(
                        value: 'riz',
                        child: Text('🌾 Sacs de riz'),
                      ),
                      DropdownMenuItem(
                        value: 'negociation',
                        child: Text('🤝 À négocier'),
                      ),
                    ],
                    onChanged: _chargement
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _modePaiement = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez choisir un mode de paiement.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // MONTANT EN FCFA
                  if (_modePaiement == 'argent')
                    TextFormField(
                      controller: _montantController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Montant de la location',
                        hintText: 'Exemple : 15000',
                        suffixText: 'FCFA',
                        prefixIcon: Icon(Icons.money),
                      ),
                      validator: (v) {
                        if (_modePaiement != 'argent') {
                          return null;
                        }

                        final montant = double.tryParse(v?.trim() ?? '');

                        if (montant == null || montant <= 0) {
                          return 'Veuillez entrer un montant valide.';
                        }

                        return null;
                      },
                    ),

                  // NOMBRE DE SACS
                  if (_modePaiement == 'riz')
                    TextFormField(
                      controller: _nombreSacsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de sacs de riz',
                        hintText: 'Exemple : 3',
                        suffixText: 'sacs',
                        prefixIcon: Icon(Icons.grain),
                      ),
                      validator: (v) {
                        if (_modePaiement != 'riz') {
                          return null;
                        }

                        final sacs = int.tryParse(v?.trim() ?? '');

                        if (sacs == null || sacs <= 0) {
                          return 'Veuillez entrer un nombre de sacs valide.';
                        }

                        return null;
                      },
                    ),

                  // NÉGOCIATION
                  if (_modePaiement == 'negociation')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.handshake, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Le prix sera négocié entre le propriétaire et l’agriculteur.',
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 15),

                  // LOCALISATION
                  TextFormField(
                    controller: _localisationController,
                    decoration: const InputDecoration(
                      labelText: 'Localisation',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Veuillez entrer la localisation.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // DISPONIBILITÉ
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Matériel disponible'),
                    subtitle: Text(
                      _disponible
                          ? 'Visible par les agriculteurs.'
                          : 'Masqué des matériels disponibles.',
                    ),
                    value: _disponible,
                    onChanged: _chargement
                        ? null
                        : (value) {
                            setState(() {
                              _disponible = value;
                            });
                          },
                  ),

                  const SizedBox(height: 20),

                  SelecteurPhotos(
                    photos: _photos,
                    desactive: _chargement,
                    onChanged: (p) => setState(() => _photos = p),
                  ),

                  const SizedBox(height: 25),

                  // BOUTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _chargement ? null : modifierMateriel,
                      icon: _chargement
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _chargement
                            ? 'Modification...'
                            : 'Enregistrer les modifications',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
