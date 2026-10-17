import 'package:flutter/material.dart';

import '../../services/report_service.dart';

class SignalementScreen extends StatefulWidget {
  const SignalementScreen({super.key});

  @override
  State<SignalementScreen> createState() => _SignalementScreenState();
}

class _SignalementScreenState extends State<SignalementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sujet = TextEditingController();
  final _description = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _sujet.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await ReportService.signaler(
        sujet: _sujet.text.trim(),
        description: _description.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement envoyé à l’administrateur.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’envoyer le signalement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Décrivez un problème rencontré sur AgriLoc. Votre signalement sera transmis à l’administrateur.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _sujet,
              decoration: const InputDecoration(labelText: 'Sujet'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Saisissez un sujet.' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description du problème',
              ),
              validator: (v) => v == null || v.trim().length < 10
                  ? 'Décrivez le problème (10 caractères minimum).'
                  : null,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _envoi ? null : _envoyer,
              icon: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_envoi ? 'Envoi...' : 'Envoyer le signalement'),
            ),
          ],
        ),
      ),
    );
  }
}
