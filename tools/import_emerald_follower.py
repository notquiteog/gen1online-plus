#!/usr/bin/env python3
"""
Emerald Overworld Follower Importer Tool
Extracts and converts Pokemon overworld walking sheets from pokeemerald-expansion-master
into 1:1 authentic RGBA vertical sprite sheets formatted for Crystal's (Gen 2) SpriteRenderer.
Maintains 100% untouched 1:1 crisp pixel art with front-edge alignment for side views so no snouts/noses are clipped.
"""

import os
import sys
import struct
import zlib
import argparse

DEFAULT_EMERALD_DIR = r"E:\staged Mods\pokeemerald-expansion-master\graphics\pokemon"
DEFAULT_OUT_DIR = r"e:\gen1recomp-dev\mods\gen1online-plus\assets\followers"

def parse_jasc_pal(pal_path):
    if not os.path.exists(pal_path):
        return None
    try:
        with open(pal_path, "r", encoding="utf-8") as f:
            lines = [l.strip() for l in f.readlines() if l.strip()]
        if len(lines) < 4 or lines[0] != "JASC-PAL":
            return None
        count = int(lines[2])
        colors = []
        for i in range(3, 3 + count):
            if i < len(lines):
                parts = [int(p) for p in lines[i].split()]
                colors.append((parts[0], parts[1], parts[2]))
        return colors
    except Exception:
        return None

def decode_png(file_path):
    with open(file_path, "rb") as f:
        data = f.read()
    
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a valid PNG file: {file_path}")
        
    pos = 8
    width = height = bit_depth = color_type = 0
    idat = bytearray()
    plte = []
    
    while pos < len(data):
        length, chunk_type = struct.unpack(">I4s", data[pos:pos+8])
        pos += 8
        chunk_data = data[pos:pos+length]
        pos += length + 4
        
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk_data[:10])
        elif chunk_type == b"PLTE":
            for i in range(0, len(chunk_data), 3):
                plte.append(tuple(chunk_data[i:i+3]))
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
            
    decompressed = zlib.decompress(bytes(idat))
    pixels = []
    stride = (width + 1) // 2 if bit_depth == 4 else width
    offset = 0
    
    for y in range(height):
        filter_type = decompressed[offset]
        offset += 1
        line_data = decompressed[offset:offset+stride]
        offset += stride
        
        line_pixels = []
        if bit_depth == 4:
            for b in line_data:
                line_pixels.append((b >> 4) & 0x0F)
                if len(line_pixels) < width:
                    line_pixels.append(b & 0x0F)
        else:
            line_pixels = list(line_data)
        pixels.append(line_pixels[:width])
        
    return width, height, pixels, plte

def write_rgba_png(file_path, width, height, rgba_pixels):
    raw_bytes = bytearray()
    for row in rgba_pixels:
        raw_bytes.append(0) # Filter None
        for r, g, b, a in row:
            raw_bytes.extend((r, g, b, a))
            
    compressed = zlib.compress(bytes(raw_bytes))
    png_data = bytearray(b"\x89PNG\r\n\x1a\n")
    
    # IHDR
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    crc = zlib.crc32(b"IHDR" + ihdr)
    png_data.extend(struct.pack(">I4s", len(ihdr), b"IHDR") + ihdr + struct.pack(">I", crc))
    
    # IDAT
    crc = zlib.crc32(b"IDAT" + compressed)
    png_data.extend(struct.pack(">I4s", len(compressed), b"IDAT") + compressed + struct.pack(">I", crc))
    
    # IEND
    crc = zlib.crc32(b"IEND")
    png_data.extend(struct.pack(">I4s", 0, b"IEND") + struct.pack(">I", crc))
    
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, "wb") as f:
        f.write(png_data)

def convert_emerald_follower(species_dir, out_dir, species_name):
    ow_png = os.path.join(species_dir, "overworld.png")
    if not os.path.exists(ow_png):
        return False
        
    try:
        w, h, pixels, plte = decode_png(ow_png)
    except Exception as e:
        print(f"Error decoding {ow_png}: {e}")
        return False
        
    norm_pal = parse_jasc_pal(os.path.join(species_dir, "overworld_normal.pal")) or plte
    shiny_pal = parse_jasc_pal(os.path.join(species_dir, "overworld_shiny.pal")) or norm_pal
    
    frame_src_size = h
    num_frames = w // frame_src_size
    frame_mapping = [0, 2, 4, 1, 3, 5] if num_frames >= 6 else [0, 0, 0, 0, 0, 0]
    
    target_w, target_h = 16, 16
    
    for is_shiny, pal, suffix in [(False, norm_pal, ""), (True, shiny_pal, "_shiny")]:
        out_pixels = []
        for dst_idx in range(6):
            src_frame = frame_mapping[dst_idx]
            src_x_offset = src_frame * frame_src_size
            
            # Find exact bounding box for this specific frame
            min_x, max_x, min_y, max_y = frame_src_size, 0, h, 0
            for y in range(h):
                for x in range(frame_src_size):
                    if pixels[y][src_x_offset + x] != 0:
                        min_x = min(min_x, x)
                        max_x = max(max_x, x)
                        min_y = min(min_y, y)
                        max_y = max(max_y, y)
                        
            if min_x > max_x:
                min_x, max_x, min_y, max_y = 8, 23, 14, 29
                
            # For side frames (src_frame 4 & 5 facing left), align from min_x so snout/front is 100% visible
            if src_frame in [4, 5]:
                crop_x = min_x
                if crop_x + target_w > frame_src_size:
                    crop_x = frame_src_size - target_w
                if crop_x < 0: crop_x = 0
            else:
                # Down and Up frames: center horizontally around the content
                content_center = (min_x + max_x) // 2
                crop_x = content_center - target_w // 2
                if crop_x + target_w > frame_src_size:
                    crop_x = frame_src_size - target_w
                if crop_x < 0: crop_x = 0
                
            # Ground vertically at max_y
            crop_y = max_y - target_h + 1
            if crop_y + target_h > h:
                crop_y = h - target_h
            if crop_y < 0: crop_y = 0
            
            for row in range(target_h):
                sy = crop_y + row
                row_rgba = []
                for col in range(target_w):
                    sx = crop_x + col
                    pal_idx = pixels[sy][src_x_offset + sx] if (0 <= sx < frame_src_size and 0 <= sy < h) else 0
                    if pal_idx == 0:
                        row_rgba.append((0, 0, 0, 0)) # transparent
                    else:
                        if pal and pal_idx < len(pal):
                            r, g, b = pal[pal_idx]
                            row_rgba.append((r, g, b, 255))
                        else:
                            row_rgba.append((0, 0, 0, 0))
                out_pixels.append(row_rgba)
                
        out_file = os.path.join(out_dir, f"{species_name.lower()}{suffix}.png")
        write_rgba_png(out_file, target_w, target_h * 6, out_pixels)
        
    return True

def main():
    parser = argparse.ArgumentParser(description="Import Pokemon overworld follower sprites from pokeemerald-expansion")
    parser.add_argument("species", nargs="*", help="Specific species names to import (e.g. pikachu cyndaquil)")
    parser.add_argument("--emerald-dir", default=DEFAULT_EMERALD_DIR, help="Path to pokeemerald graphics/pokemon folder")
    parser.add_argument("--out-dir", default=DEFAULT_OUT_DIR, help="Destination folder in mod")
    parser.add_argument("--all", action="store_true", help="Import all available species in pokeemerald")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.emerald_dir):
        print(f"Error: Emerald directory not found at {args.emerald_dir}")
        sys.exit(1)
        
    if args.all:
        species_list = [d for d in os.listdir(args.emerald_dir) if os.path.isdir(os.path.join(args.emerald_dir, d))]
    elif args.species:
        species_list = args.species
    else:
        species_list = [
            "pikachu", "bulbasaur", "ivysaur", "venusaur", "charmander", "charmeleon", "charizard",
            "squirtle", "wartortle", "blastoise", "caterpie", "metapod", "butterfree", "weedle", "kakuna", "beedrill",
            "pidgey", "pidgeotto", "pidgeot", "rattata", "raticate", "spearow", "fearow", "ekans", "arbok",
            "raichu", "sandshrew", "sandslash", "nidoran_f", "nidorina", "nidoqueen", "nidoran_m", "nidorino", "nidoking",
            "clefairy", "clefable", "vulpix", "ninetales", "jigglypuff", "wigglytuff", "zubat", "golbat", "oddish",
            "gloom", "vileplume", "paras", "parasect", "venonat", "venomoth", "diglett", "dugtrio", "meowth", "persian",
            "psyduck", "golduck", "mankey", "primeape", "growlithe", "arcanine", "poliwag", "poliwhirl", "poliwrath",
            "abra", "kadabra", "alakazam", "machop", "machoke", "machamp", "bellsprout", "weepinbell", "victreebel",
            "tentacool", "tentacruel", "geodude", "graveler", "golem", "ponyta", "rapidash", "slowpoke", "slowbro",
            "magnemite", "magneton", "farfetchd", "doduo", "dodrio", "seel", "dewgong", "grimer", "muk", "shellder",
            "cloyster", "gastly", "haunter", "gengar", "onix", "drowzee", "hypno", "krabby", "kingler", "voltorb",
            "electrode", "exeggcute", "exeggutor", "cubone", "marowak", "hitmonlee", "hitmonchan", "lickitung",
            "koffing", "weezing", "rhyhorn", "rhydon", "chansey", "tangela", "kangaskhan", "horsea", "seadra",
            "goldeen", "seaking", "staryu", "starmie", "mr_mime", "scyther", "jynx", "electabuzz", "magmar",
            "pinsir", "tauros", "magikarp", "gyarados", "lapras", "ditto", "eevee", "vaporeon", "jolteon", "flareon",
            "porygon", "omanyte", "omastar", "kabuto", "kabutops", "aerodactyl", "snorlax", "articuno", "zapdos",
            "moltres", "dratini", "dragonair", "dragonite", "mewtwo", "mew",
            # Gen 2
            "chikorita", "bayleef", "meganium", "cyndaquil", "quilava", "typhlosion", "totodile", "croconaw", "feraligatr",
            "sentret", "furret", "hoothoot", "noctowl", "ledyba", "ledian", "spinarak", "ariados", "crobat",
            "chinchou", "lanturn", "pichu", "cleffa", "igglybuff", "togepi", "togetic", "natu", "xatu", "mareep",
            "flaaffy", "ampharos", "bellossom", "marill", "azumarill", "sudowoodo", "politoed", "hoppip", "skiploom",
            "jumpluff", "aipom", "sunkern", "sunflora", "yanma", "wooper", "quagsire", "espeon", "umbreon",
            "murkrow", "slowking", "misdreavus", "unown", "wobbuffet", "girafarig", "pineco", "forretress",
            "dunsparce", "gligar", "steelix", "snubbull", "granbull", "qwilfish", "scizor", "shuckle", "heracross",
            "sneasel", "teddiursa", "ursaring", "slugma", "magcargo", "swinub", "piloswine", "corsola", "remoraid",
            "octillery", "delibird", "mantine", "skarmory", "houndour", "houndoom", "kingdra", "phanpy", "donphan",
            "porygon2", "stantler", "smeargle", "tyrogue", "hitmontop", "smoochum", "elekid", "magby", "miltank",
            "blissey", "raikou", "entei", "suicune", "larvitar", "pupitar", "tyranitar", "lugia", "ho_oh", "celebi",
            # Gen 3
            "treecko", "grovyle", "sceptile", "torchic", "combusken", "blaziken", "mudkip", "marshtomp", "swampert",
            "ralts", "kirlia", "gardevoir", "rayquaza", "kyogre", "groudon"
        ]
        
    count = 0
    for sp in species_list:
        sp_clean = sp.lower().replace(" ", "_").replace("-", "_")
        sp_dir = os.path.join(args.emerald_dir, sp_clean)
        if convert_emerald_follower(sp_dir, args.out_dir, sp_clean):
            count += 1
            print(f"[{count}/{len(species_list)}] Imported 1:1 crisp follower: {sp_clean}")
            
    print(f"Successfully imported {count} crisp follower sprites into {args.out_dir}")

if __name__ == "__main__":
    main()
