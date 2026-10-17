import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../agriculteur/agriculteur_home_screen.dart';
import '../admin/admin_home_screen.dart';
import '../proprietaire/proprietaire_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _motDePasseController = TextEditingController();
  bool _chargement = false;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> seConnecter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _chargement = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _motDePasseController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Utilisateur introuvable.');

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Profil utilisateur introuvable dans Firestore.');
      }

      final profil = document.data() ?? <String, dynamic>{};
      final role = profil['role']?.toString();
      if (profil['bloque'] == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _message('Ce compte a été bloqué par l’administrateur.');
        return;
      }
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
          (_) => false,
        );
      } else if (role == 'agriculteur') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AgriculteurHomeScreen()),
          (_) => false,
        );
      } else if (role == 'proprietaire') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProprietaireHomeScreen()),
          (_) => false,
        );
      } else {
        await FirebaseAuth.instance.signOut();
        _message('Rôle utilisateur inconnu.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'user-not-found' => 'Aucun compte trouvé avec cette adresse email.',
        'wrong-password' ||
        'invalid-credential' => 'Email ou mot de passe incorrect.',
        'invalid-email' => 'Adresse email invalide.',
        'user-disabled' => 'Ce compte a été désactivé.',
        'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
        _ => 'Une erreur est survenue lors de la connexion.',
      };
      _message(message);
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> motDePasseOublie() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _message('Entrez votre adresse email pour recevoir le lien.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted)
        _message('Un lien de réinitialisation a été envoyé à votre email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _message(
        e.code == 'user-not-found'
            ? 'Aucun compte associé à cette adresse email.'
            : 'Impossible d’envoyer le lien de réinitialisation.',
      );
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
      appBar: AppBar(title: const Text('Connexion')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.agriculture, size: 80, color: Colors.green),
                  const SizedBox(height: 18),
                  const Text(
                    'Bienvenue sur AgriLoc',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Veuillez entrer votre email.';
                      if (!email.contains('@')) return 'Email invalide.';
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
                    validator: (value) => value == null || value.isEmpty
                        ? 'Veuillez entrer votre mot de passe.'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _chargement ? null : motDePasseOublie,
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _chargement ? null : seConnecter,
                      icon: _chargement
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _chargement ? 'Connexion...' : 'Se connecter',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _chargement
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                    child: const Text('Pas encore de compte ? S’inscrire'),
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
