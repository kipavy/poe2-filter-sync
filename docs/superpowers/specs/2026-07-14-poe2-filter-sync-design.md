# POE2 Filter Sync — Design

**Date:** 2026-07-14
**Statut:** proposé (en attente de relecture)

## Objectif

Garder un filtre d'items Path of Exile 2 **toujours synchronisé avec NeverSink**, tout en
appliquant **mes sons custom**, avec **le moins d'intervention manuelle possible**.

Objectifs dérivés (issus du brainstorming) :

- **A — Robustesse** : ne plus casser en silence quand NeverSink change ses identifiants
  de section. Un mapping qui ne matche plus doit **alerter**, pas être ignoré.
- **B — Sons versionnés** : héberger les mp3 dans le repo Git (fin de la dépendance Google Drive).
- **C — Intervention minimale** : les mises à jour du **texte** du filtre sont 100 % automatiques
  (cloud). Le local ne touche qu'aux fichiers audio, ce qui est rare.
- **D — Distribution simple** : réinstall sur une machine = suivre le filtre en ligne + un
  one-liner pour les sons.

## Contexte : le système précédent

- `POE2_Filter.bat` (admin, au démarrage) : vidait le dossier POE2, téléchargeait NeverSink,
  ne gardait que le style `(STYLE) CUSTOMSOUNDS`, puis appelait un script PowerShell.
- `poe2-Update-CustomAlertSound.ps1` : pour chaque `.filter`, insérait/remplaçait
  `CustomAlertSound "x.mp3" 300` dans les blocs repérés par les identifiants NeverSink
  (`$type->… $tier->…`), puis téléchargeait les mp3 depuis Google Drive.

Points fragiles : mapping par identifiants qui **échoue en silence**, sons sur Google Drive,
`.bat` destructif (efface tout le dossier), lancement admin inutile, volume figé à `300`,
pièces éclatées sur bit.ly + 2 gists + Drive.

## Contrainte technique déterminante (vérifiée)

- **API filtres PoE** : `POST /item-filter/<id>` (update partiel), scope OAuth
  `account:item_filter`. → Une GitHub Action **peut** pousser le filtre à jour sur le compte PoE.
- **`CustomAlertSound` exige le mp3 en local** dans le dossier POE2. Le système « en ligne /
  follow » ne transporte **que le texte** du filtre, jamais l'audio.

Conséquence : impossible d'avoir un install 100 % sans rien en local *avec* des sons custom.
On découpe donc :

| Élément | Fréquence de changement | Où / comment |
|---|---|---|
| Texte du filtre (NeverSink + lignes `CustomAlertSound`) | souvent | **cloud, auto** via l'API PoE |
| Fichiers mp3 | quasi jamais | **local, ponctuel** |

## Architecture

```
poe2-filter-sync/
  sounds/                     # mp3 versionnés
  config/
    sound-mapping.psd1        # données de mapping (voir plus bas)
  src/
    Build-Filter.ps1          # CŒUR partagé : download NeverSink -> applique sons -> valide
    Install-Sounds.ps1        # copie les mp3 dans le dossier POE2
    Publish-Filter.ps1        # POST vers l'API PoE (utilisé par l'Action)
    Sync-Poe2Filter.ps1       # point d'entrée local (2 modes)
  .github/workflows/
    sync.yml                  # nuit + à chaque push : build -> valide -> publie
  README.md
```

**Principe clé : un seul cœur de build.** `Build-Filter.ps1` est appelé **à la fois** par la
GitHub Action (cloud) et par le mode `-Full` du script local. Zéro divergence entre les deux.

### Composants

- **`Build-Filter.ps1`** — entrée : dossier NeverSink + config ; sortie : `.filter` construit(s)
  en mémoire/dans un dossier temporaire. Ne fait **aucune** écriture dans le dossier POE2 et
  **aucun** appel réseau vers PoE. Télécharge NeverSink (release taggée de préférence, sinon
  `main`), applique les mappings, **valide**. Réutilisable et testable isolément.
- **`Install-Sounds.ps1`** — copie `sounds/*.mp3` vers le dossier POE2. Non-destructif :
  n'écrit que les mp3, ne touche à rien d'autre. Idempotent.
- **`Publish-Filter.ps1`** — prend le `.filter` construit et fait `POST /item-filter/<id>`
  (token OAuth via variable d'env / secret). Optionnellement `?validate=true`.
- **`Sync-Poe2Filter.ps1`** — point d'entrée local :
  - **défaut** → appelle `Install-Sounds` uniquement (cas courant).
  - **`-Full`** → appelle `Build-Filter` puis installe le `.filter` construit **et** les sons
    en local (filet de sécurité si la pipeline cloud est cassée). Aucun appel à l'API PoE.

### Flux de données

**Nominal (cloud, hands-off) :**
1. Action déclenchée (nuit + push) → `Build-Filter` (NeverSink + config) → `.filter` construit.
2. Validation. Si échec → l'Action **échoue** = alerte GitHub (objectif A).
3. `Publish-Filter` → `POST /item-filter/<id>` sur le compte PoE.
4. En jeu : le filtre en ligne (sélectionné/suivi) se met à jour tout seul. Les mp3, déjà
   présents en local, font sonner les `CustomAlertSound`.

**Repli local (`-Full`) :** `Sync-Poe2Filter.ps1 -Full` → `Build-Filter` → écrit le `.filter`
+ les mp3 directement dans le dossier POE2. Indépendant du cloud.

**Sons seuls (défaut) :** `Sync-Poe2Filter.ps1` → copie les mp3 dans le dossier POE2.

## Format de config (`sound-mapping.psd1`)

Sépare les **données** du **code**. Deux sections :

1. **Remplacement de fichiers (robuste)** — les noms par défaut du style CUSTOMSOUNDS de
   NeverSink (`1maybevaluable.mp3` … `6veryvaluable.mp3`) mappés vers un mp3 du dossier
   `sounds/`. Aucune édition de texte : survit aux updates NeverSink.
2. **Overrides ciblés (fragile, à valider)** — `identifier` (`$type->… $tier->…`) → `{ fichier,
   volume }`. Le volume devient **par-mapping** (fini le `300` figé).

## Gestion des erreurs & validation (objectif A)

- Après application des overrides ciblés, compter les matches par mapping.
  **Tout mapping à 0 match ⇒** échec en cloud (Action rouge → alerte), avertissement clair en local.
- Un mp3 référencé mais absent de `sounds/` ⇒ échec de build.
- Install local **non-destructive** : jamais de wipe du dossier POE2, pas besoin d'admin.
- Optionnel : `POST ...?validate=true` pour valider contre la version courante du jeu.

## Risques à lever en tout début d'implémentation

1. **Combo « filtre en ligne + mp3 local » joue-t-il le son en jeu ?** Très probable (mode
   FilterBlade), mais **à confirmer sur la machine** comme toute première étape.
2. **Accès API PoE** : `account:item_filter` via OAuth suppose d'**enregistrer une application
   OAuth chez GGG**. Si non accessible → on livre quand même le repli local (`-Full`), et
   l'Action ne sert qu'à **valider** (pas à publier). Le design fonctionne dans les deux cas.

## Hors périmètre (YAGNI)

- Personnalisation autre que les sons (couleurs, bordures, visibilité) : non.
- Support multi-jeux (PoE1) : non.
- UI / interface graphique : non.
- Gestion de plusieurs profils de filtres : non (un seul filtre).

## Critères de succès

- Une mise à jour NeverSink se retrouve dans le filtre en jeu **sans action manuelle** (via le
  filtre en ligne).
- Un mapping cassé **alerte** (Action rouge) au lieu de disparaître en silence.
- Réinstall sur une machine neuve = suivre le filtre en ligne + un one-liner sons.
- Le mode `-Full` reconstruit tout en local si le cloud est indisponible.
