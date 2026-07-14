# 🔊 Filtre POE2 — NeverSink + sons custom

Filtre d'items **NeverSink** (strictness *Strict*) avec mes **sons personnalisés**. Installation en 1 ligne.

## ⚡ Installation (1 ligne)

`Win + R`, colle ça, `Entrée` :

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr 'https://raw.githubusercontent.com/kipavy/poe2-filter-sync/main/install.ps1' -OutFile \"$env:TEMP\poe2.ps1\"; & \"$env:TEMP\poe2.ps1\" -Full"
```

Pas besoin d'admin. Ça télécharge le dernier filtre NeverSink, applique les sons custom, et copie le filtre **et** les .mp3 dans ton dossier `Documents\My Games\Path of Exile 2`.

## 🎮 En jeu

Options → **Item Filter** → sélectionne **`NeverSink + custom sounds`** dans la liste → *Reload*. C'est prêt.

## 🔁 Mettre à jour

Relance exactement la même ligne quand tu veux la dernière version de NeverSink. (Une version qui se met à jour toute seule via ton compte PoE arrive bientôt.)

## 🛠️ Étapes manuelles (si tu préfères)

1. Télécharge le repo : https://github.com/kipavy/poe2-filter-sync (bouton vert **Code → Download ZIP**)
2. Décompresse-le
3. Clic droit sur `install.ps1` → **Exécuter avec PowerShell** (ou : `powershell -ExecutionPolicy Bypass -File install.ps1 -Full`)

---
*Repo : https://github.com/kipavy/poe2-filter-sync — basé sur le filtre NeverSink (github.com/NeverSinkDev).*
