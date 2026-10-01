-- ======================================================================================================
-- Main loop
-- ======================================================================================================
local next_poll, next_log, last_log, broken = 0, 0, 0, false
local last_poll_t
local sentry_broken, sentry_last_error = false, nil
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
  -- (Laser Brightness: the mod manager's sub-options, in their order; no 'Off' - without the option the laser is at its
  -- normal brightness, the same as 'Normal (100%)')
  local BRIGHT = { 1.0, 0.5, 0.75, 1.5, 2.0 }
  -- each row, in the mod manager's order: its choices, which flags each sets, and the starting choice from the flags
  local OPTS = {
    { key = 'dogs', label = 'Guard Dogs', type = 'toggle',
      description = 'The mod handles your guard dog (Guard Dog, Rover, K-9). Turn off to leave your dog to the game; your sentries and the rest of the mod keep working.',
      apply = function(v) set('Dogs', v) end, start = function() return flag('Dogs') end },
    { key = 'sentries', label = 'Sentries', type = 'choice', choices = { 'Off', 'All sentries', 'All but the Tesla Tower' },
      description = 'The mod handles your sentries (Machine Gun, Gatling, Autocannon, Rocket, Laser, Flame, Mortar, EMS Mortar and the Tesla Tower), plus the guns on armed resupply pods and the Supply FRV. Turn off to leave your sentries to the game; your guard dog and the rest of the mod keep working.',
      apply = function(v) set('Sentries', v ~= 1); set('Tesla', v == 2) end,
      start = function() return not flag('Sentries') and 1 or (flag('Tesla') and 2 or 3) end },
    { key = 'intelligence', label = 'Intelligence', type = 'choice',
      choices = { 'Off', 'Armor Intelligence and Target Prioritization', 'Only Armor Intelligence', 'Only Target Prioritization' },
      description = 'How your dogs and sentries choose what to shoot. Armor Intelligence: they leave alone armor they can\'t hurt, fire only short bursts at Heavy Devastators, and no sentry wastes ammo on dropships. Target Prioritization: your dog goes for the closest threat to you first; your sentries deal with enemies at their feet, Gunships and the armor that suits the gun first. Turn off to leave both to the game.',
      apply = function(v) set('Armor', v == 2 or v == 3); set('Priority', v == 2 or v == 4) end,
      start = function() local a, p = flag('Armor'), flag('Priority'); return (a and p) and 2 or (a and 3) or (p and 4) or 1 end },
    { key = 'safety', label = 'Safety', type = 'choice', choices = { 'Off', 'You and your teammates', 'Only you', 'Only your teammates' },
      description = 'Who your dog and your sentries never fire through: they hold fire while that helldiver is in their line of fire, don\'t swing their fire across them, mortars and the rocket sentry leave enemies next to them alone, and the Tesla Tower doesn\'t zap them or arc into them. Turn off at your own risk: they will fire through anyone. Everything else keeps working.',
      apply = function(v) set('Safety', v == 2 or v == 3); set('Teammates', v == 2 or v == 4) end,
      start = function() local y, m = flag('Safety'), flag('Teammates'); return (y and m) and 2 or (y and 3) or (m and 4) or 1 end },
    { key = 'laser', label = 'Targeting Laser', type = 'choice', choices = { 'Off', 'Line', 'Glow' },
      description = 'Laser out of the barrel of your guard dog and your sentries (not the mortars) toward their targets, shown only on your screen: green while they fire, flashing red when the safety stops a shot, flashing yellow when the dog\'s target goes out of sight. The Tesla Tower shows its reach as a yellow ring. Line: thin, hidden by walls. Glow: a soft beam that shows through walls.',
      apply = function(v) set('Laser', v ~= 1); set('Glow', v == 3) end,
      start = function() return not flag('Laser') and 1 or (flag('Glow') and 3 or 2) end },
    { key = 'laser_brightness', label = 'Laser Brightness', type = 'choice',
      choices = { 'Normal (100%)', 'Dim (50%)', 'Softer (75%)', 'Bright (150%)', 'Brightest (200%)' },
      description = 'How bright the targeting laser is: its beams and rings, line or glow.',
      apply = function(v) if BRIGHT[v] then rawset(_G, 'SmarterGuardDogsLaserBrightness', BRIGHT[v]) end end,
      start = function()
        local b = rawget(_G, 'SmarterGuardDogsLaserBrightness')
        if type(b) ~= 'number' then return 1 end
        local best, bd = 1, nil
        for i, x in ipairs(BRIGHT) do if not bd or math.abs(x - b) < bd then best, bd = i, math.abs(x - b) end end
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

local function tick()
  local t = os.clock()
  FRAME = FRAME + 1
  if not SGD.seaf_only then menu_step() end
  -- the log is rewritten every 10 s, and within a second of anything new being noted
  if t >= next_log or (session.dirty and t - last_log >= 1) then next_log, last_log = t + 10, t; write_log() end
  -- (test builds: F8 also works while no dog is out, e.g. right after you died; checked every frame so a quick
  -- press isn't missed between the slower polls)
  if TESTER and SGD.status ~= 'active' then pcall(check_marker, nil) end
  if broken or t < next_poll then
    -- (a frame the mod skips: the laser as it was - line objects are only drawn on the frames they are dispatched)
    if not broken and laser_wanted() then laser.redraw() end
    return
  end
  next_poll = t + 0.1          -- relaxed while nothing is going on; every frame while a dog is out (below)
  stats.polls = stats.polls + 1
  local ok, st, why
  -- (the Smarter SEAF build: no dog; its status is only whether you are in a mission)
  if SGD.seaf_only then ok, st, why = pcall(function() return nil, in_mission() and 'in a mission' or 'not in a mission' end)
  else ok, st, why = pcall(read_state) end
  if not ok then
    local e = st
    st = nil
    if type(e) == 'table' and e[1] == Abort then why = 'read_failed: ' .. tostring(e[2])
    else
      -- a bug in this mod rather than an unexpected game state: stop steering for the rest of the session
      broken = true; why = 'stopped after error: ' .. tostring(e); restore()
    end
    stats.read_errors = stats.read_errors + 1
    last_error = why
    event('error: ' .. tostring(why))
  end
  local status = st and 'active' or why
  local dogname = st and st.dog.name or nil
  if status ~= SGD.status then event('status: ' .. tostring(status)) end
  if dogname and dogname ~= SGD.dog then event('dog: ' .. dogname) end
  local dt = last_poll_t and math.min(t - last_poll_t, 0.5) or 0
  last_poll_t = t
  session.state_time[tostring(status)] = (session.state_time[tostring(status)] or 0) + dt
  if dogname then
    local d = session.dog_time[dogname] or { out = 0, targeted = 0, firing = 0 }
    session.dog_time[dogname] = d
    d.out = d.out + dt
    if st.target ~= 0 then d.targeted = d.targeted + dt; if st.node == 7 then d.firing = d.firing + dt end end
  end
  if not st then
    SGD.status, SGD.dog = why, nil
    if next(hidden) then restore() end
  else
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
    steer(st, plan(st))
    if TESTER then
      pcall(check_marker, st)
      -- how the dog spends its time while out: docked on your back (reloading), no target, or its AI step
      local P2, D = st.player_pos, st.drone_pos
      local docked = P2 and D and ((D[1] - P2[1]) ^ 2 + (D[2] - P2[2]) ^ 2) < 1.2 ^ 2
      bump(session.steps, st.dog.name .. ': ' .. (docked and 'docked on your back' or (st.target == 0 and 'no target' or ('AI step ' .. st.node))))
    end
    -- nothing around and nothing hidden: look three times a second less often (enemies take a moment to arrive)
    if #st.candidates == 0 and st.target == 0 and not next(hidden) then next_poll = t + 0.05 end
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
  -- the laser: the dog's beam and the sentries' beams, drawn together
  if laser_wanted() and laser_ready() then
    local beams = {}
    if st then laser_frame(st, beams, P.safety_now and P.safety_t or nil, P.safety_enemy, P.safety_step, P.cover_t, P.cover_enemy, P.cover_step) end
    if sentries_out then sentry_beams(beams, t) end
    if #beams > 0 or beams.rings then laser_draw(beams) else laser_clear() end
  else laser_clear() end
end

local ok, err = pcall(function() A = resolve_layout() end)
if not ok then
  SGD.status = 'off: ' .. tostring(err)
  note('could not find the game addresses, the mod stays off: ' .. tostring(err))
  write_log()
  return
end

local game_update, game_shutdown = rawget(_G, 'update'), rawget(_G, 'shutdown')
if type(game_update) ~= 'function' then
  SGD.status = 'off: game update function not found'; write_log(); return
end
do
  -- (after the game's update: the Tesla Tower's hidden helldivers are hidden again, see sentry_after)
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
    local T = { n = 0, sum = 0, max = 0, over = 0 }
    session.timing = T
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
  rawset(_G, 'update', function(...)
    local ok2, e
    if SGD.time_tick then ok2, e = SGD.time_tick() else ok2, e = pcall(tick) end
    if not ok2 then broken = true; last_error = 'tick: ' .. tostring(e); pcall(restore); pcall(sentry_restore) end
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
write_log()
