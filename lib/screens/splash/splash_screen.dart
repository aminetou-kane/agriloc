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
      body: SizedBox.expand(
        child: Image.asset(
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
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.agriculture, size: 90, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'AgriLoc',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le matériel agricole à portée de main.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 28),
                  CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
