# Active Ability Concepts

Active abilities should be **panic buttons with a target**, not passive stat
upgrades. The player should get a short aiming beat, an unmistakable payoff,
and a visible window in which they feel stronger. These concepts complement
Meteor's delayed burst damage and Frost Nova's enemy control without replacing
either role.

## Recommended first addition: Overdrive

Select a medium-sized area and supercharge every tower inside it for a short
time.

- **Effect:** Towers in a 110-unit radius attack 70% faster for 7 seconds.
- **Cooldown:** 38 seconds.
- **Enhanced effect:** 125-unit radius, 85% faster attacks, and 8 seconds.
- **Why it feels powerful:** The player chooses their best kill zone and gets an
  immediate barrage. It scales naturally with the defense they built, while the
  area limit rewards good tower clustering and timing.
- **Best moment:** A boss or mixed threat pack enters the player's most expensive
  cluster of towers.
- **Readability:** On cast, send a gold-blue ring from the target point through
  affected towers. While active, give each tower a thin pulsing outline, small
  upward sparks, and a rotating arc around its base. Fade the outline during the
  final second so the expiration is predictable.
- **Important rule:** Snapshot the affected towers when cast. Towers placed or
  moved into the area afterward do not gain the buff, so the player can clearly
  see exactly what the click accomplished.

Overdrive is the best prototype candidate because it adds the requested tower
buffing verb, creates dramatic audiovisual feedback, and reuses the existing
point-and-radius targeting model.

## Power Grid

Select two nearby towers to link them into a temporary shared power circuit.

- **Effect:** For 9 seconds, both towers gain 35% attack speed and 25% range.
  Whenever either tower fires, the other tower immediately reduces its current
  attack cooldown by 0.12 seconds.
- **Cooldown:** 34 seconds.
- **Enhanced effect:** The link may chain through one additional tower located
  near the line between the selected pair.
- **Why it feels powerful:** It turns two favorite towers into a coordinated
  centerpiece and makes unusual cross-lane pairings exciting. Unlike Overdrive,
  it rewards selecting individual high-value towers rather than a dense cluster.
- **Best moment:** Two lanes are threatening at once, or a durable target is
  moving from one tower's range into another's.
- **Readability:** Draw an animated electrical cable between linked towers. A
  bright pulse travels across the cable whenever either tower fires, and both
  bases share the same cyan highlight.
- **Targeting note:** First click selects a tower and previews valid partners;
  second click confirms. Right-click cancels either stage.

## Last Stand

Select an area to fortify a weak section of the defense and turn near-leaks into
a comeback opportunity.

- **Effect:** For 6 seconds, affected towers gain 45% attack speed and always
  prioritize the enemy furthest along the path. The first time an enemy would
  leave the selected area, all affected towers instantly finish their current
  wind-up and fire at that enemy if it is in range.
- **Cooldown:** 45 seconds.
- **Enhanced effect:** The emergency volley can trigger twice, at least 1.5
  seconds apart.
- **Why it feels powerful:** The ability responds directly to the frightening
  moment when enemies break through, without granting lives or automatically
  deleting the wave. The player's existing towers still deliver the save.
- **Best moment:** Runners or other survivors escape the main kill zone.
- **Readability:** Tint the selected ground area amber, mark the leading enemy
  with a bold reticle, and briefly flash affected towers white when the emergency
  volley triggers.
- **Important rule:** The temporary targeting override must not permanently
  change any tower's player-selected targeting mode.

## Gravity Well

Select a path area and compress an advancing formation into a high-value target
for the player's towers.

- **Effect:** Over 3 seconds, enemies in a 95-unit radius are pulled backward
  toward the cast point, with bosses and heavy enemies resisting most of the
  displacement. The well then bursts for modest damage.
- **Cooldown:** 40 seconds.
- **Enhanced effect:** 110-unit radius and a stronger final burst.
- **Why it feels powerful:** It visibly reshapes a bad wave, creates fresh splash
  and chain opportunities, and invites combinations with Cannon, Shock, Meteor,
  and tower buffs. It is distinct from Frost Nova because enemy spacing and
  formation change rather than simply movement speed.
- **Best moment:** A formation has stretched out or fast enemies are escaping
  their escorts.
- **Readability:** Spiral path dust and enemy motion trails inward, then collapse
  into a dark-purple impact ring. Preview arrows should show the pull direction
  before the player confirms.
- **Safety rule:** Adjust path progress rather than raw world coordinates so an
  enemy cannot be dragged off-path or across an invalid branch.

## Suggested rollout

1. Prototype **Overdrive** first and tune it around one additional attack from a
   typical tower during a normal engagement. It should be impressive without
   making permanent tower upgrades feel irrelevant.
2. Add **Gravity Well** next because it creates the strongest combo stories with
   the existing damage and control abilities.
3. Consider **Power Grid** when two-stage targeting has a reusable interaction
   pattern and **Last Stand** after temporary targeting overrides are robust.
4. Initially let the player bring only two abilities. Unlocking more choices is
   interesting only if there is a clear pre-run loadout picker; automatically
   adding every unlocked ability would remove meaningful tradeoffs.

## Shared implementation and balance guardrails

- Ability definitions should declare their target mode, radius, duration,
  cooldown, effect values, and enhanced values as data.
- Tower buffs should store an expiry time and multiplier on each affected tower.
  Derive effective attack timing from those values instead of permanently
  rewriting base tower stats.
- Existing shots already in flight should not change. For haste, scale the
  tower's remaining cooldown and wind-up consistently so activation produces an
  immediate response without granting a full free shot to every tower.
- Every sustained ability needs both a world-area indicator and a per-tower or
  per-enemy status cue. The player should never need to infer whether an entity
  was included at the edge of the cast.
- Prefer multiplicative stacking with a conservative cap if future modules or
  abilities add more attack-speed modifiers.
- Cooldowns should remain independent. Combinations such as Gravity Well into
  Meteor or Overdrive should be encouraged; their opportunity cost is spending
  both equipped cooldowns at once.
