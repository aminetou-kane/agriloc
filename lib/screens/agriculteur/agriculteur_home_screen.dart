import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profil/profil_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../signalements/signalement_screen.dart';
import 'materiels_disponibles_screen.dart';
import 'mes_demandes_screen.dart';

class AgriculteurHomeScreen extends StatelessWidget {
  const AgriculteurHomeScreen({super.key});

  Future<void> _deconnexion(BuildContext context) async {
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
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriLoc'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => _deconnexion(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bonjour 👋', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            const Text(
              'Espace Agriculteur',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Trouvez facilement le matériel agricole dont vous avez besoin.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            _menuCard(
              context,
              icon: Icons.search,
              title: 'Rechercher du matériel',
              subtitle:
                  'Recherchez un équipement par nom, type ou localisation.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaterielsDisponiblesScreen(),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.assignment,
              title: 'Mes demandes',
              subtitle: 'Consultez l’état de vos demandes de location.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MesDemandesScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.notifications_active,
              title: 'Mes notifications',
              subtitle:
                  'Consultez les nouvelles demandes et réponses du propriétaire.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.flag,
              title: 'Signaler un problème',
              subtitle: 'Transmettez un problème à l’administrateur.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignalementScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.person,
              title: 'Mon profil',
              subtitle: 'Consultez et modifiez vos informations personnelles.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 35, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}
