-- ======================================================================================================
-- (4.6.6 Test 2+, research only: build.py puts this part in numbered Tester builds only, never in a release)
-- Ping and Seeker grenade probe. Reads only. Writes SmarterGuardDogsAndSentries-probe.log next to the log.
-- * Where the game keeps your ping: the component managers that sound like it (tag, spottable, guidance_target,
--   laser_designator, multi_target) are watched, and any word in them that changes to an entity id in the game's
--   registry is logged with that entity's type and name - ping an enemy and its id should show up in one of them.
-- * What a Seeker grenade is: the managers for thrown things and homing weapons (throwable, thrower,
--   seeking_missile, guided_weapon) are watched the same way, with their instance counts.
-- * Once: every manager pointer in game.dll's data next to the known ones, as an offset into the game world (so the
--   managers can be found by name later).
-- The managers sit inside the game world (game.dll+0x346BFC8); each offset below is where the game's own
-- component-stats routine reads that manager's 'max' (game.dll 0x56A920, 2026-09-24 build).
-- F8 writes a MARK line. Every error turns the probe off with a log line.
-- ======================================================================================================
do
  local MGRS = {
    { 'tag', 0xec }, { 'spottable', 0x757650 }, { 'guidance_target', 0x7c5ff8 }, { 'laser_designator', 0x75c2cc },
    { 'seeking_missile', 0x75ef64 }, { 'guided_weapon', 0x1c6f0c }, { 'throwable', 0xeb5dbc }, { 'thrower', 0xeb5d08 },
  }
  local WORLD_RVA = 0x346BFC8
  local P = { next = 0, off = false, f = nil, bytes = 0, snap = {}, seen = {}, word_n = {}, minute = 0, lines = 0,
    key = nil, t0 = os.clock(), mapped = false, max = {} }
  local function out(line)
    if P.off then return end
    if not P.f then
      P.f = io.open(LOGDIR .. '\\SmarterGuardDogsAndSentries-probe.log', 'w')
      if not P.f then P.off = true; return end
      P.f:write('Smarter Guard Dogs & Sentries ' .. VERSION .. ' ping / seeker probe. t = seconds since start.\n')
    end
    P.bytes = P.bytes + #line + 1
    if P.bytes > 3 * 1024 * 1024 then P.f:write('-- size limit reached --\n'); P.f:close(); P.off = true; return end
    P.f:write(line, '\n'); P.f:flush()
  end
  local function hexs(s) return (s:reverse():gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
  -- an entity id in the registry: its type and a name when the mod knows it
  local function entity(reg, v)
    if v == 0 or v > 0x7fffffff then return nil end
    local ri = map_lookup(reg + 73808, v, 32768, nil, true)
    if not ri or ri >= 16384 then return nil end
    local list = ptr_of(read(reg + 73832, 8), 0)
    local rp = list and ptr_of(read(list + ri * 8, 8), 0)
    local re = rp and read(rp, 24)
    if not (re and u32(re, 8) == v) then return nil end
    local kind = re:sub(1, 8)
    local a = ARMOR[kind]
    local name = (a and a.name) or LABELS[kind] or (kind == AVATAR_TYPE and 'a helldiver') or '?'
    return string.format('entity %d type %s (%s)%s', v, hexs(kind), name, is_local(re) and ', yours' or '')
  end
  local function diff(key, old, cur, reg, t)
    local n = 0
    for o = 0, #cur - 4, 4 do
      local a, b = u32(old, o), u32(cur, o)
      if a ~= b then
        local hit = entity(reg, b)
        if hit then
          out(string.format('%8.2f  %s +%x: %d -> %s', t - P.t0, key, o, a, hit))
        else
          local wk = key .. o
          local c = (P.word_n[wk] or 0) + 1
          P.word_n[wk] = c
          -- (plain changes: 3 a word, 60 lines a minute)
          if c <= 3 and P.lines < 60 then
            P.lines = P.lines + 1
            out(string.format('%8.2f  %s +%x: %08x -> %08x (%.4g)', t - P.t0, key, o, a, b, f32(cur, o)))
          end
        end
        n = n + 1
        if n > 40 then break end
      end
    end
  end
  SGD.probe_step = function(t)   -- ((4.6.6 review) on the mod's own table, not a global)
    if P.off then return end
    -- (F8 every frame: a MARK line at the moment you ping or throw)
    local KB = SR and SR.Keyboard
    if P.key == nil then
      P.key = false
      if type(KB) == 'table' and type(KB.button_index) == 'function' then local ok, i = pcall(KB.button_index, 'f8'); if ok and i then P.key = i end end
    end
    if P.key then local ok, down = pcall(KB.pressed, P.key); if ok and down then out(string.format('%8.2f  MARK (F8)', t - P.t0)) end end
    if t < P.next then return end
    P.next = t + 0.25
    if t >= P.minute then P.minute, P.lines = t + 60, 0 end
    local ok, err = pcall(function()
      if not (A and A.gbase and A.g.registry) then return end
      local world = ptr_of(read(A.gbase + WORLD_RVA, 8), 0)
      if not world then return end
      local reg = ptr_of(read(A.g.registry, 8), 0)
      if not reg then return end
      -- once: every pointer into the world among game.dll's data next to the known manager pointers
      if not P.mapped then
        P.mapped = true
        local lo = A.g.targeting - 0x1000
        local blk = read(lo, 0x2000)
        local found = {}
        if blk then
          for o = 0, 0x2000 - 8, 8 do
            local v = ptr_of(blk, o)
            if v and v >= world and v < world + 0x1000000 then found[#found + 1] = string.format('rva %x = world+%x', lo + o - A.gbase, v - world) end
          end
        end
        out('manager pointers: ' .. (#found > 0 and table.concat(found, ', ') or 'none found'))
        local function rel(v) v = (v or world) - world; return v < 0 and string.format('-%x', -v) or string.format('+%x', v) end
        out(string.format('known: targeting rva %x -> world%s, behaviors rva %x -> world%s', A.g.targeting - A.gbase,
          rel(ptr_of(read(A.g.targeting, 8), 0)), A.g.behaviours - A.gbase, rel(ptr_of(read(A.g.behaviours, 8), 0))))
      end
      for _, m in ipairs(MGRS) do
        local name, statoff = m[1], m[2]
        -- the manager's 'max' (instances so far), logged when it changes
        local mx = read(world + statoff, 4)
        mx = mx and u32(mx, 0)
        if mx and mx ~= P.max[name] then
          if P.max[name] ~= nil then out(string.format('%8.2f  %s count %d -> %d', t - P.t0, name, P.max[name], mx)) end
          P.max[name] = mx
        end
        -- the area round it, and up to 8 blocks it points to
        local areas = { { key = name, addr = world + statoff - 0x100, size = 0x200 } }
        local hdr = read(world + statoff - 0x100, 0x200)
        if hdr then
          for o = 0, 0x1F8, 8 do
            local p = ptr_of(hdr, o)
            if p and #areas < 9 and not (p >= world and p < world + 0x1000000) then
              areas[#areas + 1] = { key = string.format('%s[%x]', name, o - 0x100), addr = p, size = 0x800 }
            end
          end
        end
        for _, ar in ipairs(areas) do
          local cur = read(ar.addr, ar.size)
          local prev = P.snap[ar.key]
          if cur and prev and prev.addr == ar.addr and prev.data ~= cur then diff(ar.key, prev.data, cur, reg, t) end
          P.snap[ar.key] = cur and { addr = ar.addr, data = cur } or nil
        end
      end
    end)
    if not ok then P.off = true; out('probe stopped: ' .. tostring(type(err) == 'table' and err[2] or err)); note('probe (test) stopped: ' .. tostring(type(err) == 'table' and err[2] or err)) end
  end
end
