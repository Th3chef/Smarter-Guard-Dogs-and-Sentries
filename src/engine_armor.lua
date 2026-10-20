
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
armor('58b2b86c11369241', 5, 'Incendiary MG Devastator', { legs = 2, burst = true })   -- ((5.1) the asset index: cha_soldier_mg_ivory_legion; Codex: its shield is AV5)
armor('b8a9c5e5ca2bed52', 4, 'Heavy Devastator (Jet Brigade)', { legs = 2, burst = true })
armor('9b9e22b1fbf4aead', 4, 'Heavy Devastator (Incineration Corps)', { legs = 2, burst = true })
armor('01ecb61cfba04732', 2, 'Rocket Devastator (Iron Fleet)')
armor('0c95f5e9fbda85a5', 2, 'Rocket Devastator (Ivory Legion)')
armor('be8fe6b6d1f66828', 2, 'Rocket Devastator (Jet Brigade)')
armor('fa7a1664fbc642bd', 2, 'Rocket Devastator (Incineration Corps)')
armor('ed1b320d618b35a2', 2, 'Devastator (shotgun)')
armor('3045ad506156c217', 2, 'Devastator (shotgun) (Iron Fleet)')
armor('e0353177f1329573', 4, 'Conflagration Devastator', { legs = 2, burst = true })   -- ((5.1) the asset index: cha_soldier_shotgun_ivory_legion, the Conflagration Devastator; Codex: a Shield AV4)
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
armor('390e6b3d2f26bd70', 3, 'Factory Strider (Fusion Gatling Gun)')   -- ((5.1) the asset index: an entity on cyborg_top_turret named Factory Strider - its gatling gun, Codex AV3)
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
-- ((5.1) the asset index: both are entities on cyborg_top_turret named Vox Engine (its miniguns), like the Factory Strider's
-- gatling guns. Listed at their own armor (Codex AV3) now that a gun is judged by where the game aims it)
armor('f2881f5807348116', 3, 'Vox Engine (minigun)')
armor('356de4a7808ef3e3', 3, 'Vox Engine (minigun)')
armor('1c6981ca2fb69508', 3, 'Factory Strider (Fusion Gatling Gun)')
armor('3aafba89b53b0f63', 3, 'Factory Strider (Fusion Gatling Gun)')
armor('6a7a54d5fb3a6d17', 3, 'Factory Strider (Fusion Gatling Gun)')
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
-- packs) carry that enemy's rule. Names as checked by a tester in the Codex. Gatekeepers and Veracitors were left off the
-- list on purpose (their pilots are Light and their shields can be brought down; (5.1) they are listed now, judged only
-- by their part model, and shot at as before when it can't be read); anything under Light is not armor
-- What counts is the armor where the shots land: Hive Guards (armored front, the rest of the body exposed) and the
-- Spewers (a little face armor, and only on higher difficulties) are hit mostly where they are unarmored, and Alpha
-- and Brood Commanders are only lightly armored, so they are left off (named in LABELS instead)
armor('56b7f620948be11e', 4, 'Anti-Air Emplacement')   -- cyborg_turret_aa_base
armor('9b6c199030d86085', 4, 'Emplacement base')   -- (4.5, Codex check) env_cyborg/cyborg_turret_base: the base under the Anti-Air and Mortar Emplacements and the Bunker Turret, AV4
armor('2c1a7790c435fd67', 2, 'Automaton MG Emplacement')   -- cyborg_emplacement_mg
armor('dfb610642eff47d7', 4, 'Conflagration Devastator (scattergun)', { legs = 2, burst = true })   -- soldier_riotgun (Codex: a Shield AV4 like the Heavy Devastator's)
armor('070bc8d3e18bb8f9', 2, 'Devastator (cannon)')   -- soldier_standard_rifle
armor('48c91e42b9f16512', 3, 'Factory Strider (Fusion Gatling Gun)')   -- cyborg_top_turret (Codex AV3)
armor('d37e8d120d2836e3', 4, 'Factory Strider')   -- cyborg_spawner
armor('2ed3696e12a14d4c', 4, 'Heavy Devastator (fusion repeater)', { legs = 2, burst = true })   -- soldier_machinegun
armor('f96257fcae258caa', 4, 'Heavy Devastator (shield)', { legs = 2, burst = true })   -- soldier_shield
armor('feb484ee972469f7', 5, 'Incendiary MG Devastator (shield)', { legs = 2, burst = true })   -- soldier_shield_ivory_legion (Codex 4.5: its shield is AV5)
-- ((5.1) 9647b00cc3a9d36f was listed as the Heavy Devastator's shield (likely); the asset index shows it is the Rocket
-- Devastator's entity (cha_soldier_rpg, on the cha_soldier_rocket unit): Light like the other Devastators)
armor('9647b00cc3a9d36f', 2, 'Rocket Devastator')
armor('c9bcccb0a54a82a4', 2, 'Rocket Devastator (Ivory Legion)')   -- cha_soldier_rpg_ivory_legion
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

-- (5.1 Test 1) the asset index's entities on the enemies that now have part models, that weren't listed: their armor
-- is their Codex main armor; the part model decides where the shots land (engine_armor PARTS below)
armor('f8b5a81a86d5d4eb', 4, 'Heavy Devastator', { legs = 2, burst = true })   -- cha_soldier_mg_assassinate
armor('53d8919d7b8abd67', 5, 'Annihilator Tank')            -- cyborg_tank_heavycannon (on the cyborg_tank hull)
armor('31bae74d2f064d8d', 5, 'Annihilator Tank')            -- cyborg_tank_base
armor('8fb47dd28b398cf7', 5, 'Annihilator Tank turret')     -- cyborg_tank_turret_heavycannon
armor('30f2dee2333f227a', 4, 'Factory Strider')             -- cyborg_spawner_jammer
armor('9076eeed17fcee35', 3, 'Reinforced Scout Strider')    -- (on the cyborg_walker_scout unit)
armor('d63fcbff0851b7af', 4, 'Harvester')                   -- cha_tripod_tier_2
armor('453fe22c634eb30f', 4, 'Gatekeeper', { open = true })  -- cha_exomech_ranged
armor('20b9c7734daead65', 3, 'Veracitor', { open = true })   -- cha_exomech_melee (Main AV3: only the Rover looks at its parts)

-- (5.1.3; a player: the Machine Gun Sentry tried to kill a Jet Brigade Hulk by shooting its head) entities on the
-- units of listed enemies that weren't listed - an unlisted kind counts as unarmored, so every gun fired on it where the
-- game aims (a Hulk's head). Found by checking every entity in the asset index whose unit is a listed enemy's; the ones
-- without a file name are most likely the sub-faction versions (Jet Brigade, Incineration Corps). Armor as their listed
-- kin; the Hulks and the Behemoth get their part models by name, the others below by type id
armor('32cdeada234fb8df', 4, 'Hulk Bruiser')                -- (on cha_lieutenant; no file name)
armor('e44ec9f9b3fe1d2a', 4, 'Hulk Scorcher')               -- (on cha_lieutenant_assault; no file name)
armor('1e66ee1f6f7fd00e', 4, 'Hulk Obliterator')            -- cha_lieutenant_artillery
armor('96ba14c9ebb49ce1', 4, 'Hulk')                        -- cha_lieutenant_base
armor('1897bdd32105d2dc', 4, 'Hulk Scorcher')               -- cha_lieutenant_ivory_legion_assault
armor('fd5247653c897803', 4, 'Charger Behemoth')            -- (on cha_charger_bull; no file name)
armor('91ebd77931110afc', 4, 'Heavy Devastator', { legs = 2, burst = true })   -- (on cha_soldier_heavy_weapon; no file name)
armor('fc8dec78be8ab47d', 2, 'Devastator')                  -- (on cha_soldier; no file name)
armor('be743b2faa3a6e26', 2, 'Devastator (jump pack)')      -- cha_soldier_jumppack
armor('f66d0bad8693779a', 2, 'Rocket Devastator')           -- cha_soldier_rpg_assassinate
armor('98152772a72f7838', 5, 'Dropship', { sentries_skip = true })   -- (on cyborg_dropship; no file name)
armor('2cf3488c4845f8bd', 5, 'Cannon Turret')               -- cyborg_turret_heavycannon (the Annihilator turret's unit)
armor('abdb2e2a0479d8ca', 5, 'Cannon Turret')               -- cyborg_turret_base
armor('b8580cac32214fc0', 5, 'Annihilator Tank turret')     -- cyborg_tank_turret_base
armor('96110f9d6b010e02', 4, 'Leviathan (cannon turret)')   -- (on illuminate_turret_wm_cannon; no file name)
armor('f196069e7e14c497', 4, 'Leviathan (cannon turret)')   -- illuminate_turret_wm_cannon_head_l
armor('7acb4bd753b71de0', 4, 'Leviathan (cannon turret)')   -- illuminate_turret_wm_cannon_head_r
armor('397fb7e4883af100', 2, 'Reinforced Scout Strider (rocket rack)')   -- (on its rocket rack unit; no file name)
armor('a8173fba5dec35c3', 2, 'Reinforced Scout Strider (rocket rack)')   -- (on its rocket rack unit; no file name)

-- the highest armor each dog can hurt (its armor penetration)
local PEN = { ['Rover'] = 2, ['Guard Dog'] = 3, ['K-9'] = 7 }
-- (sentries carry their own 'pen' in SENTRIES: machine gun and Gatling 3, Laser 4 (Heavy), Autocannon and Rocket 5
-- ((5.1.5 Test 10) were 'shoot everything'); those without one - the mortars, the Tesla Tower, the Flame Sentry - shoot
-- everything)

-- ======================================================================================================
-- (5.0 Test 12) Part armor. My ask: "see if the sentries and guard dogs can read what part they are aiming at and
-- determine what Armor rating it is, before firing on it, instead of blacklisting a whole enemy", and "add a fallback
-- so if it cant determine what part an enemy is, it goes off of the old version and blacklists an enemy based on what
-- armor rating it is".
-- (5.1 Test 1) my ask: "Let's add all of those functionalities. It should only worry about shooting parts of an
-- enemy it can actually hit, Sentries and guard dogs only aim at a specific point on an enemy": part models for the
-- Heavy Devastators' shields, the Impaler, the Bile Titans, the Dragonroach, the tanks and their turrets, the
-- emplacements and the Bunker Turret, the Factory Strider, the Vox Engine, the War Strider, the Scout Striders, the
-- Harvester, the Gatekeeper and the Veracitor.
-- For an enemy with a part model, the line from the gun to where it aims is followed into the enemy: the first part
-- it meets decides, by that part's armor (Codex). A Hulk facing away shows its Heatsink (AV1); a Charger facing away
-- its Butt (AV0); a tank turret its heatsink (AV3); a Heavy Devastator's body only where its shield isn't in the way.
-- Anything that can't be worked out - no model for that enemy, its bones can't be read or don't match a known
-- skeleton, the line meets none of the parts - falls back to the whole enemy's armor rules (as before).
-- A model: boxes in a bone's own axes (the frame bone; the game's pose matrices: rows = the bone's axes in the world,
-- then its place), from the game's own models (Filediver glb, bind pose: each visibility group's bounds in the frame
-- bone's axes). A few boxes ride a second bone (f = 2: a Heavy Devastator's shield on its hand, the Barrager's launch
-- tubes on their pitch bone). Each box has an armor value, and a face can have its own (the Hulk's back face is its
-- heatsink). The skeleton is checked before use: child bones whose origins sit at fixed places in the frame bone's
-- axes (they rotate, they don't move) must be where the model says, to within 10 cm; this also catches a variant
-- whose bones are numbered differently.
-- ======================================================================================================
local PARTS
do
  -- box: { x0, x1, y0, y1, z0, z1, armor, part name, f = frame (1 if left out), faces = { ['y-'] = { armor, name }, ... } } (meters)
  -- model: name, aim (where to look when the game's own aim point isn't known: frame 1), back (for the log's angle),
  -- checks (the check bones' places in frame 1), nf (frames used)
  local function mirror(list)   -- each box given for the +x side, and its mirror image on the -x side
    local out = {}
    for _, b in ipairs(list) do
      out[#out + 1] = b
      -- ((5.1.0 release review) a face on the x sides swaps with it)
      local fc = b.faces
      if fc and (fc['x-'] or fc['x+']) then
        local sw = {}
        for k, v in pairs(fc) do sw[k == 'x-' and 'x+' or k == 'x+' and 'x-' or k] = v end
        fc = sw
      end
      local m = { -b[2], -b[1], b[3], b[4], b[5], b[6], b[7], b[8], f = b.f, faces = fc }
      out[#out + 1] = m
    end
    return out
  end
  local function join(a, b) for _, x in ipairs(b) do a[#a + 1] = x end; return a end
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
  -- (5.1 Test 1) the Heavy Devastators: frame bone boss (+y forward, z up, -x its left), the shield on the bone its left
  -- hand holds it by (frame 2: the shield's own axes; the plate runs across y and z, 35 cm thick along x). The game
  -- aims at aim_root (the chest). Shield AV4 (the Incendiary MG Devastator's AV5)
  local function devastator(name, shield)
    return { name = name, back = { 0, -1, 0 }, aim = { 0, 0.119, 0.266 }, nf = 2,
      boxes = join({
        { -0.22, 0.22, 0.10, 0.55, 0.50, 0.85, 1, 'Head' },
        { -0.45, 0.45, -0.25, 0.45, 0.00, 0.60, 3, 'Torso' },
        { -0.38, 0.38, -0.20, 0.35, -0.35, 0.00, 1, 'Stomach' },
        { -0.42, 0.42, -0.25, 0.35, -0.65, -0.35, 2, 'Pelvis' },
        { -0.60, 0.60, -0.30, 0.40, -1.48, -0.65, 2, 'Legs' },
        { -0.36, 0.36, -0.70, -0.25, -0.12, 0.70, 2, 'Backpack' },
        { -0.36, 0.02, -0.55, 0.55, -1.22, 0.50, shield, 'Shield', f = 2 },
      }, mirror({ { 0.45, 0.80, -0.25, 0.40, 0.25, 0.75, 2, 'Shoulder' } })),
      checks = { { 0, -0.011, 0.251 }, { 0, 0, 0 } } }   -- chest, pelvis
  end
  -- Impaler: frame bone boss (+x forward, +y its left, z up), like the Charger's; its face (AV1) hangs in front and below
  -- (frame 2: headplate1, the crest over its head - its head and crest move with it: +x its right, +y forward, z up)
  local IMPALER = { name = 'Impaler', back = { -1, 0, 0 }, aim = { 0, 0, 0 }, nf = 2,
    boxes = {
      { -2.29, 1.82, -1.63, 1.66, -1.60, 1.26, 4, 'Torso Armor', faces = { ['z-'] = { 2, 'Underside' } } },
      { -1.39, 1.28, -1.08, 1.39, -2.42, 0.52, 1, 'Head', f = 2 },
      { -2.41, 2.41, -2.90, -0.24, -0.29, 3.21, 4, 'Crest Armor', f = 2 },
      { -4.91, -2.29, -1.72, 1.72, 1.10, 2.68, 4, 'Rear Armor Plates' },
      { -4.91, -2.29, -1.60, 1.60, -0.28, 1.10, 1, 'Butt' },
    },
    checks = { { 0.981, 0, 0.334 }, { -1.132, 0, 0.824 } } }   -- neck1, spine1
  -- Bile Titan: frame bone boss (+x forward, z up, about 9 m above its feet); the game aims at its target_node, 1.4 m
  -- below it. Its belly (Underside AV2) and the sac under its abdomen (AV0) face the ground
  local TITAN = { name = 'Bile Titan', back = { -1, 0, 0 }, aim = { 0, 0, -1.4 },
    boxes = {
      { -2.20, 2.10, -1.80, 1.80, -2.45, 0.85, 4, 'Torso Armor', faces = { ['z-'] = { 2, 'Underside' } } },
      { 2.10, 3.48, -0.98, 0.99, -1.65, 1.43, 4, 'Head' },
      { -7.18, -2.20, -1.45, 1.45, -4.20, -0.97, 4, 'Butt Armor', faces = { ['z-'] = { 0, 'Sac' } } },
    },
    checks = { { 1.135, 0, 0 }, { -1.566, 0, -0.793 } } }   -- spine_upper_1, spine_lower_1
  -- Dragonroach: frame bone boss (+y forward, z up); carapace on top, its sacs underneath (AV0), four wings (AV0)
  local DRAGON = { name = 'Dragonroach', back = { 0, -1, 0 }, aim = { 0, 0, 0 },
    boxes = join({
      { -1.20, 1.20, -1.97, 1.86, 0.00, 2.44, 4, 'Carapace' },
      { -1.44, 1.44, -2.34, 2.03, -1.73, 0.00, 4, 'Thorax Innards', faces = { ['z-'] = { 0, 'Sacs' } } },
      { -0.63, 0.63, 2.03, 3.27, -1.52, 0.48, 4, 'Head' },
      { -1.40, 1.40, 1.86, 2.45, -0.47, 1.26, 4, 'Neck' },
      { -1.00, 1.00, -5.40, -2.34, -5.06, 0.45, 4, 'Abdomen Armor' },
    }, mirror({
      { 1.30, 17.50, -0.80, 7.36, 0.20, 4.05, 0, 'Wing' },
      { 1.30, 12.30, -5.80, -0.59, -0.24, 1.48, 0, 'Wing' },
    })),
    checks = { { 0, 1.002, -0.069 }, { 0, -1.087, 0.064 } } }   -- spine, hips
  -- tank hull (every tank): frame bone boss (+y forward, z up); the engine bay (AV4) at the back, the tracks (AV3) low on
  -- the sides; the turret (a target of its own) sits on top. The game aims at aim_root, 0.5 m up
  local TANK = { name = 'Tank', back = { 0, -1, 0 }, aim = { 0, 0, 0.5 },
    boxes = join({
      { -1.49, 1.49, -2.06, 5.22, -1.32, 0.90, 5, 'Hull Main', faces = { ['y+'] = { 5, 'Hull Front' } } },
      { -1.49, 1.49, -3.89, -2.06, -1.16, 0.84, 4, 'Engine Bay' },
      { -2.34, 2.34, -2.03, 2.20, 0.90, 1.90, 5, 'Turret' },
    }, mirror({
      { 1.49, 3.14, -3.64, 4.88, -1.10, 0.89, 5, 'Hull Sides' },
      { 1.51, 2.60, -4.33, 5.01, -1.77, -1.10, 3, 'Tracks' },
    })),
    checks = { { -2, -3.584, -0.226 }, { 2, -3.584, -0.226 } } }   -- l_backwheel_rotation, r_backwheel_rotation
  -- turrets: frame bone yaw (it turns with the turret: +y the way the gun points, z up); the back is the heatsink (AV3;
  -- the game's damage effects for it sit there)
  local CANNON_TURRET = { name = 'Tank turret', back = { 0, -1, 0 }, aim = { 0, 0, 0.5 },
    boxes = {
      { -2.34, 2.34, -2.03, 2.20, -0.06, 0.98, 5, 'Turret Main', faces = { ['y-'] = { 3, 'Turret Heatsink' } } },
      { -0.45, 0.45, 2.20, 5.16, 0.15, 0.85, 5, 'Cannon' },
    },
    checks = { { 0, 0.849, 0.468 }, { -1.4, -2.0, 0.3 } } }   -- pitch, fx_damage_l
  local function autocannon_turret(name, av)   -- the Shredder Tank's turret (AV5) and the Anti-Air Emplacement (AV4)
    return { name = name, back = { 0, -1, 0 }, aim = { 0, 0, 0.7 },
      boxes = {
        { -1.42, 1.42, -1.28, 1.60, 0.03, 1.45, av, 'Turret Main', faces = { ['y-'] = { 3, 'Heatsink' } } },
        { -1.00, 1.00, 1.60, 4.16, 0.40, 1.30, av, 'Cannons' },
      },
      checks = { { 0, 0.734, 1.424 }, { -0.69, -1.2, 0.7 } } }   -- upper_plate, fx_damage_l
  end
  local MORTAR = { name = 'Mortar Emplacement', back = { 0, -1, 0 }, aim = { 0, 0, 0.7 },
    boxes = {
      { -1.42, 1.42, -1.31, 1.50, 0.00, 1.44, 4, 'Main', faces = { ['y-'] = { 3, 'Heatsink' } } },
      { -0.60, 0.60, 1.50, 2.98, 0.30, 1.40, 4, 'Mortar' },
    },
    checks = { { 0, 0.734, 1.424 }, { -0.69, -1.2, 0.7 } } }   -- upper_plate, fx_damage_l
  -- the Barrager's turret: its launch tubes (AV3) ride the pitch bone (frame 2) on both sides
  local BARRAGER = { name = 'Barrager turret', back = { 0, -1, 0 }, aim = { 0, 0, 0.8 }, nf = 2,
    boxes = join({
      { -1.75, 1.75, -2.92, 1.75, -0.13, 0.60, 5, 'Turret Main' },
      { -0.90, 0.90, -0.13, 6.22, -0.40, 1.19, 5, 'Turret Main', f = 2 },
    }, mirror({ { 0.90, 2.04, -0.13, 6.22, -0.40, 1.19, 3, 'Launch Tubes', f = 2 } })),
    checks = { { 0, -2.653, 0.67 }, { 0, 0, 0 } } }   -- pitch, boss
  local BUNKER = { name = 'Bunker Turret', back = { 0, -1, 0 }, aim = { 0, 0, 0.5 },
    boxes = {
      { -0.98, 0.98, -0.90, 1.30, 0.02, 1.03, 4, 'Main', faces = { ['y-'] = { 3, 'Heatsink' } } },
      { -0.40, 0.40, 1.30, 2.83, 0.30, 0.90, 4, 'Cannons' },
    },
    checks = { { 0, 0.677, 0.601 }, { -0.69, -1.2, 0.7 } } }   -- pitch, fx_damage_l
  -- Factory Strider: frame bone boss (+y forward, z up, 7 m above its feet); the game aims at aim_root, under the
  -- front of its neck. The belly panels (AV3) are the underside of its body, the rear engine weakspot (AV3) the back of
  -- the engine on top, the stratagem scrambler (AV0) on top behind it; the rest is AV4-5
  local FACTORY = { name = 'Factory Strider', back = { 0, -1, 0 }, aim = { 0, 5.99, -0.99 },
    boxes = {
      { -1.40, 1.40, 5.89, 8.87, -0.98, 1.70, 5, 'Head Armor' },
      { -1.31, 1.31, 3.97, 5.89, -0.89, 1.99, 5, 'Neck Armor' },
      { -2.18, 2.18, 2.08, 3.97, -1.60, 3.20, 5, 'Front Armor' },
      { -2.81, 2.81, -3.36, 2.08, -1.79, 2.43, 5, 'Side Armor', faces = { ['z-'] = { 3, 'Belly Panels' } } },
      { -2.50, 2.50, -0.35, 2.08, 2.43, 3.60, 5, 'Front Top Armor' },
      { -2.41, 2.41, -6.57, -3.36, -1.55, 2.41, 5, 'Rear Armor' },
      { -2.24, 2.24, -6.22, -0.35, 2.43, 3.22, 5, 'Rear Engine Armor', faces = { ['y-'] = { 3, 'Rear Engine Weakspot' } } },
      { -0.60, 0.60, -3.60, -2.40, 3.22, 4.20, 0, 'Stratagem Scrambler' },
      { -1.18, 1.18, -3.92, 2.80, -3.22, -1.79, 4, 'Main' },                  -- the cage under its belly
    },
    checks = { { 0, 4.349, 0.965 }, { 0, -3.021, 2.754 } } }   -- neck, jammer
  -- Vox Engine: frame bone boss (+y forward, z up, 4.7 m above its tracks); vents (AV1) under it, a hatch (AV0) at the
  -- back, flaps, missile launchers and speakers (AV3) on its torso, tracks (AV4); the rest AV5
  local VOX = { name = 'Vox Engine', back = { 0, -1, 0 }, aim = { 0, 0, 0.5 },
    boxes = join({
      { -2.40, 2.40, -3.40, 3.60, -1.60, 1.01, 5, 'Undercarriage' },
      { -2.40, 2.40, 0.63, 3.57, -2.83, -1.60, 5, 'Undercarriage' },
      { -1.10, 1.10, -0.86, 0.86, -1.75, -1.60, 1, 'Vents' },
      { -0.86, 0.86, -3.45, -1.74, -0.36, 0.52, 0, 'Hatch' },
      { -2.79, 2.79, -3.85, 3.13, 1.01, 6.39, 5, 'Torso' },
    }, mirror({
      { 2.79, 3.48, -1.82, 1.47, 0.84, 2.05, 3, 'Torso Flap' },
      { 2.79, 3.85, -3.76, -2.25, 2.51, 4.82, 3, 'Missile Launcher' },
      { 1.62, 2.85, 0.99, 2.45, 6.39, 6.71, 3, 'Speaker' },
      { 1.69, 5.50, 2.19, 6.84, -5.02, -0.35, 4, 'Tracks' },
      { 1.69, 5.50, -7.24, -2.54, -5.02, -0.35, 4, 'Tracks' },
    })),
    checks = { { 0, 0, 1.36 }, { 0.001, -1.897, 0.262 } } }   -- head_yaw, boss_lid
  -- War Strider: frame bone boss (+y forward, z up, 3.3 m above its feet); its hip joints (AV3) behind the platform
  local WAR_STRIDER = { name = 'War Strider', back = { 0, -1, 0 }, aim = { 0, 0, 0 },
    boxes = join({
      { -0.83, 0.83, -1.69, 1.19, -0.81, 0.39, 4, 'Crotch' },
      { -1.15, 1.15, -2.12, 1.66, 0.39, 1.87, 4, 'Torso' },
    }, mirror({
      { 0.83, 1.25, -1.50, -0.50, -0.70, 0.20, 3, 'Hip Joint' },
      { 0.70, 1.83, -1.98, 1.41, -3.34, -0.70, 4, 'Leg' },
    })),
    checks = { { 0, -0.226, 0.227 }, { -0.645, -1.02, -0.242 } } }   -- turret_compression, l_hip_rotator
  -- Scout Striders (they matter to the Rover only): frame bone boss (+y forward, z up); legs AV2, the pilot (AV0)
  -- behind the front plate (AV4); the Reinforced one's pilot sits in an armored cabin
  local function scout(name, pilot, pname)
    return { name = name, back = { 0, -1, 0 }, aim = { 0, 0, 0 },
      boxes = join({
        { -0.36, 0.36, -1.04, 0.52, -0.34, 0.10, 3, 'Waist' },
        { -0.30, 0.30, -0.75, 0.00, 0.10, 0.95, pilot, pname },
        { -0.45, 0.45, 0.00, 0.55, 0.10, 1.00, 4, 'Front Plate' },
      }, mirror({ { 0.36, 0.70, -1.18, 0.38, -1.76, -0.06, 2, 'Leg' } })),
      checks = { { 0, -0.106, 0.168 }, { -0.395, -0.666, -0.066 } } }   -- turret_compression, l_hip
  end
  -- Harvester: frame bone boss (+y forward, z up, 9.6 m above its feet); its eye (AV2) in front, hip joints (AV3). Its
  -- shield isn't modeled: the body is judged as if the shield were down (as the whole-enemy rule did)
  -- ((5.1.0 Test 1 log: the game aims a Rover at 0, -1.25, 0 in this frame - its Bone_459bb7fc - every time))
  local HARVESTER = { name = 'Harvester', back = { 0, -1, 0 }, aim = { 0, -1.25, 0 },
    boxes = join({
      { -1.34, 1.34, -2.39, 0.16, -0.80, 1.30, 4, 'Chassis' },
      { -0.73, 0.73, 0.16, 1.35, -0.71, 0.72, 2, 'Eye' },
      { -0.33, 0.33, -3.41, -1.86, -1.74, -0.88, 3, 'Hip Joint' },
    }, mirror({ { 1.74, 2.39, -1.66, -0.59, -1.37, -0.57, 3, 'Hip Joint' } })),
    checks = { { -0.539, -0.003, -0.427 }, { 0, -0.292, -0.789 } } }   -- l_leg1, b_leg1
  -- Gatekeeper and Veracitor (the same frame: boss, +y forward, z up): the cockpit below, its energy shield in front of it
  local GATEKEEPER = { name = 'Gatekeeper', back = { 0, -1, 0 }, aim = { 0, 0, 0 },
    boxes = join({
      { -1.00, 1.00, -2.56, 0.72, 0.71, 2.06, 4, 'Carapace' },
      { -0.95, 0.95, -1.50, 1.00, -0.60, 0.71, 4, 'Chassis', faces = { ['y-'] = { 1, 'Rear Weakspot' } } },
      { -0.58, 0.58, -4.45, -1.50, -4.41, 1.02, 3, 'Rear Hip' },
      { -0.73, 0.73, -1.14, 1.41, -3.09, -0.60, 4, 'Cockpit' },
      { -0.96, 0.96, 0.09, 1.50, -2.75, -0.62, 2, 'Shield' },
    }, mirror({
      { 0.15, 2.06, 0.55, 1.78, -0.03, 1.14, 4, 'Shoulder Armor' },
      { 1.37, 2.23, 0.11, 1.35, -1.15, -0.03, 3, 'Arm' },
      { 1.44, 2.77, 1.35, 4.43, -2.77, -1.37, 4, 'Gun' },
      { 0.95, 3.21, -1.99, -0.19, -1.14, 0.93, 3, 'Hip' },
      { 2.35, 3.36, -2.02, 1.36, -4.93, -1.14, 4, 'Leg Armor' },
    })),
    checks = { { 0.605, 1.359, 0.281 }, { -0.018, -1.286, 0.131 } } }   -- collar_right, hip_back
  local VERACITOR = { name = 'Veracitor', back = { 0, -1, 0 }, aim = { 0, 0, 0 },
    boxes = join({
      { -1.11, 1.11, -2.95, 0.80, 0.69, 2.33, 3, 'Carapace' },
      { -0.95, 0.95, -1.50, 0.80, -0.60, 0.69, 3, 'Chassis' },
      { -0.52, 0.52, -4.56, -1.50, -4.93, 1.00, 3, 'Rear Leg' },
      { -0.73, 0.73, -1.14, 1.41, -3.09, -0.60, 3, 'Cockpit' },
      { -0.96, 0.96, 0.09, 1.50, -2.75, -0.62, 2, 'Shield' },
    }, mirror({
      { 0.15, 2.34, 0.50, 1.81, -0.62, 1.17, 2, 'Shoulder' },
      { 1.44, 2.23, 0.16, 1.22, -1.17, -0.62, 2, 'Upper Arm' },
      { 0.85, 2.75, 1.22, 5.90, -2.93, -1.15, 3, 'Lower Arm' },
      { 0.95, 3.25, -2.20, -0.31, -1.09, 1.07, 2, 'Hip' },
      { 2.38, 3.18, -2.11, 1.37, -4.95, -1.09, 3, 'Lower Leg' },
    })),
    checks = { { 0.605, 1.359, 0.281 }, { -0.018, -1.286, 0.131 } } }
  -- skeletons: the frame bones (f) and the check bones (c) by node number (asset index bone_names; node k = bone k)
  local HULK_S = { { f = { 79 }, c = { 120, 135 } }, { f = { 79 }, c = { 120, 138 } } }                     -- cha_lieutenant, cha_lieutenant_assault
  local CHARGER_S = { { f = { 61 }, c = { 62, 79 } }, { f = { 72 }, c = { 73, 90 } }, { f = { 62 }, c = { 63, 80 } } }   -- cha_charger(_bull), _acid, _burrower
  local DEV_S = { { f = { 57, 145 }, c = { 58, 109 } }, { f = { 56, 87 }, c = { 57, 108 } } }               -- cha_soldier_heavy_weapon (boss, attach_shield), cha_soldier (boss, attach_l_hand)
  local DEV_S2 = { DEV_S[2], DEV_S[1] }
  local KNOWN = {   -- units the asset index names: their own skeleton first
    ['846bc06c6b213a06'] = HULK_S[1], ['b16493b009eec762'] = HULK_S[2],
    ['32cdeada234fb8df'] = HULK_S[1], ['1e66ee1f6f7fd00e'] = HULK_S[1], ['96ba14c9ebb49ce1'] = HULK_S[1], ['1897bdd32105d2dc'] = HULK_S[1],
    ['e44ec9f9b3fe1d2a'] = HULK_S[2], ['fd5247653c897803'] = CHARGER_S[1],
    ['1a7fcdff98c664b0'] = CHARGER_S[1], ['3aff5fd7d5450b99'] = CHARGER_S[1], ['6b202392f4ab605e'] = CHARGER_S[2], ['0ab7b92b131c228c'] = CHARGER_S[3],
  }
  -- (5.1 Test 1) the other models by type id (the game's entity or unit ids; the asset index gives each entity's unit)
  local BY_KIND = {}
  local function give(model, skels, ...) for _, h in ipairs({ ... }) do BY_KIND[h] = { model, skels } end end
  give(devastator('Heavy Devastator', 4), DEV_S, 'b92435fbf60f0748', '3d9c95bd03c0c7cf', 'f8b5a81a86d5d4eb', '793d676154cce8f9', 'b8a9c5e5ca2bed52', '9b9e22b1fbf4aead', '91ebd77931110afc')
  give(devastator('Incendiary MG Devastator', 5), DEV_S, '58b2b86c11369241')
  give(devastator('Conflagration Devastator', 4), DEV_S2, 'e0353177f1329573')
  give(IMPALER, { { f = { 65, 110 }, c = { 87, 120 } } }, 'dcf8e74212fbee3b')
  give(TITAN, { { f = { 93 }, c = { 134, 121 } } }, '9e2e17f2ccccafdd', 'ef04cb84d097a497')
  give(DRAGON, { { f = { 84 }, c = { 121, 115 } } }, '960b48a421a3faaa')
  give(TANK, { { f = { 25 }, c = { 35, 36 } } }, '00bcf8247a544cdc', 'c6449ffd9ea3779c', '63df3d07b7424588', '53d8919d7b8abd67', '31bae74d2f064d8d')
  give(CANNON_TURRET, { { f = { 17 }, c = { 20, 33 } } }, 'cecd6979cf7bb0f2', '8fb47dd28b398cf7', '2cf3488c4845f8bd', 'abdb2e2a0479d8ca', 'b8580cac32214fc0')
  give(autocannon_turret('Shredder turret', 5), { { f = { 16 }, c = { 17, 33 } } }, '49674794a165eda8')
  give(autocannon_turret('Anti-Air Emplacement', 4), { { f = { 16 }, c = { 17, 33 } } }, 'aeaef7a1851e6c9d')
  give(MORTAR, { { f = { 17 }, c = { 18, 28 } } }, '6293d7ab6e681855', 'ff5cc825b9571052')
  give(BARRAGER, { { f = { 16, 17 }, c = { 17, 15 } } }, '5d142c3a73ebc634')
  give(BUNKER, { { f = { 12 }, c = { 13, 18 } } }, '9926876b2375a1bb')
  give(FACTORY, { { f = { 90 }, c = { 156, 204 } } }, 'd37e8d120d2836e3', '30f2dee2333f227a', '8093204aea733daa')
  give(VOX, { { f = { 57 }, c = { 58, 87 } } }, 'bc242702fb46b7e7')
  give(WAR_STRIDER, { { f = { 38 }, c = { 63, 39 } } }, 'ef570293245a17c2')
  give(scout('Scout Strider', 0, 'Pilot'), { { f = { 35 }, c = { 36, 47 } } }, 'f8131632aa867107')
  give(scout('Reinforced Scout Strider', 4, 'Cabin'), { { f = { 35 }, c = { 36, 47 } } }, '9076eeed17fcee35')
  give(HARVESTER, { { f = { 85 }, c = { 86, 98 } } }, '965eae5a51acdd4a', 'd63fcbff0851b7af')
  give(GATEKEEPER, { { f = { 110 }, c = { 168, 142 } } }, '453fe22c634eb30f')
  give(VERACITOR, { { f = { 111 }, c = { 169, 143 } } }, '20b9c7734daead65')
  PARTS = { kinds = {}, units = {}, frames = {}, verdict = {}, lines = 0, bad = {}, aims = 0 }
  -- every listed Hulk and Charger (sub-faction and tier variants too: their skeleton is found by the checks); not the
  -- Hulks' arms, flag and jetpack, which are units of their own; then the other models by type id
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
  for h, m in pairs(BY_KIND) do PARTS.kinds[type_hash(h)] = { model = m[1], skel = m[2] } end
  local function now() return os.clock() end
  -- a bone's world place (or, with whole = true, its axes too) from the unit's pose array
  -- ((5.1.0 release review) 'into': a frame table to fill in place - the frames read every 30 ms reuse theirs)
  local function bone(pose, i, whole, into)
    local m = read(pose + 64 * i, 64)
    if not m then return nil end
    local x, y, z = f32(m, 48), f32(m, 52), f32(m, 56)
    if not (x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6) then return nil end
    if not whole then return { x, y, z } end
    local B = into or { rows = { {}, {}, {} } }
    for r = 0, 2 do
      local a, b, c = f32(m, r * 16), f32(m, r * 16 + 4), f32(m, r * 16 + 8)
      local len = math.sqrt(a * a + b * b + c * c)
      if not (len > 0.5 and len < 2) then return nil end
      local R = B.rows[r + 1]
      R[1], R[2], R[3] = a / len, b / len, c / len
    end
    B[1], B[2], B[3] = x, y, z
    return B
  end
  local function loc(F, p)
    local dx, dy, dz = p[1] - F[1], p[2] - F[2], p[3] - F[3]
    local R = F.rows
    return dx * R[1][1] + dy * R[1][2] + dz * R[1][3], dx * R[2][1] + dy * R[2][2] + dz * R[2][3], dx * R[3][1] + dy * R[3][2] + dz * R[3][3]
  end
  -- (5.1 Test 1) a point given in a frame's axes, in the world
  local WP = { 0, 0, 0 }
  local function world(F, x, y, z)
    local R = F.rows
    WP[1] = F[1] + x * R[1][1] + y * R[2][1] + z * R[3][1]
    WP[2] = F[2] + x * R[1][2] + y * R[2][2] + z * R[3][2]
    WP[3] = F[3] + x * R[1][3] + y * R[2][3] + z * R[3][3]
    return WP
  end
  -- which skeleton this unit has (checked once per unit): the first whose check bones sit where the model says
  local function skeleton(unit, kind, pose)
    local u = PARTS.units[unit]
    if u and u.kind == kind and not (u.retry and now() >= u.retry) then u.seen = now(); return u.skel end
    local K = PARTS.kinds[kind]
    local found, unread = false, false
    for _, s in ipairs(K.skel) do
      local F = bone(pose, s.f[1], true)
      if not F then unread = true end
      if F then
        local ok = true
        for ci = 1, 2 do
          local q = bone(pose, s.c[ci])
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
      PARTS.units[unit] = { kind = kind, skel = false, retry = now() + 1, unit_tries = u and u.unit_tries, seen = now() }
      return false
    end
    -- ((5.1.0 Test 1, my logs: "Harvester ... match no known skeleton" every Illuminate mission, while other
    -- Harvesters were judged by their parts fine - most likely one seen while it was still warping in, its bones not yet
    -- where they settle) a mismatch is looked at again 2 s later, 4 times, before the unit is judged by main armor for good.
    -- Test builds write where the check bones were (each kind once)
    if not found then
      local tries = ((u and u.unit_tries) or 0) + 1
      if TESTER and not (PARTS.bad_seen or {})[kind] then
        PARTS.bad_seen = PARTS.bad_seen or {}; PARTS.bad_seen[kind] = true
        local s = K.skel[1]
        local F = bone(pose, s.f[1], true)
        local got = {}
        for ci = 1, 2 do
          local q = F and bone(pose, s.c[ci])
          if q then local x, y, z = loc(F, q); got[#got + 1] = string.format('%.2f %.2f %.2f (model %.2f %.2f %.2f)', x, y, z, K.model.checks[ci][1], K.model.checks[ci][2], K.model.checks[ci][3]) end
        end
        event('part armor (test): ' .. K.model.name .. ' ' .. hexr(kind) .. ' check bones at ' .. (#got > 0 and table.concat(got, '; ') or 'unreadable') .. ' (first look)')
      end
      if tries < 5 then
        PARTS.units[unit] = { kind = kind, skel = false, retry = now() + 2, unit_tries = tries, seen = now() }
        return false
      end
    end
    PARTS.units[unit] = { kind = kind, skel = found, seen = now() }
    if not found and not PARTS.bad[kind] then
      PARTS.bad[kind] = true
      note('part armor: ' .. K.model.name .. ' type ' .. hexr(kind) .. ' - its bones match no known skeleton, so it is judged by its main armor')
    end
    return found
  end
  -- the frame bones of an enemy this frame (read at most every 30 ms per unit): a list, frame 1 first
  local function frame(c)
    local unit = c.ent and u32(c.ent, 12)
    if not unit or unit == 0 then return nil end
    local t = now()
    local F = PARTS.frames[unit]
    if F and F.kind == c.kind and t - F.t < 0.03 then return F.F end
    -- ((5.1.0 release review) a unit judged by its main armor for good, or waiting for its next look: nothing read)
    local u = PARTS.units[unit]
    if u and u.kind == c.kind and u.skel == false and not (u.retry and t >= u.retry) then u.seen = t; return nil end
    local root = unit_position(unit)
    if not (root and root.pose) then return nil end
    local s = skeleton(unit, c.kind, root.pose)
    -- ((5.1.0 release review) one table per unit, its frames filled in place)
    if not F then F = { bufs = {}, list = {} }; PARTS.frames[unit] = F end
    F.kind, F.t = c.kind, t
    local B
    if s then
      B = F.list
      for i, b in ipairs(s.f) do
        local buf = F.bufs[i]
        if not buf then buf = { rows = { {}, {}, {} } }; F.bufs[i] = buf end
        if not bone(root.pose, b, true, buf) then B = nil; break end
        B[i] = buf
      end
    end
    F.F = B
    return B
  end
  -- ((5.1.0 release review) old entries are dropped by age, every 20000 answers (decide and exposed together): what a
  -- gun has said about an enemy, units and frames, not looked at for 30 s)
  local function sweep(t)
    for g, W2 in pairs(PARTS.verdict) do
      for k2, V2 in pairs(W2) do if t - (V2.seen or 0) > 30 then W2[k2] = nil end end
      if next(W2) == nil then PARTS.verdict[g] = nil end
    end
    for g, E2 in pairs(PARTS.exp) do
      for k2, X2 in pairs(E2) do if t - (X2.seen or 0) > 30 then E2[k2] = nil end end
      if next(E2) == nil then PARTS.exp[g] = nil end
    end
    for k2, F2 in pairs(PARTS.frames) do if t - F2.t > 30 then PARTS.frames[k2] = nil end end
    for k2, U2 in pairs(PARTS.units) do if t - (U2.seen or 0) > 30 then PARTS.units[k2] = nil end end
  end
  local function tick_sweep(t)
    PARTS.n = (PARTS.n or 0) + 1
    if PARTS.n > 20000 then PARTS.n = 0; sweep(t) end
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
  -- the first part the segment from the gun toward a world point meets: its armor and name ((5.0 release review) one
  -- function and reused tables instead of a closure and tables per call; (5.1) the segment is put in each frame's axes)
  local SA, SD = { { 0, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, 0 }, { 0, 0, 0 } }
  local function try_meet(M, FR, from, p)
    for f = 1, M.nf or 1 do
      local A, D = SA[f], SD[f]
      A[1], A[2], A[3] = loc(FR[f], from)
      local px, py, pz = loc(FR[f], p)
      -- (the segment runs 1.5 times past the aim point: a shot doesn't stop where it was aimed)
      D[1], D[2], D[3] = (px - A[1]) * 1.5, (py - A[2]) * 1.5, (pz - A[3]) * 1.5
    end
    local best, bf, bb
    for _, b in ipairs(M.boxes) do
      local f = b.f or 1
      local tt, face = enter(SA[f], SD[f], b)
      if tt and (not best or tt < best) then best, bf, bb = tt, face, b end
    end
    if not best then return nil end
    local fc = bb.faces and bb.faces[bf]
    if fc then return fc[1], fc[2] end
    return bb[7], bb[8]
  end
  -- the part the line from 'from' toward 'aim' meets first: armor, part name, angle from behind (degrees); nil if
  -- it can't be worked out
  PARTS.meet = function(c, from, aim, want_angle)
    local K = PARTS.kinds[c.kind]
    local FR = frame(c)
    if not FR then return nil end
    local M = K.model
    local av, part
    -- ((5.1 Test 1) the game's aim point only when it is a real point near this enemy - within 15 m of its frame bone)
    if aim and aim[1] == aim[1] and aim[2] == aim[2] and aim[3] == aim[3]
      and (aim[1] - FR[1][1]) ^ 2 + (aim[2] - FR[1][2]) ^ 2 + (aim[3] - FR[1][3]) ^ 2 < 225 then
      av, part = try_meet(M, FR, from, aim)
    end
    if not av then
      local p = world(FR[1], M.aim[1], M.aim[2], M.aim[3])
      av, part = try_meet(M, FR, from, p)
    end
    if not av then return nil end
    if not want_angle then return av, part end
    -- angle between the gun's direction and straight behind (for the test builds' log)
    local ax, ay, az = loc(FR[1], from)
    local bk, h = M.back, math.sqrt(ax * ax + ay * ay + az * az)
    local ang = h > 0.01 and math.deg(math.acos(math.max(-1, math.min(1, (ax * bk[1] + ay * bk[2] + az * bk[3]) / h)))) or 0
    return av, part, ang
  end
  -- a short hold: a gun that could hurt an enemy keeps that answer for PARTS.HOLD (0.6 s) after its line last met a part it can hurt,
  -- so an enemy turning back and forth on the edge doesn't flip it every frame
  -- ((5.0 Test 21, my note: sentries "dont seem to consistently aim at the rear of chargers" - Test 20 log: guns 8-15 m up,
  -- coming down on a Charger's back, the answer flipped Butt <-> Rear Armor Plates 123 times) 0.6 s, was 0.25 s
  PARTS.HOLD = 0.6
  -- true: the line meets a part it can't hurt (skip); false: one it can (fire); nil: it can't be worked out (the
  -- whole-enemy rules decide, in cannot_hurt)
  PARTS.decide = function(dog, c, from, who, aim, pen)
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
    local av, part, ang = PARTS.meet(c, from, aim, TESTER)
    V.seen = now()
    local K = PARTS.kinds[c.kind]
    -- ((5.0 Test 16, test builds) where the game really aims a gun at a modeled enemy, in the enemy's frame (frame bone
    -- axes): at most every 2 s per model and 6 lines per model, 60 in all ((5.1) every model, was Hulks and Chargers)
    if TESTER and aim and PARTS.aims < 60 then
      local tk = (PARTS.aim_t or {})[K.model.name]
      local tn = now()
      PARTS.aim_n = PARTS.aim_n or {}
      if (not tk or tn - tk > 2) and (PARTS.aim_n[K.model.name] or 0) < 6 then
        local FR = frame(c)
        if FR then
          PARTS.aim_t = PARTS.aim_t or {}; PARTS.aim_t[K.model.name] = tn
          PARTS.aim_n[K.model.name] = (PARTS.aim_n[K.model.name] or 0) + 1
          PARTS.aims = PARTS.aims + 1
          local x, y, z = loc(FR[1], aim)
          local gx, gy, gz = loc(FR[1], from)
          event(string.format('part aim (test): %s on %s %d: the game aims at %.2f %.2f %.2f in its frame, the gun at %.1f %.1f %.1f; the line meets %s',
            dog.name, K.model.name, c.id, x, y, z, gx, gy, gz, part and (part .. ' AV' .. av) or 'nothing'))
        end
      end
    end
    local t = now()
    local can
    if av then can = av <= pen end
    if can then
      V.last_can = t
    elseif V.last_can and t - V.last_can < PARTS.HOLD then
      can = true
    end
    local r
    if can == nil then
      r = nil   -- (not worked out, and no recent 'it can': the whole-enemy rules)
    else
      r = not can
      -- a change of answer is counted (and in test builds written out, at most 60); not the first look that says
      -- skip - that is what every gun says of every armored enemy facing it
      local first = V.can == nil
      if V.can ~= can and not (first and not can) then
        V.can = can
        local say = (av and (part .. ' AV' .. av) or 'part not found (held)') .. (can and ': fires' or ': skips')
        local name = (ARMOR[c.kind] and ARMOR[c.kind].name) or K.model.name
        bump(session.parts, string.format('%s on %s: %s', dog.name, name, say))
        if TESTER and PARTS.lines < 60 then
          PARTS.lines = PARTS.lines + 1
          local gl = ''
          if aim then
            local FR = frame(c)
            if FR then local x, y, z = loc(FR[1], aim); gl = string.format(', the game aims at %.2f %.2f %.2f in its frame', x, y, z) end
          end
          event(string.format('part check: %s on %s %d: %s%s%s', who and tostring(who) ~= dog.name and (dog.name .. ' ' .. tostring(who)) or dog.name,
            name, c.id, say, ang and string.format(' (%.0f deg from straight behind)', ang) or '', gl))
        end
      end
      if first then V.can = can end
    end
    tick_sweep(t)   -- (old answers are dropped now and then: the tables must not grow all session)
    if aim then V.fa, V.ra = FRAME, r else V.fn, V.rn = FRAME, r end
    return r
  end
  -- ((5.1.0 Test 1) Heavy Devastators: is the gun's line on its body rather than its shield? true while the line meets
  -- any part but the Shield, and for PARTS.HOLD after (so it doesn't flip between bursts and full auto as it turns);
  -- false when the shield is in the way or it can't be worked out (short bursts, as before). The first answer each frame
  -- is kept per gun and enemy; a change is counted (and written out in test builds, with the part checks' limit)
  PARTS.exp = {}
  PARTS.exposed = function(dog, c, from, who, aim)
    if not (from and c.kind and PARTS.kinds[c.kind]) then return false end
    local key = who or dog.name
    local E = PARTS.exp[key]
    if not E then E = {}; PARTS.exp[key] = E end
    local X = E[c.id]
    if not X then X = {}; E[c.id] = X end
    if X.f == FRAME then return X.r end
    local ok, av, part = pcall(PARTS.meet, c, from, aim)
    local t = now()
    X.seen = t
    if ok and av and part ~= 'Shield' then X.last = t end
    local r = X.last ~= nil and t - X.last < PARTS.HOLD
    if r ~= X.was then
      if X.was ~= nil or r then
        bump(session.parts, string.format('%s on %s: %s', dog.name, (ARMOR[c.kind] and ARMOR[c.kind].name) or '?', r and 'body open: full auto' or 'shield in the way: short bursts'))
        if TESTER and PARTS.lines < 60 then
          PARTS.lines = PARTS.lines + 1
          event(string.format('part check: %s on %s %d: %s (%s)', who and tostring(who) ~= dog.name and (dog.name .. ' ' .. tostring(who)) or dog.name,
            (ARMOR[c.kind] and ARMOR[c.kind].name) or '?', c.id, r and 'body open: full auto' or 'shield in the way: short bursts',
            ok and av and (part .. ' AV' .. av) or 'part not found'))
        end
      end
      X.was = r
    end
    X.f, X.r = FRAME, r
    tick_sweep(t)
    return r
  end
end

-- switched on by the optional 'Armor skipping' part of the mod (a tiny second addon that sets this flag); read
-- every frame, so load order does not matter
-- ((5.0 Test 12) from = the gun's muzzle (or the dog), who = which gun (a sentry's id; a dog's name), aim = where the
-- game is aiming it now, if this enemy is its target: with them, an enemy with a part model is judged by the part the
-- line of fire meets; without them, or when that can't be worked out, by the whole-enemy rules as before)
-- ((5.1 Test 1) the part answer comes first; the whole-enemy rules (the main armor) are the fallback when the part can't be
-- worked out. Heavy Devastators are never skipped: see a.burst below)
local armor_state
local function cannot_hurt(dog, c, from, who, aim)
  local on = rawget(_G, 'SmarterGuardDogsArmor') == true
  if on ~= armor_state then armor_state = on; note('armor intelligence: ' .. (on and 'on' or 'off (option not installed)')) end
  if not on or not c.kind then return false end
  local a = ARMOR[c.kind]
  if not a then return false end
  if a.sentries_skip and dog.sentry then return true end         -- dropships: no sentry shoots them
  -- ((5.1.0 Test 1, my ask: "guard dog should still fire short bursts at the heavy devastator, the point is
  -- suppression"; "dont have any of the sentries hold fire on the heavy devastators, it should fire short bursts to keep
  -- them surpressed and then if its turned around it should go full auto") no gun skips a Heavy Devastator: the guns
  -- that fire short bursts (the Guard Dog, the machine gun and Gatling sentries) burst while its shield is in the way and
  -- go full auto while its back is turned (PARTS.exposed); the rest fire on it as before
  if a.burst then return false end
  local pen = dog.pen or PEN[dog.name] or 99
  if a.av <= pen then return false end
  if from and PARTS.kinds[c.kind] then
    local ok, r = pcall(PARTS.decide, dog, c, from, who, aim, pen)
    if ok then
      if r ~= nil then return r end
    else
      if not PARTS.failed then PARTS.failed = true; note('part armor stopped (error): ' .. tostring(r)) end
      PARTS.kinds = {}   -- (back to the whole-enemy rules for every enemy)
    end
  end
  if a.open then return false end                                 -- (5.1) Gatekeeper, Veracitor: shot at as before
  if a.legs and a.legs <= pen then return false end
  return true
end
laser.cannot_hurt = cannot_hurt   -- ((5.0 Test 10) for the dogs' markers (engine_laser.lua comes first)
-- ((5.1.0 Test 1) short bursts while the shield is in the way (or the part can't be worked out); full auto while its
-- line meets the body - turned around, or the shield held aside: see PARTS.exposed)
local function burst_only(dog, c, from, aim)
  local a = c.kind and rawget(_G, 'SmarterGuardDogsArmor') == true and ARMOR[c.kind]
  if not (a and a.burst and dog.name == 'Guard Dog') then return false end
  return not PARTS.exposed(dog, c, from, dog.name, aim)
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
