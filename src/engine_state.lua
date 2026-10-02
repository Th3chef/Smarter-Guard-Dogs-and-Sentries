
-- ======================================================================================================
-- Reading the game: the local player's guard dog, its AI record and what it can see
-- ======================================================================================================
local A   -- absolute layout, set at start-up

local function is_local(entity) return bit.band(entity:byte(21), 3) == 1 end

-- world pose of a unit (position + rotation axes), from the engine's unit table in helldivers2.exe.
-- The first lookup of a unit walks the table and checks it thoroughly; after that its object is remembered
-- and only its id is re-checked (the remembered objects are dropped whenever the dog is looked up afresh).
local VTABLE_CHECK = '\72\141\65\96\195'   -- the unit class's "world pose" accessor: lea rax,[rcx+60h]; ret
local unit_cache = {}
local function unit_object(id)
  local obj = unit_cache[id]
  if obj then
    local h = read(obj, 144)
    if h and u32(h, 8) == id then return obj, h end
    unit_cache[id] = nil
  end
  local units = rptr(A.exe_units, 'unit table')
  local index = id % 4194304
  local count = u32(rd(units + 152, 4, 'unit count'), 0)
  if index >= count then return nil end
  local gen = rd(rptr(units + 160, 'unit generations') + index, 1, 'unit generation'):byte()
  if gen ~= math.floor(id / 4194304) % 256 then return nil end
  obj = rptr(rptr(units + 136, 'unit array') + 8 * index, 'unit')
  local h = rd(obj, 144, 'unit')
  if u32(h, 8) ~= id then return nil end
  if rd(rptr(rptr(obj, 'unit vtable') + 232, 'unit accessor'), 5, 'unit accessor') ~= VTABLE_CHECK then return nil end
  unit_cache[id] = obj
  return obj, h
end
local function unit_position(id, want_axes)
  if not id or id == 0 then return nil end
  local ok, pos = pcall(function()
    local obj, h = unit_object(id)
    if not obj then return nil end
    local pose = need(ptr_of(h, 136), 'unit pose')
    local m = rd(pose, 64, 'unit pose')
    local x, y, z = f32(m, 48), f32(m, 52), f32(m, 56)
    if x ~= x or y ~= y or z ~= z or math.abs(x) > 1e6 or math.abs(y) > 1e6 or math.abs(z) > 1e6 then return nil end
    local p = { x, y, z, pose = pose }
    if want_axes then
      -- rotation rows, normalised; dropped if they do not look like a rotation
      local axes = {}
      for r = 0, 2 do
        local a = { f32(m, r * 16), f32(m, r * 16 + 4), f32(m, r * 16 + 8) }
        local len = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
        if not (len > 0.5 and len < 2) then axes = nil; break end
        axes[r + 1] = { a[1] / len, a[2] / len, a[3] / len }
      end
      p.axes = axes
    end
    return p
  end)
  return ok and pos or nil
end

-- Teammates: every helldiver has a row in the same owner table as ours (2048 rows of 24 bytes; the game's own
-- code wraps its free-row search at 0x800). The whole table is read in one go once a second and the rows of
-- other players' helldivers kept; in between only their positions are read (two small reads each).
local OWNER_ROWS = 2048
local TEAM_SCAN_SECONDS = 1.0
local TEAM_MAX = 8
local team = { units = {}, next_scan = 0, key = nil, last = {}, found = 0, rows = {}, moved = {}, players = '?' }
local function scan_teammates(owners, player_unit)
  local rows = read(owners + A.owner_rows, OWNER_ROWS * 24)
  local units = {}
  if not rows then return units, 0 end
  local found, at = 0, 1
  team.rows = {}
  while true do
    local p = rows:find(AVATAR_TYPE, at, true)
    if not p then break end
    if (p - 1) % 24 == 0 then
      local row = rows:sub(p, p + 23)
      local unit = u32(row, 12)
      if not is_local(row) and unit ~= 0 and unit ~= 4294967295 and unit ~= player_unit then
        found = found + 1
        -- (test builds: what each row looks like, to tell live teammates from leftovers such as bodies)
        if TESTER then team.rows[#team.rows + 1] = { index = (p - 1) / 24, owner = u32(row, 8), unit = unit, raw = row:sub(17, 24) } end
        if #units < TEAM_MAX then units[#units + 1] = unit end
      end
    end
    at = p + 1
  end
  return units, found
end

-- switched on by the optional 'Teammate safety' part of the mod (a tiny second addon that sets this flag); read
-- every frame, so load order does not matter. While it is off, teammates are not looked up at all.
local team_state
local function team_wanted()
  local on = rawget(_G, 'SmarterGuardDogsTeammates') == true
  if on ~= team_state then
    team_state = on; session.team.off = not on
    note('teammate safety: ' .. (on and 'on' or (rawget(_G, 'SmarterGuardDogsMenu') and 'off (in the mod options menu)' or 'off (option not installed)')))
  end
  return on
end

-- (4.0.1) the optional parts that choose what the mod handles: Safety (you), Guard Dogs and Sentries (each set by a
-- tiny addon, like the laser's). Read every frame, so load order doesn't matter.
local OPT = {}
do
  local noted = {}
  local function flag(key, name, off_text)
    local on = rawget(_G, key) == true
    if noted[key] ~= on then
      noted[key] = on
      note(name .. ': ' .. (on and 'on' or ((rawget(_G, 'SmarterGuardDogsMenu') and 'off (in the mod options menu)' or 'off (option not installed)') .. off_text)))
    end
    return on
  end
  OPT.safety = function() return flag('SmarterGuardDogsSafety', 'safety for you', ': your dogs and sentries may fire through you') end
  OPT.dogs = function() return flag('SmarterGuardDogsDogs', 'guard dogs', ': left to the game') end
  OPT.sentries = function() return flag('SmarterGuardDogsSentries', 'sentries', ': left to the game') end
  OPT.tesla = function() return flag('SmarterGuardDogsTesla', 'tesla tower', ': left to the game') end
  OPT.priority = function() return flag('SmarterGuardDogsPriority', 'target prioritization', ': the game decides the order') end
end

-- positions of the other players' helldivers (with a smoothed velocity, for a short look-ahead). Worked out once
-- per frame: the dogs and the sentries share the result.
local FRAME = 0   -- counts the mod's frames (the main loop adds one each tick)
local function teammates(c, t)
  if team.frame == FRAME and team.frame_key == c.team_key and team.frame_mates then return team.frame_mates end
  if t >= team.next_scan or team.key ~= c.team_key then
    team.units, team.found = scan_teammates(c.owners, c.player_unit)
    team.next_scan, team.key = t + TEAM_SCAN_SECONDS, c.team_key
    local keep = {}
    for _, u in ipairs(team.units) do keep[u] = team.last[u] end
    team.last = keep
  end
  local mates = {}
  for _, u in ipairs(team.units) do
    local p = unit_position(u)
    if p then
      local prev = team.last[u]
      local vel = prev and prev.vel
      if not prev or p[1] ~= prev[1] or p[2] ~= prev[2] or p[3] ~= prev[3] then team.moved[u] = t end
      if prev and (p[1] ~= prev[1] or p[2] ~= prev[2] or p[3] ~= prev[3]) then
        -- remote helldivers move in network steps (the same spot for a few frames, then a jump), so the speed is
        -- taken between position changes, smoothed, and teleports (respawn, ragdoll) are ignored
        local dt = t - prev.t
        if dt > 0.004 and dt < 0.3 then
          local v = { (p[1] - prev[1]) / dt, (p[2] - prev[2]) / dt, (p[3] - prev[3]) / dt }
          if v[1] * v[1] + v[2] * v[2] + v[3] * v[3] < 15 * 15 then
            vel = vel and { vel[1] * 0.5 + v[1] * 0.5, vel[2] * 0.5 + v[2] * 0.5, vel[3] * 0.5 + v[3] * 0.5 } or v
          end
        else vel = nil end
        team.last[u] = { p[1], p[2], p[3], t = t, vel = vel }
      elseif not prev then
        team.last[u] = { p[1], p[2], p[3], t = t }
      elseif t - prev.t > 0.3 then
        vel = nil; prev.vel = nil   -- not moving
      end
      mates[#mates + 1] = { p[1], p[2], p[3], vel = vel, unit = u }
    end
  end
  team.frame, team.frame_key, team.frame_mates = FRAME, c.team_key, mates
  return mates
end

-- test builds: one line describing every teammate row found (for the log)
local function team_detail(me)
  local out = { 'players ' .. tostring(team.players) }
  for _, r in ipairs(team.rows) do
    local last = team.last[r.unit]
    local d = (last and me) and string.format('%.0f m', math.sqrt((last[1] - me[1]) ^ 2 + (last[2] - me[2]) ^ 2 + (last[3] - me[3]) ^ 2)) or 'no position'
    local still = team.moved[r.unit] and string.format('still %.0fs', os.clock() - team.moved[r.unit]) or 'never seen'
    out[#out + 1] = string.format('row %d owner %d unit %d [%s] %s %s', r.index, r.owner, r.unit,
      (r.raw:gsub('.', function(c) return string.format('%02x', c:byte()) end)), d, still)
  end
  return table.concat(out, '; ')
end

-- (count offset, first entry, and the name the research log shows; singles: entry and name)
local GROUPS = { { 784, 792, 'g1' }, { 2072, 2080, 'g2' }, { 3360, 3368, 'g3' } }
local SINGLES = { { 4648, 's1' }, { 4728, 's2' }, { 4808, 's3' } }

-- The walk from the game's player table to our dog's AI and perception records takes ~30 reads. It is done
-- four times a second (and at once if anything looks different); in between the addresses it found are
-- reused and checked against the dog's own AI record every frame.
local LOCATE_SECONDS = 0.25
-- your helldiver: its owner row (id, unit) and the owner table itself (also used for teammates and sentries)
local function find_player()
  local g = A.g
  local function global(name) return rptr(g[name], name) end
  local players = global('players')
  local pp = rd(players + 132, 8, 'players')
  need(u32(pp, 0) <= 4 and u32(pp, 4) <= 4, 'player count')
  if u32(pp, 0) == 0 or u32(pp, 4) == 0 then return nil, 'no local player yet' end
  team.players = u32(pp, 0) .. '/' .. u32(pp, 4)
  local avatar = u32(rd(players + 936, 4, 'avatar'), 0)
  if avatar == 32767 then return nil, 'no helldiver yet' end

  local owners = global('owners')
  local e = map_lookup(owners + A.owner_index, avatar, 1048576)
  if not e then return nil, 'no helldiver yet' end
  need(e < 262144, 'owner index')
  local me = rd(owners + A.owner_rows + e * 24, 24, 'owner entity')
  if me:sub(1, 8) ~= AVATAR_TYPE or not is_local(me) then return nil, 'helldiver is not ours' end
  return { me = me, owner_id = u32(me, 8), player_unit = u32(me, 12), owners = owners, team_key = me:sub(1, 20) }
end

local function locate()
  local g = A.g
  local function global(name) return rptr(g[name], name) end
  -- (the Guard Dogs option off: nothing to look up, your dog is left to the game)
  if not OPT.dogs() then return nil, 'guard dogs option off (left alone)' end
  local pl, why = find_player()
  if not pl then return nil, why end
  local me, owner_id, player_unit, owners = pl.me, pl.owner_id, pl.player_unit, pl.owners

  local equipment = global('equipment')
  local q = map_lookup(equipment + 40, owner_id, 8192)
  if not q then return nil, 'no loadout' end
  need(q < 4096, 'equipment index')
  need(rd(rptr(rptr(equipment + 64, 'equipment owners') + q * 8, 'equipment owner'), 20, 'equipment owner') == me:sub(1, 20), 'equipment owner')
  local slot = rd(rptr(equipment + 80, 'equipment slots') + q * 48, 16, 'equipment slot')
  local pack_id = u32(slot, 12)
  if pack_id == 0 or pack_id == 4294967295 then return nil, 'no backpack worn' end

  local backpacks = global('backpacks')
  local n = u32(rd(backpacks + 16, 4, 'backpack count'), 0)
  need(n <= 256, 'backpack count')
  local packs, drones = rptr(backpacks + 56, 'backpack list'), rptr(backpacks + 80, 'backpack drones')
  local dog, drone_index
  for i = 0, n - 1 do
    local pe = read(ptr_of(read(packs + i * 8, 8), 0) or 0, 24)
    if pe and u32(pe, 8) == pack_id then
      dog = DOG_BY_PACK[pe:sub(1, 8)]
      if not dog then return nil, 'backpack is not a supported dog' end
      if not is_local(pe) then return nil, 'backpack is not ours' end
      drone_index = u32(rd(drones + i * 8, 8, 'backpack drone'), 4)
      break
    end
  end
  if not dog then return nil, 'no backpack worn' end
  if not drone_index or drone_index == 32767 then return nil, 'dog not deployed' end

  local attachments = global('attachments')
  local at = map_lookup(attachments + 32, pack_id, 8192)
  if not at then return nil, 'backpack not attached' end
  need(at < 4096, 'attachment index')
  if u32(rd(rptr(attachments + 64, 'attachments') + at * 48, 8, 'attachment'), 4) ~= owner_id then return nil, 'backpack not on our helldiver' end

  local targeting, behaviours = global('targeting'), global('behaviours')
  local reg = rd(targeting + 308, 84, 'targeting registry')
  local tn, ta, tb = u32(reg, 0), u32(reg, 12), u32(reg, 16)
  need(tb <= ta and ta <= tn and tn <= 8192, 'targeting registry')
  local tents, tstates = rptr(targeting + 360, 'targeting entities'), rptr(targeting + 376, 'targeting states')
  local slot_i, drone_ptr, drone_ent
  for i = 0, tn - 1 do
    local p = ptr_of(read(tents + i * 8, 8), 0)
    local de = p and read(p, 24)
    if de and de:sub(1, 8) == dog.drone and u32(de, 16) == drone_index then
      if not is_local(de) then return nil, 'dog is not ours' end
      slot_i, drone_ptr, drone_ent = i, p, de
      break
    end
  end
  if not slot_i then return nil, 'dog has no targeting' end
  local drone_id, drone_unit = u32(drone_ent, 8), u32(drone_ent, 12)
  need(map_lookup(targeting + 336, drone_id, 16384) == slot_i, 'targeting slot')

  local bi = map_lookup(behaviours + 64, drone_id, 32768)
  if not bi then return nil, 'dog has no AI record' end
  need(bi < u32(rd(behaviours + 32, 4, 'behaviour count'), 0) and bi < 16384, 'behaviour index')
  need(rptr(rptr(behaviours + 88, 'behaviour owners') + bi * 8, 'behaviour owner') == drone_ptr, 'behaviour owner')
  local rec_addr = rptr(behaviours + 96, 'behaviour records') + bi * A.stride
  local rec = rd(rec_addr, 160, 'behaviour record')
  local want_behaviour = dog.laser and A.laser_behaviour or A.laser_behaviour + 1
  if u32(rec, 0) ~= want_behaviour then return nil, 'dog AI type ' .. u32(rec, 0) end
  need(u32(rec, 104) == drone_id, 'perception owner')

  local perception = global('perception')
  local pi = map_lookup(perception + 48, drone_id, 32768)
  if not pi then return nil, 'dog has no perception' end
  need(pi < 16384, 'perception index')
  need(rptr(rptr(perception + 72, 'perception owners') + pi * 8, 'perception owner') == drone_ptr, 'perception owner')
  local pbase = rptr(perception + 80, 'perception records') + pi * 5112
  -- (4.5.3 Test 9) the dog's fire node: the part the game fires its weapon from (the muzzle), from the same weapon
  -- records as the sentries' (optional). The laser starts there. Before, the barrel was guessed from the drone's parts,
  -- and the guess could land on an aiming helper higher up on the drone (a tester's picture: the Guard Dog's beam
  -- above its gun; the Rover's guess was dropped and its beam left the drone's front as before)
  local fire_nodes, wr_addr, fire_unit, fire_how
  -- (4.6.0 review: only while the laser is on - nothing else uses it)
  if A.g.weapons and rawget(_G, 'SmarterGuardDogsLaser') == true then
    pcall(function()
      local wm = rptr(A.g.weapons, 'weapons')
      local owners, runtimes = rptr(wm + 72, 'weapon owners'), rptr(wm + 88, 'weapon runtimes')
      local function nodes_of(wi)
        local addr = runtimes + wi * 1008
        local wr = rd(addr, 228, 'weapon runtime')
        local count = u32(wr, 216)
        if count == 0 or count > 24 then return nil end
        local l = {}
        for j = 0, count - 1 do
          local nj = u32(wr, 120 + 4 * j)
          if nj < 1024 then l[j] = nj end
        end
        if next(l) then return l, addr end
      end
      local wi = map_lookup(wm + 48, drone_id, 32768)
      if wi and wi < 16384 and rptr(owners + wi * 8, 'weapon owner') == drone_ptr then
        fire_nodes, wr_addr = nodes_of(wi)
        fire_unit, fire_how = drone_unit, 'the drone'
        return
      end
      -- (4.5.3 Test 11) the dogs' guns have weapon records of their own (Test 10 log: none under the drone's id), so the
      -- gun is looked for among all weapon records: the dog's own gun type (Guard Dog, Rover, K-9 from tester logs)
      -- within 3 m of the drone, else a weapon of another type within 0.5 m of it and not on you. Up to 3 tries 5 s apart
      -- per deployment; a gun found is kept while its record still belongs to the same owner
      local F = dog.fire_found
      if F and F.drone == drone_id and rptr(owners + F.wi * 8, 'weapon owner') == F.ptr then
        fire_nodes, wr_addr = nodes_of(F.wi)
        fire_unit, fire_how = F.unit, F.how
        return
      end
      -- (4.6.0 review: the tries start again for each deployment - before, three failed tries for one drone stopped the
      -- search for every later one in the session)
      if dog.fire_scan_drone ~= drone_id then dog.fire_found, dog.fire_scans, dog.fire_scan_t, dog.fire_scan_drone = nil, 0, nil, drone_id end
      if (dog.fire_scans or 0) >= 3 or (dog.fire_scan_t and os.clock() < dog.fire_scan_t) then return end
      dog.fire_scan_t, dog.fire_scans = os.clock() + 5, (dog.fire_scans or 0) + 1
      local D = unit_position(drone_unit)
      if not D then return end
      local ME = unit_position(player_unit)
      local h = rd(wm + 48, 20, 'map header')
      local cap, empty = u32(h, 8), u32(h, 12)
      if cap == 0 or cap > 32768 or bit.band(cap, cap - 1) ~= 0 then return end
      local raw = read(need(ptr_of(h, 0), 'map slots'), cap * 8)
      if not raw then return end
      local function hx(b) return (b:reverse():gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
      -- (4.6.0 review) the dog's own gun type first: only those records' positions are read. Every record's position
      -- (enemies' weapons too) only when that finds nothing, or once per dog in test builds for their list
      local full = TESTER and not dog.fire_scan_noted
      local best, bd, seen
      for pass = 1, 2 do
        if pass == 2 and best and not full then break end
        best, bd, seen = nil, 9, full and {} or nil
        for i = 0, cap - 1 do
          local key, v = u32(raw, 8 * i), u32(raw, 8 * i + 4)
          if key ~= empty and v < 16384 then
            local op = ptr_of(read(owners + v * 8, 8) or '', 0)
            local oe = op and read(op, 24)
            local kind = oe and oe:sub(1, 8)
            local mine = dog.gun and kind == dog.gun
            if oe and kind ~= AVATAR_TYPE and (pass == 2 or mine or not dog.gun) then
              local unit = u32(oe, 12)
              local p = unit_position(unit)
              if p then
                local d2 = (p[1] - D[1]) ^ 2 + (p[2] - D[2]) ^ 2 + (p[3] - D[3]) ^ 2
                if d2 < 9 then
                  if seen then seen[#seen + 1] = string.format('%s id %d unit %d at %.2f m', hx(kind), u32(oe, 8), unit, math.sqrt(d2)) end
                  -- (your own weapons are 0.6-1.2 m from the drone when it leaves your back - a tester's logs; the dogs'
                  -- guns 0.20-0.23 m: a weapon of another type only counts within 0.5 m and not within 0.6 m of you)
                  local on_me = ME and (p[1] - ME[1]) ^ 2 + (p[2] - ME[2]) ^ 2 + (p[3] - ME[3]) ^ 2 < 0.36
                  if mine or (not (best and best.mine) and d2 < bd and d2 < 0.25 and not on_me) then
                    best, bd = { wi = v, unit = unit, id = u32(oe, 8), kind = hx(kind), ptr = op, mine = mine }, mine and -1 or d2
                  end
                end
              end
            end
          end
        end
        if not dog.gun then break end   -- (a dog without a known gun type: the one full pass above)
      end
      if seen then
        dog.fire_scan_noted = true
        note('laser (test): weapon records within 3 m of the ' .. dog.name .. ': ' .. (#seen > 0 and table.concat(seen, '; ') or 'none'))
      end
      if best then
        fire_nodes, wr_addr = nodes_of(best.wi)
        fire_unit, fire_how = best.unit, string.format('its gun %s (id %d, unit %d)', best.kind, best.id, best.unit)
        if fire_nodes then dog.fire_found = { drone = drone_id, wi = best.wi, ptr = best.ptr, unit = best.unit, how = fire_how } end
      end
    end)
  end
  if fire_nodes and dog.fire_noted ~= 'found' then
    dog.fire_noted = 'found'
    local l = {}
    for j = 0, 23 do if fire_nodes[j] then l[#l + 1] = tostring(fire_nodes[j]) end end
    note('laser: the ' .. dog.name .. ' fires from part ' .. table.concat(l, ', ') .. ' of ' .. (fire_how or '?') .. ' (its muzzle)')
  elseif not fire_nodes and not dog.fire_noted then
    dog.fire_noted = 'missing'
    note('laser: the ' .. dog.name .. "'s weapon record was not found (yet); its barrel is learned from its parts")
  end
  return {
    dog = dog, key = me:sub(1, 20) .. pack_id .. drone_ent:sub(1, 20), team_key = me:sub(1, 20), rec_addr = rec_addr, want = want_behaviour,
    drone_id = drone_id, drone_unit = drone_unit, player_unit = player_unit, tstate = tstates + slot_i * 208, owners = owners,
    fire_nodes = fire_nodes, wr_addr = wr_addr, fire_unit = fire_nodes and fire_unit,
    pbase = pbase, registry = global('registry'), clock = rptr(g.clock, 'clock'),
  }
end

local ctx, ctx_until = nil, 0
local reg_rows = {}   -- registry index -> entity row address (re-checked on every read)
local reg_frame, reg_seen = -1, {}   -- enemies already looked up this frame

-- the enemies one AI agent (a dog or a sentry) is currently considering, from its perception record. 'origin' is
-- where distances (d2) are measured from. Also returns the raw record, for the research log.
local function read_candidates(pbase, origin, registry)
  local perc = rd(pbase, 5112, 'perception record')
  local fcount = u32(perc, 0)
  need(fcount <= 32, 'faction filter')
  local filter = 0
  for j = 0, fcount - 1 do
    local f = u32(perc, 8 + j * 8)
    need(f < 32, 'faction id')
    filter = bit.bor(filter, bit.lshift(1, f))
  end

  local reg_head = rd(registry + 73808, 20, 'registry map')
  local reg_list = ptr_of(read(registry + 73832, 8), 0)
  local candidates = {}
  local function add(off, group)
    local id = u32(perc, off)
    if id == 0 then return end
    local flags, faction, score = u32(perc, off + 72), u32(perc, off + 76), f32(perc, off + 68)
    need(score == score and math.abs(score) < 100000, 'candidate score')
    local alive, ent = false, nil
    -- (the dog and every sentry mostly see the same enemies: each is looked up once per frame)
    if reg_frame ~= FRAME then reg_frame, reg_seen = FRAME, {} end
    local known = reg_seen[id]
    if known then alive, ent = known[1], known[2] or nil
    else
      local ri = map_lookup(registry + 73808, id, 32768, reg_head)
      if ri then
        need(ri < 16384, 'registry index')
        local rp = reg_rows[ri]
        local re = rp and read(rp, 24)
        if not (re and u32(re, 8) == id) then
          rp = reg_list and ptr_of(read(reg_list + ri * 8, 8), 0)
          re = rp and read(rp, 24)
          reg_rows[ri] = rp
        end
        alive = re ~= nil and u32(re, 8) == id
        if alive then ent = re end
      end
      reg_seen[id] = { alive, ent or false }
    end
    local x, y, z = f32(perc, off + 4), f32(perc, off + 8), f32(perc, off + 12)
    local pos, d2
    if x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6 then
      pos = { x, y, z }
      if origin then d2 = (x - origin[1]) ^ 2 + (y - origin[2]) ^ 2 + (z - origin[3]) ^ 2 end
    end
    candidates[#candidates + 1] = {
      id = id, pos = pos, d2 = d2, entry = pbase + off,
      mask_addr = pbase + off + 76, mask = perc:sub(off + 77, off + 80), alive = alive and bit.band(flags, 1) ~= 0, score = score,
      group = group, flags = flags, off = off, ent = ent, kind = ent and ent:sub(1, 8),
      -- the dog's own line of sight: set while it can see the enemy, cleared when cover blocks it; the
      -- float after it is how well it still remembers the enemy (1 = seen now, runs down to 0 over ~1 s)
      visible = perc:byte(off + 49) ~= 0, memory = f32(perc, off + 64),
      eligible = alive and bit.band(flags, 1) ~= 0 and bit.band(faction, filter) ~= 0 and score > 0,
    }
  end
  for _, grp in ipairs(GROUPS) do
    local c = u32(perc, grp[1])
    need(c <= 16, 'candidate group')
    for k = 0, c - 1 do add(grp[2] + k * 80, grp[3]) end
  end
  for _, one in ipairs(SINGLES) do if u32(perc, one[1] + 72) ~= 0 then add(one[1], one[2]) end end
  return candidates, perc
end


local function in_mission()
  local mission_ptr = ptr_of(read(A.g.mission, 8), 0)
  local mission = mission_ptr and read(mission_ptr, 68)
  return mission ~= nil and u32(mission, 8) ~= 0 and u32(mission, 64) ~= 0
end

-- returns a state table, or nil + a short reason. Game-structure surprises raise an Abort error.
local function read_state()
  if not in_mission() then ctx = nil; return nil, 'not in a mission' end

  local t = os.clock()
  local rec
  for attempt = 1, 2 do
    if not ctx or t >= ctx_until or attempt == 2 then
      local c, why = locate()
      if not c then ctx = nil; return nil, why end
      ctx, ctx_until, unit_cache, reg_rows = c, t + LOCATE_SECONDS, {}, {}
    end
    rec = read(ctx.rec_addr, 160)
    if rec and u32(rec, 0) == ctx.want and u32(rec, 104) == ctx.drone_id then break end
    rec = nil
    if attempt == 2 then need(false, 'behaviour record') end
  end
  local dog, rec_addr, pbase, registry = ctx.dog, ctx.rec_addr, ctx.pbase, ctx.registry
  local tstate = rd(ctx.tstate, 32, 'targeting state')
  local drone_pos = unit_position(ctx.drone_unit)
  local candidates, perc = read_candidates(pbase, drone_pos, registry)

  local now = u64(rd(ctx.clock + 24, 8, 'clock'), 0)
  need(now > 0 and now < 9007199254740991, 'clock')
  local deadline = u64(rec, 152)
  need(deadline < 9007199254740991, 'deadline')
  local target = u32(rec, 24)
  -- (the weapon's current fire node, only while the laser is on: one small read)
  local fire_node
  if ctx.wr_addr and rawget(_G, 'SmarterGuardDogsLaser') == true then
    local w = read(ctx.wr_addr + 216, 8)
    if w then
      local count, index = u32(w, 0), u32(w, 4)
      if index < count then fire_node = ctx.fire_nodes[index] end
    end
    fire_node = fire_node or ctx.fire_nodes[0]
  end
  -- (the gun's own pose array when its weapon belongs to another unit than the drone's)
  local fire_pose
  if fire_node and ctx.fire_unit and ctx.fire_unit ~= ctx.drone_unit then
    local gp = unit_position(ctx.fire_unit)
    fire_pose = gp and gp.pose
    if not fire_pose then fire_node = nil end
  end
  return {
    dog = dog, key = ctx.key,
    rec_addr = rec_addr, rec_head = rec:sub(1, 4), node = u32(rec, 8), target = target,
    synced = target ~= 0 and u32(tstate, 0) == target and rec:byte(121) == 1 and bit.band(u32(rec, 96), 1) ~= 0,
    candidates = candidates, now = now, deadline = deadline, perc = perc,
    player_pos = unit_position(ctx.player_unit, true), drone_pos = drone_pos, fire_node = fire_node, fire_pose = fire_pose,
    -- (4.5.3 Test 12) where the game aims the dog's gun (its targeting state; already read): the laser's fallback
    -- points there, and test builds check the beam against it (only built with a fire node: nothing else uses it)
    aim = fire_node and target ~= 0 and u32(tstate, 0) == target and { f32(tstate, 20), f32(tstate, 24), f32(tstate, 28) } or nil,
    mates = team_wanted() and teammates(ctx, t) or {}, mates_found = team_state and team.found or 0,
  }
end
