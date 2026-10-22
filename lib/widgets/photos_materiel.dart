import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Nombre maximum de photos par annonce.
const int maxPhotos = 3;

/// Liste de photos (base64) d'un document `materiels`.
List<String> photosDe(Map<String, dynamic> data) {
  final brut = data['photos'];
  if (brut is! List) return [];
  return brut.whereType<String>().where((p) => p.isNotEmpty).toList();
}

/// Vignette : première photo du matériel, ou l'icône tracteur à défaut.
class PhotoMateriel extends StatelessWidget {
  final Map<String, dynamic> data;
  final double taille;

  const PhotoMateriel({super.key, required this.data, this.taille = 56});

  @override
  Widget build(BuildContext context) {
    final photos = photosDe(data);
    if (photos.isEmpty) {
      return Icon(Icons.agriculture, size: taille * 0.8, color: Colors.green);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        base64Decode(photos.first),
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.agriculture, size: taille * 0.8, color: Colors.green),
      ),
    );
  }
}

/// Bande de toutes les photos (affichage dans la fiche d'une annonce).
class BandePhotos extends StatelessWidget {
  final List<String> photos;
  const BandePhotos({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(photos[i]),
            height: 110,
            width: 150,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox(width: 150),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de photos (galerie ou appareil photo) pour les formulaires.
/// Les images sont réduites (800 px, qualité 60) puis encodées en base64
/// pour être stockées directement dans Firestore (pas besoin de Firebase Storage).
class SelecteurPhotos extends StatefulWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final bool desactive;

  const SelecteurPhotos({
    super.key,
    required this.photos,
    required this.onChanged,
    this.desactive = false,
  });

  @override
  State<SelecteurPhotos> createState() => _SelecteurPhotosState();
}

class _SelecteurPhotosState extends State<SelecteurPhotos> {
  final _picker = ImagePicker();
  bool _occupe = false;

  Future<void> _ajouter(ImageSource source) async {
    if (widget.photos.length >= maxPhotos) return;
    setState(() => _occupe = true);
    try {
      final fichier = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );
      if (fichier == null) return;
      final Uint8List octets = await fichier.readAsBytes();
      if (octets.length > 300 * 1024) {
        _message('Image trop lourde. Choisissez une image plus petite.');
        return;
      }
      widget.onChanged([...widget.photos, base64Encode(octets)]);
    } catch (_) {
      _message('Impossible de charger la photo.');
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  void _choisirSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _ajouter(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(ctx);
                _ajouter(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (${photos.length}/$maxPhotos)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(photos[i]),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: widget.desactive
                              ? null
                              : () => widget.onChanged([...photos]..removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (photos.length < maxPhotos)
                InkWell(
                  onTap: widget.desactive || _occupe ? null : _choisirSource,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.green.withValues(alpha: 0.06),
                    ),
                    child: _occupe
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo, color: Colors.green, size: 30),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
