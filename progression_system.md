# Progression System (Einsteiger-Doku)

Diese Datei erklaert dein aktuelles Progression-System im Projekt `godot-survivors-game`.
Ziel: Du sollst verstehen, **wie alles zusammenhaengt** und **wie du es sauber erweiterst**.

## 1) Kurzueberblick

Dein Progression-System hat 3 Ebenen:

1. **XP + Level**
- Enemies sterben -> XP-Orbs spawnen -> Player sammelt XP -> Level steigt.

2. **Level-Up Auswahl**
- Bei jedem Level-Up oeffnet sich ein Popup mit bis zu 3 Optionen.
- Optionen sind getypt (`LevelUpOption`), nicht mehr lose Dictionaries.

3. **Anwenden der Wahl**
- Neue Waffe freischalten, Waffenupgrade anwenden oder Player-Utility upgraden.

## 2) Voller Ablauf eines Level-Ups

1. Enemy stirbt in `scripts/main.gd` (`_on_enemy_died`) und ruft `XPOrbManager.spawn_orb(...)`.
2. Orb wird vom Player eingesammelt (`scripts/pickups/xp_orb.gd`), Signal `collected` geht an `XPOrbManager`.
3. `XPOrbManager` ruft `player.collect_xp(amount)`.
4. `Player.collect_xp` delegiert an `PlayerProgression.add_xp(...)`.
5. `PlayerProgression` emittiert:
- `xp_changed`
- bei Schwelle: `leveled_up(new_level)`
6. `Player` leitet `leveled_up` weiter an `Main`.
7. `Main` queued das Level in `_pending_level_ups` und zeigt nacheinander Popups.
8. `Main._build_level_up_options(level)` baut die Auswahl:
- ggf. Unlock-Optionen (neue Waffen)
- Waffen-Upgrades
- Utility-Upgrades
9. `LevelUpPopup` zeigt Optionen und emittiert `option_selected(LevelUpOption)`.
10. `Main._apply_level_up_option(...)` fuehrt die gewaehlte Option aus.

## 3) Welche Skripte arbeiten zusammen?

## XP + Level
- `scripts/pickups/xp_orb_manager.gd`
- Spawn, Pooling, Einsammel-Handling von XP-Orbs.
- `scripts/pickups/xp_orb.gd`
- Bewegung/Magnet zum Player, Signal bei Einsammeln.
- `scripts/player/player_progression.gd`
- Berechnet XP-Schwelle und Level-Ups.
- `scripts/player/player.gd`
- Bruecke: `collect_xp` -> `PlayerProgression`, leitet Signale weiter.

## Orchestrierung + UI
- `scripts/main.gd`
- Zentrale Orchestrierung fuer Level-Up Queue, Popup anzeigen, Option anwenden.
- `scripts/ui/level_up_popup.gd`
- Zeigt 1..3 `LevelUpOption` an und gibt Auswahl zurueck.
- `scripts/ui/action_button_bar.gd`
- Aktualisiert Action-Bar Icons aus den Weapon-Slots.

## Weapon-Progression (Kern)
- `scripts/player/player_weapon_system.gd`
- Runtime-Combat (Input, Chargen, Schiessen, VFX/Audio).
- Nutzt `WeaponProgressionModel` fuer Progression-Daten und Upgrade-Regeln.
- `scripts/player/weapon_progression_model.gd`
- Datengetriebene Weapon-Progression:
- laedt Ability/Upgrade-Definitionen aus `.tres`
- verwaltet Slots/Unlocks
- erzeugt Upgrade-Optionen
- wendet Waffenupgrades an
- `scripts/player/weapon_ability_state.gd`
- Runtime-State einer Weapon-Ability (Stats + Upgrade-Zaehler).

## Datenmodelle
- `scripts/data/progression/ability_definition.gd.gd`
- Daten fuer Abilities (Unlock-Level, Verhalten, Stats, Icons, etc.).
- `scripts/data/progression/upgrade_definition.gd.gd`
- Daten fuer Upgrades (Typ, max Stacks, Texte, Icon).
- `scripts/data/progression/level_up_option.gd`
- Typisierte Option im Popup (`new_weapon`, `weapon_upgrade`, `player_upgrade`).

## 4) Wichtige Resource-Ordner

- `resources/progression/abilities/`
- Jede Ability als `.tres` (z. B. `ki_blast.tres`, `barrier.tres`).
- `resources/progression/upgrades/`
- Upgrade-Definitionen (`damage.tres`, `reflect.tres`, ability-spezifische wie `ki_blast_damage.tres`).
- `resources/progression/icons/`
- Atlas-Icons fuer Action-Bar und Level-Up.

## 5) Warum `LevelUpOption` wichtig ist

Frueher wurden freie Dictionaries benutzt (fragil bei Tippfehlern).
Jetzt gibt es eine klare Klasse mit festen Feldern:

- `option_type`
- `ability_id`
- `upgrade_id`
- `title`
- `description`
- `icon`

Das macht Refactors sicherer und den Code leichter lesbar.

## 6) Unlock-Logik (neue Waffen)

Im `WeaponProgressionModel`:

- Jede Weapon hat `unlock_level`.
- Bei Level-Up baut `Main` Optionen.
- Wenn ein echtes Unlock-Milestone-Level erreicht ist:
- Unlock-Optionen werden priorisiert.
- Falls weniger als 3 Unlocks verfuegbar sind, werden mit normalen Upgrades aufgefuellt.
- Beim Anwenden wird immer der **naechste freie Slot** genommen.

## 7) Utility-Upgrades (Dash/Charge-Ki)

Diese liegen aktuell im `Player`:

- Optionen erzeugen: `Player.get_utility_upgrade_options()`
- Anwenden: `Player.apply_utility_upgrade(...)`

Beispiele:
- Dash Cooldown reduzieren
- Dash Distanz erhoehen
- Dash Phase aktivieren
- Charge-Ki Regen/Knockback/AOE erhoehen

## 8) So erweiterst du das System

## A) Neue Weapon-Ability hinzufuegen

1. Neue `.tres` in `resources/progression/abilities/` anlegen.
2. Felder setzen:
- `id`, `progression_domain = weapon`, `display_name`
- `unlock_level`, `unlock_description`
- `behavior` (`projectile` oder `barrier`)
- Stats (`base_cost`, `base_damage_min/max`, etc.)
- `upgrade_ids`
- Icon-Felder
3. Falls Projektil:
- `projectile_scene` setzen
- optional `charge_vfx_scene`, `is_chargeable`, Audio-Varianten
4. Falls Startwaffe:
- `starts_unlocked = true`
- `start_slot_index` setzen

Wichtig:
- `id` muss eindeutig sein.
- `upgrade_ids` muessen zu existierenden Upgrade-Definitionen passen.

## B) Neues Waffen-Upgrade hinzufuegen

1. Upgrade-Typ festlegen (z. B. `damage`, `bounce`, ...).
2. Falls neuer Typ: im `WeaponProgressionModel` erweitern:
- Konstante
- Logik in `apply_weapon_upgrade`
- Stack-Zaehlung in `_get_upgrade_stack_count`
- Anzeige in `_upgrade_display_name` und `_upgrade_description`
3. Neue `.tres` in `resources/progression/upgrades/` anlegen:
- `id`
- `upgrade_type`
- optional `ability_id`
- optional `max_stacks`, `title`, `description`, `icon`
4. Ability `.tres` um `upgrade_ids` erweitern.

## C) Neue Utility-Upgrades (Player) hinzufuegen

1. Neue Konstanten in `player.gd` anlegen.
2. Option in `get_utility_upgrade_options()` hinzufuegen (mit `LevelUpOption.make_player_upgrade`).
3. Verhalten in `apply_utility_upgrade(...)` implementieren.

## D) Popup-Optionstyp erweitern

Wenn du einen ganz neuen Optionstyp willst:

1. Neuen Typ in `LevelUpOption` einfuehren.
2. Optionen an passender Stelle erzeugen (`Main` / Model / Player).
3. `Main._apply_level_up_option(...)` um neuen `match`-Fall erweitern.

## 9) Trennung der Verantwortlichkeiten (wichtig fuer Wartbarkeit)

- `Main`: Ablauf und UI-Orchestrierung.
- `PlayerWeaponSystem`: Combat-Runtime.
- `WeaponProgressionModel`: Daten + Regeln + Upgrade/Unlock-Entscheidungen.
- `Player`: Charakterzustand + Utility-Upgrades.
- `LevelUpPopup`: reine Darstellung/Interaktion.

Wenn du neue Features baust, halte diese Trennung ein. Dann bleibt das System sauber.

## 10) Typische Fehlerquellen

1. `upgrade_ids` verweisen auf nicht vorhandene Upgrade-`id`.
2. Ability hat kein gueltiges Icon -> Option wirkt "leer".
3. Neuer Upgrade-Typ wurde in `.tres` gesetzt, aber nicht in `WeaponProgressionModel`-Logik implementiert.
4. `progression_domain` falsch (Weapon vs. Utility) -> Ability wird nicht im Weapon-Model geladen.
5. Unlock-Level korrekt gesetzt, aber kein freier Slot mehr vorhanden.

## 11) Kurze Checkliste vor jedem Test

1. `id` eindeutig?
2. Icons sichtbar?
3. `unlock_level` sinnvoll?
4. `upgrade_ids` korrekt?
5. Option erscheint im Popup?
6. Auswahl wird korrekt angewendet?

---
