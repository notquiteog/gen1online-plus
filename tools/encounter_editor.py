#!/usr/bin/env python3
"""
Pokemon Crystal - Route & Landmark Encounter Editor GUI Tool
A lightweight visual tool to customize wild Pokemon encounter tables across ALL 95+ landmarks & routes,
including Morning/Day/Night cycles, Water, Fishing, and Overworld Rare Encounters.
Directly edits and exports to mods/gen1online-plus/data/encounter_tables.json.
"""

import os
import sys
import json
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog

DEFAULT_DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "encounter_tables.json")

ALL_SPECIES = [
    # Gen 1
    "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER", "CHARMELEON", "CHARIZARD",
    "SQUIRTLE", "WARTORTLE", "BLASTOISE", "CATERPIE", "METAPOD", "BUTTERFREE",
    "WEEDLE", "KAKUNA", "BEEDRILL", "PIDGEY", "PIDGEOTTO", "PIDGEOT", "RATTATA",
    "RATICATE", "SPEAROW", "FEAROW", "EKANS", "ARBOK", "PIKACHU", "RAICHU",
    "SANDSHREW", "SANDSLASH", "NIDORAN_F", "NIDORINA", "NIDOQUEEN", "NIDORAN_M",
    "NIDORINO", "NIDOKING", "CLEFAIRY", "CLEFABLE", "VULPIX", "NINETALES",
    "JIGGLYPUFF", "WIGGLYTUFF", "ZUBAT", "GOLBAT", "ODDISH", "GLOOM", "VILEPLUME",
    "PARAS", "PARASECT", "VENONAT", "VENOMOTH", "DIGLETT", "DUGTRIO", "MEOWTH",
    "PERSIAN", "PSYDUCK", "GOLDUCK", "MANKEY", "PRIMEAPE", "GROWLITHE", "ARCANINE",
    "POLIWAG", "POLIWHIRL", "POLIWRATH", "ABRA", "KADABRA", "ALAKAZAM", "MACHOP",
    "MACHOKE", "MACHAMP", "BELLSPROUT", "WEEPINBELL", "VICTREEBEL", "TENTACOOL",
    "TENTACRUEL", "GEODUDE", "GRAVELER", "GOLEM", "PONYTA", "RAPIDASH", "SLOWPOKE",
    "SLOWBRO", "MAGNEMITE", "MAGNETON", "FARFETCHD", "DODUO", "DODRIO", "SEEL",
    "DEWGONG", "GRIMER", "MUK", "SHELLDER", "CLOYSTER", "GASTLY", "HAUNTER",
    "GENGAR", "ONIX", "DROWZEE", "HYPNO", "KRABBY", "KINGLER", "VOLTORB",
    "ELECTRODE", "EXEGGCUTE", "EXEGGUTOR", "CUBONE", "MAROWAK", "HITMONLEE",
    "HITMONCHAN", "LICKITUNG", "KOFFING", "WEEZING", "RHYHORN", "RHYDON", "CHANSEY",
    "TANGELA", "KANGASKHAN", "HORSEA", "SEADRA", "GOLDEEN", "SEAKING", "STARYU",
    "STARMIE", "MR_MIME", "SCYTHER", "JYNX", "ELECTABUZZ", "MAGMAR", "PINSIR",
    "TAUROS", "MAGIKARP", "GYARADOS", "LAPRAS", "DITTO", "EEVEE", "VAPOREON",
    "JOLTEON", "FLAREON", "PORYGON", "OMANYTE", "OMASTAR", "KABUTO", "KABUTOPS",
    "AERODACTYL", "SNORLAX", "ARTICUNO", "ZAPDOS", "MOLTRES", "DRATINI", "DRAGONAIR",
    "DRAGONITE", "MEWTWO", "MEW",
    # Gen 2
    "CHIKORITA", "BAYLEEF", "MEGANIUM", "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
    "TOTODILE", "CROCONAW", "FERALIGATR", "SENTRET", "FURRET", "HOOTHOOT", "NOCTOWL",
    "LEDYBA", "LEDIAN", "SPINARAK", "ARIADOS", "CROBAT", "CHINCHOU", "LANTURN",
    "PICHU", "CLEFFA", "IGGLYBUFF", "TOGEPI", "TOGETIC", "NATU", "XATU", "MAREEP",
    "FLAAFFY", "AMPHAROS", "BELLOSSOM", "MARILL", "AZUMARILL", "SUDOWOODO", "POLITOED",
    "HOPPIP", "SKIPLOOM", "JUMPLUFF", "AIPOM", "SUNKERN", "SUNFLORA", "YANMA", "WOOPER",
    "QUAGSIRE", "ESPEON", "UMBREON", "MURKROW", "SLOWKING", "MISDREAVUS", "UNOWN",
    "WOBBUFFET", "GIRAFARIG", "PINECO", "FORRETRESS", "DUNSPARCE", "GLIGAR", "STEELIX",
    "SNUBBULL", "GRANBULL", "QWILFISH", "SCIZOR", "SHUCKLE", "HERACROSS", "SNEASEL",
    "TEDDIURSA", "URSARING", "SLUGMA", "MAGCARGO", "SWINUB", "PILOSWINE", "CORSOLA",
    "REMORAID", "OCTILLERY", "DELIBIRD", "MANTINE", "SKARMORY", "HOUNDOUR", "HOUNDOOM",
    "KINGDRA", "PHANPY", "DONPHAN", "PORYGON2", "STANTLER", "SMEARGLE", "TYROGUE",
    "HITMONTOP", "SMOOCHUM", "ELEKID", "MAGBY", "MILTANK", "BLISSEY", "RAIKOU",
    "ENTEI", "SUICUNE", "LARVITAR", "PUPITAR", "TYRANITAR", "LUGIA", "HO_OH", "CELEBI",
    # Gen 3 bonus
    "TREECKO", "GROVYLE", "SCEPTILE", "TORCHIC", "COMBUSKEN", "BLAZIKEN", "MUDKIP",
    "MARSHTOMP", "SWAMPERT", "RALTS", "KIRLIA", "GARDEVOIR", "RAYQUAZA", "KYOGRE", "GROUDON"
]

class EncounterEditorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Pokemon Crystal - Route & Landmark Encounter Editor")
        self.root.geometry("880x680")
        self.root.minsize(780, 580)

        self.db_path = DEFAULT_DB_PATH
        self.db_data = {}

        self.current_route = None
        self.current_category = "grass" # grass, water, fish, rare_ow
        self.current_tod = "MORN"       # MORN, DAY, NITE

        self.load_data()
        self.build_ui()

    def load_data(self):
        if os.path.exists(self.db_path):
            try:
                with open(self.db_path, "r", encoding="utf-8") as f:
                    self.db_data = json.load(f)
            except Exception as e:
                messagebox.showerror("Error", f"Failed to load encounter database:\n{e}")
                self.db_data = {}
        else:
            self.db_data = {}

    def save_data(self):
        try:
            os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
            # Ensure both raw key and LANDMARK_ key are synchronized
            for k, v in list(self.db_data.items()):
                if not k.startswith("LANDMARK_"):
                    self.db_data[f"LANDMARK_{k}"] = v
                else:
                    raw_k = k[9:]
                    self.db_data[raw_k] = v

            with open(self.db_path, "w", encoding="utf-8") as f:
                json.dump(self.db_data, f, indent=2)
            messagebox.showinfo("Saved", f"Encounter database saved successfully to:\n{self.db_path}\nTotal Landmarks: {len(self.get_unique_routes())}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save encounter database:\n{e}")

    def get_unique_routes(self):
        # Filter out redundant LANDMARK_ prefixed entries for clean dropdown list
        unique = []
        for k in self.db_data.keys():
            clean = k[9:] if k.startswith("LANDMARK_") else k
            if clean not in unique:
                unique.append(clean)
        return sorted(unique)

    def build_ui(self):
        # Top Control Bar (Route & Category Selectors)
        top_frame = ttk.LabelFrame(self.root, text="Map / Landmark & Category Selection", padding=10)
        top_frame.pack(fill="x", padx=10, pady=5)

        ttk.Label(top_frame, text="Select Route / Landmark:").grid(row=0, column=0, sticky="w", padx=5)
        self.route_combo = ttk.Combobox(top_frame, state="readonly", width=34)
        self.route_combo.grid(row=0, column=1, padx=5, pady=2)
        self.route_combo.bind("<<ComboboxSelected>>", self.on_route_change)

        btn_new_route = ttk.Button(top_frame, text="+ Add Landmark", command=self.add_new_route)
        btn_new_route.grid(row=0, column=2, padx=5)

        ttk.Label(top_frame, text="Category:").grid(row=1, column=0, sticky="w", padx=5, pady=5)
        self.cat_combo = ttk.Combobox(top_frame, state="readonly", width=22,
                                     values=["Tall Grass / Land (Wild)", "Water (Surfing)", "Fishing (Rods)", "Overworld Rare Spawns"])
        self.cat_combo.current(0)
        self.cat_combo.grid(row=1, column=1, sticky="w", padx=5, pady=5)
        self.cat_combo.bind("<<ComboboxSelected>>", self.on_category_change)

        self.tod_label = ttk.Label(top_frame, text="Time of Day:")
        self.tod_label.grid(row=1, column=2, sticky="w", padx=5)
        self.tod_combo = ttk.Combobox(top_frame, state="readonly", width=16,
                                     values=["Morning (MORN)", "Day (DAY)", "Night (NITE)"])
        self.tod_combo.current(0)
        self.tod_combo.grid(row=1, column=3, sticky="w", padx=5)
        self.tod_combo.bind("<<ComboboxSelected>>", self.on_tod_change)

        # Slots Table Frame
        slots_frame = ttk.LabelFrame(self.root, text="Encounter Slots", padding=10)
        slots_frame.pack(fill="both", expand=True, padx=10, pady=5)

        columns = ("slot", "species", "min_lvl", "max_lvl", "chance")
        self.tree = ttk.Treeview(slots_frame, columns=columns, show="headings", selectmode="browse")
        self.tree.heading("slot", text="Slot #")
        self.tree.heading("species", text="Pokemon Species")
        self.tree.heading("min_lvl", text="Min Level")
        self.tree.heading("max_lvl", text="Max Level")
        self.tree.heading("chance", text="Spawn Chance %")

        self.tree.column("slot", width=60, anchor="center")
        self.tree.column("species", width=240, anchor="w")
        self.tree.column("min_lvl", width=100, anchor="center")
        self.tree.column("max_lvl", width=100, anchor="center")
        self.tree.column("chance", width=140, anchor="center")

        tree_scroll = ttk.Scrollbar(slots_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=tree_scroll.set)
        self.tree.pack(side="left", fill="both", expand=True)
        tree_scroll.pack(side="right", fill="y")

        # Slot Edit Bar
        edit_bar = ttk.Frame(self.root, padding=10)
        edit_bar.pack(fill="x", padx=10)

        btn_add = ttk.Button(edit_bar, text="+ Add Slot", command=self.add_slot)
        btn_add.pack(side="left", padx=5)

        btn_edit = ttk.Button(edit_bar, text="Edit Slot", command=self.edit_slot)
        btn_edit.pack(side="left", padx=5)

        btn_delete = ttk.Button(edit_bar, text="Delete Slot", command=self.delete_slot)
        btn_delete.pack(side="left", padx=5)

        self.prob_label = ttk.Label(edit_bar, text="Total Probability: 0%", font=("Segoe UI", 10, "bold"))
        self.prob_label.pack(side="right", padx=10)

        # Bottom Action Bar
        bottom_bar = ttk.Frame(self.root, padding=10)
        bottom_bar.pack(fill="x", padx=10, pady=5)

        ttk.Label(bottom_bar, text=f"Mod File: mods/gen1online-plus/data/encounter_tables.json (ROM/Recomp untouched)", font=("Segoe UI", 8), foreground="gray").pack(side="left", padx=5)

        btn_save = ttk.Button(bottom_bar, text="Save & Export to Game / Server", command=self.save_data)
        btn_save.pack(side="right", padx=5)

        btn_reload = ttk.Button(bottom_bar, text="Reload Database", command=self.reload_data)
        btn_reload.pack(side="right", padx=5)

        self.refresh_route_list()

    def refresh_route_list(self):
        routes = self.get_unique_routes()
        self.route_combo["values"] = routes
        if routes:
            if "ROUTE_29" in routes:
                self.route_combo.set("ROUTE_29")
                self.current_route = "ROUTE_29"
            else:
                self.route_combo.current(0)
                self.current_route = routes[0]
            self.refresh_slots_view()
        else:
            self.current_route = None

    def on_route_change(self, event=None):
        self.current_route = self.route_combo.get()
        self.refresh_slots_view()

    def on_category_change(self, event=None):
        cat_str = self.cat_combo.get()
        if "Grass" in cat_str:
            self.current_category = "grass"
            self.tod_combo.configure(state="readonly")
        elif "Water" in cat_str:
            self.current_category = "water"
            self.tod_combo.configure(state="disabled")
        elif "Fish" in cat_str:
            self.current_category = "fish"
            self.tod_combo.configure(state="disabled")
        else:
            self.current_category = "rare_ow"
            self.tod_combo.configure(state="disabled")
        self.refresh_slots_view()

    def on_tod_change(self, event=None):
        tod_str = self.tod_combo.get()
        if "MORN" in tod_str: self.current_tod = "MORN"
        elif "DAY" in tod_str: self.current_tod = "DAY"
        else: self.current_tod = "NITE"
        self.refresh_slots_view()

    def get_current_route_data(self):
        if not self.current_route: return None
        return self.db_data.get(self.current_route) or self.db_data.get(f"LANDMARK_{self.current_route}")

    def get_current_slots_list(self):
        rdata = self.get_current_route_data()
        if not rdata:
            return []
        if self.current_category == "grass":
            grass = rdata.setdefault("grass", {})
            return grass.setdefault(self.current_tod, [])
        elif self.current_category == "water":
            return rdata.setdefault("water", [])
        elif self.current_category == "fish":
            return rdata.setdefault("fish", [])
        elif self.current_category == "rare_ow":
            return rdata.setdefault("rare_ow", [])
        return []

    def refresh_slots_view(self):
        for item in self.tree.get_children():
            self.tree.delete(item)

        slots = self.get_current_slots_list()
        total_prob = 0
        for i, s in enumerate(slots):
            sp = s.get("species", "UNKNOWN")
            min_l = s.get("minLevel", 1)
            max_l = s.get("maxLevel", min_l)
            chance = s.get("chance", 0)
            total_prob += chance
            self.tree.insert("", "end", iid=str(i), values=(i + 1, sp, min_l, max_l, f"{chance}%"))

        if total_prob == 100 or self.current_category == "rare_ow":
            self.prob_label.config(text=f"Total Probability: {total_prob}% (VALID)", foreground="green")
        else:
            self.prob_label.config(text=f"Total Probability: {total_prob}% (Aim for 100%)", foreground="dark orange")

    def add_slot(self):
        if not self.current_route:
            messagebox.showwarning("Warning", "Please select or create a landmark first!")
            return
        self.open_slot_editor(None)

    def edit_slot(self):
        sel = self.tree.selection()
        if not sel:
            messagebox.showwarning("Warning", "Please select a slot to edit!")
            return
        idx = int(sel[0])
        self.open_slot_editor(idx)

    def delete_slot(self):
        sel = self.tree.selection()
        if not sel:
            return
        idx = int(sel[0])
        slots = self.get_current_slots_list()
        if 0 <= idx < len(slots):
            del slots[idx]
            self.refresh_slots_view()

    def open_slot_editor(self, index):
        dialog = tk.Toplevel(self.root)
        dialog.title("Edit Slot" if index is not None else "Add Slot")
        dialog.geometry("380x280")
        dialog.transient(self.root)
        dialog.grab_set()

        slots = self.get_current_slots_list()
        slot_data = slots[index] if index is not None else {"species": "PIDGEY", "minLevel": 3, "maxLevel": 4, "chance": 10}

        ttk.Label(dialog, text="Pokemon Species:").grid(row=0, column=0, padx=10, pady=10, sticky="w")
        sp_combo = ttk.Combobox(dialog, values=ALL_SPECIES, width=22)
        sp_combo.set(slot_data.get("species", "PIDGEY"))
        sp_combo.grid(row=0, column=1, padx=10, pady=10)

        ttk.Label(dialog, text="Min Level:").grid(row=1, column=0, padx=10, pady=5, sticky="w")
        min_spin = ttk.Spinbox(dialog, from_=1, to=100, width=10)
        min_spin.set(slot_data.get("minLevel", 3))
        min_spin.grid(row=1, column=1, padx=10, pady=5, sticky="w")

        ttk.Label(dialog, text="Max Level:").grid(row=2, column=0, padx=10, pady=5, sticky="w")
        max_spin = ttk.Spinbox(dialog, from_=1, to=100, width=10)
        max_spin.set(slot_data.get("maxLevel", slot_data.get("minLevel", 3)))
        max_spin.grid(row=2, column=1, padx=10, pady=5, sticky="w")

        ttk.Label(dialog, text="Spawn Chance %:").grid(row=3, column=0, padx=10, pady=5, sticky="w")
        chance_spin = ttk.Spinbox(dialog, from_=1, to=100, width=10)
        chance_spin.set(slot_data.get("chance", 10))
        chance_spin.grid(row=3, column=1, padx=10, pady=5, sticky="w")

        def save_slot():
            sp = sp_combo.get().strip().upper()
            try:
                min_l = int(min_spin.get())
                max_l = int(max_spin.get())
                ch = int(chance_spin.get())
            except ValueError:
                messagebox.showerror("Error", "Levels and Chance must be valid integers!")
                return

            if max_l < min_l:
                max_l = min_l

            new_slot = {"species": sp, "minLevel": min_l, "maxLevel": max_l, "chance": ch}
            if index is not None:
                slots[index] = new_slot
            else:
                slots.append(new_slot)

            dialog.destroy()
            self.refresh_slots_view()

        btn_save = ttk.Button(dialog, text="Apply Slot", command=save_slot)
        btn_save.grid(row=4, column=0, columnspan=2, pady=20)

    def add_new_route(self):
        new_name = simpledialog.askstring("New Landmark", "Enter Landmark Identifier (e.g. ROUTE_36, MT_MOON):")
        if new_name:
            clean_name = new_name.strip().upper().replace(" ", "_")
            if clean_name in self.db_data or f"LANDMARK_{clean_name}" in self.db_data:
                messagebox.showwarning("Warning", "Landmark already exists!")
                return
            entry = {
                "name": clean_name.replace("_", " ").title(),
                "grassRate": 25,
                "waterRate": 10,
                "grass": {"MORN": [], "DAY": [], "NITE": []},
                "rare_ow": [],
                "water": [],
                "fish": []
            }
            self.db_data[clean_name] = entry
            self.db_data[f"LANDMARK_{clean_name}"] = entry
            self.refresh_route_list()
            self.route_combo.set(clean_name)
            self.on_route_change()

    def reload_data(self):
        self.load_data()
        self.refresh_route_list()
        messagebox.showinfo("Reloaded", "Encounter database reloaded from disk.")

def main():
    root = tk.Tk()
    app = EncounterEditorApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
