-- ======================================================================================================
-- Main loop
-- ======================================================================================================
local next_poll, next_log, last_log, broken = 0, 0, 0, false
local last_poll_t
local sentry_broken, sentry_last_error = false, nil
local function tick()
  local t = os.clock()
  FRAME = FRAME + 1
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
  local ok, st, why = pcall(read_state)
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
    if TESTER and laser.calib then laser.add_calib(beams, t) end
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
