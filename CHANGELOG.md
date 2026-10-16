# Changelog

## 5.1.2

- Nothing the mod draws is left on screen when a mission ends: extracting with a Tesla Tower still standing (or with the Rocket Sentry's ring or a dog's laser showing at that moment) could leave the ring or laser on screen on the ship and in later missions until the game was restarted. The same is now true if the laser ever stops after an error.

## 5.1.1

- The laser on the Supply FRV gun and the Armed Resupply Pod gun now starts at the tip of the barrel instead of a little in front of it.

## 5.1.0

- Part armor for nearly every armored enemy: Impalers, Bile Titans, Dragonroaches, tanks and their turrets, emplacements and Bunker Turrets, Factory Striders, the Vox Engine, War Striders, Scout Striders, Harvesters, Gatekeepers and Veracitors are judged by the part each gun is aiming at (heatsinks, bellies, rears, weak spots), as Hulks and Chargers were.
- Heavy Devastators: nothing holds fire on them. The Guard Dog and the Machine Gun and Gatling sentries fire short bursts while the shield is in the way and full auto when its back is turned; the Rover keeps burning them.
- Sharper target markers, traced from the game's stratagem icons, and a new Marker Size option (50% to 200%). The dog's marker only shows on a target it keeps, instead of flicking to enemies it can't reach.
- Targeting Laser: choose Red while firing (the default) or Green while firing (the colors before 5.0). The Line choice is gone; the glow beam is used.
- Better enemy identification: Rocket Devastators no longer get short bursts, the Factory Strider's gatlings and the Vox Engine's miniguns are judged by their real armor (Medium), and more tank, Factory Strider, Harvester and Scout Strider variants are recognized.
- Fixes and speed-ups from the release review: a Harvester seen while warping in is looked at again, less work and memory per frame for part armor and the markers, and the in-game menu keeps your laser choice straight after the update.

## 5.0.0

- Part armor (Armor Intelligence): dogs and sentries judge a Hulk or Charger by the part they're aiming at, so they fire on a Hulk's heatsink and a Charger's rear or underside and still leave the armored front alone. If the part can't be worked out, the whole-enemy armor rule is used as before.
- New Ping Targeting option: your sentries go for an enemy you or a teammate ping (up to 20 s), safety first; a ping waits while an enemy is at the sentry's feet or right next to a helldiver.
- New SEAF Safety option: your guard dog and sentries don't fire through SEAF soldiers or civilians.
- New Targeting Marker and Marker Opacity options: each dog and sentry shows its own stratagem icon over its target (yellow on target, gray when it goes out of sight), only on enemies it can hurt and has in reach, side by side when several guns share a target, facing you from any angle.
- Targeting laser rework: the beam runs along each gun's barrel like a mounted laser, red while firing and flashing green when a friendly is in the way. Glow is now the default. The Tesla Tower's ring is red, and the Rocket Sentry's too-close ring is thicker.
- Cloaked Stalkers and Predator Stalkers are no longer avoided as if they were behind cover.
- The guard dog no longer sets aside an enemy close to you because the safety held its shot, and its marker stays on its target the whole time.
- Fixes and speed-ups from the release review: ping and part armor recover from a bad read, the safety laser blinks evenly, markers stay in place, and less work per frame.

## 4.6.8

Fixed the Rocket Sentry's red minimum-range ring staying on screen after the sentry was gone (it stayed through extraction, on the ship and in later missions until the game was restarted). The ring flashes again as it should, and the same fix covers the Tesla Tower's ring.

## 4.6.7

The Rover gives each enemy about half a second of beam before moving on, so it spends much more of its time firing (it used to move on after a split second and spend about half its time lining up), and it's never switched away before its first shot. Steadier targeting laser on the guard dogs. The Laser Sentry never leaves a burning enemy near you hidden, only counts an enemy as burning once it has actually hit it, and falls back to its own heat estimate if the game's heat meter stops reading. Sentries also check their line of fire to a target that has dropped out of their list, the dog keeps protecting you through a moment when your position can't be read, and it stops firing at a dead target sooner. A Tesla Tower can no longer go idle for the rest of a mission. Lighter on your PC: the log file is written far less often (each write caused a tiny hitch), and the safety checks do less work.

## 4.6.6

The Laser Sentry no longer flicks between targets or ignores enemies close by: it gives each enemy about half a second of beam before moving on, keeps firing at burning enemies within 15 m of you or itself, never sits idle while enemies are in reach, and stays on Chargers, Bile Titans and other heavy armor until they're dead. A safety stop is never given up on, even when a sentry or the dog keeps its target. Enemies hidden from a sentry stay hidden while the game moves its records, and the dog no longer briefly shows them again when a read fails. Faster start-up after a game patch. The log notes any target a sentry keeps firing at that the mod doesn't recognize.

## 4.6.5

Every sentry and guard dog now stops firing at the spot the moment its target is lost (the game kept them shooting where it was for about a second, so a Machine Gun Sentry could still hit a helldiver who stepped in front of it). New Sentry Safety option: your sentries don't fire through, swing their fire across or blast other sentries, yours or your teammates'. The safety now also covers you while you pilot an exosuit.

## 4.6.4

The Rocket Sentry fires at gunships whether they're moving or hovering. Works alongside Bingus' Laser Sentry Cooldown (an overheated Laser Sentry cools down and comes back; this mod still stops it before it overheats). Target Prioritization uses each sentry's real range, the Mortar and EMS Mortar safety distances match their real blast (13 m and 12 m), the Flame Sentry's turns are safety-checked reliably, and a safety stop is never delayed by another redirect. Lighter on your PC, faster start-up, holds up better after game patches, and the log numbers each sentry.

## 4.6.3

The Guard Dog and K-9 get their burst off on a new target before switching to a closer enemy. The Bright and Brightest laser settings now look different (Brightest is whiter). A laser problem can no longer stop the dog and sentry handling, and after an error your sentries are put back to normal too. More reliable detection of your dog's gun when other dogs are nearby, and lighter on your PC over long sessions.

## 4.6.2

The Supply FRV gun stops firing the moment its last enemy is gone (the game kept it shooting at the spot for a second), and it and the Armed Resupply Pod gun no longer spray while swinging round to an enemy far off to the side: they turn, then fire. The Flame Sentry switches to closer enemies sooner and moves on from burning enemies to the next unlit one, closer ones first, never leaving one next to you.

## 4.6.1

The Flame Sentry now engages enemies out to 30 m (was 20 m), goes for the closest enemies first and deals with one right at it before anything else, instead of the game's pick of far-off enemies while others close in.

## 4.6.0

New: Bingus' Mod Options Menu support - every option in game under ESC > MODS, laid out as in the mod manager - and a Laser Brightness option, for the line and the glow. The targeting laser now comes out of the muzzle of every sentry and guard dog: along the barrel, and for the Rover and K-9 straight to where they aim. Sentries stop firing the moment their last enemy dies or is lost (the game kept them, the Supply FRV gun most of all, shooting at where it was for about a second), the same after a safety stop, and no longer pick the body again. The Rocket Sentry no longer stands idle while an enemy is inside its minimum range. The Guard Dog holds fire far less often when you turn quickly (it fired about four times as often in testing). A Tesla Tower the mod lets go of is now put back properly.

## 4.5.2

The Flame Sentry only engages enemies its flames can reach (20 m); the game let it pick enemies well past that. Sentries no longer keep firing at nothing for a second after dropping a target with nothing else to shoot (for example the Laser Sentry after setting its last enemy alight, or while cooling down).

## 4.5.1

Sentries no longer go back to an enemy that just died (the Supply FRV gun kept shooting bodies on Illuminate missions): the body is kept out of its choices. Sentries and guard dogs no longer keep firing at nothing for a second when their target drops out of view with nothing else to shoot (the FRV gun was shooting between targets).

## 4.5.0

Now also handles the guns on Armed Resupply Pods and the M-103 Supply FRV: the FRV gun never stops for riders sitting in the FRV, only for anyone leaning out of a window, and its laser shows only while it fires. Sentries move on the moment their target dies. A much safer Tesla Tower: it no longer picks helldivers directly, and it leaves enemies within 10 m of a helldiver alone (was 5 m); its ring is now yellow and sits about 4 feet up so uneven ground doesn't hide it. Targeting laser: choose a solid neon green Line or the new Glow, and a steadier beam on the Gatling. The Guard Dog's short bursts at Heavy Devastators work again. Enemy list checked against the Enemy Codex (War Strider cannons, emplacement bases, the Incendiary MG Devastator's shield). Lighter on your PC: idle sentries are checked less often. The log is now SmarterGuardDogsAndSentries.log in %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs.

## 4.0.5

More options: turn the Guard Dogs and Sentries on or off separately, handle the sentries with or without the Tesla Tower, and choose who the Safety protects (you and your teammates, only you, only your teammates, or no one). New Intelligence option with Armor Intelligence (the old Armor skipping) and Target Prioritization, each of which can be turned off on its own. A thinner, more realistic targeting laser with a small cross where it hits, and a thicker Tesla Tower ring. Game stratagem icons for the options.

## 4.0.0

Now with sentries (Machine Gun, Gatling, Autocannon, Rocket, Laser, Flame, Mortar, EMS Mortar and the Tesla Tower): they never fire through you or (optionally) your teammates or swing their fire across you, stop firing into walls, deal with enemies at their feet first, go for Gunships and Stingrays first, pick Heavy or lighter targets to suit the gun, skip armor they can't hurt and dropships, the Laser Sentry spreads its fire and cools down before it burns out, and the Tesla Tower no longer zaps you or arcs into you. The targeting laser covers the sentries (a range ring for the Tesla Tower). Armor list rebuilt from the wiki's armor tables for where shots actually land. Dogs and sentries no longer keep going back to a Scout Strider they should leave alone. Renamed to Smarter Guard Dogs & Sentries. New thumbnail and header.

## 3.0.0

Teammate safety (new option): the dogs hold fire while another player is in their line of fire, just as they do for you. Dogs engage the moment an enemy they can shoot comes into view, and give up much sooner on enemies they can't get a shot at. The Guard Dog and K-9 finish lining up sooner after being pulled to a closer enemy. Automaton bunker turrets are skipped. Icons for the options in Arsenal. Clearer log. New thumbnail.

## 2.5.0

Fires again the moment you're out of its line after a safety stop, with shorter safety pauses. The Guard Dog and K-9 get a burst off before being pulled to a closer enemy. Dogs give up on enemies they can't get a shot at (too far, or stuck in the terrain). The Rover sticks to enemies within 35 m, and the Guard Dog ignores enemies beyond its reach. Stops firing the moment its target ducks behind cover, and the laser flashes yellow when that happens. The guns on Factory Striders and Vox Engines are skipped, and Annihilator Tanks are recognized. Clearer, lighter log.

## 2.0.1

The Guard Dog and Rover now skip Anti-Air Emplacements and every tank type (Shredder, Barrager, Annihilator and their turrets). The Rover now burns Devastators' legs instead of skipping them, and the Guard Dog fires short suppressing bursts at Heavy Devastators instead of ignoring them. The Guard Dog laser stays on the barrel more reliably.

## 2.0.0

Armor skipping (optional), no shooting into cover, Guard Dog range, Rover fire spreading, less hesitation, laser follows the barrel and turns off while reloading, ~70% lighter.

## 1.1.0

Targeting laser option, more efficient targeting.

## 1.0.x

Player safety, closest threat first, retarget on kill, fast Rover switching.
