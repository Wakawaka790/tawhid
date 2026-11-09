# Guide de test — Le Jardin du Tawhid

## 1. Le plus rapide : le serveur déjà lancé

Le serveur de prévisualisation tourne déjà. Ouvre simplement la racine du dépôt puis
**« Le Jardin du Tawhid »** (ou directement `/app-enfants/index.html`).

> ⚠️ **Piège n°1 :** n'ouvrez pas `index.html` en double-cliquant dessus.
> En `file://`, le navigateur bloque le chargement des fichiers JSON et le service worker :
> l'application restera vide. Il faut toujours passer par un serveur HTTP.

## 2. Tester sur votre propre ordinateur

Récupérez le code (une ligne à la fois) :

```bash
git clone https://github.com/Wakawaka790/tawhid.git
cd tawhid
git checkout arena/00959781-tawhid     # ou la branche de votre choix
cd app-enfants
```

Puis lancez le serveur :

```bash
./lancer.sh          # Linux / macOS
.\lancer.bat         # Windows, dans PowerShell
                     # (ou double-clic depuis l'Explorateur)
```

Le script affiche `http://localhost:8000` **et** l'adresse à ouvrir depuis un
téléphone branché au même Wi-Fi (pas besoin de chercher votre IP à la main).
Sur Windows, si Python n'est pas installé, le script vous le dit.

### ⚠️ Sur Windows / PowerShell — les 3 pièges

| Piège | Mauvaise commande | Bonne commande |
|---|---|---|
| `&&` n'existe pas dans PowerShell 5.1 | `cd tawhid && git checkout …` | `cd tawhid` **puis Entrée**, `git checkout …` |
| Le slash est inversé | `./lancer.bat` | `.\lancer.bat` (antislash) |
| Il faut être **dans** le dossier | `lancer.bat` depuis `C:\Users\...` | `cd app-enfants` d'abord |

La suite complète, à coller ligne par ligne dans PowerShell :

```powershell
cd tawhid
git checkout arena/00959781-tawhid
cd app-enfants
.\lancer.bat
```

### Sans script, en une ligne

```powershell
python -m http.server 8000             # puis http://localhost:8000
```

Pour connaître l'adresse à taper sur le téléphone :

```powershell
ipconfig | findstr IPv4
```

À défaut de Python : `npx serve .` (Node.js) ou `php -S localhost:8000` (PHP).

## 3. Tester sur téléphone (le plus réaliste)

L'application est conçue pour le téléphone. Deux méthodes :

**a) Même Wi-Fi.** Lancez le serveur avec `--bind 0.0.0.0`, trouvez l'IP de votre
ordinateur (`ipconfig` sur Windows, `ip a` sur Linux/Mac), puis sur le téléphone
ouvrez `http://192.168.x.x:8000`.

**b) Installation (recommandé).** Une fois la page ouverte :
- Android / Chrome : menu ⋮ → *Installer l'application*
- iPhone / Safari : Partager → *Sur l'écran d'accueil*

L'application s'ouvre alors en plein écran, sans barre d'adresse — c'est le vrai
ressenti qu'auront les enfants.

## 4. Tester le mode hors ligne

1. Ouvrez l'application une première fois (elle se met en cache).
2. Outils de développement → onglet *Réseau* → cochez **Hors ligne**.
3. Rechargez : tout doit fonctionner.

C'est important : beaucoup de familles n'ont pas toujours de réseau, et cela garantit
qu'aucune donnée n'est envoyée pendant l'utilisation.

## 5. Tester la révision espacée sans attendre 21 jours

La progression normale est J+1, J+3, J+7, J+21. Pour la tester immédiatement :

1. Dépliez **« Espace parents »** en bas de l'onglet Jardin.
2. **Pré-remplir 12 leçons** → remplit un historique fictif.
3. **⏩ Simuler +1 jour / +7 jours** → décale les dates de révision dans le passé.
   Les feuilles correspondantes passent au jaune et pulsent.
4. Cliquez sur **« Réviser maintenant (n) »** pour enchaîner les révisions.

## 6. Scénario de test guidé (10 minutes)

| # | Action | Ce qu'il faut vérifier |
|---|---|---|
| 1 | Onglet **Jardin** → branche 1 → leçon 1 | L'histoire, la notion et la question s'affichent ; la page du livre (p. 13) est indiquée |
| 2 | Répondre **faux** exprès | La bonne réponse se colore en vert, l'explication s'affiche, le ton reste bienveillant |
| 3 | Cliquer **« J'ai compris »** | La feuille devient verte, le compteur passe à 1, l'arbre gagne une feuille |
| 4 | **⏩ Simuler +1 jour** | La leçon 1 passe en jaune « à réviser » |
| 5 | Onglet **Les 8 clés** → clé 1 | La question, puis l'explication avec le verset |
| 6 | Onglet **Détective** → scène « Dans la chambre » | 4 indices, 4 verdicts possibles, explication sourcée après chaque réponse |
| 7 | Onglet **Compagnon** → « Où est Allah ? » | La réponse + « Leçon 7, p. 28 » |
| 8 | Poser « Quel temps fera-t-il demain ? » | L'app **refuse** de répondre et renvoie vers un parent ou un savant — c'est voulu |
| 9 | Bouton **🔊 Voix** | La synthèse vocale lit les textes (selon le navigateur) |
| 10 | Bouton **A+** | Le texte grossit, pour les plus jeunes |

## 7. Test avec des enfants — ce qu'il faut observer

Ne demandez pas « tu as aimé ? ». Observez plutôt :

- **Compréhension** : à la fin, posez 3 questions oralement, sans l'application
  (ex. « c'est quoi le Tawhid ? », « pourquoi on ne demande pas aux morts ? »).
- **Transfert** : le défi de la leçon a-t-il été fait dans la vraie vie ?
- **Rétention à 7 jours** : revenez une semaine plus tard et reposez la même question.
  C'est l'indicateur qui compte vraiment.
- **Autonomie** : l'enfant retrouve-t-il son chemin seul ?
- **Décrochage** : à quel moment regarde-t-il ailleurs ?

Un test utile = **5 à 10 enfants**, en les laissant seuls devant l'app, sans les aider.

## 8. Signaler un problème

Notez : l'appareil et le navigateur, le module concerné, ce qui s'est passé,
et ce qui était attendu. Les données étant locales, **n'oubliez pas le bouton
« Réinitialiser » avant de prêter l'appareil à un autre enfant**.

## 9. Avant toute diffusion

- [ ] Relecture du contenu par une personne de science
- [ ] Vérification de chaque référence (verset, hadith)
- [ ] Validation du vocabulaire pour la tranche d'âge visée
- [ ] Test sur au moins 5 familles
