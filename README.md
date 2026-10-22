# 🌾 AgriLoc — Application de location de matériel agricole

## Présentation du projet

**AgriLoc** est une application mobile développée avec Flutter et Firebase pour faciliter la mise en relation entre les agriculteurs qui ont besoin de matériel agricole et les propriétaires qui souhaitent le proposer à la location.

Le projet répond à une difficulté rencontrée dans le milieu agricole : l'accès aux équipements nécessaires aux travaux des champs, notamment lorsque l'achat de ces équipements représente un coût important.

## Objectifs

- Faciliter l'accès au matériel agricole.
- Mettre en relation les agriculteurs et les propriétaires d'équipements.
- Simplifier les demandes de location et leur suivi.
- Favoriser une meilleure utilisation des équipements agricoles.

## Fonctionnalités

- Création de compte et connexion des utilisateurs.
- Gestion des profils selon le rôle de l'utilisateur.
- Consultation du matériel agricole disponible, recherche par mot-clé et filtre par type.
- Publication et gestion du matériel proposé à la location (12 types : tracteur, motopompe, semoir, etc.).
- Demande de location pour une **période donnée** (date de début / date de fin).
- **Calendrier de disponibilité** : les périodes déjà réservées sont affichées et les chevauchements sont refusés.
- Acceptation / refus des demandes par les propriétaires, fin de location.
- Notifications à chaque étape (demande, acceptation, refus, fin) et **rappel avant la date** de location.
- Historique des locations et avis / notes après chaque location terminée.
- Signalements et espace administrateur (blocage de comptes, modération des annonces, traitement des signalements).

## Technologies utilisées

- **Flutter** : développement de l'application mobile.
- **Dart** : langage de programmation.
- **Firebase Authentication** : authentification des utilisateurs.
- **Cloud Firestore** : stockage et gestion des données.

## Organisation du projet

```text
agriloc/
├── android/                 # Configuration Android
├── assets/                  # Ressources de l'application
│   └── images/              # Images
├── ios/                     # Configuration iOS
├── lib/                     # Code source Dart
├── linux/                   # Configuration Linux
├── macos/                   # Configuration macOS
├── test/                    # Tests
├── web/                     # Configuration Web
├── windows/                 # Configuration Windows
├── .gitignore               # Fichiers exclus de Git
├── firebase.json            # Configuration Firebase CLI
├── firestore.rules          # Règles de sécurité Firestore
├── pubspec.yaml             # Dépendances et configuration Flutter
└── README.md                # Documentation du projet
```

## Prérequis

Avant de lancer le projet, il faut disposer de :

- Flutter et Dart installés.
- Git installé.
- Un environnement de développement compatible, comme Android Studio ou Visual Studio Code.
- Un projet Firebase configuré pour l'application.

## Installation

### 1. Cloner le dépôt

```bash
git clone URL_DU_DEPOT
cd agriloc
```

Remplacer `URL_DU_DEPOT` par l'adresse du dépôt GitHub.

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Configurer Firebase

Configurer Firebase pour l'environnement de développement utilisé et vérifier que les fichiers de configuration nécessaires sont présents localement.

Ne jamais publier de mots de passe, de clés privées ou d'autres secrets dans le dépôt.

### 4. Vérifier le projet

```bash
flutter analyze
flutter test
```

### 5. Lancer l'application

Connecter un appareil ou démarrer un émulateur, puis exécuter :

```bash
flutter run
```

## Déployer les règles de sécurité Firestore

Les règles se trouvent dans `firestore.rules`. Elles doivent être publiées, sinon les notifications, avis, signalements et réservations seront refusés :

```bash
firebase deploy --only firestore:rules
```

## Créer le compte administrateur

Le rôle `admin` ne peut pas être choisi à l'inscription. Pour créer l'administrateur :

1. Créer un compte depuis l'application (rôle quelconque).
2. Dans la console Firebase → Firestore → collection `users` → document de cet utilisateur, remplacer le champ `role` par `admin`.

## Changer l'image d'ouverture

Remplacer le fichier `assets/images/agriloc_splash.png` par la nouvelle image (même nom, format PNG), puis relancer `flutter run`.

## Sécurité

AgriLoc utilise Firebase pour l'authentification et la gestion des données. Les règles Firestore (rôles protégés, accès limité aux parties concernées) doivent être vérifiées avant tout déploiement afin que chaque utilisateur puisse uniquement effectuer les opérations autorisées pour son rôle.

## Évolutions possibles

Les évolutions futures pourront inclure l'amélioration de l'expérience utilisateur, l'optimisation des notifications et l'ajout de fonctionnalités facilitant davantage les échanges entre agriculteurs et propriétaires.

## Auteur et contexte académique

Projet académique réalisé dans le cadre de la formation en informatique.

**AgriLoc — Le matériel agricole à portée de main.** 🌾
