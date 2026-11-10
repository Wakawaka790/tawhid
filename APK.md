# Générer l'APK Android — Le Jardin du Tawhid

L'APK **embarque** les fichiers de l'application : une fois installée, elle
fonctionne **sans connexion** et sans serveur. C'est le gros avantage sur la PWA.

---

## La méthode simple : une seule commande

Le script `construire-apk.ps1` fait **tout** : il installe ce qui manque,
configure le projet, compile, et ouvre le dossier contenant l'APK.

Dans PowerShell, à la racine du dépôt :

```powershell
cd C:\Users\Win10\tawhid
git pull
powershell -ExecutionPolicy Bypass -File .\construire-apk.ps1
```

C'est tout. Comptez **une quinzaine de minutes** la première fois (Java et le
SDK Android doivent être téléchargés), puis **moins d'une minute** les fois
suivantes.

Le script n'installe que ce qui est réellement absent. Comme votre SDK Android
est déjà en place, il passera directement à l'installation de Java 21.

### Ce que le script fait, étape par étape

| Étape | Action |
|---|---|
| 1/5 | Cherche Java 21 ; s'il manque, le télécharge depuis GitHub et l'installe |
| 2/5 | Vérifie le SDK Android (déjà présent chez vous) |
| 3/5 | Écrit `android\local.properties` et le JDK à utiliser pour Gradle |
| 4/5 | Copie les fichiers web, puis compile |
| 5/5 | Ouvre l'Explorateur sur l'APK et affiche comment l'installer |

### Si l'assistant d'installation de Java s'ouvre

C'est normal : le script n'a pas les droits administrateur. Laissez **toutes les
options par défaut**, cliquez jusqu'à la fin, et le script enchaînera
automatiquement sur la compilation.

---

## Installer sur le téléphone

Copiez `app-debug.apk` sur le téléphone (USB, Bluetooth ou WhatsApp vers
vous-même), ouvrez le fichier, et autorisez les « sources inconnues ».

Une fois installée, l'application fonctionne **sans connexion**.

---

## Si vous préférez tout faire à la main

### 1. Java JDK 21 — obligatoire

Capacitor 8 compile en Java 21. Un Java 17 fait échouer le build avec
`error: invalid source release: 21`.

**Téléchargement direct** (Temurin 21, Windows 64 bits, ~180 Mo) :
le script récupère automatiquement la dernière version via l'API GitHub.
À défaut : <https://adoptium.net>

Vérifiez avec `java -version` : vous devez voir `openjdk version "21…"`.

> Les JDK cohabitent sans problème : inutile de désinstaller Java 17.

### 2. Le SDK Android

Le script l'installe dans `C:\Android` (700 Mo). S'il manque, il vous demandera
de télécharger les *Command line tools* (~130 Mo) depuis
<https://developer.android.com/studio#command-line-tools-only> et de laisser le
`.zip` dans vos Téléchargements.

Vous n'avez **pas besoin d'Android Studio** (plus de 5 Go). Si vous
l'installez quand même, le script détectera son SDK et l'utilisera.

### 3. Compiler

```powershell
cd C:\Users\Win10\tawhid
npm install
npm run sync
cd android
.\gradlew.bat assembleDebug
```

L'APK est ensuite dans `android\app\build\outputs\apk\debug\app-debug.apk`.

> `npm run sync` est **à relancer après chaque modification** de
> `app-enfants/`, sinon l'APK contiendrait l'ancienne version.
> Le script `construire-apk.ps1` s'en charge pour vous.

### 4. Avec Android Studio

1. *Open* → sélectionnez le dossier `android`
2. Attendez la synchronisation Gradle
3. **Build** → **Build Bundle(s) / APK(s)** → **Build APK(s)**
4. Cliquez sur *locate* dans la notification

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

Deux fichiers de configuration sont volontairement **hors du dépôt** :
`android\local.properties` (ignoré par Git) et
`C:\Users\Win10\.gradle\gradle.properties` (dossier personnel). Un `git pull` ne
les écrasera donc jamais.

Aucune représentation d'être animé nulle part, y compris dans l'icône
(leçon 52 du livre).
