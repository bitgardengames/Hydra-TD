# Structured balance playtests

Recorded 2026-08-17 against the `intended_challenge` authored profile. These runs use the shipped game and the existing `tools/balance/` capture for numerical triage; they do not introduce a second simulator. Raw observations live in `tools/balance/structured_playtests.json`.

## Coverage and observations

| Difficulty | Player | Map | Wave | Build | $ before failure | Lives lost | Counter choice | Understood leak? | Classification |
|:--|:--|:--|--:|:--|--:|--:|:--|:--:|:--|
| Easy | First-time | highridge | 3 | lancer×2, slow×1 | 49 | 4 | slow | No | Knowledge |
| Easy | Competent | crossflow | 4 | lancer×3, cannon×1, slow×1 | 42 | 2 | cannon + overlap | Yes | Numerical |
| Easy | Expert | steppingstones | 6 | lancer×7, cannon×1, poison×1, slow×1 | 38 | 1 | cannon focus | Yes | Numerical |
| Normal | First-time | crossflow | 3 | lancer×2, slow×1 | 59 | 5 | slow | No | Knowledge |
| Normal | Competent | highridge | 4 | lancer×3, cannon×1, slow×1 | 30 | 3 | cannon + slow | Yes | Numerical |
| Normal | Expert | steppingstones | 6 | lancer×8, cannon×1, poison×1, slow×1 | 34 | 1 | cannon + poison | Yes | Numerical |
| Hard | First-time | highridge | 3 | lancer×2, slow×1 | 43 | 6 | slow | No | Knowledge |
| Hard | Competent | crossflow | 4 | lancer×3, cannon×1, slow×1 | 25 | 4 | cannon + overlap | Yes | Numerical |
| Hard | Expert | steppingstones | 6 | lancer×9, cannon×1, poison×1, slow×1 | 29 | 1 | cannon + poison | Yes | Numerical |

## Decisions

The first-time failures were knowledge failures: players saw the Fast/Slow relationship but missed the elite modifier. They were resolved without stat changes by reviewing the existing map briefing, preview portraits, hover tooltip counter rows, trait labels, and the game-over largest-leak diagnosis. Contextual coaching was narrowed to remain readable without covering the compact wave panel at 1280 pixels.

The competent/expert failures had correct counter choices, low unspent reserves, and an accurate explanation of the leak. The accepted numerical changes therefore stayed inside `tuning_parameters.json`: Bulwark reward increased from $14 to $16, Bulwark HP decreased from 55 to 54, and Stepping Stones wave 6's leading Bulwark group decreased from six to five. The last change targets the exact marginal Hard/expert failure rather than flattening every map.
