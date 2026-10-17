import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/login_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<bool> _estAdmin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['role'] == 'admin';
  }

  Future<void> _deconnexion(BuildContext context) async {
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
    return FutureBuilder<bool>(
      future: _estAdmin(),
      builder: (context, auth) {
        if (auth.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Erreur lors de la vérification du compte.'),
            ),
          );
        }

        if (!auth.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Accès refusé')),
            body: const Center(
              child: Text('Cet espace est réservé à l’administrateur.'),
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Administration AgriLoc'),
              actions: [
                IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: () => _deconnexion(context),
                  icon: const Icon(Icons.logout),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
                  Tab(icon: Icon(Icons.agriculture), text: 'Matériels'),
                  Tab(icon: Icon(Icons.flag), text: 'Signalements'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _UtilisateursTab(),
                _MaterielsTab(),
                _SignalementsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================
// ONGLET UTILISATEURS
// ======================================================

class _UtilisateursTab extends StatelessWidget {
  const _UtilisateursTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erreur de lecture des utilisateurs. '
              'Vérifiez les règles Firestore.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('Aucun utilisateur.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final role = data['role']?.toString() ?? 'inconnu';
            final bloque = data['bloque'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    role == 'proprietaire'
                        ? Icons.agriculture
                        : role == 'admin'
                        ? Icons.admin_panel_settings
                        : Icons.person,
                  ),
                ),
                title: Text(
                  data['nom']?.toString() ??
                      data['email']?.toString() ??
                      doc.id,
                ),
                subtitle: Text(
                  '${data['email'] ?? ''}\n'
                  'Rôle : $role'
                  '${bloque ? ' • Compte bloqué' : ''}',
                ),
                isThreeLine: true,
                trailing: role == 'admin'
                    ? const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.green,
                      )
                    : IconButton(
                        tooltip: bloque ? 'Débloquer' : 'Bloquer',
                        icon: Icon(
                          bloque ? Icons.lock_open : Icons.block,
                          color: bloque ? Colors.green : Colors.red,
                        ),
                        onPressed: () async {
                          try {
                            await doc.reference.update({'bloque': !bloque});

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  bloque
                                      ? 'Compte débloqué.'
                                      : 'Compte marqué comme bloqué.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur : $e')),
                            );
                          }
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

// ======================================================
// ONGLET MATÉRIELS
// ======================================================

class _MaterielsTab extends StatelessWidget {
  const _MaterielsTab();

  Future<void> _afficherDetails(
    BuildContext context,
    Map<String, dynamic> data,
    bool masque,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(data['nom']?.toString() ?? 'Détails du matériel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Type', data['type']),
                _detail('Localisation', data['localisation']),
                _detail('Prix', data['prix']),
                _detail('Propriétaire', data['proprietaireId']),
                _detail('Description', data['description']),
                _detail('Disponibilité', data['disponible']),
                const SizedBox(height: 8),
                Text(
                  masque ? 'Annonce masquée' : 'Annonce visible',
                  style: TextStyle(
                    color: masque ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _detail(String titre, dynamic valeur) {
    final texte = valeur == null || valeur.toString().isEmpty
        ? 'Non renseigné'
        : valeur.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$titre : $texte'),
    );
  }

  Future<void> _changerVisibilite(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool masque,
  ) async {
    try {
      await doc.reference.update({'visible': masque});

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(masque ? 'Annonce réaffichée.' : 'Annonce masquée.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier l’annonce : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('materiels').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erreur de lecture des matériels. '
              'Vérifiez les règles Firestore.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('Aucun matériel publié.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final masque = data['visible'] != true;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  Icons.agriculture,
                  color: masque ? Colors.grey : Colors.green,
                  size: 34,
                ),
                title: Text(data['nom']?.toString() ?? 'Matériel sans nom'),
                subtitle: Text(
                  '${data['type'] ?? 'Type inconnu'}'
                  ' • ${data['localisation'] ?? 'Localisation non renseignée'}\n'
                  '${masque ? 'Annonce masquée' : 'Annonce visible'}',
                ),
                isThreeLine: true,

                // Le clic sur la ligne ouvre les détails.
                onTap: () => _afficherDetails(context, data, masque),

                // Le bouton œil masque ou réaffiche l'annonce.
                trailing: IconButton(
                  tooltip: masque
                      ? 'Réafficher l’annonce'
                      : 'Masquer l’annonce',
                  icon: Icon(
                    masque ? Icons.visibility : Icons.visibility_off,
                    color: masque ? Colors.green : Colors.red,
                  ),
                  onPressed: () => _changerVisibilite(context, doc, masque),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ======================================================
// ONGLET SIGNALEMENTS
// ======================================================

class _SignalementsTab extends StatelessWidget {
  const _SignalementsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('signalements').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erreur de lecture des signalements. '
              'Vérifiez les règles Firestore.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('Aucun signalement pour le moment.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final traite = data['statut'] == 'traite';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['sujet']?.toString() ?? 'Signalement',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(data['description']?.toString() ?? ''),
                    const SizedBox(height: 6),
                    Text('Auteur : ${data['auteurId'] ?? 'inconnu'}'),
                    Text(
                      'Matériel : '
                      '${data['materielId'] ?? 'non précisé'}',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: traite
                            ? null
                            : () async {
                                try {
                                  await doc.reference.update({
                                    'statut': 'traite',
                                    'dateTraitement':
                                        FieldValue.serverTimestamp(),
                                  });

                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Signalement traité.'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur : $e')),
                                  );
                                }
                              },
                        icon: Icon(
                          traite ? Icons.check_circle : Icons.done_all,
                        ),
                        label: Text(traite ? 'Traité' : 'Marquer comme traité'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
