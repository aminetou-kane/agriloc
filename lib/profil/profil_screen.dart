import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _villeController = TextEditingController();

  bool _chargement = true;
  bool _enregistrement = false;
  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    chargerProfil();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _villeController.dispose();
    super.dispose();
  }

  Future<void> chargerProfil() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _chargement = false);
        return;
      }

      _email = user.email ?? '';
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = document.data() ?? {};
      _nomController.text = data['nom']?.toString() ?? user.displayName ?? '';
      _telephoneController.text = data['telephone']?.toString() ?? '';
      _villeController.text = data['ville']?.toString() ?? '';
      _role = data['role']?.toString() ?? '';

      if (mounted) setState(() => _chargement = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _message('Erreur lors du chargement du profil.');
    }
  }

  Future<void> enregistrerProfil() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Vous devez être connecté.');
      return;
    }

    setState(() => _enregistrement = true);
    try {
      final nom = _nomController.text.trim();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nom': nom,
        'telephone': _telephoneController.text.trim(),
        'ville': _villeController.text.trim(),
        'email': user.email ?? '',
        'role': _role,
      }, SetOptions(merge: true));

      await user.updateDisplayName(nom);

      if (mounted) _message('Profil enregistré avec succès !');
    } on FirebaseException catch (e) {
      if (mounted) _message('Erreur Firebase : ${e.message ?? e.code}');
    } catch (e) {
      if (mounted) _message('Erreur : $e');
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _deconnexion() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _texteRole => switch (_role) {
    'agriculteur' => 'Agriculteur',
    'proprietaire' => 'Propriétaire',
    _ => 'Utilisateur',
  };

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 550),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.green,
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Mon profil',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Chip(
                          avatar: const Icon(Icons.badge, size: 18),
                          label: Text(_texteRole),
                        ),
                        const SizedBox(height: 25),
                        TextFormField(
                          controller: _nomController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Veuillez entrer votre nom.'
                              : null,
                        ),
                        const SizedBox(height: 15),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Adresse email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          child: Text(
                            _email.isEmpty ? 'Non renseigné' : _email,
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _telephoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Veuillez entrer votre numéro.'
                              : null,
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _villeController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Ville',
                            prefixIcon: Icon(Icons.location_city),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Veuillez entrer votre ville.'
                              : null,
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _enregistrement
                                ? null
                                : enregistrerProfil,
                            icon: _enregistrement
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _enregistrement
                                  ? 'Enregistrement...'
                                  : 'Enregistrer les modifications',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _enregistrement ? null : _deconnexion,
                            icon: const Icon(Icons.logout),
                            label: const Text('Se déconnecter'),
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
