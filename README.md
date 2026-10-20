![Smarter Guard Dogs & Sentries](media/gallery.png)

# Smarter Guard Dogs & Sentries
*Smarter, safer aiming for the Guard Dog, Rover and K-9, your sentries, and the guns on resupply pods and the Supply FRV.*

Smarter Guard Dogs & Sentries makes the shooting guard dog backpacks and your sentries aim the way you wish they did: they never shoot through you, your teammates, SEAF soldiers or other sentries, don't waste ammo, and go for the right target. New in 5.2: much lighter on your game, sentries that see the ground in their way and notice when their shots do no damage, Rocket and Autocannon Sentries that deal with what's close first, and mortars that only shell enemies on the ground, with markers.

## Featured on YouTube
[SwanyPlaysGames - "Helldivers 2 Will NEVER Be the Same!"](https://youtu.be/55fwJxfNaDM?t=456) (the mod is shown from 7:36).

## New in 5.2
- **Lighter on your game:** the mod switches itself off when there's nothing to do (no dog or sentry out, or no enemy within 150 m), and big fights cost far less: fewer memory reads, sentries that share the work between frames, and code the game's Lua can run faster. The log no longer causes a hitch when it's written.
- **Ground awareness:** your sentries learn the shape of the ground from where enemies, sentries and you walk, and hold fire when a rise or a hill's crest is in their line of fire, picking a target they can hit instead. They fire again the moment the line is clear.
- **Shots that do no damage:** a sentry or dog that keeps firing at an enemy whose health doesn't go down (it's behind a wall or an obstacle) moves on to one it can hurt, and comes back later. Shielded enemies, tanks and other heavy armor are left to Armor Intelligence. A sentry also finishes an enemy it's hurting before switching.
- **No firing at the dead:** a sentry the game leaves stuck on a dead enemy is freed after a moment, instead of firing into the ground.
- **Rocket and Autocannon Sentries: close threats first:** enemies within 25 m of the sentry come first (the heaviest of those first), then heavy armor farther out. Gunships still come before everything. The Autocannon Sentry also fires on a heavy that has walked up to one of your sentries.
- **Mortars:** the Mortar, EMS Mortar and the newly supported Gas Mortar Sentry now show their markers (no laser): the marker follows the target, then stays where the salvo will land until the shells come down. They only shell enemies on the ground, never ones still aboard a dropship, and give troops that just landed a moment to come off.
- **Autocannon Sentry:** its laser runs along its barrel like every other sentry's, and its beam and marker stay on the enemy through the whole salvo; the marker goes up the moment it turns to a new enemy.
- **Laser Sentry:** stays on Heavy Devastators walking up to it, instead of moving off them because their shields take the hits.
- **Markers:** the default size is 25% smaller (Marker Size still scales them), they keep their size out to 140 m, and the lasers no longer end above an enemy's head. The Armed Resupply Pod's gun shows the booster's icon, and the Gas Mortar its own.
- **Checked against the Helldivers Wiki:** every sentry and mortar: the Autocannon Sentry's 6 m blast is now part of the safety, the Rocket and Autocannon Sentries leave alone what their shells can't hurt, and the Armed Resupply Pod and Supply FRV guns engage out to 30 m.

## Guard dog features
- **Never shoots through you or your teammates:** it looks ahead when you spin around, and fires again the moment you're out of its way. The Safety option chooses who it protects: you and your teammates, only you, or only your teammates. The K-9 also avoids arcs that would chain back to you or a teammate. SEAF Safety covers SEAF soldiers and civilians too.
- **Closest threat first, without the hesitation (Target Prioritization):** the Guard Dog and K-9 get a burst off before they're pulled to the next closer enemy, then catch up.
- **No shooting the dead:** it moves on the moment its target dies, and stops firing at the spot the moment its target is lost.
- **Engages at once:** the moment an enemy it can shoot comes into view, it picks it and opens fire instead of waiting on the game's own re-pick timer.
- **No wasted aiming:** it stops firing the moment its target ducks behind cover, doesn't pick enemies it can't see, and gives up on an enemy it keeps lining up without getting a shot (quickly for far ones, only briefly for ones close to you).
- **Shoots only armor it can hurt (Armor Intelligence):** the Guard Dog and Rover judge armored enemies by the part they're aiming at: a Hulk's heatsink, a Charger's or Impaler's rear, a Bile Titan's belly, a tank's tracks and so on are fair game, the armored rest is left alone. The Guard Dog fires short suppressing bursts at a Heavy Devastator's shield and full auto at its back; the Rover keeps burning them. The Rover goes for a Scout Strider's legs and pilot. The K-9 skips nothing.
- **Range:** the Guard Dog ignores enemies beyond its reach (about 32 m), and the Rover sticks to enemies within 35 m while any are around. It's a guard dog: the enemies near you come first.
- **The Rover spreads its fire:** lighting the closest unlit enemies first, with about half a second of beam on each.

## Sentry features
- **Never fires through you or your teammates:** every sentry holds fire while you're in its line of fire (also while you pilot an exosuit), and the Machine Gun, Gatling, Laser and Flame sentries won't swing their fire across you while turning to the next target. The Autocannon and Rocket sentries won't fire at an enemy close enough to you to catch you in the blast, and the Mortar and EMS Mortar sentries won't shell enemies next to you.
- **Never fires through SEAF soldiers or civilians (SEAF Safety):** the same care for the SEAF soldiers and civilians fighting alongside you.
- **Never fires through other sentries (Sentry Safety):** your sentries hold fire while another sentry, yours or a teammate's, is in their line of fire, and don't swing their fire across one. The Rocket, Autocannon and Flame sentries won't fire at an enemy right next to a sentry (the Autocannon still takes on a heavy that has walked up to one), and the Mortar won't shell enemies within 7 m of one. (The Tesla Tower's arc doesn't hurt sentries.)
- **Goes for your pings (Ping Targeting):** a sentry that can hurt the enemy you or a teammate pinged, and has it in reach and in view, turns to it first.
- **No firing into walls:** a sentry drops a target that went behind cover and picks one it can hit.
- **No shooting the dead:** a sentry moves on the moment its target dies, and stops firing at the spot the moment its target is lost (the game kept it shooting where it was for about a second).
- **Self-defense first (Target Prioritization):** an enemy right at the sentry that it can hurt is dealt with before anything else, so the sentry isn't wrecked while it chases a better target.
- **Gunships first (Target Prioritization):** the Gatling, Autocannon, Rocket and Laser sentries go for Gunships (and Stingrays on Illuminate missions) before anything else.
- **The right target for the gun (Target Prioritization):** the Rocket and Autocannon sentries deal with enemies within 25 m of them first, then go for Heavy armor; the Machine Gun, Gatling and Laser sentries go for everything lighter first. An enemy right next to you always stays the target.
- **Ground awareness:** every gun sentry holds fire when a rise or a hill's crest is in its line of fire, and picks a target it can hit.
- **Shots that do no damage:** a sentry that keeps firing at an enemy its shots aren't hurting (behind a wall or an obstacle) moves on to one it can hurt.
- **Mortar, EMS Mortar and Gas Mortar Sentries:** they shell only enemies on the ground, never ones still aboard a dropship (troops that just landed get a moment to come off), and never enemies next to you. Their markers follow the target, then stay where the salvo will land.
- **Shoots only what it can hurt (Armor Intelligence):** the Machine Gun, Gatling and Laser sentries judge armored enemies by the part they're aiming at: a Hulk's heatsink, a Charger's rear or underside, a Bile Titan's belly, a tank turret's heatsink, a Factory Strider's belly panels and so on are fair game, the armored rest is left alone (the Laser Sentry only skips what is above Heavy). The Machine Gun and Gatling sentries fire short suppressing bursts at a Heavy Devastator's shield and full auto at its back. No sentry wastes ammo on dropships, and only the Rocket and Autocannon sentries (whose blast also hurts the dropship) shoot enemies still aboard one.
- **Flame Sentry:** engages enemies its flames can reach (30 m), not ones well out of range, and goes for the closest first, so an enemy closing in comes before one farther out (Target Prioritization). Once an enemy is on fire it moves on to the next unlit one, closer ones first, but never leaves a burning enemy next to you.
- **Laser Sentry:** sets enemies alight with about half a second of beam and moves on to the next one, like the Rover, but keeps firing at burning enemies within 15 m of you or itself, never sits idle while enemies are in reach, and stays on Chargers, Bile Titans and other heavy armor until they're dead. It cools down before it burns out (it reads the game's own heat meter and runs between 90% and 70% heat).
- **Tesla Tower:** it no longer zaps you or your teammates when you stand in its range: the mod keeps helldivers off its list of targets. It also leaves enemies within 10 m of a helldiver (or a SEAF soldier) alone so its arc doesn't chain into them.
- **Armed Resupply Pod and Supply FRV guns:** the guns on Armed Resupply Pods and the M-103 Supply FRV get the same care as the Machine Gun Sentry: safety, armor skipping and the right targets. The FRV gun never stops for riders sitting in the FRV, only for anyone leaning out of a window to shoot. Both guns turn to an enemy far off to the side before firing instead of spraying on the way, and the FRV gun stops firing the moment its last enemy is gone.
- **Works with Sentry Aim Retention and Laser Sentry Cooldown.**

## Targeting laser and markers
Shown only on your screen, for your dog and your sentries (the mortars show their markers, but no laser: they fire over cover).
- **Targeting Laser:** a beam out of each gun's barrel along where it's really pointing, like a mounted laser, so you can see the angle it's firing from, with a bright spot on the target. *Glow* (the default): a soft glowing beam that shows through walls and objects. *Line*: a thin line that walls and objects hide. Off while the dog reloads. The Tesla Tower shows its 20 m reach as a red ring, lit the whole time it's out, and a red ring flashes around the Rocket Sentry while an enemy is too close for it to fire.
- **Laser Color:** *Red while firing* (the default): red while it fires, flashing green when a friendly is in the way and the safety holds the shot. *Green while firing*: the other way round.
- **Laser Brightness:** Dim (50%), Softer (75%), Normal, Bright (150%) or Brightest (200%), for the beams and rings.
- **Targeting Marker:** each gun's own stratagem icon over the enemy it's on, like a ping: yellow while it's on that enemy, gray when the enemy goes out of sight (cover or smoke). Only on enemies it can hurt and has in reach; several guns on one enemy show side by side; it faces you from any angle. *Through walls* (the default): shown over everything, like a ping. *Behind walls*: walls and objects hide it (drawn solid, so Marker Opacity doesn't change it). Works with or without the laser.
- **Marker Opacity:** Full (100%), Medium (75%), Light (50%) or Faint (25%).
- **Marker Size:** Smallest (50%), Small (75%), Normal, Large (150%) or Largest (200%). Normal is 25% smaller than before 5.2.

Only your own dog and sentries are affected (the Safety option also protects the other players from them). Works hosting or joining, finds what it needs again after game patches, and is light on your PC. Hot Dog and Dog Breath are not changed.

## Options (Arsenal / HD2 Mod Manager)
- **Smarter Guard Dogs and Sentries** - the core. Keep this on.
- **Guard Dogs** - turn off to leave your guard dog to the game.
- **Sentries** - your sentries (the Gas Mortar Sentry too) and the guns on resupply pods and the Supply FRV. Choose *All sentries* or *All but the Tesla Tower*, or turn off to leave them to the game.
- **Intelligence** - choose *Armor Intelligence and Target Prioritization*, *Only Armor Intelligence* or *Only Target Prioritization*, or turn off to leave both to the game. Armor Intelligence: shooting armored enemies only at the parts they can hurt, short bursts at a Heavy Devastator's shield and skipping dropships. Target Prioritization: the closest threat first for the dogs; self-defense, Gunships and the armor that suits the gun first for the sentries (the closest first for the Flame Sentry).
- **Ping Targeting** - your sentries go for the enemies you and your teammates ping. On by default.
- **Safety** - choose who they never fire through: *You and your teammates*, *Only you* or *Only your teammates*. Turn off at your own risk.
- **Sentry Safety** - your sentries don't fire through other sentries, yours or your teammates'. On by default.
- **SEAF Safety** - your dog and your sentries don't fire through SEAF soldiers or civilians. On by default.
- **Targeting Laser** - choose *Glow* (the default) or *Line*, or turn off to hide the laser.
- **Laser Color** - choose *Red while firing* (the default) or *Green while firing*.
- **Laser Brightness** - choose *Normal (100%)* (the default), *Dim (50%)*, *Softer (75%)*, *Bright (150%)* or *Brightest (200%)*.
- **Targeting Marker** - each gun's icon over its target: choose *Through walls* (the default) or *Behind walls*, or turn off to hide the markers.
- **Marker Opacity** - choose *Full (100%)* (the default), *Medium (75%)*, *Light (50%)* or *Faint (25%)*.
- **Marker Size** - choose *Normal (100%)* (the default), *Smallest (50%)*, *Small (75%)*, *Large (150%)* or *Largest (200%)*.
**In game:** with [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) installed, every option is also under ESC > MODS > SMARTER GUARD DOGS & SENTRIES, laid out as in the mod manager, and a change takes effect the moment you apply it. The options picked in the mod manager are the starting values.

## Requirements
[Bingus Shared Loader](https://www.nexusmods.com/helldivers2/mods/16292) v19 or newer, last in the load order.

## Download
Get the latest zip from the [Releases](../../releases/latest) page (the `Smarter-Guard-Dogs-and-Sentries-<version>.zip` file, not the source code).

## Install / update
1. Install Bingus Shared Loader v19 or newer.
2. Remove any older version of Smarter Guard Dogs (& Sentries).
3. Add Smarter-Guard-Dogs-and-Sentries-5.2.0.zip in Arsenal or the HD2 Mod Manager and check the options you want (updating: no new options in 5.2, check the ones you had).
4. Purge, then Deploy (always both, every time you install or update), then restart the game.

## Uninstall
Remove it in your mod manager, then Purge and Deploy. Nothing is left behind in the game.

## Compatibility
- Works alongside Sentry Aim Retention.
- Works alongside Laser Sentry Cooldown (CowboyBingus): an overheated Laser Sentry cools down and comes back, and this mod still cools it before it overheats.
- Supports Mod Options Menu (optional).
- Don't combine it with other mods that change guard dog or sentry targeting (for example Laser Rover Targeting Optimization).
- Made and tested on the October 2026 game version: the Rover, Guard Dog and K-9 and every sentry, against Terminids, Automatons (Incineration Corps too) and Illuminate, solo and in multiplayer.

## Known limitations
- The game still decides when to shoot. The dog may hold fire on enemies that haven't engaged you yet.
- Brief pauses when you step into the line of fire, by design.
- Line of sight updates about twice a second, so a dog or sentry may briefly fire at cover or hesitate as enemies duck in and out of view.
- Sentries learn the ground as the mission goes, so early on, or where nobody has walked, a sentry may still fire into a rise. Walls and buildings aren't mapped: there the damage check moves it on after a moment.
- Part armor uses a simplified shape of each enemy, so now and then a gun may hold off a part it could hurt or fire at one it can't. Enemies without a part model are judged by their main armor.
- A Harvester's shield isn't modeled: it is judged as if the shield were down.
- Sentries sometimes finish a salvo or burst on their old target before switching, and the Autocannon and Rocket sentries may fire at the spot for up to a second after a kill (stopping that would cut their salvos short).
- The Tesla Tower can't be stopped once it has started a zap, so a helldiver who steps into its path at that moment can still be hit. Going prone still keeps you safe, as in the base game.
- The Glow laser and the Through walls markers show through walls and objects (the game draws them on top of the world). Pick Line and Behind walls to have walls hide them; Behind walls markers are drawn solid, so Marker Opacity doesn't change them.
- The Rocket Sentry can't fire while an enemy is within about 10 m of it (the game's rule); a red ring flashes around it then.
- Teammates' sentries run on their own game and aren't changed (yours still won't fire through them).
- Teammates piloting an exosuit aren't protected yet (you are).
- Safety for teammates may briefly hold fire near a teammate's body right after they reinforce.
- A major game update may switch the mod off until it's updated.

## How it works
**It doesn't alter any game data.** No game files, weapon stats, damage, range or enemy values are changed, unlike mods that rework those. It's a Lua addon that filters your dog's and sentries' choice of target while you play: the game's own targeting stays in charge, and the mod only hides the enemies they shouldn't shoot from their list and asks them to pick again (and keeps helldivers off the Tesla Tower's list of targets). No DLLs are added, no game code is patched, and everything is put back when it's not needed.

## Troubleshooting
Attach SmarterGuardDogsAndSentries.log to your bug report. You'll find it in %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs, next to the other Bingus mods' logs (paste that into the File Explorer address bar and press Enter). It lists what the mod did, how long each dog and sentry was out and how much of that time it had a target, and any errors.

## Support

All my mods are free and always will be. Every release is rigorously tested in real missions, highly optimized and kept working through game updates. If you'd like to help me keep that up and build new mods, you can support me on [Patreon](https://www.patreon.com/c/Chefboiardee).

Thank you for diving with me!

## Credits

- **CowboyBingus** - Bingus Shared Loader.
- Armor values: Helldivers Wiki.

## Building from source
The mod is plain Lua: `src/build.py` (Python 3, no extra packages) joins the `engine_*.lua` parts into one script, packs it and the option add-ons into Helldivers 2 patch archives, and writes the Arsenal / HD2 Mod Manager zip to `src/build/`.

```
cd src
python build.py
```

The zip it makes is the same one attached to each release. `python build.py tester` also builds a Tester zip with extra logging for bug hunting.

## Changelog
See [CHANGELOG.md](CHANGELOG.md).

## License
Copyright (c) 2026 Th3chef. All rights reserved. You're welcome to read the source, report bugs and suggest fixes, but please ask before reusing it or reuploading the mod. See [LICENSE](LICENSE).
