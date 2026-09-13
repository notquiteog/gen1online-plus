# PokeEmerald Asset Integration Guide (gen1online-plus)

This guide explains how to import and use assets from the **Pokemon Emerald Decompilation** (`pokeemerald` / `pokeemerald-expansion`) in the **gen1online-plus** Crystal mod.

---

## 1. Overview & Fallback Guarantee

- **Optional Integration**: Adding PokeEmerald assets is **100% optional**.
- **Graceful Fallback**: If PokeEmerald assets are missing, the game and online multiplayer (GTS, Wonder Trade, battles, global chat) will continue to function normally using vanilla built-in fallback sprites.
- **On-Demand Importer**: You do not need to copy the entire `pokeemerald` project into the mod. The included extraction tool selectively pulls, converts, and formats only the assets you need.

---

## 2. Setting Up PokeEmerald Assets

### Prerequisites
- Python 3 installed on your system.
- The `pokeemerald` or `pokeemerald-expansion` project folder located anywhere on your computer (e.g. `E:\staged Mods\pokeemerald-expansion-master`).

---

## 3. Running the Automated Importer Tool

The mod includes an automated importer script located at:
```
mods/gen1online-plus/tools/import_emerald_follower.py
```

### Option A: Import Starters & Popular Pokémon (Default)
To import a curated collection of Gen 1, Gen 2, and Gen 3 Pokémon (266 species, 520 regular and shiny sheets):
```bash
python mods/gen1online-plus/tools/import_emerald_follower.py
```

### Option B: Import ALL Available Species
To import every Pokémon species present in the Emerald decomp:
```bash
python mods/gen1online-plus/tools/import_emerald_follower.py --all
```

### Option C: Import Specific Pokémon on Demand
To import only specific species by name:
```bash
python mods/gen1online-plus/tools/import_emerald_follower.py cyndaquil totodile chikorita pikachu treecko
```

### Option D: Specifying a Custom Emerald Project Path
If your Emerald decomp is in a custom directory:
```bash
python mods/gen1online-plus/tools/import_emerald_follower.py --emerald-dir "D:/path/to/pokeemerald-expansion/graphics/pokemon"
```

---

## 4. Asset Storage Structure

Converted sprite sheets are stored in:
```
mods/gen1online-plus/assets/followers/
  ├── bulbasaur.png
  ├── bulbasaur_shiny.png
  ├── cyndaquil.png
  ├── cyndaquil_shiny.png
  ├── pikachu.png
  ├── pikachu_shiny.png
  ├── treecko.png
  └── ...
```

- Each file is formatted as a 6-frame vertical strip ($16 \times 96$ RGBA PNG) with true 32-bit color and alpha transparency.
- The frames are aligned to standard Crystal/GBC tile geometries with front-edge alignment so no features (noses, ears, tails) are clipped during overworld exploration.

---

## 5. Startup Notification Status

Whenever you launch the game and step into the overworld:
- The mod scans `mods/gen1online-plus/assets/followers/`.
- If assets are detected:
  ```
  EMERALD ASSETS: ACTIVE
  266 FOLLOWER SPRITES LOADED!
  ```
- If assets are missing:
  ```
  EMERALD ASSETS: NOT FOUND (OPTIONAL)
  USING FALLBACK SPRITES.
  SEE README_ASSETS.MD
  ```
