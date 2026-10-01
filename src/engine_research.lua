
-- ======================================================================================================
-- Research recorder (1.5 test builds): writes SmarterGuardDogsAndSentries-research.log next to the
-- status log (%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs) with what the
-- dog targets, each enemy's unit type and the raw fields of its perception entry, so line-of-sight and
-- armour rules can be worked out from real missions. Reads only. Press F8 in game to drop a marker line
-- ("MARK") at a moment worth looking at, e.g. the dog shooting through a wall or at a Hulk.
-- ======================================================================================================
local RESEARCH = false
local hexr, check_marker, research_frame, research_close
-- (its helpers live inside a function of their own, to leave room among the main chunk's locals)
;(function()
local RESEARCH_MAX_BYTES = 4 * 1024 * 1024
local SAMPLE_SECONDS = 0.25     -- the dog's current target while it is lining up or firing
local LIST_SECONDS = 2.0        -- the whole enemy list
local research = { f = nil, bytes = 0, full = false, types = {}, next_sample = 0, next_list = 0, t0 = os.clock(),
  last_target = nil, key = nil, key_down = false, key_state = 'not checked', marks = 0 }

local function hex(s) return (s:gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
local function type_of(c)
  -- entity rows start with the unit type hash (stored byte-reversed); shown the way Filediver names units
  return c.ent and hex(c.ent:sub(1, 8):reverse()) or '-'
end

local function rwrite(line)
  if not RESEARCH or research.full or not LOGDIR then return end
  if not research.f then
    research.f = io.open(LOGDIR .. '\\SmarterGuardDogsAndSentries-research.log', 'w')
    if not research.f then research.full = true; return end
    research.f:write('Smarter Guard Dogs & Sentries ' .. VERSION .. ' research log. t = seconds since start. F8 = MARK.\n')
    research.f:write('S = sample of the dog\'s target: t dog step target type group flags score dist_dog dist_you synced raw16_67 dock(drone to you, level m) barrel_off(up, sideways m)\n')
    research.f:write('L = enemy list: t dog [id:type:group:flags:score:dist_you:eligible:alive:visible:memory:hidden ...]\n')
    research.f:write('V = line of sight changed: t dog id type now_visible hidden_by_us\n')
  end
  research.bytes = research.bytes + #line + 1
  if research.bytes > RESEARCH_MAX_BYTES then
    research.f:write('-- size limit reached, recording stopped --\n'); research.f:close(); research.f = nil; research.full = true
    return
  end
  research.f:write(line, '\n')
end

-- F8 marker (only if the engine's keyboard functions are available): notes in the status log what the dog is
-- aiming at right now and which enemy types are around, so a player can point out an enemy for a bug report
function hexr(s) return (s:reverse():gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
function check_marker(st)
  local KB = SR and SR.Keyboard
  if research.key == nil then
    research.key = false
    if type(KB) == 'table' and type(KB.button_index) == 'function' and type(KB.pressed) == 'function' then
      local ok, idx = pcall(KB.button_index, 'f8')
      if ok and idx then research.key = idx; research.key_state = 'F8 marker ready' else research.key_state = 'F8 marker unavailable' end
    else
      research.key_state = 'F8 marker unavailable (no keyboard functions)'
    end
    note(research.key_state)
  end
  if not research.key then return end
  local ok, down = pcall(KB.pressed, research.key)
  if not (ok and down) then return end
  research.marks = research.marks + 1
  rwrite(string.format('MARK %d at %.2f', research.marks, os.clock() - research.t0))
  local cur, near = nil, {}
  local me = st and st.player_pos
  for _, c in ipairs(st and st.candidates or {}) do
    if c.id == st.target then cur = c end
    if c.kind and c.alive and c.pos and me and (c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 < 60 ^ 2 then
      local k = hexr(c.kind) .. (LABELS[c.kind] and ('(' .. LABELS[c.kind] .. ')') or ''); near[k] = (near[k] or 0) + 1
    end
  end
  local list = {}
  for k, n in pairs(near) do list[#list + 1] = k .. 'x' .. n end
  table.sort(list)
  local msg = string.format('%8.1fs  marker %d: %s', os.clock() - T0, research.marks, st and st.dog.name or ('no dog out (' .. tostring(SGD.status) .. ')'))
  if cur and cur.kind then
    msg = msg .. string.format(' aiming at type %s%s (%.0f m, AI step %d)', hexr(cur.kind), LABELS[cur.kind] and (' ' .. LABELS[cur.kind]) or '', cur.d2 and math.sqrt(cur.d2) or -1, st.node)
  else msg = msg .. ' not aiming at anything' end
  msg = msg .. '; enemies within 60 m: ' .. (#list > 0 and table.concat(list, ' ') or 'none')
  -- details (test builds): what the dog is doing, then each enemy near you, nearest first
  if st then
    local D = st.drone_pos
    msg = msg .. string.format('\n      dog: AI step %d, target %d for %.1fs, lined up %.1fs on it without firing, timer %.2fs, %.1f m from you (level)',
      st.node, st.target, st.target_for or 0, st.lineup_acc or 0, math.max(0, (st.deadline or 0) - (st.now or 0)) / 1e6,
      (me and D) and math.sqrt((D[1] - me[1]) ^ 2 + (D[2] - me[2]) ^ 2) or -1)
    local tm = {}
    for _, m in ipairs(st.mates or {}) do
      tm[#tm + 1] = me and string.format('%.1f m', math.sqrt((m[1] - me[1]) ^ 2 + (m[2] - me[2]) ^ 2 + (m[3] - me[3]) ^ 2)) or '?'
    end
    msg = msg .. string.format('\n      teammates: %d%s', #tm, #tm > 0 and (' (' .. table.concat(tm, ', ') .. ' from you)') or '')
    if #team.rows > 0 then msg = msg .. '\n      teammate rows: ' .. team_detail(me) end
    msg = msg .. '\n      id type             from you  height  from dog  sight memory  score pickable  hidden by the mod'
    local rows = {}
    for _, c in ipairs(st.candidates or {}) do
      if c.pos and me then
        local dz = c.pos[3] - me[3]
        local d = math.sqrt((c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + dz ^ 2)
        if d < 60 then rows[#rows + 1] = { c = c, d = d, dz = dz } end
      end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    for i = 1, math.min(#rows, 16) do
      local c, why = rows[i].c, {}
      for _, k in ipairs({ 'unsafe', 'cover', 'armour', 'range', 'no_shot', 'closer_threat', 'focus' }) do
        if st.hide_sets and st.hide_sets[k] and st.hide_sets[k][c.id] then
          why[#why + 1] = (k == 'unsafe' and st.unsafe_why and (st.unsafe_why[c.id] or ''):find('teammate')) and 'unsafe(teammate)' or k
        end
      end
      if #why == 0 and c.mask == '    ' then why[1] = 'held' end
      msg = msg .. string.format('\n      %d %s %5.1f m %+6.1f m %6.1f m  %-5s %5.2f %6.2f %-8s  %s%s', c.id, c.kind and hexr(c.kind) or '-',
        rows[i].d, rows[i].dz, c.d2 and math.sqrt(c.d2) or -1, c.visible and 'yes' or 'no', c.memory or -1, c.score or -1,
        c.eligible and 'yes' or (c.alive and 'no' or 'dead'), #why > 0 and table.concat(why, ',') or '-', (c.kind and LABELS[c.kind] and ('  ' .. LABELS[c.kind]) or '') .. (c.id == st.target and '  <- target' or ''))
    end
    if #rows > 16 then msg = msg .. string.format('\n      (+%d more)', #rows - 16) end
  end
  -- (4.0) what each of your sentries is doing
  if sentry_marker_text then
    local ok, lines = pcall(sentry_marker_text, me)
    if ok and lines and #lines > 0 then msg = msg .. '\n      sentry ' .. table.concat(lines, '\n      sentry ') end
  end
  local m = session.markers
  m[#m + 1] = msg
  if #m > 30 then table.remove(m, 1) end
  event('F8 marker ' .. research.marks)
end

local function dist(a, b)
  if not (a and b) then return -1 end
  return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

function research_frame(st)
  if not RESEARCH or research.full then return end
  local t = os.clock()
  local me, D = st.player_pos, st.drone_pos
  for _, c in ipairs(st.candidates) do
    local ty = type_of(c)
    if ty ~= '-' and not research.types[ty] then
      research.types[ty] = true
      rwrite(string.format('T %.2f new unit type %s (first seen as %d, group %s)', t - research.t0, ty, c.id, c.group or '?'))
    end
  end
  research.vis = research.vis or {}
  local seen = {}
  for _, c in ipairs(st.candidates) do
    seen[c.id] = true
    local was = research.vis[c.id]
    if was ~= nil and was ~= c.visible then
      rwrite(string.format('V %.2f %s %d %s %d %d', t - research.t0, st.dog.name, c.id, type_of(c), c.visible and 1 or 0, c.mask == '    ' and 1 or 0))
    end
    research.vis[c.id] = c.visible
  end
  for id in pairs(research.vis) do if not seen[id] then research.vis[id] = nil end end
  local cur
  for _, c in ipairs(st.candidates) do if c.id == st.target then cur = c end end
  if st.target ~= research.last_target then
    research.last_target = st.target
    rwrite(string.format('C %.2f %s target -> %d type %s step %d', t - research.t0, st.dog.name, st.target, cur and type_of(cur) or '-', st.node))
  end
  if t >= research.next_sample and st.target ~= 0 and (st.node == 6 or st.node == 7) then
    research.next_sample = t + SAMPLE_SECONDS
    if cur then
      rwrite(string.format('S %.2f %s %d %d %s %s %08x %.3f %.1f %.1f %s %s', t - research.t0, st.dog.name, st.node, st.target,
        type_of(cur), cur.group or '?', cur.flags or 0, cur.score or 0, dist(cur.pos, D), dist(cur.pos, me),
        st.synced and 1 or 0, hex(st.perc:sub(cur.off + 17, cur.off + 68))) .. string.format(' dock %.1f', (me and D) and math.sqrt((D[1] - me[1]) ^ 2 + (D[2] - me[2]) ^ 2) or -1)
        .. ((laser.last_gun and laser.last_to) and string.format(' barrel_off %.2f %.2f', laser.last_gun[3] - laser.last_to[3],
          math.sqrt((laser.last_gun[1] - laser.last_to[1]) ^ 2 + (laser.last_gun[2] - laser.last_to[2]) ^ 2)) or ''))
    else
      rwrite(string.format('S %.2f %s %d %d not-in-list', t - research.t0, st.dog.name, st.node, st.target))
    end
  end
  if t >= research.next_list then
    research.next_list = t + LIST_SECONDS
    local parts = {}
    for _, c in ipairs(st.candidates) do
      parts[#parts + 1] = string.format('%d:%s:%s:%x:%.2f:%.0f:%d:%d:%d:%.2f:%d', c.id, type_of(c), c.group or '?', c.flags or 0,
        c.score or 0, dist(c.pos, me), c.eligible and 1 or 0, c.alive and 1 or 0, c.visible and 1 or 0, c.memory or -1,
        c.mask == '    ' and 1 or 0)
    end
    rwrite(string.format('L %.2f %s %s', t - research.t0, st.dog.name, table.concat(parts, ' ')))
    if research.f then research.f:flush() end
  end
end

function research_close()
  if research.f then pcall(function() research.f:close() end); research.f = nil end
end
end)()
