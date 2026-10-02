-- HD2-Addon: mods/chef/smarter_guard_dogs
-- Smarter Guard Dogs & Sentries for Helldivers 2 (Bingus Shared Loader v15+ addon).
--  * Rover (laser): fast target switching so its burn spreads over the group.
--  * Rover, K-9 and Guard Dog: player safety - they will not fire through you or your teammates.
--  * All three go for the enemy closest to you first.
--  * They move on the moment their target dies instead of shooting the body.
--  * Sentries (4.0): the same safety for your sentries - no firing through you or your teammates, also not while
--    they swing round to a new target; mortars leave enemies next to a helldiver alone; the machine gun and
--    Gatling sentries skip armor they can't hurt; sentries stop firing into walls, go for the right target first,
--    and the Tesla Tower leaves helldivers alone.
--  * (5.0) The same for the guns on armed resupply pods (Armed Resupply Pods booster) and on the Supply FRV.
--  * Options (4.0.5), each a tiny addon that sets a flag read every frame: Guard Dogs; Sentries (all, or all but the
--    Tesla Tower); Intelligence (Armor Intelligence and/or Target Prioritization); Safety (you and/or your teammates);
--    Targeting Laser (your screen only).
--  * Finds the game addresses it needs by scanning the game's code after a patch.
-- Inspired by retrox's "Laser Rover Targeting Optimization"; this is an independent implementation.
-- Keeps a small status log (SmarterGuardDogsAndSentries.log) in the local app-data folder for bug reports.
local VERSION = '4.6.2'
local READ_ONLY = false            -- diagnostic builds set this to true: nothing is ever written to game memory
local TESTER = false               -- test builds only: F8 markers and the list of enemy types the dog picked, in the log

if rawget(_G, 'SmarterGuardDogs') then return end
local SGD = { version = VERSION, status = 'starting', read_only = READ_ONLY, seaf_only = false }   -- (seaf_only: the Smarter SEAF build, build_seaf.py)
rawset(_G, 'SmarterGuardDogs', SGD)

local ffi = require('ffi')
local bit = require('bit')
