import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _motDePasseController = TextEditingController();
  String? _role;
  bool _chargement = false;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> creerCompte() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      _message('Veuillez choisir votre rôle.');
      return;
    }

    setState(() => _chargement = true);
    User? user;

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _motDePasseController.text,
          );
      user = credential.user;
      if (user == null) throw Exception('Utilisateur non créé.');

      await user.updateDisplayName(_nomController.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nom': _nomController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role,
        'ville': '',
        'dateCreation': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _message('Compte créé avec succès. Connectez-vous maintenant.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'Cette adresse email est déjà utilisée.',
        'invalid-email' => 'Cette adresse email n’est pas valide.',
        'weak-password' =>
          'Le mot de passe doit contenir au moins 6 caractères.',
        'operation-not-allowed' =>
          'La création de compte par email n’est pas activée.',
        _ => 'Une erreur est survenue. Veuillez réessayer.',
      };
      _message(message);
    } on FirebaseException catch (e) {
      if (user != null) await FirebaseAuth.instance.signOut();
      if (mounted) _message('Erreur Firebase : ${e.message ?? e.code}');
    } catch (e) {
      if (user != null) await FirebaseAuth.instance.signOut();
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.agriculture, size: 70, color: Colors.green),
                  const SizedBox(height: 15),
                  const Text(
                    'Créer un compte AgriLoc',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nomController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Veuillez entrer votre nom.'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _telephoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Veuillez entrer votre téléphone.'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Veuillez entrer votre email.';
                      if (!email.contains('@'))
                        return 'Veuillez entrer un email valide.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _motDePasseController,
                    obscureText: !_motDePasseVisible,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _motDePasseVisible = !_motDePasseVisible,
                        ),
                        icon: Icon(
                          _motDePasseVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Le mot de passe doit avoir au moins 6 caractères.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choisissez votre rôle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioListTile<String>(
                    title: const Text('👨‍🌾 Agriculteur'),
                    value: 'agriculteur',
                    groupValue: _role,
                    onChanged: _chargement
                        ? null
                        : (value) => setState(() => _role = value),
                  ),
                  RadioListTile<String>(
                    title: const Text('🚜 Propriétaire de matériel'),
                    value: 'proprietaire',
                    groupValue: _role,
                    onChanged: _chargement
                        ? null
                        : (value) => setState(() => _role = value),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _chargement ? null : creerCompte,
                      icon: _chargement
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: Text(
                        _chargement ? 'Création...' : 'Créer mon compte',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _chargement
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Déjà un compte ? Se connecter'),
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
