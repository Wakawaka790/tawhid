# Générer l'APK Android — Le Jardin du Tawhid

Le projet Android est **déjà généré** dans le dossier `android/`. Vous n'avez donc
pas à configurer Capacitor : il ne reste qu'à compiler.

L'APK **embarque** les fichiers de l'application : une fois installée, elle
fonctionne **sans connexion** et sans serveur. C'est le gros avantage sur la PWA.

---

## Ce qu'il vous faut (une seule fois)

### 1. Java JDK 17 — obligatoire pour compiler

- Téléchargez **JDK 17** (Temurin / Eclipse Adoptium) : https://adoptium.net
- Prenez « JDK 17 (LTS) », Windows x64, `.msi`
- Installez en laissant les options par défaut

Vérifiez dans PowerShell :

```powershell
java -version
```

Vous devez voir `openjdk version "17…"`.

### 2. Le SDK Android — **le script s'en occupe**

Vous n'avez **pas besoin d'Android Studio** : il pèse plus de 5 Go alors que
seuls 700 Mo sont nécessaires pour fabriquer l'APK.

Lancez simplement le script fourni, depuis la racine du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File .\installer-sdk-android.ps1
```

Il vous demandera une seule chose : télécharger les *Command line tools*
depuis <https://developer.android.com/studio#command-line-tools-only>
(~130 Mo), puis il installe le SDK dans `C:\Android` et crée le fichier
`android\local.properties` tout seul.

> **Si vous préférez Android Studio**, installez-le normalement : le script le
> détectera et se contentera de configurer le projet.

### 3. Node.js — déjà installé chez vous (vous avez npm)

Vérifiez :

```powershell
node -v
```

---

## Compiler l'APK

### Étape 1 — installer les dépendances du projet

Dans PowerShell, à la racine du dépôt :

```powershell
cd C:\Users\Win10\tawhid
npm install
```

### Étape 2 — resynchroniser l'application web

```powershell
npm run sync
```

Cette commande copie `app-enfants/` vers `android/app/src/main/assets/public`.
**À relancer après chaque modification de l'application web.**

### Étape 3 — compiler

**Méthode A — en ligne de commande (la plus rapide)**

```powershell
cd android
.\gradlew.bat assembleDebug
```

Patientez 3 à 10 minutes la première fois (téléchargement de Gradle).
Le fichier produit se trouve ici :

```
android\app\build\outputs\apk\debug\app-debug.apk
```

**Méthode B — avec Android Studio**

1. Ouvrez Android Studio → *Open* → sélectionnez le dossier `android`
2. Attendez la fin de la synchronisation Gradle (barre en bas)
3. Menu **Build** → **Build Bundle(s) / APK(s)** → **Build APK(s)**
4. Cliquez sur *locate* dans la notification pour ouvrir le dossier

---

## Installer sur le téléphone

**Le plus simple :** copiez `app-debug.apk` sur le téléphone (USB, Bluetooth ou
WhatsApp vers vous-même), ouvrez le fichier, autorisez « sources inconnues ».

**Ou via adb**, téléphone branché en USB avec le débogage activé :

```powershell
adb install android\app\build\outputs\apk\debug\app-debug.apk
```

---

## Pour la publier sur le Play Store

Il faudra un APK **signé** (pas un `debug`). Dans Android Studio :
**Build** → **Generate Signed Bundle / APK** → **APK** → *Create new…* pour créer
un fichier de clé (`.jks`).

⚠️ **Conservez ce fichier `.jks` et son mot de passe précieusement** : sans lui,
vous ne pourrez jamais publier une mise à jour de l'application.

Pensez aussi à personnaliser avant publication :

- `android/app/build.gradle` → `applicationId` (`com.tawhid.jardin`), `versionCode`, `versionName`
- `android/app/src/main/res/values/strings.xml` → nom affiché sous l'icône

---

## Détails techniques

| Élément | Valeur |
|---|---|
| Identifiant | `com.tawhid.jardin` |
| Nom | Le Jardin du Tawhid |
| Schéma interne | `https://localhost` (contexte sécurisé : le service worker fonctionne) |
| Dossier web | `app-enfants/` → copié dans `assets/public` |
| Icône | étoile à 8 branches or sur vert, générée en 5 densités + icône adaptative |
| Écran de démarrage | même motif, en 11 tailles (portrait et paysage) |
| Permissions | **aucune** en dehors d'Internet, et l'application n'en a pas besoin |

Aucune représentation d'être animé nulle part, y compris dans l'icône
(leçon 52 du livre).
