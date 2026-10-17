import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profil/profil_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../signalements/signalement_screen.dart';
import 'ajouter_materiel_screen.dart';
import 'demandes_location_screen.dart';
import 'materiels_screen.dart';

class ProprietaireHomeScreen extends StatelessWidget {
  const ProprietaireHomeScreen({super.key});

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

  Widget _tableauDeBord() {
    final utilisateur = FirebaseAuth.instance.currentUser;

    if (utilisateur == null) {
      return const Text('Connectez-vous pour consulter vos statistiques.');
    }

    final uid = utilisateur.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('materiels')
          .where('proprietaireId', isEqualTo: uid)
          .snapshots(),
      builder: (context, materielsSnapshot) {
        if (materielsSnapshot.hasError) {
          return const Text(
            'Impossible de charger les statistiques des matériels.',
          );
        }

        if (!materielsSnapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final materiels = materielsSnapshot.data!.docs;

        final totalMateriels = materiels.length;

        final materielsDisponibles = materiels.where((doc) {
          return doc.data()['disponible'] == true;
        }).length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('demandes')
              .where('proprietaireId', isEqualTo: uid)
              .snapshots(),
          builder: (context, demandesSnapshot) {
            if (demandesSnapshot.hasError) {
              return const Text(
                'Impossible de charger les statistiques des locations.',
              );
            }

            if (!demandesSnapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final demandes = demandesSnapshot.data!.docs;

            final demandesEnAttente = demandes.where((doc) {
              return doc.data()['statut'] == 'en_attente';
            }).length;

            final locationsTerminees = demandes.where((doc) {
              return doc.data()['statut'] == 'terminee';
            }).length;

            final materielsEnLocation = demandes
                .where((doc) => doc.data()['statut'] == 'acceptee')
                .map((doc) => doc.data()['materielId'])
                .whereType<String>()
                .toSet()
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mon activité',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Suivez vos matériels et vos locations en temps réel.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _statCard(
                      icon: Icons.agriculture,
                      titre: 'Total matériels',
                      valeur: totalMateriels,
                      couleur: Colors.blue,
                    ),
                    _statCard(
                      icon: Icons.check_circle,
                      titre: 'Disponibles',
                      valeur: materielsDisponibles,
                      couleur: Colors.green,
                    ),
                    _statCard(
                      icon: Icons.handyman,
                      titre: 'En location',
                      valeur: materielsEnLocation,
                      couleur: Colors.orange,
                    ),
                    _statCard(
                      icon: Icons.mark_email_unread,
                      titre: 'En attente',
                      valeur: demandesEnAttente,
                      couleur: Colors.deepOrange,
                    ),
                    _statCard(
                      icon: Icons.task_alt,
                      titre: 'Terminées',
                      valeur: locationsTerminees,
                      couleur: Colors.teal,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String titre,
    required int valeur,
    required Color couleur,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 29, color: couleur),
            const SizedBox(height: 8),
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
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
              'Espace Propriétaire',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Gérez vos matériels agricoles et vos locations.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 25),

            // Tableau de bord avec statistiques Firebase
            _tableauDeBord(),

            const SizedBox(height: 30),

            _menuCard(
              context,
              icon: Icons.add_circle,
              title: 'Ajouter un matériel',
              subtitle:
                  'Ajoutez un tracteur, une machine ou un autre équipement.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AjouterMaterielScreen(),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.agriculture,
              title: 'Mes matériels',
              subtitle: 'Consultez, modifiez et gérez vos équipements.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MaterielsScreen()),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.assignment,
              title: 'Demandes de location',
              subtitle: 'Acceptez ou refusez les demandes des agriculteurs.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DemandesLocationScreen(),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _menuCard(
              context,
              icon: Icons.notifications_active,
              title: 'Mes notifications',
              subtitle: 'Consultez les nouvelles demandes et mises à jour.',
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
