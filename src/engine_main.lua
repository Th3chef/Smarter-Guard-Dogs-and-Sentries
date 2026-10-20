-- ======================================================================================================
-- Main loop
-- ======================================================================================================
local next_poll, last_log, broken = 0, 0, false
local LOG_EVERY = { idle = 60, changed = 15 }   -- (4.6.7) seconds between log rewrites: in a mission / out of one (5.1.4)
local read_fail_since           -- (4.6.6 review) when the dog's reads started failing (nil: they work)
local last_poll_t
local sentry_broken, sentry_last_error = false, nil
local error_repeats = 0   -- (4.6.4 review: the same read error again, counted instead of logged again)
-- (4.5.3) Bingus' Mod Options Menu (optional, needs Bingus Shared Loader v18+): the same options as in the mod manager
-- (Arsenal), in the same order, with the same names, choices and texts, under ESC > MODS > SMARTER GUARD DOGS &
-- SENTRIES; an option with sub-options gets 'Off' first, then its sub-options (as in Armored Overhaul's rows). Each sets the same flags as the
-- option addons, which the mod reads every frame, so a change takes effect the moment it is applied. The mod manager's
-- picks are the starting values, and each row's id carries the pick it started from (the pattern shared with
-- Armored Overhaul, the project note on the Mod Options Menu), so picking something else in the mod manager starts
-- that row afresh from the new pick instead of an old saved value. The menu may load after this mod: it is looked
-- for once a second until found, and the rows are added once
local menu_step = (function()
  local ID = 'smarter_guard_dogs.'
  local MOD = 'SMARTER GUARD DOGS & SENTRIES'
  local function flag(k) return rawget(_G, 'SmarterGuardDogs' .. k) == true end
  local function set(k, v) rawset(_G, 'SmarterGuardDogs' .. k, v == true) end
  -- (Laser Brightness: the mod manager's sub-options, dimmest to brightest here - a tester's call, 4.5.3 Test 14; the mod
  -- manager lists Normal first because it preselects its first entry. No 'Off' - without the option the laser is at its
  -- normal brightness, the same as 'Normal (100%)')
  local BRIGHT = { 0.5, 0.75, 1.0, 1.5, 2.0 }
  local OPAC = { 0.25, 0.5, 0.75, 1.0 }   -- ((5.0 Test 15) Marker Opacity)
  local SIZE = { 0.5, 0.75, 1.0, 1.5, 2.0 }   -- ((5.1.0 Test 1) Marker Size, smallest first)
  -- each row, in the mod manager's order: its choices, which flags each sets, and the starting choice from the flags
  local OPTS = {
    { key = 'dogs', label = 'Guard Dogs', type = 'toggle',
      description = 'The mod handles your guard dog (Guard Dog, Rover, K-9). Turn off to leave your dog to the game; your sentries and the rest of the mod keep working.',
      apply = function(v) set('Dogs', v) end, start = function() return flag('Dogs') end },
    { key = 'sentries', label = 'Sentries', type = 'choice', choices = { 'Off', 'All sentries', 'All but the Tesla Tower' },
      description = 'The mod handles your sentries (Machine Gun, Gatling, Autocannon, Rocket, Laser, Flame, Mortar, EMS Mortar, Gas Mortar and the Tesla Tower), plus the guns on armed resupply pods and the Supply FRV. Turn off to leave your sentries to the game; your guard dog and the rest of the mod keep working.',
      apply = function(v) set('Sentries', v ~= 1); set('Tesla', v == 2) end,
      start = function() return not flag('Sentries') and 1 or (flag('Tesla') and 2 or 3) end },
    { key = 'intelligence', label = 'Intelligence', type = 'choice',
      choices = { 'Off', 'Armor Intelligence and Target Prioritization', 'Only Armor Intelligence', 'Only Target Prioritization' },
      description = 'How your dogs and sentries choose what to shoot. Armor Intelligence: they shoot armor only at parts they can hurt, burst at a Heavy Devastator\'s shield and leave dropships alone. Target Prioritization: your dog takes the closest threat to you first; your sentries take enemies at their feet, Gunships and the right armor first. Turn off to leave both to the game.',
      apply = function(v) set('Armor', v == 2 or v == 3); set('Priority', v == 2 or v == 4) end,
      start = function() local a, p = flag('Armor'), flag('Priority'); return (a and p) and 2 or (a and 3) or (p and 4) or 1 end },
    -- (5.0) Ping Targeting: its own on/off row, after Intelligence
    { key = 'ping', label = 'Ping Targeting', type = 'toggle',
      description = 'Your sentries go for an enemy you or a teammate ping: each sentry that can hurt it and has it in reach and in view turns to it first, for up to 20 seconds after the ping. The safety rules still come first, and a ping waits while an enemy is at the sentry\'s feet or right next to a helldiver. Turn off to let them pick their own targets.',
      apply = function(v) set('Ping', v) end, start = function() return flag('Ping') end },
    { key = 'safety', label = 'Safety', type = 'choice', choices = { 'Off', 'You and your teammates', 'Only you', 'Only your teammates' },
      description = 'Who your dog and your sentries never fire through: they hold fire while that helldiver is in their line of fire, don\'t swing their fire across them, mortars and the rocket sentry leave enemies next to them alone, and the Tesla Tower doesn\'t zap them or arc into them. Turn off at your own risk: they will fire through anyone. Everything else keeps working.',
      apply = function(v) set('Safety', v == 2 or v == 3); set('Teammates', v == 2 or v == 4) end,
      start = function() local y, m = flag('Safety'), flag('Teammates'); return (y and m) and 2 or (y and 3) or (m and 4) or 1 end },
    -- (4.6.5) Sentry Safety: its own on/off row, after Safety
    { key = 'sentry_safety', label = 'Sentry Safety', type = 'toggle',
      description = 'Your sentries don\'t shoot through other sentries, yours or other players\': they hold fire while one is in their line of fire, don\'t swing their fire across one, and the mortars and the rocket, autocannon and flame sentries leave alone enemies right next to one. Turn off to let them fire through sentries. Everything else keeps working.',
      apply = function(v) set('SentrySafety', v) end, start = function() return flag('SentrySafety') end },
    -- (4.7.0) SEAF Safety: its own on/off row, after Sentry Safety
    { key = 'seaf_safety', label = 'SEAF Safety', type = 'toggle',
      description = 'Your guard dog and your sentries don\'t shoot through SEAF soldiers or civilians: they hold fire while one is in their line of fire, don\'t swing their fire across one, and the mortars, the Tesla Tower and the rocket, autocannon and flame sentries leave alone enemies right next to one. Turn off to let them fire through SEAF soldiers and civilians. Everything else keeps working.',
      apply = function(v) set('SEAFSafety', v) end, start = function() return flag('SEAFSafety') end },
    -- ((5.1.3, my ask: "organize the options better for the targeting laser ... add targeting laser color as an
    -- option and then add Targeting laser Glow and Line as options again") as in the mod manager: the style here, the colors
    -- in Laser Color. New keys: the old 'laser' (Line / Glow) and 'laser_color' (Off / Red / Green / Line) rows saved other
    -- choice numbers
    -- ((release review, my ask: "Glow laser should be first, and line should be an option they can switch to") Glow
    -- first, as in the mod manager)
    { key = 'laser_style', label = 'Targeting Laser', type = 'choice', choices = { 'Glow', 'Line', 'Off' },
      description = 'A laser from the barrel of your guard dog and your sentries (not the mortars), only on your screen: one color while they fire, the other flashing when a friendly is in the way (see Laser Color). Glow: a soft glowing beam that shows through walls, like the markers. Line: a thin line that walls hide. The Tesla Tower shows its reach as a red ring.',
      apply = function(v) set('Laser', v ~= 3); set('Glow', v == 1) end,
      start = function() return not flag('Laser') and 3 or (flag('Glow') and 1 or 2) end },
    { key = 'laser_colors', label = 'Laser Color', type = 'choice', choices = { 'Red while firing', 'Green while firing' },
      description = 'The targeting laser\'s colors, for the Glow and the Line. Red while firing: red while they fire, flashing green when a friendly is in the way. Green while firing: the other way round (the colors before 5.0).',
      apply = function(v) set('LaserInvert', v == 2) end,
      start = function() return flag('LaserInvert') and 2 or 1 end },
    { key = 'laser_brightness', label = 'Laser Brightness', type = 'choice',
      choices = { 'Dim (50%)', 'Softer (75%)', 'Normal (100%)', 'Bright (150%)', 'Brightest (200%)' },
      description = 'How bright the targeting laser is: its beams and rings.',
      apply = function(v) if BRIGHT[v] then rawset(_G, 'SmarterGuardDogsLaserBrightness', BRIGHT[v]) end end,
      start = function()
        local b = rawget(_G, 'SmarterGuardDogsLaserBrightness')
        if type(b) ~= 'number' then return 3 end
        local best, bd = 3, nil
        for i, x in ipairs(BRIGHT) do if not bd or math.abs(x - b) < bd then best, bd = i, math.abs(x - b) end end
        return best
      end },
    -- (5.0 Test 13) Targeting Marker: its own row, after Laser Brightness. ((5.1.3) a choice now, as in the mod
    -- manager: through walls or hidden by them - a new key, the old 'marker' row saved on/off)
    { key = 'marker_walls', label = 'Targeting Marker', type = 'choice', choices = { 'Off', 'Through walls', 'Behind walls' },
      description = 'The gun\'s stratagem icon over the enemy your guard dog or sentry is on, only on your screen: yellow while it is on it, gray when it goes out of sight. Only on enemies it can hurt and has in reach. Through walls: shown over everything, like a ping. Behind walls: walls hide it (drawn solid, so Marker Opacity doesn\'t change it).',
      apply = function(v) set('Marker', v ~= 1); set('MarkerWalls', v == 3) end,
      start = function() return not flag('Marker') and 1 or (flag('MarkerWalls') and 3 or 2) end },
    -- (5.0 Test 15) Marker Opacity: how see-through the markers are (dimmest first, like Laser Brightness)
    { key = 'marker_opacity', label = 'Marker Opacity', type = 'choice',
      choices = { 'Faint (25%)', 'Light (50%)', 'Medium (75%)', 'Full (100%)' },
      description = 'How solid the targeting markers are drawn. Full is how they are designed; lower lets more of the game show through them.',
      apply = function(v) if OPAC[v] then rawset(_G, 'SmarterGuardDogsMarkerOpacity', OPAC[v]) end end,
      start = function()
        local o = rawget(_G, 'SmarterGuardDogsMarkerOpacity')
        if type(o) ~= 'number' then return 4 end
        local best, bd = 4, nil
        for i, x in ipairs(OPAC) do if not bd or math.abs(x - o) < bd then best, bd = i, math.abs(x - o) end end
        return best
      end },
    -- (5.1.0 Test 1) Marker Size: how big the markers are (smallest first)
    { key = 'marker_size', label = 'Marker Size', type = 'choice',
      choices = { 'Smallest (50%)', 'Small (75%)', 'Normal (100%)', 'Large (150%)', 'Largest (200%)' },
      description = 'How big the targeting markers are drawn. Normal is how they are designed.',
      apply = function(v) if SIZE[v] then rawset(_G, 'SmarterGuardDogsMarkerSize', SIZE[v]) end end,
      start = function()
        local o = rawget(_G, 'SmarterGuardDogsMarkerSize')
        if type(o) ~= 'number' then return 3 end
        local best, bd = 3, nil
        for i, x in ipairs(SIZE) do if not bd or math.abs(x - o) < bd then best, bd = i, math.abs(x - o) end end
        return best
      end },
  }
  local done, at = false, 0
  return function()
    if done or FRAME < at then return end
    at = FRAME + 60
    local menu = rawget(_G, 'ModOptionsMenu')
    if type(menu) ~= 'table' or menu.api ~= 1 or type(menu.register_option) ~= 'function' then return end
    done = true
    local added, failed = 0, nil
    for _, o in ipairs(OPTS) do
      local start = o.start()
      -- (the id carries the mod manager's pick: 'on'/'off' for a checkbox, else the choice's number)
      local id = ID .. o.key .. '.' .. (type(start) == 'boolean' and (start and 'on' or 'off') or tostring(start))
      local spec = { type = o.type, label = o.label, mod = MOD, description = o.description, choices = o.choices, default = start }
      local ok, did, why = pcall(menu.register_option, id, spec)
      if ok and did then
        added = added + 1
        local okg, v = pcall(menu.get, id)
        if okg and v ~= nil then pcall(o.apply, v) end
        pcall(menu.on_change, id, function(value) pcall(o.apply, value); session.dirty = true end)
      else
        failed = id .. ': ' .. tostring(ok and why or did)
      end
    end
    rawset(_G, 'SmarterGuardDogsMenu', added > 0)
    note('options menu: ' .. added .. ' setting(s) in the MODS tab' .. (failed and ('; not added: ' .. failed) or ''))
  end
end)()

-- (4.6.3) this frame's laser: the dog's beam and the sentries' beams, drawn together (called in a pcall from tick)
laser.step = function(st, sentries_out, t)
  laser.inv = laser.inverted()   -- ((5.1.0 release review) the Targeting Laser color choice, once a frame)
  laser.walls = rawget(_G, 'SmarterGuardDogsMarkerWalls') == true   -- ((5.1.3) Targeting Marker: Behind walls
  laser.mark_lines = 0   -- ((5.1.4) the Behind walls markers' line budget, this frame's
  -- (the markers drawn as lines - Behind walls, or a game build with no world GUI: their icons cut ahead, one a frame)
  -- ((release review) only while the markers are on, and no more once every icon is cut)
  if not laser.markers_warm and rawget(_G, 'SmarterGuardDogsMarker') == true
     and (laser.walls or not (laser.glow and laser.glow.markers_ok())) then laser.warm_markers() end
  laser.me = (st and st.player_pos) or EXT.me   -- ((5.0) beams fade with their distance from you)
  local beams = {}
  laser.dog_target = false
  if st then laser_frame(st, beams, P.safety_now and P.safety_t or nil, P.safety_enemy, P.safety_step, P.cover_t, P.cover_enemy, P.cover_step) end
  if sentries_out then sentry_beams(beams, t) end
  -- ((5.0 Test 13, my ask: "Targeting Marker should be an option that can be toggled") the markers belong to the
  -- Targeting Marker option, the beams and rings to the Targeting Laser: whatever is off is dropped here
  local lines_on, marks_on = rawget(_G, 'SmarterGuardDogsLaser') == true, OPT.marker()
  if not (lines_on and marks_on) then
    local kept = {}
    for _, b in ipairs(beams) do
      if (b.marker and marks_on) or (not b.marker and lines_on) then kept[#kept + 1] = b end
    end
    kept.rings = lines_on and beams.rings or nil
    beams = kept
  end
  if #beams > 0 or beams.rings then laser_draw(beams) else laser_clear() end
end

-- ((5.1.5 Test 11) the idle state's changes, logged once each (up to 40 a mission), and its frame counts for the log)
local function idle_note(t, working, why)
  IDLE.frames = IDLE.frames + 1
  if working then IDLE.work_frames = IDLE.work_frames + 1 end
  -- (each change between idle and working, and between idle reasons; not between the working ones, which come and go
  -- as the dog and the sentries take turns)
  if working ~= IDLE.working or (not working and why ~= IDLE.state) then
    IDLE.working, IDLE.state = working, why
    IDLE.notes = IDLE.notes + 1
    if IDLE.notes <= 40 then event(why) elseif IDLE.notes == 41 then event('(idle and working changes: no more are logged this mission)') end
  end
end

local function tick()
  local t = os.clock()
  FRAME = FRAME + 1
  -- (4.6.4) CowboyBingus's Laser Sentry Cooldown (it keeps an overheated Laser Sentry from exploding: it cools down and
  -- comes back): noted once - both work together, this mod still stands the sentry down before it overheats
  if not SGD.lsc_seen and FRAME % 120 == 1 and rawget(_G, 'LaserSentryCooldownInstalled') then
    SGD.lsc_seen = true
    note('Laser Sentry Cooldown (CowboyBingus) is installed: works alongside it (an overheated Laser Sentry cools down and comes back; this mod still cools it before it overheats)')
  end
  menu_step()
  -- (numbered Tester builds only: the research probe, engine_probe.lua - not in releases)
  if SGD.probe_step then SGD.probe_step(t) end
  -- the log is rewritten every 10 s, and within a second of anything new being noted
  -- ((4.6.4 review) a change is written within 3 s, not every second: each rewrite is a whole file on the game thread;
  -- errors and shutdown still write at once)
  -- ((4.6.7, a player reported a performance cost) each rewrite took ~3.3 ms on the game thread in a Test 3 log (every
  -- one over 1 ms - the mod's only frame spikes; everything else ~0.15 ms a frame): now every 60 s, and a change within
  -- 15 s (was every 10 s and within 3 s). Errors and shutdown still write at once)
  -- ((5.1.4, players: "the performance is much worse"; a 5.1.3 Tester log: 19 rewrites at ~3.2 ms each, the mod's only
  -- frame spikes) in a mission only once a minute and only with something new; when the mission ends, at once; out of
  -- a mission within 15 s of a change. Nothing new, no rewrite. Errors and shutdown still write at once
  local in_mission = SGD.status ~= 'not in a mission'
  if in_mission then SGD.log_mission = true end
  if not in_mission and SGD.log_mission then
    SGD.log_mission = false; last_log = t; pcall(write_log)   -- (the mission's totals, as it ends)
  elseif session.dirty and t - last_log >= (in_mission and LOG_EVERY.idle or LOG_EVERY.changed) then
    last_log = t; pcall(write_log)   -- ((4.6.6 review) in a pcall: a log error stopped the whole mod)
  end
  -- (test builds: F8 also works while no dog is out, e.g. right after you died; checked every frame so a quick
  -- press isn't missed between the slower polls)
  if TESTER and (SGD.status ~= 'active' or IDLE.dog_asleep) then pcall(check_marker, nil) end
  if broken or t < next_poll then
    -- (a frame the mod skips: the laser as it was - sent again as they are)
    if not broken and laser_wanted() then laser.redraw() end
    if IDLE.working ~= nil then idle_note(t, IDLE.working, IDLE.state) end
    return
  end
  next_poll = t + 0.1          -- relaxed while nothing is going on; every frame while a dog is out (below)
  stats.polls = stats.polls + 1
  local ok, st, why
  -- ((5.1.5 Test 11) a dog with nothing to do idles: only its look every IDLE.look s (IDLE.dog_peek); anything else
  -- wakes it, and it is then looked up afresh before anything is done)
  local asleep = false
  if IDLE.dog_asleep then
    if t < IDLE.dog_next then asleep = true
    else
      IDLE.dog_next = t + IDLE.look
      local okp, still = pcall(IDLE.dog_peek, t)
      if okp and still then asleep = true
      else IDLE.dog_asleep, IDLE.dog_since = false, nil; IDLE.dog_wake(); IDLE.wake_scan = true end
    end
  end
  if asleep then ok, st, why = true, nil, nil else ok, st, why = pcall(read_state) end
  if not ok then
    local e = st
    st = nil
    if type(e) == 'table' and e[1] == Abort then why = 'read_failed: ' .. tostring(e[2])
    else
      -- a bug in this mod rather than an unexpected game state: stop steering for the rest of the session
      -- (4.6.3: the sentries too - they are no longer ticked once 'broken' is set, so their hidden enemies and a Tesla
      -- Tower's target list are put back now, as the update wrapper below does)
      broken = true; why = 'stopped after error: ' .. tostring(e); restore()
      sentry_broken = true; pcall(sentry_restore)
    end
    stats.read_errors = stats.read_errors + 1
    -- ((4.6.4 review) the same error again: counted, not logged again - a check that kept failing filled the recent
    -- events and the first-10 error list with copies and rewrote the log every second)
    if why == last_error then
      error_repeats = error_repeats + 1
    else
      if error_repeats > 0 then event(string.format('(the last error repeated %d more time(s))', error_repeats)) end
      error_repeats = 0
      event('error: ' .. tostring(why))
      pcall(write_log); last_log = t   -- (a new error is in the log at once)
    end
    last_error = why
  end
  local status = (st or asleep) and 'active' or why
  -- ((5.1.5 review) the end of a mission, whatever is out or switched on: the damage check is armed afresh in the next
  -- one (it was reset in the sentries' step only, which returns early with the Sentries option off), and the dog's count
  -- of enemies it left alone for doing no damage goes (it decides how long the next one is left alone)
  if why == 'not in a mission' and SGD.status ~= 'not in a mission' then
    HEALTH.proven = false
    P.nd_n, P.nd, P.dw = nil, nil, nil
    read_candidates('forget')   -- ((5.1.5 Test 18) the kept registry places
    IDLE.dog_asleep, IDLE.dog_since, IDLE.notes = false, nil, 0
  end
  -- ((4.6.4 review) out of a mission: forget the laser's per-world objects - see laser.forget)
  -- ((5.1.2, my note: make sure a ring isn't left on screen) but the game keeps its world through the extraction
  -- (ship and later missions), and a line object goes on showing its last dispatch: a Tesla Tower still out, the
  -- Rocket Sentry's ring on its lit half, or a dog's beam at that moment stayed on screen until the game restarted
  -- (sims sentry_tesla_mission_end / sentry_rocket_mission_end). So on the poll the mission ends - the poll before was
  -- in it, a fraction of a second ago, too soon for the world to be rebuilt - everything is cleared once first, and
  -- only in the world it was drawn in (laser_draw only touches the objects kept for the world main_world() gives now)
  if why == 'not in a mission' and (next(laser.worlds) or (laser.glow and next(laser.glow.guis))) then
    if SGD.status ~= 'not in a mission' then laser.clear_now() end
    laser.forget()
  end
  local dogname = st and st.dog.name or (asleep and SGD.dog) or nil
  if status ~= SGD.status then event('status: ' .. tostring(status)) end
  if dogname and dogname ~= SGD.dog then event('dog: ' .. dogname) end
  local dt = last_poll_t and math.min(t - last_poll_t, 0.5) or 0
  last_poll_t = t
  session.state_time[tostring(status)] = (session.state_time[tostring(status)] or 0) + dt
  if dogname then
    local d = session.dog_time[dogname] or { out = 0, targeted = 0, firing = 0 }
    session.dog_time[dogname] = d
    d.out = d.out + dt
    if st and st.target ~= 0 then d.targeted = d.targeted + dt; if st.node == 7 then d.firing = d.firing + dt end end
  end
  if asleep then
    -- (the dog idles: nothing to read or steer)
  elseif not st then
    SGD.status, SGD.dog = why, nil
    -- ((4.6.6 review) a failed read keeps the dog's hidden enemies hidden for up to half a second: putting them all
    -- back at once let the game pick the enemy behind you while the dog was still out. Each one is put back only if its
    -- entry still holds that enemy, so keeping them is safe; out of a mission, an error or the dog gone puts them back)
    local transient = type(why) == 'string' and why:find('^read_failed') ~= nil
    if transient then read_fail_since = read_fail_since or t else read_fail_since = nil end
    if next(hidden) and not (transient and t - read_fail_since < 0.5) then restore() end
  else
    read_fail_since = nil
    SGD.status, SGD.dog = 'active', st.dog.name
    if #st.mates > session.team.max then session.team.max = #st.mates end
    if st.mates_found ~= session.team.last then
      session.team.last = st.mates_found
      session.team.notes = session.team.notes + 1
      if session.team.notes <= 20 then
        event(string.format('teammates: %d found', st.mates_found) .. (TESTER and (' (' .. team_detail(st.player_pos) .. ')') or ''))
      end
    end
    next_poll = 0
    local dreq = plan(st)
    steer(st, dreq)
    if SGD.probe_dog then SGD.probe_dog(st, t) end   -- (numbered Tester builds: the research probe)
    if TESTER then
      pcall(SGD.dog_seaf_check, st, dreq, t)
      pcall(check_marker, st)
      -- how the dog spends its time while out: docked on your back (reloading), no target, or its AI step
      local P2, D = st.player_pos, st.drone_pos
      local docked = P2 and D and ((D[1] - P2[1]) ^ 2 + (D[2] - P2[2]) ^ 2) < 1.2 ^ 2
      bump(session.steps, st.dog.name .. ': ' .. (docked and 'docked on your back' or (st.target == 0 and 'no target' or ('AI step ' .. st.node))))
    end
    -- nothing around and nothing hidden: look three times a second less often (enemies take a moment to arrive)
    if #st.candidates == 0 and st.target == 0 and not next(hidden) then next_poll = t + 0.05 end
    -- ((5.1.5 Test 11) nothing to do - no target, nothing hidden from it, no enemy alive in its list within IDLE.range -
    -- for IDLE.settle s: it idles. The bodies in its list then are left out of its look (they never come back to life))
    local quiet = st.target == 0 and not next(hidden)
    if quiet then
      local R2 = IDLE.range * IDLE.range
      for _, c in ipairs(st.candidates) do if (c.alive and (not c.d2 or c.d2 < R2)) or c.mask == BLANK then quiet = false; break end end
    end
    if not quiet then IDLE.dog_since = nil
    elseif not IDLE.dog_since then IDLE.dog_since = t
    elseif t - IDLE.dog_since >= IDLE.settle then
      IDLE.dog_asleep, IDLE.dog_next, IDLE.dog_since = true, t + IDLE.look, nil
      local skip = {}
      for _, c in ipairs(st.candidates) do if not c.alive then skip[c.id] = true end end
      IDLE.dog_skip = skip
    end
    if RESEARCH then local okr, er = pcall(research_frame, st); if not okr then RESEARCH = false; note('research stopped: ' .. tostring(er)) end end
  end
  -- sentries (4.0): handled whether or not a dog is out; polled every frame while one of yours is out
  local sentries_out, sentries_busy = false, false
  if not sentry_broken then
    local ok3, r, busy = pcall(sentry_tick, st, t, dt)
    if ok3 then sentries_out, sentries_busy = r, busy
    elseif type(r) == 'table' and r[1] == Abort then
      -- (a structure that couldn't be read this time, e.g. during loading: try again next poll)
      local msg = 'sentries: read_failed: ' .. tostring(r[2])
      if msg ~= sentry_last_error then sentry_last_error = msg; event(msg) end
    else
      sentry_broken = true; last_error = 'sentries stopped after error: ' .. tostring(r)
      event('error: ' .. last_error); pcall(sentry_restore)
    end
  end
  -- (every frame while a sentry is busy; idle ones - no target, no enemy in their lists - ten times a second)
  if sentries_busy then next_poll = 0 end
  -- ((5.1.5 Test 11) the whole mod idles while no dog is awake and no sentry is busy: a poll every IDLE.look s)
  local working = st ~= nil or sentries_busy == true
  if not working then next_poll = math.max(next_poll, t + IDLE.look); IDLE.idle_s = IDLE.idle_s + dt end
  IDLE.on = not working
  idle_note(t, working, working and (st and ('working: your ' .. st.dog.name .. ' (an enemy within ' .. IDLE.range .. ' m, or a target)')
      or ('working: your sentries (an enemy within ' .. IDLE.range .. ' m, a target, or a Tesla Tower out)'))
    or (why == 'not in a mission' and 'idle: not in a mission (menus, the ship or loading)')
    or ((asleep or sentries_out) and ('idle: no enemy within ' .. IDLE.range .. ' m of your guard dog or sentries'))
    or 'idle: no guard dog out and no sentries of yours')
  -- the laser: the dog's beam and the sentries' beams, drawn together
  -- (4.6.3) in a pcall of its own: an error in the laser (it is only for show) stops the laser, not the steering
  -- ((5.1.2) nothing is drawn out of a mission: sentries still read as out there (the end of a mission, before their
  -- units go) were drawn again into fresh objects, which the next poll forgot - on screen until the game restarted)
  if laser_wanted() and laser_ready() and why ~= 'not in a mission' then
    local okl, errl = pcall(laser.step, st, sentries_out, t)
    if not okl then laser_fail(errl) end
  else laser_clear() end
end

local ok, err = pcall(function() A = resolve_layout() end)
if not ok then
  SGD.status = 'off: ' .. tostring(err)
  note('could not find the game addresses, the mod stays off: ' .. tostring(err))
  pcall(write_log)
  return
end

local game_update, game_shutdown = rawget(_G, 'update'), rawget(_G, 'shutdown')
if type(game_update) ~= 'function' then
  SGD.status = 'off: game update function not found'; pcall(write_log); return
end
do
  -- (after the game's update: the Tesla Tower's hidden helldivers are hidden again, see sentry_after. 4.6.4 Test 9
  -- tried the same for every sentry and the dog: in game it never found one shown again - the game shows hidden
  -- entries again later in the frame, after this hook - so it was taken out)
  local function after(...)
    if not broken and not sentry_broken then pcall(sentry_after) end
    return ...
  end
  -- (4.0.6 test builds) what the mod itself costs each frame, measured with the high-precision system timer: the log
  -- shows the average and highest, and how many frames went over 1 ms
  local timed = TESTER and pcall(function()
    pcall(ffi.cdef, 'int SgdQueryPerformanceCounter(int64_t *count) __asm__("QueryPerformanceCounter");')
    pcall(ffi.cdef, 'int SgdQueryPerformanceFrequency(int64_t *freq) __asm__("QueryPerformanceFrequency");')
    local q, f = ffi.new('int64_t[1]'), ffi.new('int64_t[1]')
    assert(K32.SgdQueryPerformanceFrequency(f) ~= 0 and f[0] > 0)
    local per_ms = tonumber(f[0]) / 1000
    local T = { n = 0, sum = 0, max = 0, over = 0, parts = {} }
    session.timing = T
    -- (4.6.7 Test 1, a player reported a high performance cost) the main parts timed too - the log rewrite, reading
    -- the dog's state, the sentries and the laser - so a test log shows which one makes the slow frames
    local q2 = ffi.new('int64_t[1]')
    local function finish(Pt, a, ...)
      K32.SgdQueryPerformanceCounter(q2)
      local ms = tonumber(q2[0] - a) / per_ms
      Pt.n, Pt.sum = Pt.n + 1, Pt.sum + ms
      if ms > Pt.max then Pt.max = ms end
      if ms > 1 then Pt.over = Pt.over + 1 end
      return ...
    end
    local function part(name, fn)
      local Pt = { name = name, n = 0, sum = 0, max = 0, over = 0 }
      T.parts[#T.parts + 1] = Pt
      return function(...) K32.SgdQueryPerformanceCounter(q2); return finish(Pt, q2[0], fn(...)) end
    end
    write_log = part('writing the log', write_log)
    read_state = part('reading the dog and enemies', read_state)
    sentry_tick = part('sentries', sentry_tick)
    laser.step = part('laser', laser.step)
    SGD.time_tick = function()
      K32.SgdQueryPerformanceCounter(q); local a = q[0]
      local ok2, e = pcall(tick)
      K32.SgdQueryPerformanceCounter(q)
      local ms = tonumber(q[0] - a) / per_ms
      T.n, T.sum = T.n + 1, T.sum + ms
      if ms > T.max then T.max = ms end
      if ms > 1 then T.over = T.over + 1 end
      return ok2, e
    end
  end)
  if TESTER and not timed then note('frame timing (test): not available') end
  -- ((5.1.5 Test 20) code the game's LuaJIT (2.1.0-alpha) can never compile, so it isn't asked to: the frame's entry
  -- points (they call back into the game), the laser and marker drawing (every line and triangle is a call into the
  -- game) and the F8 key check. My Test 19 log had the compiler start and give up on these about 20,000 times in a
  -- 16-minute session - wasted work every time. Turning them off changes nothing else: they ran uncompiled anyway
  do
    local j = rawget(_G, 'jit')
    if type(j) == 'table' and type(j.off) == 'function' then
      -- ((5.1.5 Test 22) and union (select and pairs: 1,812 give-ups in my Test 19 log) and the Mod Options Menu's
      -- registration check (551)
      for _, f in ipairs({ tick, laser_draw_body, laser_ready, check_marker, sentry_after, SGD.time_tick or tick, union, menu_step }) do
        if type(f) == 'function' then pcall(j.off, f, true) end
      end
    end
  end
  rawset(_G, 'update', function(...)
    local ok2, e
    if SGD.time_tick then ok2, e = SGD.time_tick() else ok2, e = pcall(tick) end
    if not ok2 then
      -- ((4.6.4 review) said so in the log too: before, it kept saying 'status: active' while nothing ran any more)
      if not broken then
        local why = 'stopped after error: tick: ' .. tostring(e)
        SGD.status = why; pcall(event, 'error: ' .. why)
      end
      broken = true; sentry_broken = true; last_error = 'tick: ' .. tostring(e); pcall(restore); pcall(sentry_restore)
    end
    return after(game_update(...))
  end)
end
rawset(_G, 'shutdown', function(...)
  pcall(restore)
  pcall(sentry_restore)
  pcall(research_close)
  SGD.status = 'closed'
  pcall(write_log)
  if type(game_shutdown) == 'function' then return game_shutdown(...) end
end)
SGD.status = 'waiting'
pcall(write_log)
