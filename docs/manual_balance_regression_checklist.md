# Manual Balance Regression Checklist

## Setup

- Build startet ohne Resource-Load-Fehler.
- Player, LevelProgression, Wave, Progression-Daten sind geladen.
- Keine `push_error`/`push_warning` zu fehlenden IDs/Definitions.

## Level-Up / Progression

- Level 1: Popup zeigt valide Optionen (keine leeren Titel, keine Null-Icons bei definierten Icons).
- Level 5: Unlock-Option `charged_ki_blast` erscheint.
- Level 9: Unlock-Option `barrier` erscheint.
- Level 13: Unlock-Option `energy_ball` erscheint.
- Option-Anwendung mutiert exakt einen Zustand (keine Doppelanwendung).

## Combat

- Ki-Blast: Schaden/Speed/Size fuehlen sich baseline-konsistent an.
- Charged-Ki-Blast: Charge-Time und Damage-Ramp korrekt.
- Energy-Ball: unbegrenztes Pierce bleibt aktiv.
- Barrier: Lifetime/Absorb/Reflect funktionieren.
- Dash-Upgrades: Cooldown/Distance/Invuln/Phase funktionieren inkl. Kollisionsverhalten.

## Spawn

- Spawnrate startet erwartungsgemaess.
- Spawn-Druck steigt entsprechend Pacing-/Wave-Daten.
- Keine Endlosschleife ohne Enemy-Spawn.

## Data Integrity

- Fehlende Ability-/Upgrade-IDs brechen im Debug sichtbar ab (fail-fast) statt silent fallback.
- Keine implizite Directory-Discovery fuer Progression-Definitionen.
- Run-Balancing laesst sich ueber zentrale Run-Resource tauschen.
