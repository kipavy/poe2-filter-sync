# 🔊 Filtre POE2 — NeverSink + sons custom

Filtre d'items **NeverSink** (strictness *Strict*) avec mes **sons personnalisés**. Installation en 1 ligne.

## ⚡ Installation (1 ligne)

`Win + R`, colle ça, `Entrée` :

```
powershell -c "[Net.ServicePointManager]::SecurityProtocol='Tls12'; &([scriptblock]::Create((irm https://tinyurl.com/2b2xuyal))) -Full"
```

Pas besoin d'admin. Ça télécharge le dernier filtre NeverSink, applique les sons custom, et copie **toutes les variantes de strictness** (Soft → Uber Plus Strict) **et** les .mp3 dans ton dossier `Documents\My Games\Path of Exile 2`.

## 🎮 En jeu

Options → **Item Filter** → choisis parmi les variantes installées celle qui correspond à la strictness que tu veux (ex. `...3-STRICT (customsounds)`) → *Reload*. C'est prêt.

## 🔁 Mettre à jour

Relance exactement la même ligne quand tu veux la dernière version de NeverSink. (Une version qui se met à jour toute seule via ton compte PoE arrive bientôt.)

## 🛠️ Étapes manuelles (si tu préfères)

1. Télécharge le repo : https://github.com/kipavy/poe2-filter-sync (bouton vert **Code → Download ZIP**)
2. Décompresse-le
3. Clic droit sur `install.ps1` → **Exécuter avec PowerShell** (ou : `powershell -ExecutionPolicy Bypass -File install.ps1 -Full`)

---

### ⚙️ Comment ça marche (technique)

- Le **texte du filtre** provient de [NeverSink](https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2) (variante CUSTOMSOUNDS), toujours la dernière release.
- Les **sons custom** sont appliqués de deux façons : remplacement des 6 fichiers audio par défaut de NeverSink, + quelques overrides ciblés par tier (`config/sound-mapping.json`).
- Une **GitHub Action** reconstruit et valide le filtre chaque nuit ; si un identifiant NeverSink change, le build échoue (alerte). La publication auto sur le compte PoE arrive une fois l'accès API GGG obtenu.
- Conçu, planifié et documenté dans `docs/superpowers/`.
