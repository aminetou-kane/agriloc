import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/rappel_service.dart';
import '../auth/login_screen.dart';
import '../admin/admin_home_screen.dart';
import '../agriculteur/agriculteur_home_screen.dart';
import '../proprietaire/proprietaire_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _continuer);
  }

  Future<void> _continuer() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _ouvrir(const LoginScreen());
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profil = doc.data() ?? <String, dynamic>{};
      final role = profil['role']?.toString();

      if (profil['bloque'] == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _ouvrir(const LoginScreen());
        return;
      }
      if (!mounted) return;

      if (role == 'agriculteur' || role == 'proprietaire') {
        // Rappels avant la date de location (sans bloquer l'ouverture).
        RappelService.verifier().catchError((_) {});
      }

      if (role == 'admin') {
        _ouvrir(const AdminHomeScreen());
      } else if (role == 'agriculteur') {
        _ouvrir(const AgriculteurHomeScreen());
      } else if (role == 'proprietaire') {
        _ouvrir(const ProprietaireHomeScreen());
      } else {
        await FirebaseAuth.instance.signOut();
        if (mounted) _ouvrir(const LoginScreen());
      }
    } catch (_) {
      if (mounted) _ouvrir(const LoginScreen());
    }
  }

  void _ouvrir(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image d'ouverture (assets/images/agriloc_splash.png)
          Image.asset(
            'assets/images/agriloc_splash.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF14532D), Color(0xFF65A30D)],
                ),
              ),
            ),
          ),
          // Voile sombre pour que le texte reste lisible
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0xCC0B3D1E)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      size: 70,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Agri',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Loc',
                          style: TextStyle(color: Color(0xFFFFA726)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Le matériel agricole à portée de main.',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
