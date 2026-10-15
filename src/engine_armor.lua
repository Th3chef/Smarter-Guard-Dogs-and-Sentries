
-- ======================================================================================================
-- Armor: enemies a dog cannot hurt. The game keys every enemy by a type hash (the first 8 bytes of its
-- entity row, byte-reversed). Each listed enemy has the armor where the dogs' shots land (the middle of
-- the body; for the Scout Strider that is the Medium-armored crotch, not the Heavy front plate), from the
-- Helldivers wiki. Shots bounce off armor above a dog's penetration: Rover Light (2) - its beam must
-- connect to set anything on fire - Guard Dog Medium (3), K-9 Anti-Tank (7). Unlisted enemies are never
-- skipped, so an unknown or new enemy type is simply treated the way the game treats it.
-- ======================================================================================================
local ARMOR = {}
local function armor(hash, av, name, extra)
  local e = extra or {}
  e.av, e.name = av, name
  ARMOR[type_hash(hash)] = e
end
-- Terminids
armor('1a7fcdff98c664b0', 4, 'Charger')
armor('3aff5fd7d5450b99', 4, 'Charger Behemoth')
armor('6b202392f4ab605e', 4, 'Spore Charger')
armor('0ab7b92b131c228c', 4, 'Rupture Charger')
armor('dcf8e74212fbee3b', 4, 'Impaler')
armor('960b48a421a3faaa', 4, 'Dragonroach')
armor('d465d9c7f77a07cb', 5, 'Hive Lord')
-- Bile Titan (4.0, by file name: fac_bugs/cha_strider): Heavy carapace; the dogs never pick it anyway, but the sentries
-- rank it (the rocket and autocannon sentries go for it first, the machine gun and Gatling sentries leave it alone)
armor('9e2e17f2ccccafdd', 4, 'Bile Titan')
armor('ef04cb84d097a497', 4, 'Spore Burst Bile Titan')
-- the game files its bug types by tier too ("cha_charger_tier2" is the Charger seen in game); the other tiers
-- and sub-types follow the same pattern (a name that doesn't exist simply never matches)
armor('b69a85547b03e00b', 4, 'Charger (tier1)')
armor('a05bd1ec67b3ac4c', 4, 'Charger')
armor('c9a50ad41ba6e366', 4, 'Charger (tier3)')
armor('2ee35a025f7be547', 4, 'Charger (tier 1)')
armor('1cc0cbc3c8c203e6', 4, 'Charger (tier 2)')
armor('81cfb7520c2fd4ea', 4, 'Charger (tier 3)')
armor('ff922fb58cf3c898', 4, 'Charger (gloom)')
armor('1d7c1121d14d4640', 4, 'Charger (predator)')
armor('82d7dbf36df2cd5d', 4, 'Charger Behemoth (tier1)')
armor('cb0ac45550e3fa08', 4, 'Charger Behemoth (tier2)')
armor('a268efcfd5960e5b', 4, 'Charger Behemoth (tier3)')
armor('a9825f1cf370258d', 4, 'Charger Behemoth (tier 1)')
armor('5618ff7dcba169de', 4, 'Charger Behemoth (tier 2)')
armor('712123d7050156ce', 4, 'Charger Behemoth (tier 3)')
armor('3552e6e38336b99d', 4, 'Charger Behemoth (gloom)')
armor('e3c3cba17ecc82bb', 4, 'Charger Behemoth (predator)')
armor('097150e4fba7baaf', 4, 'Spore Charger (tier1)')
armor('d627f630fb6cad19', 4, 'Spore Charger (tier2)')
armor('6acb7837c592b516', 4, 'Spore Charger (tier3)')
armor('f8fd2aad1cff629f', 4, 'Spore Charger (tier 1)')
armor('6dd3c4f82f64f81d', 4, 'Spore Charger (tier 2)')
armor('b51014ff0536c61d', 4, 'Spore Charger (tier 3)')
armor('ded63b68585fa88e', 4, 'Spore Charger (gloom)')
armor('95782440f640c3b4', 4, 'Spore Charger (predator)')
armor('cbf1826547aa60ec', 4, 'Rupture Charger (tier1)')
armor('848e53715479be04', 4, 'Rupture Charger (tier2)')
armor('fd2e34a1b1c6a4d3', 4, 'Rupture Charger (tier3)')
armor('ef3129d9dbef6503', 4, 'Rupture Charger (tier 1)')
armor('18a07ac28c3b8258', 4, 'Rupture Charger (tier 2)')
armor('db6181255b9b4497', 4, 'Rupture Charger (tier 3)')
armor('725647c42e84de3d', 4, 'Rupture Charger (gloom)')
armor('1e6a385598cba826', 4, 'Rupture Charger (predator)')
armor('8396bcd1003b7f46', 4, 'Impaler (tier1)')
armor('b7c25339a05a04c4', 4, 'Impaler (tier2)')
armor('2683800ebc99c5be', 4, 'Impaler (tier3)')
armor('446825542ef85f41', 4, 'Impaler (tier 1)')
armor('d26d4b7d4166dbe1', 4, 'Impaler (tier 2)')
armor('ee74e10e8693a124', 4, 'Impaler (tier 3)')
armor('65a81640a158d4a0', 4, 'Impaler (gloom)')
armor('184ad328cc8c6010', 4, 'Impaler (predator)')
armor('aa4668216fb9dc7e', 4, 'Dragonroach (tier1)')
armor('2f3ecea87263f777', 4, 'Dragonroach (tier2)')
armor('50d9042eea9da250', 4, 'Dragonroach (tier3)')
armor('6bd57fd70a200f03', 4, 'Dragonroach (tier 1)')
armor('8f0f553c0726adbe', 4, 'Dragonroach (tier 2)')
armor('8628b0f6e5129d2d', 4, 'Dragonroach (tier 3)')
armor('6728b887e4a17d0d', 4, 'Dragonroach (gloom)')
armor('6127e8bb9026de42', 4, 'Dragonroach (predator)')
armor('555069735072f167', 5, 'Hive Lord (tier1)')
armor('a25f9da353c6b87d', 5, 'Hive Lord (tier2)')
armor('150ffdb619e0060d', 5, 'Hive Lord (tier3)')
armor('d44584b9b341f2dd', 5, 'Hive Lord (tier 1)')
armor('7ab2961e1725be57', 5, 'Hive Lord (tier 2)')
armor('5b89ba8c3a303363', 5, 'Hive Lord (tier 3)')
armor('fa91c6c1d9d68536', 5, 'Hive Lord (gloom)')
armor('846fc796b658993d', 5, 'Hive Lord (predator)')
-- Automatons
armor('f8131632aa867107', 3, 'Scout Strider')   -- (Codex: Waist and Turret System AV3 where shots land; its Front Plate and HMG are separate parts, AV4)
armor('ae63e525853d7044', 2, 'Devastator')
armor('b92435fbf60f0748', 4, 'Heavy Devastator', { legs = 2, burst = true })
armor('db7139323c40ae6f', 2, 'Rocket Devastator')
armor('3d9c95bd03c0c7cf', 4, 'Heavy Devastator', { legs = 2, burst = true })   -- soldier_heavy_weapon
armor('c626d2bb495a202d', 2, 'Devastator (Iron Fleet)')
-- Devastators: listed at their Light legs, so every dog shoots them (the Rover burns their legs).
-- Heavy Devastators: their Heavy shield faces the dog. The Rover still burns their Light legs; the Guard Dog
-- fires only short suppressing bursts at them (see BURST in engine_logic.lua) instead of emptying its magazine.
-- Devastators of the Automaton sub-factions (Ivory Legion ones confirmed in game)
armor('57eed0eac346cd9d', 2, 'Devastator (Ivory Legion)')
armor('387d5f34dee8ed58', 2, 'Devastator (Jet Brigade)')
armor('fd7cb6955092ded7', 2, 'Devastator (Incineration Corps)')
armor('793d676154cce8f9', 4, 'Heavy Devastator (Iron Fleet)', { legs = 2, burst = true })
armor('58b2b86c11369241', 4, 'Heavy Devastator (Ivory Legion)', { legs = 2, burst = true })
armor('b8a9c5e5ca2bed52', 4, 'Heavy Devastator (Jet Brigade)', { legs = 2, burst = true })
armor('9b9e22b1fbf4aead', 4, 'Heavy Devastator (Incineration Corps)', { legs = 2, burst = true })
armor('01ecb61cfba04732', 2, 'Rocket Devastator (Iron Fleet)')
armor('0c95f5e9fbda85a5', 2, 'Rocket Devastator (Ivory Legion)')
armor('be8fe6b6d1f66828', 2, 'Rocket Devastator (Jet Brigade)')
armor('fa7a1664fbc642bd', 2, 'Rocket Devastator (Incineration Corps)')
armor('ed1b320d618b35a2', 2, 'Devastator (shotgun)')
armor('3045ad506156c217', 2, 'Devastator (shotgun) (Iron Fleet)')
armor('e0353177f1329573', 2, 'Devastator (shotgun) (Ivory Legion)')
armor('0acde1a3ae2eb027', 2, 'Devastator (shotgun) (Jet Brigade)')
armor('4daec072f9395162', 2, 'Devastator (shotgun) (Incineration Corps)')
armor('f4ceeaf35ee84f15', 2, 'Devastator (heavy weapon) (Iron Fleet)')
armor('d6ad92ab466a4014', 2, 'Devastator (heavy weapon) (Ivory Legion)')
armor('651f72844a012959', 2, 'Devastator (heavy weapon) (Jet Brigade)')
armor('03ed7c9298237257', 2, 'Devastator (heavy weapon) (Incineration Corps)')
armor('282eb766c1ffa6a1', 3, 'Gunship')
-- Hulks: the game files them as "lieutenants" (their saw, cannon and launcher arms are lieutenant_* weapons).
-- Confirmed in game: the Scorcher, the Bruiser and the Firebomber (filed as the Ivory Legion lieutenant); the rest are the same names with the other
-- sub-faction endings the game uses (a name that doesn't exist simply never matches)
armor('3e0537d606438fea', 4, 'Hulk Scorcher')
armor('6dab2eadf5d8b692', 4, 'Hulk Firebomber')
armor('137988cea16458f7', 4, 'Hulk Bruiser')
armor('846bc06c6b213a06', 4, 'Hulk')
armor('b16493b009eec762', 4, 'Hulk Scorcher')
armor('68d696b3ddc8efa0', 4, 'Hulk (Iron Fleet)')
armor('92674f050150fa24', 4, 'Hulk (Jet Brigade)')
armor('b96035bf3708da51', 4, 'Hulk (Incineration Corps)')
armor('5581097fe8bad0cf', 4, 'Hulk Scorcher (Iron Fleet)')
armor('970810405c11ea79', 4, 'Hulk Scorcher (Ivory Legion)')
armor('64d3a01db1863ccb', 4, 'Hulk Scorcher (Jet Brigade)')
armor('f93ec7e4b88037b1', 4, 'Hulk Scorcher (Incineration Corps)')
-- emplacements (Mortar confirmed in game; the machine-gun one turned up as its file name, so the heavy
-- machine-gun one is taken from its file name too)
armor('ff5cc825b9571052', 4, 'Mortar Emplacement')
armor('a98f8b559c7993d8', 3, 'Automaton HMG Emplacement')   -- file name says heavy MG emplacement; seen in game as an armored strider
armor('aeaef7a1851e6c9d', 4, 'Anti-Air Emplacement')   -- confirmed in game (F8 markers)
armor('ef570293245a17c2', 4, 'War Strider')
-- (4.0) a separate part of the War Strider that the Gatling Sentry kept firing at (a tester's F8 marker; its file
-- name isn't in the game's unit list): Heavy like the rest of it
armor('390e6b3d2f26bd70', 4, 'War Strider (part)')
-- (4.5, Codex check) its two fusion cannons are units of their own (Codex: left and right fusion cannon, AV4)
armor('8372619b2702d743', 4, 'War Strider (left fusion cannon)')
armor('9ab036439f74c115', 4, 'War Strider (right fusion cannon)')
armor('00bcf8247a544cdc', 5, 'Tank hull')
-- tank variants (Shredder confirmed in game with an F8 marker; the others by file name)
armor('c6449ffd9ea3779c', 5, 'Shredder Tank')   -- confirmed in game (F8 marker)
armor('63df3d07b7424588', 5, 'Barrager Tank')   -- seen in game logs
armor('f75a20ca493f7407', 5, 'Annihilator Tank')   -- guess by file name (cyborg_tank_cannon): never seen in game
-- the enemy the Guard Dog kept firing at while a tester marked it shooting an Annihilator Tank (RC 14, bots); its name is
-- not in the game's file list, so identified from that log rather than by name
armor('36390775d61159eb', 5, 'Annihilator Tank')
armor('0de06d0359ce6b1c', 5, 'Tank (mortar)')
armor('b64245d92dd8fa1a', 5, 'Tank (machine gun)')
-- tank turrets and hull gun can be picked on their own (the rocket turret was, in game)
armor('5d142c3a73ebc634', 5, 'Barrager Tank turret')
armor('49674794a165eda8', 5, 'Shredder Tank')
armor('cecd6979cf7bb0f2', 5, 'Annihilator Tank turret')
armor('6293d7ab6e681855', 4, 'Mortar Emplacement (gun)')   -- (Codex: the mortar of the Mortar Emplacement, stored with the tank turrets; Main AV4)
armor('16023e554fee830e', 5, 'Tank hull machine gun')
-- (bc242702fb46b7e7 was listed as the Factory Strider until Filediver showed it is cyborg_siege_engine: the Vox Engine)
armor('bc242702fb46b7e7', 5, 'Vox Engine')
-- the big walkers' guns are separate targets. The miniguns are the same part on the Factory Strider (its front
-- Fusion Gatling Guns) and the Vox Engine (its side Plasma Duster miniguns): wiki 300 health, Medium (AV3) on both.
-- But the dogs aim low, so their shots land on the armored body around them (Heavy/Tank, AV4-5) and are wasted:
-- listed at AV5. The two minigun ids were identified by where they sat in a Vox Engine F8 marker (not by name);
-- the upper pair is cyborg_siege_engine_turret (Vox cannons or launchers), and the Factory Strider's cannon turret
-- is cyborg_big_walker_turret_cannon (Tank I, AV5); both names confirmed by hash
armor('f2881f5807348116', 5, 'Minigun (Factory Strider / Vox Engine)')
armor('356de4a7808ef3e3', 5, 'Minigun (Factory Strider / Vox Engine)')
armor('611ba777783b08a2', 5, 'Vox Engine turret')
armor('843d18d4b5512b63', 5, 'Factory Strider cannon turret')
armor('8093204aea733daa', 4, 'Factory Strider')   -- guess: cyborg_big_walker (the Factory Strider's own id is not confirmed)
-- dropships (4.0): every sentry leaves them alone - they only waste ammo and time on them (a tester's call)
armor('db90077e76faa025', 5, 'Dropship', { sentries_skip = true })   -- fac_cyborgs/vehicles/cyborg_dropship
-- bunker turrets (3.0): the tower turret on Automaton bunkers, confirmed in game with F8 markers (a tester: the Guard Dog
-- can't damage it; it sits ~11 m up); its file name isn't in the game's unit list. The command bunker's machine-gun
-- turret is added by file name (not yet seen in game). Both left alone by the Rover and Guard Dog (the K-9 still shoots them)
armor('9926876b2375a1bb', 4, 'Bunker Turret')   -- confirmed in game (F8 markers); Codex: Main AV4, Heatsink AV3
armor('cd28a27a79be53d5', 5, 'Command Bunker MG turret')     -- fac_cyborgs/turrets/cyborg_turret_command_bunker_hmg
-- Illuminate
armor('19e18b46ec55d94a', 3, 'Stingray')
armor('965eae5a51acdd4a', 4, 'Harvester')
armor('f22d027b37bef107', 4, 'Leviathan')
armor('74e2285c01da4f71', 5, 'Warp Ship', { sentries_skip = true })   -- fac_illuminate/vehicles/illuminate_dropship

-- from the HD2 Enemy Codex (2026-09-28): every enemy model with armor Light (2) or more that wasn't listed above,
-- at its wiki armor value (the body's armor, where shots land); parts that attach to a bigger enemy (guns, plates,
-- packs) carry that enemy's rule. Names as checked by a tester in the Codex. Gatekeepers and Veracitors stay off the
-- list on purpose (their pilots are Light and their shields can be brought down); anything under Light is not armor
-- What counts is the armor where the shots land: Hive Guards (armored front, the rest of the body exposed) and the
-- Spewers (a little face armor, and only on higher difficulties) are hit mostly where they are unarmored, and Alpha
-- and Brood Commanders are only lightly armored, so they are left off (named in LABELS instead)
armor('56b7f620948be11e', 4, 'Anti-Air Emplacement')   -- cyborg_turret_aa_base
armor('9b6c199030d86085', 4, 'Emplacement base')   -- (4.5, Codex check) env_cyborg/cyborg_turret_base: the base under the Anti-Air and Mortar Emplacements and the Bunker Turret, AV4
armor('2c1a7790c435fd67', 2, 'Automaton MG Emplacement')   -- cyborg_emplacement_mg
armor('dfb610642eff47d7', 4, 'Conflagration Devastator (scattergun)', { legs = 2, burst = true })   -- soldier_riotgun (Codex: a Shield AV4 like the Heavy Devastator's)
armor('070bc8d3e18bb8f9', 2, 'Devastator (cannon)')   -- soldier_standard_rifle
armor('48c91e42b9f16512', 4, 'Factory Strider (rotary cannon)')
armor('d37e8d120d2836e3', 4, 'Factory Strider')   -- cyborg_spawner
armor('2ed3696e12a14d4c', 4, 'Heavy Devastator (fusion repeater)', { legs = 2, burst = true })   -- soldier_machinegun
armor('f96257fcae258caa', 4, 'Heavy Devastator (shield)', { legs = 2, burst = true })   -- soldier_shield
armor('feb484ee972469f7', 5, 'Incendiary MG Devastator (shield)', { legs = 2, burst = true })   -- soldier_shield_ivory_legion (Codex 4.5: its shield is AV5)
-- (the shield as it shows up in game: 9647b00cc3a9d36f is not a unit file, but it spawns with each Devastator and sits
-- right next to it, and the sentries picked it often; a tester identified it as the Heavy Devastator's shield (likely))
armor('9647b00cc3a9d36f', 4, 'Heavy Devastator shield (likely)', { legs = 2, burst = true })
armor('4d61156dd350a82b', 4, 'Hulk (autocannon arm)')   -- lieutenant_cannon
armor('7b5c9bdd385d0516', 4, 'Hulk (rocket arm)')   -- lieutenant_launcher
armor('8fc2784308e9ba99', 4, 'Hulk (flag)')   -- lieutenant_flag
armor('b940c889d77f8219', 4, 'Hulk (jetpack)')   -- lieutenant_jetpack
armor('bb37f12d0f46690f', 4, 'Hulk (buzzsaw arm)')   -- lieutenant_saw_ivory_legion
armor('c89ed7ac3e425b25', 4, 'Hulk (buzzsaw arm)')   -- lieutenant_saw
armor('33b3e0ce8d179eec', 2, 'Jet Brigade Devastator (jump pack)')   -- soldier_jumppack
armor('d3cd6f0ca83bb51e', 4, 'Reinforced Scout Strider (cabin)')   -- (Codex: Faceplate AV4)
armor('e5b14182b25f7f7d', 2, 'Reinforced Scout Strider (rocket rack)')   -- (Codex: Rocket Rails and Rockets AV2)
armor('2a346bf4552997e2', 4, 'Scout Strider (heavy machine gun)')   -- (Codex: HMG AV4)
armor('ee00bfe8ff769f70', 4, 'Scout Strider (front plate)')   -- (Codex: Front Plate AV4)
armor('8612789d750e8d92', 5, 'Vox Engine (gun turret)')
armor('abdc3c3c4eb8e1ee', 5, 'Vox Engine (sarcophagus)')   -- cyborg_siege_engine_sarcophagus
armor('0bd274fdd3b20e90', 10, 'Illuminate Overship', { sentries_skip = true })
armor('e7074f10233cd0b8', 10, 'Illuminate Overship', { sentries_skip = true })
armor('4e342031a9d5c4f9', 4, 'Leviathan (cannon turret)')   -- illuminate_turret_wm_cannon
armor('f735a51a991e4bda', 5, 'Warp Ship', { sentries_skip = true })
armor('019610dfe2e4ab79', 5, 'Hive Lord (shard f 02)')   -- cha_hive_lord_shard_f_02
armor('09cd7fc0ba3ffcf4', 6, 'Hive Lord (r mandible)')   -- cha_hive_lord_r_mandible
armor('0a2bbb5dd1dc065f', 5, 'Hive Lord (r leg)')   -- cha_hive_lord_r_leg
armor('1614f01ade1aac64', 5, 'Hive Lord (shard b 03)')   -- cha_hive_lord_shard_b_03
armor('3d75b189bf969ec0', 5, 'Hive Lord (shard f 03)')   -- cha_hive_lord_shard_f_03
armor('86f2a2d347c70074', 6, 'Hive Lord (l mandible)')   -- cha_hive_lord_l_mandible
armor('909bffb60c2236f0', 5, 'Hive Lord (shard f 01)')   -- cha_hive_lord_shard_f_01
armor('a5b106ba5d813094', 5, 'Hive Lord (l leg)')   -- cha_hive_lord_l_leg
armor('cbddb06fa202b2a4', 5, 'Hive Lord (shard b 02)')   -- cha_hive_lord_shard_b_02
armor('fecada76a501af4c', 5, 'Hive Lord (shard b 01)')   -- cha_hive_lord_shard_b_01

-- the highest armor each dog can hurt (its armor penetration)
local PEN = { ['Rover'] = 2, ['Guard Dog'] = 3, ['K-9'] = 7 }
-- (sentries carry their own 'pen' in SENTRIES: machine gun and Gatling 3, Laser 4 (Heavy); those without one - the
-- anti-tank weapons and mortars - shoot everything)

-- ======================================================================================================
-- (5.0 Test 12) Part armor. the author: "see if the sentries and guard dogs can read what part they are aiming at and
-- determine what Armor rating it is, before firing on it, instead of blacklisting a whole enemy", and "add a fallback
-- so if it cant determine what part an enemy is, it goes off of the old version and blacklists an enemy based on what
-- armor rating it is".
-- For an enemy with a part model, the line from the gun to where it aims is followed into the enemy: the first part
-- it meets decides, by that part's armor (Codex). A Hulk facing away shows its Heatsink (AV1); a Charger facing away
-- its Butt (AV0). Anything that can't be worked out - no model for that enemy, its bones can't be read or don't
-- match a known skeleton, the line meets none of the parts - falls back to the whole enemy's main armor (as before).
-- A model: boxes in one bone's own axes (the frame bone; the game's pose matrices: rows = the bone's axes in the
-- world, then its place), from the game's own models (Filediver glb, bind pose: tools/parts_gen.py). Each box has an
-- armor value, and a face can have its own (the Hulk's back face is its heatsink). The skeleton is checked before
-- use: child bones whose origins sit at fixed places in the frame bone's axes (they rotate, they don't move) must be
-- where the model says, to within 10 cm; this also catches a variant whose bones are numbered differently.
-- ======================================================================================================
local PARTS
do
  -- box: { x0, x1, y0, y1, z0, z1, armor, part name, faces = { ['y-'] = { armor, name }, ... } } (meters)
  local HULK = { name = 'Hulk', back = { 0, -1, 0 }, aim = { 0, 0, 0 },
    -- frame bone spine2 (+x up, -y back, z sideways); its aim_root sits on it (the game aims at the chest)
    boxes = {
      { -0.25, 1.45, -1.10, 0.85, -0.75, 0.75, 4, 'Main', faces = { ['y-'] = { 1, 'Heatsink' } } },   -- upper body: the back is the heatsink
      { -1.05, -0.25, -0.90, 0.75, -0.72, 0.72, 4, 'Main' },                                            -- lower body
      { 0.16, 1.05, -0.60, 0.16, 0.39, 1.66, 4, 'Shoulder' },
      { 0.16, 1.05, -0.60, 0.16, -1.66, -0.39, 4, 'Shoulder' },
    },
    checks = { { 0.691, 0.532, 0 }, { 0.9, -0.9, 0 } } }   -- head, backpack_damage
  local CHARGER = { name = 'Charger', back = { -1, 0, 0 }, aim = { 0, 0, 0 },
    -- frame bone boss (+x forward, z up); the abdomen runs back to x -3.5
    boxes = {
      { -1.50, 0.85, -1.37, 1.37, -0.60, 1.70, 4, 'Torso Armor', faces = { ['z-'] = { 2, 'Underside' } } },
      { 0.75, 2.60, -0.90, 0.90, -1.00, 1.00, 4, 'Head' },                    -- (the Behemoth's bigger head)
      -- ((5.0 Test 16, Test 14 log on bugs: the answer from 15-30 deg behind flipped between Butt and the plates every few
      -- tenths of a second) the plates' box no longer reaches past the butt's at the back or sides, and starts a little
      -- higher: from behind, a sentry's line meets the butt; only a line coming down on it meets the plates
      { -3.30, -1.10, -0.80, 0.80, 0.95, 1.85, 4, 'Rear Armor Plates' },     -- the plates over the abdomen
      { -3.30, -1.10, -0.80, 0.80, -0.45, 0.95, 0, 'Butt' },                 -- the abdomen under them
    },
    checks = { { 0.669, 0, 0.228 }, { -1.087, 0, 0.238 } } }   -- neck1, spine1
  -- skeletons: the frame bone and the check bones by node number (asset index bone_names; node k = bone k)
  local HULK_S = { { 79, 120, 135 }, { 79, 120, 138 } }                  -- cha_lieutenant, cha_lieutenant_assault
  local CHARGER_S = { { 61, 62, 79 }, { 72, 73, 90 }, { 62, 63, 80 } }   -- cha_charger(_bull), _acid, _burrower
  local KNOWN = {   -- units the asset index names: their own skeleton first
    ['846bc06c6b213a06'] = HULK_S[1], ['b16493b009eec762'] = HULK_S[2],
    ['1a7fcdff98c664b0'] = CHARGER_S[1], ['3aff5fd7d5450b99'] = CHARGER_S[1], ['6b202392f4ab605e'] = CHARGER_S[2], ['0ab7b92b131c228c'] = CHARGER_S[3],
  }
  PARTS = { kinds = {}, units = {}, frames = {}, verdict = {}, lines = 0, bad = {} }
  -- every listed Hulk and Charger (sub-faction and tier variants too: their skeleton is found by the checks); not the
  -- Hulks' arms, flag and jetpack, which are units of their own
  for k, a in pairs(ARMOR) do
    local n = a.name
    local model = (n:find('^Hulk') and not n:find('arm%)') and not n:find('flag') and not n:find('jetpack') and HULK)
      or (n:find('Charger') and CHARGER) or nil
    if model then
      local list = {}
      local own = KNOWN[hexr(k)]
      if own then list[1] = own end
      for _, s in ipairs(model == HULK and HULK_S or CHARGER_S) do if s ~= own then list[#list + 1] = s end end
      PARTS.kinds[k] = { model = model, skel = list }
    end
  end
  local function now() return os.clock() end
  -- a bone's world place (or, with whole = true, its axes too) from the unit's pose array
  local function bone(pose, i, whole)
    local m = read(pose + 64 * i, 64)
    if not m then return nil end
    local x, y, z = f32(m, 48), f32(m, 52), f32(m, 56)
    if not (x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6) then return nil end
    if not whole then return { x, y, z } end
    local rows = {}
    for r = 0, 2 do
      local a, b, c = f32(m, r * 16), f32(m, r * 16 + 4), f32(m, r * 16 + 8)
      local len = math.sqrt(a * a + b * b + c * c)
      if not (len > 0.5 and len < 2) then return nil end
      rows[r + 1] = { a / len, b / len, c / len }
    end
    return { x, y, z, rows = rows }
  end
  local function loc(F, p)
    local dx, dy, dz = p[1] - F[1], p[2] - F[2], p[3] - F[3]
    local R = F.rows
    return dx * R[1][1] + dy * R[1][2] + dz * R[1][3], dx * R[2][1] + dy * R[2][2] + dz * R[2][3], dx * R[3][1] + dy * R[3][2] + dz * R[3][3]
  end
  -- which skeleton this unit has (checked once per unit): the first whose check bones sit where the model says
  local function skeleton(unit, kind, pose)
    local u = PARTS.units[unit]
    if u and u.kind == kind and not (u.retry and now() >= u.retry) then return u.skel end
    local K = PARTS.kinds[kind]
    local found, unread = false, false
    for _, s in ipairs(K.skel) do
      local F = bone(pose, s[1], true)
      if not F then unread = true end
      if F then
        local ok = true
        for ci = 1, 2 do
          local q = bone(pose, s[ci + 1])
          local e = K.model.checks[ci]
          if not q then ok = false; unread = true; break end
          local x, y, z = loc(F, q)
          if (x - e[1]) ^ 2 + (y - e[2]) ^ 2 + (z - e[3]) ^ 2 > 0.01 then ok = false; break end
        end
        if ok then found = s; break end
      end
    end
    -- ((5.0 release review) a bone that couldn't be read (a unit just spawned, its pose not filled in yet) is not an
    -- answer: main armor for now, and the skeleton is looked at again in a second)
    if not found and unread then
      PARTS.units[unit] = { kind = kind, skel = false, retry = now() + 1 }
      return false
    end
    PARTS.units[unit] = { kind = kind, skel = found }
    if not found and not PARTS.bad[kind] then
      PARTS.bad[kind] = true
      note('part armor: ' .. K.model.name .. ' type ' .. hexr(kind) .. ' - its bones match no known skeleton, so it is judged by its main armor')
    end
    return found
  end
  -- the frame bone of an enemy this frame (read at most every 30 ms per unit)
  local function frame(c)
    local unit = c.ent and u32(c.ent, 12)
    if not unit or unit == 0 then return nil end
    local t = now()
    local F = PARTS.frames[unit]
    if F and F.kind == c.kind and t - F.t < 0.03 then return F.F end
    local root = unit_position(unit)
    if not (root and root.pose) then return nil end
    local s = skeleton(unit, c.kind, root.pose)
    local B = s and bone(root.pose, s[1], true) or nil
    PARTS.frames[unit] = { kind = c.kind, t = t, F = B }
    return B
  end
  -- slab test of the segment a -> b (local coordinates) against a box: where it enters, and through which face
  -- ((5.0 release review) the face names made once, not a table and a string per axis per box per call)
  local FACE = { { 'x-', 'x+' }, { 'y-', 'y+' }, { 'z-', 'z+' } }
  local function enter(a, d, b)
    local t0, t1, face = 0, 1, nil
    for ax = 1, 3 do
      local lo, hi = b[ax * 2 - 1], b[ax * 2]
      if math.abs(d[ax]) < 1e-9 then
        if a[ax] < lo or a[ax] > hi then return nil end
      else
        local ta, tb = (lo - a[ax]) / d[ax], (hi - a[ax]) / d[ax]
        local side = 1
        if ta > tb then ta, tb, side = tb, ta, 2 end
        if ta > t0 then t0, face = ta, FACE[ax][side] end
        if tb < t1 then t1 = tb end
        if t0 > t1 then return nil end
      end
    end
    if not face then return nil end   -- (it starts inside the box)
    return t0, face
  end
  -- the first part the segment from SA toward (px, py, pz) meets: its armor and name ((5.0 release review) one function
  -- and two reused tables instead of a closure and two tables per call)
  local SA, SD = { 0, 0, 0 }, { 0, 0, 0 }
  local function try_meet(M, px, py, pz)
    -- (the segment runs 1.5 times past the aim point: a shot doesn't stop where it was aimed)
    SD[1], SD[2], SD[3] = (px - SA[1]) * 1.5, (py - SA[2]) * 1.5, (pz - SA[3]) * 1.5
    local best, bf, bb
    for _, b in ipairs(M.boxes) do
      local tt, face = enter(SA, SD, b)
      if tt and (not best or tt < best) then best, bf, bb = tt, face, b end
    end
    if not best then return nil end
    local f = bb.faces and bb.faces[bf]
    if f then return f[1], f[2] end
    return bb[7], bb[8]
  end
  -- the part the line from 'from' toward 'aim' meets first: armor, part name, angle from behind (degrees); nil if
  -- it can't be worked out
  PARTS.meet = function(c, from, aim)
    local K = PARTS.kinds[c.kind]
    local F = frame(c)
    if not F then return nil end
    local M = K.model
    local ax, ay, az = loc(F, from)
    SA[1], SA[2], SA[3] = ax, ay, az
    local av, part
    if aim then local x, y, z = loc(F, aim); av, part = try_meet(M, x, y, z) end
    if not av then av, part = try_meet(M, M.aim[1], M.aim[2], M.aim[3]) end
    if not av then return nil end
    -- angle between the gun's direction and straight behind (for the log)
    local bk, h = M.back, math.sqrt(ax * ax + ay * ay + az * az)
    local ang = h > 0.01 and math.deg(math.acos(math.max(-1, math.min(1, (ax * bk[1] + ay * bk[2] + az * bk[3]) / h)))) or 0
    return av, part, ang
  end
  -- a short hold: a gun that could hurt an enemy keeps that answer for PARTS.HOLD (0.6 s) after its line last met a part it can hurt,
  -- so an enemy turning back and forth on the edge doesn't flip it every frame
  -- ((5.0 Test 21, the author: sentries "dont seem to consistently aim at the rear of chargers" - Test 20 log: guns 8-15 m up,
  -- coming down on a Charger's back, the answer flipped Butt <-> Rear Armor Plates 123 times) 0.6 s, was 0.25 s
  PARTS.HOLD = 0.6
  PARTS.decide = function(dog, c, from, who, aim, pen, main_av)
    -- ((5.0 release review) the same gun asks about the same enemy several times a frame (its target pick, the no-shot
    -- list, the marker, the priority rules): the first answer this frame is kept, one for a look along its aim and one
    -- without. Answers are kept per gun, then per enemy - no key string made per call)
    local W = PARTS.verdict[who or dog.name]
    if not W then W = {}; PARTS.verdict[who or dog.name] = W end
    local V = W[c.id]
    if not V then V = {}; W[c.id] = V end
    if aim then
      if V.fa == FRAME then return V.ra end
    elseif V.fn == FRAME then return V.rn end
    local av, part, ang = PARTS.meet(c, from, aim)
    -- ((5.0 Test 16, test builds) where the game really aims a sentry at a Hulk or Charger, in the enemy's frame (frame
    -- bone axes: Hulk +x up / -y back; Charger +x forward / +z up): at most every 2 s per enemy kind, 16 lines
    if TESTER and aim and (PARTS.aims or 0) < 16 then
      local K = PARTS.kinds[c.kind]
      local tk = (PARTS.aim_t or {})[K.model.name]
      local tn = now()
      if not tk or tn - tk > 2 then
        local F = frame(c)
        if F then
          PARTS.aim_t = PARTS.aim_t or {}; PARTS.aim_t[K.model.name] = tn
          PARTS.aims = (PARTS.aims or 0) + 1
          local x, y, z = loc(F, aim)
          local gx, gy, gz = loc(F, from)
          event(string.format('part aim (test): %s on %s %d: the game aims at %.2f %.2f %.2f in its frame, the gun at %.1f %.1f %.1f; the line meets %s',
            dog.name, K.model.name, c.id, x, y, z, gx, gy, gz, part and (part .. ' AV' .. av) or 'nothing'))
        end
      end
    end
    local t = now()
    local can
    if av then can = av <= pen else can = main_av <= pen end
    if can then
      V.last_can = t
    elseif V.last_can and t - V.last_can < PARTS.HOLD then
      can = true
    end
    -- a change of answer is counted (and in test builds written out, at most 40); not the first look that says
    -- skip - that is what every gun says of every Hulk and Charger facing it
    local first = V.can == nil
    if V.can ~= can and not (first and not can) then
      V.can = can
      local say = (av and (part .. ' AV' .. av) or ('main armor AV' .. main_av .. ' (part not found)')) .. (can and ': fires' or ': skips')
      local name = (ARMOR[c.kind] and ARMOR[c.kind].name) or '?'
      bump(session.parts, string.format('%s on %s: %s', dog.name, name, say))
      if TESTER and PARTS.lines < 40 then
        PARTS.lines = PARTS.lines + 1
        local gl = ''
        if aim then
          local F = frame(c)
          if F then local x, y, z = loc(F, aim); gl = string.format(', the game aims at %.2f %.2f %.2f in its frame', x, y, z) end
        end
        event(string.format('part check: %s on %s %d: %s%s%s', who and tostring(who) ~= dog.name and (dog.name .. ' ' .. tostring(who)) or dog.name,
          name, c.id, say, ang and string.format(' (%.0f deg from straight behind)', ang) or '', gl))
      end
    end
    if first then V.can = can end
    -- (old answers are dropped now and then: the table must not grow all session)
    PARTS.n = (PARTS.n or 0) + 1
    if PARTS.n > 20000 then
      PARTS.n = 0
      for g, W2 in pairs(PARTS.verdict) do
        for k2, V2 in pairs(W2) do if not V2.last_can or t - V2.last_can > 30 then W2[k2] = nil end end
        if next(W2) == nil then PARTS.verdict[g] = nil end
      end
      PARTS.units, PARTS.frames = {}, {}
    end
    if aim then V.fa, V.ra = FRAME, not can else V.fn, V.rn = FRAME, not can end
    return not can
  end
end

-- switched on by the optional 'Armor skipping' part of the mod (a tiny second addon that sets this flag); read
-- every frame, so load order does not matter
-- ((5.0 Test 12) from = the gun's muzzle (or the dog), who = which gun (a sentry's id; a dog's name), aim = where the
-- game is aiming it now, if this enemy is its target: with them, an enemy with a part model is judged by the part the
-- line of fire meets; without them, or when that can't be worked out, by its main armor as before)
local armor_state
local function cannot_hurt(dog, c, from, who, aim)
  local on = rawget(_G, 'SmarterGuardDogsArmor') == true
  if on ~= armor_state then armor_state = on; note('armor intelligence: ' .. (on and 'on' or 'off (option not installed)')) end
  if not on or not c.kind then return false end
  local a = ARMOR[c.kind]
  if not a then return false end
  if a.burst and dog.name == 'Guard Dog' then return false end   -- short bursts instead (engine_logic.lua)
  if a.sentries_skip and dog.sentry then return true end         -- dropships: no sentry shoots them
  local pen = dog.pen or PEN[dog.name] or 99
  if a.legs and a.legs <= pen then return false end
  if a.av <= pen then return false end
  if from and PARTS.kinds[c.kind] then
    local ok, r = pcall(PARTS.decide, dog, c, from, who, aim, pen, a.av)
    if ok then return r end
    if not PARTS.failed then PARTS.failed = true; note('part armor stopped (error): ' .. tostring(r)) end
    PARTS.kinds = {}   -- (back to main armor for every enemy)
  end
  return true
end
laser.cannot_hurt = cannot_hurt   -- ((5.0 Test 10) for the dogs' markers (engine_laser.lua comes first)
local function burst_only(dog, c)
  local a = c.kind and rawget(_G, 'SmarterGuardDogsArmor') == true and ARMOR[c.kind]
  return a and a.burst and dog.name == 'Guard Dog'
end
-- (4.0.6) a Heavy Devastator shows up in the target list as more than one entry - its body and its shield (and the
-- variants' parts) - and the game can pick any of them. Resting only the entry that was just fired at let the dog (or
-- a sentry) switch to the shield or body of the same Devastator and keep firing, so the short bursts turned into
-- continuous fire. So a rest covers every short-burst entry within 3 m of the one fired at: the whole Devastator.
local function rest_parts(rest, candidates, current, until_t)
  rest[current.id] = until_t
  local p = current.pos
  if not p then return 0 end
  local n = 0
  for _, c in ipairs(candidates) do
    local q = c.pos
    if c ~= current and q and c.kind and (q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2 + (q[3] - p[3]) ^ 2 < 9 then
      local a = ARMOR[c.kind]
      if a and a.burst then rest[c.id] = until_t; n = n + 1 end
    end
  end
  return n
end
