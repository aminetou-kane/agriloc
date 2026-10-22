/// Outils de gestion des périodes de location (calendrier de disponibilité).
///
/// Une période est définie par un jour de début et un jour de fin, tous deux
/// inclus. Deux périodes se chevauchent dès qu'elles partagent au moins un jour.
DateTime jourSeul(DateTime d) => DateTime(d.year, d.month, d.day);

bool periodesSeChevauchent(
  DateTime debutA,
  DateTime finA,
  DateTime debutB,
  DateTime finB,
) {
  final a1 = jourSeul(debutA);
  final a2 = jourSeul(finA);
  final b1 = jourSeul(debutB);
  final b2 = jourSeul(finB);
  return !a1.isAfter(b2) && !b1.isAfter(a2);
}

/// Nombre de jours d'une période (bornes incluses).
int nombreDeJours(DateTime debut, DateTime fin) =>
    jourSeul(fin).difference(jourSeul(debut)).inDays + 1;

String formaterJour(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formaterPeriode(DateTime debut, DateTime fin) =>
    'du ${formaterJour(debut)} au ${formaterJour(fin)}';
