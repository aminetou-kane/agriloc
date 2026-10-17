import 'package:flutter/material.dart';

import 'materiels_disponibles_screen.dart';

/// Ancien nom d’écran conservé pour éviter de casser d’éventuels imports.
/// L’application utilise maintenant les données Firestore réelles.
class MaterielsScreen extends StatelessWidget {
  const MaterielsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterielsDisponiblesScreen();
  }
}
