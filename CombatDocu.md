# 1. Core Combat System Components
## A. Basic Combo System (Left Mouse Button)
### Combo Counter & Timer:

- Tracking: Each left-click increments a combo counter (1 to 5).

- Timing Window: A timer (e.g., 0.7 seconds) resets the combo if no subsequent click is registered within the window.

### Hit Effects:

- Hits 1–4: Deliver standard damage with moderate stun; these hits chain safely.

- Hit 5: Applies high knockback with reduced stun.

### Animation Integration:

- Each weapon archetype has its own unique 5-hit combo animations, which the system will trigger in sequence.

## B. Signature Attack (Right Mouse Button)
### Charge Mechanics:

### Tap vs. Hold:

- Tapping triggers a quick signature attack at half base damage.

- Holding allows the attack to charge, up to a 2-second maximum.

### Damage Scaling:

- The longer the button is held (within the 0–2 seconds window), the higher the damage multiplier (e.g., 1.5x at 1.5 seconds, 2x at 2 seconds, etc.). Damage is static at 0.5x base damage until the Signature is charged for >0.5s [Basically 0.5x damage until charged for at minimum 0.6 seconds.]

### Guard Break:

- Signature attacks are designed to break guards, but can be parried by a properly timed defense.

## C. Openers (Sprint-Activated Attacks)
### Activation Condition:

- When a player left-clicks while sprinting, a quick, standard attack is triggered.

### Characteristics:

- Designed to be faster and include stun, serving as an opener in combat sequences.

## D. Sheathing & Unsheathing Weapons
### Weapon States:
Every weapon has three states:

  - Sheathed: The weapon is not drawn, meaning the player fights unarmed or with a “ready” stance.

  - Unsheathed: The weapon is actively drawn, granting increased range, damage, and a larger stamina pool for guarding.

  - Shifted: This state exists only for Null characters, and is how they are able to access their special abilities.

Impact on Fighting Style:

  - Unsheathed Mode:

    - Benefits include increased damage, longer range, and a better stamina buffer for guarding.

    - Standard attacks, signatures, and defensive maneuvers remain available, but with enhanced parameters.

  - Sheathed Mode:

    - Reduced range and damage, as well as a smaller stamina pool for guarding.

    - The basic combat moves (attacks, guard, parry) are still accessible, but the overall performance is diminished.

  - Special Moves Difference:

    - The key distinction between sheathed and unsheathed modes lies in special moves. When a weapon is sheathed, certain special moves (like those tied to the E and R keys) change their behavior, reflecting the altered fighting style.

## Special Moves
### General Setup:

Players have up to 8 special moves per mode, with keys mapped to E, R, T, Y, G, Z, X, and C.

Weapon-Dependent Specials:

E Key:

In the unsheathed state, this might be a weapon-based special move.

When the weapon is sheathed, E turns into a grab that bypasses block (though it's still parriable).

Mechanics of the Grab:

On pressing E, the player grabs the opponent, holding them in place.

The grabder moves at a slightly reduced speed while holding the victim.

The victim takes continuous damage while held.

Pressing E again launches the grabbed opponent:

The thrown opponent becomes a projectile, with damage calculated based on their defense and the velocity of the throw (typically double their dash speed, significantly reduced by their resistance).

Both the thrown player and any entity hit by the thrown player take damage according to these calculations.

R Key:

This is a scripted grab resembling a command grab from fighting games.

The player initiates a grabbing animation, and if it connects (and isn’t parried), the grab transitions into a follow-up move based on the player’s sub-aspect.

This move deals damage and knocks the opponent in the direction the attacker is facing.

Other Special Moves:

The remaining keys (T, Y, G, Z) would tie into other weapon and sub-aspect–dependent moves, each with unique animations, damage profiles, and effects.

The design is modular so that each weapon archetype and sub-aspect can define its own set of special moves.

Physics-Based Damage & Ragdolling
Ragdolling Mechanics:

When an attack’s knockback exceeds a threshold (e.g., 1.5× the target’s Resistance), the victim is forced into a ragdoll state.

Launch & Bounce:

Upon ragdolling, the player is launched at a 30° angle.

They may bounce off the floor; each bounce reduces their velocity and height and inflicts additional damage.

There’s a threshold: lighter hits cause the player to simply land with damage, whereas heavier hits cause significant bouncing.

Collision Damage:

If the ragdolled player hits a wall or other obstacle, they take extra damage calculated similarly to being thrown.

Hitting a wall might multiply the damage (e.g., 1.4×) and could also generate AoE effects based on their defense and velocity.

Ultimate Abilities
Ultimate Mode Triggering:

Ultimate abilities (mapped to keys X and C) are only available when a player’s magic proficiency reaches its maximum (i.e., at 5).

Activation:

The player enters ultimate mode by pressing H three times within 1.5 seconds.

Ultimate Mode Effects:

Once activated, the player’s special moves (except the unarmed E) are replaced with stronger, ultimate-specific moves.

All stats are tripled during ultimate mode.

The player becomes immune to ragdoll-based damage (though they can still be knocked back or ragdolled, the damage from it is negated).

Proficiency and Stun
Magic Proficiency:

Aside from unlocking ultimate mode, proficiency gradually scales up from 0 to 4.9, modifying moves with incremental improvements like larger areas of effect or increased damage.

Stun Types:

Soft Stun: Typically inflicted by regular hit stun from damage, interrupting current actions.

Hard Stun: Caused by certain special moves, guard breaks, or ragdoll events.

The duration of hard stun is modulated by the target’s resistance and defense stats, meaning higher stats can reduce stun time.

Additional Considerations for Null Characters
Null-Specific Mechanics:

Null characters do not have a sub-aspect, so their special moves derive from the Shifted state of their weapon instead of sub-aspect moves.

They also avoid penalties typically associated with unarmed combat.


