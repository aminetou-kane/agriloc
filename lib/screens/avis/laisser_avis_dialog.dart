import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/review_service.dart';

Future<void> afficherDialogueAvis(
  BuildContext context, {
  required String demandeId,
  required String materielId,
  required String proprietaireId,
  required String nomMateriel,
}) async {
  final commentaire = TextEditingController();
  int note = 5;
  bool envoi = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Évaluer cette location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nomMateriel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Votre note :'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final valeur = index + 1;
                  return IconButton(
                    tooltip: '$valeur étoile${valeur > 1 ? 's' : ''}',
                    onPressed: envoi
                        ? null
                        : () => setDialogState(() => note = valeur),
                    icon: Icon(
                      valeur <= note ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                      size: 32,
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentaire,
                enabled: !envoi,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (facultatif)',
                  hintText: 'Décrivez votre expérience...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: envoi ? null : () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: envoi
                ? null
                : () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    setDialogState(() => envoi = true);
                    try {
                      await ReviewService.ajouter(
                        demandeId: demandeId,
                        materielId: materielId,
                        agriculteurId: user.uid,
                        proprietaireId: proprietaireId,
                        nomMateriel: nomMateriel,
                        note: note,
                        commentaire: commentaire.text,
                      );
                      if (dialogContext.mounted) {
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Merci ! Votre avis a été enregistré.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => envoi = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: Text(envoi ? 'Enregistrement...' : 'Publier mon avis'),
          ),
        ],
      ),
    ),
  );
  commentaire.dispose();
}
