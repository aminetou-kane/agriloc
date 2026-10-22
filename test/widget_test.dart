import 'package:agriloc/utils/periode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('periodesSeChevauchent', () {
    final d = (int j) => DateTime(2026, 11, j);

    test('périodes disjointes : pas de conflit', () {
      expect(periodesSeChevauchent(d(1), d(5), d(6), d(10)), isFalse);
    });

    test('un jour en commun : conflit', () {
      expect(periodesSeChevauchent(d(1), d(5), d(5), d(10)), isTrue);
    });

    test('période incluse dans une autre : conflit', () {
      expect(periodesSeChevauchent(d(1), d(20), d(5), d(6)), isTrue);
    });

    test('les heures sont ignorées', () {
      expect(
        periodesSeChevauchent(
          DateTime(2026, 11, 1, 23),
          DateTime(2026, 11, 2, 1),
          DateTime(2026, 11, 3, 8),
          DateTime(2026, 11, 4, 8),
        ),
        isFalse,
      );
    });
  });

  test('nombreDeJours compte les deux bornes', () {
    expect(nombreDeJours(DateTime(2026, 11, 1), DateTime(2026, 11, 1)), 1);
    expect(nombreDeJours(DateTime(2026, 11, 1), DateTime(2026, 11, 3)), 3);
  });
}
