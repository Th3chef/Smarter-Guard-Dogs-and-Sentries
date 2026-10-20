
-- ======================================================================================================
-- Reading the game: the local player's guard dog, its AI record and what it can see
-- ======================================================================================================
local A   -- absolute layout, set at start-up

-- (4.6.3) the names other files use are declared here; the rest of this file sits in a do-block so its own
-- helpers stop counting toward Lua's 200 locals of the main chunk once the file ends
local is_local, unit_position, team, team_wanted, OPT, FRAME, teammates, team_detail, GROUPS, SINGLES, find_player, read_candidates, in_mission, read_state, PERC, loss_cut, HEALTH, IDLE   -- ((4.6.6 review) loss_cut: was a global)
-- ((5.1.5 Test 5) HEALTH: the game's health records, for the damage check of the sentries and dogs (below))
-- ((5.1.5 Test 11) IDLE: the mod idling while it has nothing to do (my ask: "If a guard dog is put away and there
-- are no deployed sentries, the mod shouldnt run. If there are no enemies within 150, then the mod shouldnt run as no
-- sentry/dog can engage at that range"): one cheap look every 0.25 s instead, see near_hostile, dog_peek (below), the
-- sentries' sleep in sentry_tick and the main loop
do
function is_local(entity) return bit.band(entity:byte(21), 3) == 1 end

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
-- ((4.6.4 review) the work in a named function: a new closure for every call - the drone, you, each teammate, each
-- sentry, every weapon record looked at - stopped LuaJIT from compiling these paths)
local function unit_position_raw(id, want_axes)
    local obj, h = unit_object(id)
    if not obj then return nil end
    local pose = need(ptr_of(h, 136), 'unit pose')
    local m = rd(pose, 64, 'unit pose')
    local x, y, z = f32(m, 48), f32(m, 52), f32(m, 56)
    if x ~= x or y ~= y or z ~= z or math.abs(x) > 1e6 or math.abs(y) > 1e6 or math.abs(z) > 1e6 then return nil end
    local p = { x, y, z, pose = pose }
    if want_axes then
      -- rotation rows, normalized; dropped if they do not look like a rotation
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
end
function unit_position(id, want_axes)
  if not id or id == 0 then return nil end
  local ok, pos = pcall(unit_position_raw, id, want_axes)
  return ok and pos or nil
end

-- Teammates: every helldiver has a row in the same owner table as ours (2048 rows of 24 bytes; the game's own
-- code wraps its free-row search at 0x800). The whole table is read in one go once a second and the rows of
-- other players' helldivers kept; in between only their positions are read (two small reads each).
local OWNER_ROWS = 2048
local TEAM_SCAN_SECONDS = 1.0
local TEAM_MAX = 8
team = { units = {}, next_scan = 0, key = nil, last = {}, found = 0, rows = {}, moved = {}, players = '?' }
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
function team_wanted()
  local on = rawget(_G, 'SmarterGuardDogsTeammates') == true
  if on ~= team_state then
    team_state = on; session.team.off = not on
    note('teammate safety: ' .. (on and 'on' or (rawget(_G, 'SmarterGuardDogsMenu') and 'off (in the mod options menu)' or 'off (option not installed)')))
  end
  return on
end

-- (4.0.1) the optional parts that choose what the mod handles: Safety (you), Guard Dogs and Sentries (each set by a
-- tiny addon, like the laser's). Read every frame, so load order doesn't matter.
OPT = {}
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
  -- (4.6.5) Sentry Safety: your sentries don't fire through or blast any sentry out - yours or another player's
  OPT.sentry_safety = function() return flag('SmarterGuardDogsSentrySafety', 'sentry safety', ': your sentries may fire through other sentries') end
  -- (4.7.0) SEAF Safety: your dog and sentries don't fire through, swing across or blast SEAF soldiers and civilians
  OPT.seaf_safety = function() return flag('SmarterGuardDogsSEAFSafety', 'SEAF safety', ': your dog and sentries may fire through SEAF soldiers and civilians') end
  -- (5.0) Ping Targeting: your sentries go for a pinged enemy they can hurt first
  OPT.ping = function() return flag('SmarterGuardDogsPing', 'ping targeting', ': your sentries pick their own targets, pinged or not') end
  -- (5.0 Test 13) Targeting Marker: the gun's icon over the enemy it is on (its own option; works without the laser)
  OPT.marker = function() return flag('SmarterGuardDogsMarker', 'targeting marker', ': no markers over enemies') end
  OPT.priority = function() return flag('SmarterGuardDogsPriority', 'target prioritization', ': the game decides the order') end
end

-- positions of the other players' helldivers (with a smoothed velocity, for a short look-ahead). Worked out once
-- per frame: the dogs and the sentries share the result.
FRAME = 0   -- counts the mod's frames (the main loop adds one each tick)
function teammates(c, t)
  if team.frame == FRAME and team.frame_key == c.team_key and team.frame_mates then return team.frame_mates end
  if t >= team.next_scan or team.key ~= c.team_key then
    team.units, team.found = scan_teammates(c.owners, c.player_unit)
    team.next_scan, team.key = t + TEAM_SCAN_SECONDS, c.team_key
    local keep, moved = {}, {}
    for _, u in ipairs(team.units) do keep[u] = team.last[u]; moved[u] = team.moved[u] end
    team.last, team.moved = keep, moved   -- (4.6.3 review: 'moved' was never pruned - every respawn added a unit)
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
function team_detail(me)
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
GROUPS = { { 784, 792, 'g1' }, { 2072, 2080, 'g2' }, { 3360, 3368, 'g3' } }
SINGLES = { { 4648, 's1' }, { 4728, 's2' }, { 4808, 's3' } }

-- The walk from the game's player table to our dog's AI and perception records takes ~30 reads. It is done
-- four times a second (and at once if anything looks different); in between the addresses it found are
-- reused and checked against the dog's own AI record every frame.
local LOCATE_SECONDS = 0.25
-- your helldiver: its owner row (id, unit) and the owner table itself (also used for teammates and sentries)
function find_player()
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
  if not is_local(me) then return nil, 'helldiver is not ours' end
  -- (4.6.5, a commenter: players in exosuits weren't protected) while you pilot something (an exosuit, say) the game's
  -- avatar is that unit, not your helldiver: it used to end here - no body for you, the sentries' safety off for you.
  -- Now it is returned as a vehicle (its type), and the sentries keep a larger body round it (bodies_for)
  if me:sub(1, 8) ~= AVATAR_TYPE then
    return { me = me, owner_id = u32(me, 8), player_unit = u32(me, 12), owners = owners, team_key = me:sub(1, 20), vehicle = me:sub(1, 8) }
  end
  return { me = me, owner_id = u32(me, 8), player_unit = u32(me, 12), owners = owners, team_key = me:sub(1, 20) }
end

local function locate()
  local g = A.g
  local function global(name) return rptr(g[name], name) end
  -- (the Guard Dogs option off: nothing to look up, your dog is left to the game)
  if not OPT.dogs() then return nil, 'guard dogs option off (left alone)' end
  local pl, why = find_player()
  if not pl then return nil, why end
  if pl.vehicle then return nil, 'piloting a vehicle' end   -- (4.6.5: as before, the dog is left alone then)
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
  local dog, drone_index, pack_i, pack_p
  for i = 0, n - 1 do
    local pp = ptr_of(read(packs + i * 8, 8), 0)
    local pe = read(pp or 0, 24)
    if pe and u32(pe, 8) == pack_id then
      dog = DOG_BY_PACK[pe:sub(1, 8)]
      if not dog then return nil, 'backpack is not a supported dog' end
      if not is_local(pe) then return nil, 'backpack is not ours' end
      drone_index = u32(rd(drones + i * 8, 8, 'backpack drone'), 4)
      pack_i, pack_p = i, pp
      break
    end
  end
  if not dog then return nil, 'no backpack worn' end
  if not drone_index or drone_index == 32767 then
    -- ((5.1.5 Test 11) where its drone will show when it is launched: looked at every 0.25 s while it is put away)
    IDLE.pack = pack_i and { packs + pack_i * 8, pack_p, drones + pack_i * 8 } or nil
    return nil, 'dog not deployed'
  end
  IDLE.pack = nil

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
  local function try(i, p)
    local de = p and read(p, 24)
    if de and de:sub(1, 8) == dog.drone and u32(de, 16) == drone_index then slot_i, drone_ptr, drone_ent = i, p, de; return true end
  end
  -- ((5.1.5 Test 11) the slot it had at the last look first (from its id in the targeting map): this look runs every
  -- 0.25 s while the dog is out, and walked the whole agent list - two reads an agent, hundreds in a big fight - each time)
  local last = IDLE.drone
  if last and last.index == drone_index then
    local i = map_lookup(targeting + 336, last.id, 16384)
    if i and i < tn then try(i, ptr_of(read(tents + i * 8, 8), 0)) end
  end
  if not slot_i and tn > 0 then
    local ptrs = rd(tents, 8 * tn, 'targeting entities')   -- (one read for the whole list)
    for i = 0, tn - 1 do if try(i, ptr_of(ptrs, i * 8)) then break end end
  end
  if slot_i and not is_local(drone_ent) then return nil, 'dog is not ours' end
  if not slot_i then return nil, 'dog has no targeting' end
  local drone_id, drone_unit = u32(drone_ent, 8), u32(drone_ent, 12)
  need(map_lookup(targeting + 336, drone_id, 16384) == slot_i, 'targeting slot')
  IDLE.drone = { id = drone_id, index = drone_index }

  local bi = map_lookup(behaviours + 64, drone_id, 32768)
  if not bi then return nil, 'dog has no AI record' end
  need(bi < u32(rd(behaviours + 32, 4, 'behavior count'), 0) and bi < 16384, 'behavior index')
  need(rptr(rptr(behaviours + 88, 'behavior owners') + bi * 8, 'behavior owner') == drone_ptr, 'behavior owner')
  local rec_addr = rptr(behaviours + 96, 'behavior records') + bi * A.stride
  local rec = rd(rec_addr, 160, 'behavior record')
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
      -- (4.6.3 review: read without raising - an empty owner slot raised before, which skipped the search below for
      -- the rest of the deployment)
      if F and F.drone == drone_id then
        if ptr_of(read(owners + F.wi * 8, 8), 0) == F.ptr then
          fire_nodes, wr_addr = nodes_of(F.wi)
          fire_unit, fire_how = F.unit, F.how
          return
        end
        dog.fire_found = nil
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
            local op = ptr_of(read(owners + v * 8, 8), 0)   -- ((4.6.6 review) no "or ''": that read 8 bytes past an empty string
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
                  -- (4.6.3 review: the closest of the dog's own gun type - before, the last one within 3 m won, which
                  -- could be a teammate's dog launched next to yours)
                  if (mine and not (best and best.mine and best.d2 <= d2)) or (not mine and not (best and best.mine) and d2 < bd and d2 < 0.25 and not on_me) then
                    best, bd = { wi = v, unit = unit, id = u32(oe, 8), kind = hx(kind), ptr = op, mine = mine, d2 = d2 }, mine and -1 or d2
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
    pbase = pbase, registry = global('registry'), clock = rptr(g.clock, 'clock'), bi = bi, pi = pi,
  }
end

local ctx, ctx_until = nil, 0
local reg_rows = {}   -- registry index -> entity row address (re-checked on every read)
local reg_frame, reg_seen = -1, {}   -- enemies already looked up this frame (id -> its row, or false)
-- ((5.1.5 Test 18) an enemy's place in the registry map, kept a while (ix: id -> { index, until frame }): the map was
-- looked up afresh for every enemy every frame - over a third of all the mod's reads in my big-fight sim. Its row is
-- still read each frame (still it, still there), and the map asked again after 'keep' frames or as soon as the row
-- isn't it any more. 'fresh': ids looked up in the map this frame. The map's header and row list: once a frame
-- (one table: the main chunk is near LuaJIT's 200 locals)
local REG = { ix = {}, n = 0, keep = 24, fresh = {}, hf = -1, gone = {}, gn = 0, pos = {} }

-- the enemies one AI agent (a dog or a sentry) is currently considering, from its perception record. 'origin' is
-- where distances (d2) are measured from. Also returns the raw record, for the research log.
-- ((4.6.4 review) the perception record is read into one buffer kept for the whole session and parsed in place: before,
-- every dog and busy sentry made a new 5 KB string every frame - about 1.5 MB a second of garbage with five out. Only
-- what the groups and the three singles use (up to 4888 bytes) is read)
local PERC_N = 4888
local PBUF = ffi.new('uint8_t[?]', PERC_N)
local pread, bu32, bf32
do
  local PV, PU32p, PF32p = ffi.typeof('const void *'), ffi.typeof('const uint32_t *'), ffi.typeof('const float *')
  local NAN = 0 / 0
  pread = function(addr)
    return K32.SgdReadProcessMemory(PROCESS, ffi.cast(PV, addr), PBUF, PERC_N, DONE) ~= 0 and DONE[0] == PERC_N
  end
  -- ((5.1.5 Test 18) through typed views of the buffer made once: indexing them gives a plain number, where the
  -- pointer sums before made a small throwaway object per number whenever the code wasn't compiled - every field of
  -- every enemy in every sentry's list, every frame. Every offset read here is a multiple of 4; any other goes the old way)
  local V32, VF = ffi.cast(PU32p, PBUF), ffi.cast(PF32p, PBUF)
  bu32 = function(o)
    if o % 4 == 0 then return V32[o / 4] end
    return tonumber(ffi.cast(PU32p, PBUF + o)[0])
  end
  bf32 = function(o)
    local v
    if o % 4 == 0 then v = VF[o / 4] else v = tonumber(ffi.cast(PF32p, PBUF + o)[0]) end
    if v == nil or v ~= v then return NAN end
    return v
  end
end
-- ((4.6.4 release review) the same buffer for the Tesla Tower's pass right after the game's update (sentry_after),
-- which made a new 5 KB string every frame while a tower was out)
PERC = { read = function(addr) return pread(addr) end, u32 = function(o) return bu32(o) end, str = function(o, n) return ffi.string(PBUF + o, n) end }

-- ((4.6.4 release review) 'want_header': the 264-byte faction list at its start as a string - only the Tesla Tower
-- uses it; every other dog and sentry skipped making it each frame)
-- ((5.1.5 Test 18) 'pool' (a sentry's): its candidate entries are reused from two frames back instead of made anew.
-- They were most of the mod's garbage in a big fight - one table per enemy per sentry per frame, ~350 a frame with 8
-- sentries and 40 enemies. Two sets taken in turn, so last frame's list (its 'st', which the beams and a failed read
-- fall back on) is never written over. Every field is set on each use; 'pos' stays a fresh table, as places are kept
-- (the mortar's landing spot, the laser's ends)
-- ('fresh': the id of its current target, whose place in the map is always looked up afresh: the dead-target rules
-- lean on an enemy dropping out of the registry the frame it does)
-- ((5.1.5 Test 31) an entity's registry row by its id (nil if it isn't there): for a sentry's target that isn't in its own
-- list - my Test 30 log had mortars and the Autocannon on targets missing from their lists for 1,435 frames, so no marker)
function entity_row(registry, id)
  if not (registry and id and id ~= 0) then return nil end
  if REG.hf ~= FRAME or REG.hr ~= registry then
    REG.head = rd(registry + 73808, 20, 'registry map')
    REG.list = ptr_of(read(registry + 73832, 8), 0)
    REG.hf, REG.hr = FRAME, registry
  end
  local ri = map_lookup(registry + 73808, id, 32768, REG.head, true)
  if not ri or ri >= 16384 then return nil end
  local rp = reg_rows[ri]
  local re = rp and read(rp, 24)
  if not (re and u32(re, 8) == id) then
    rp = REG.list and ptr_of(read(REG.list + ri * 8, 8), 0)
    re = rp and read(rp, 24)
    if re then reg_rows[ri] = rp end
  end
  if re and u32(re, 8) == id then return re end
  return nil
end
function read_candidates(pbase, origin, registry, want_header, pool, fresh)
  if pbase == 'forget' then REG.ix, REG.n, REG.gone, REG.gn = {}, 0, {}, 0; return end   -- ((5.1.5 Test 18) a mission's end: ids start over
  need(type(pbase) == 'number' and pbase >= 65536 and pread(pbase), 'perception record')
  local fcount = bu32(0)
  need(fcount <= 32, 'faction filter')
  local filter = 0
  for j = 0, fcount - 1 do
    local f = bu32(8 + j * 8)
    need(f < 32, 'faction id')
    filter = bit.bor(filter, bit.lshift(1, f))
  end

  if REG.hf ~= FRAME or REG.hr ~= registry then
    REG.head = rd(registry + 73808, 20, 'registry map')
    REG.list = ptr_of(read(registry + 73832, 8), 0)
    REG.hf, REG.hr = FRAME, registry
  end
  local reg_head, reg_list = REG.head, REG.list
  local candidates, items, pk
  if pool then
    -- (the set not handed out last time; it only counts as handed out once this read gets through)
    pk = pool.k == 1 and 2 or 1
    candidates, items = pool[pk], pool[pk + 2]
    if not candidates then candidates, items = {}, {}; pool[pk], pool[pk + 2] = candidates, items end
    for i = #candidates, 1, -1 do candidates[i] = nil end
  else candidates = {} end
  local function add(off, group)
    local id = bu32(off)
    if id == 0 then return end
    local flags, faction, score = bu32(off + 72), bu32(off + 76), bf32(off + 68)
    need(score == score and math.abs(score) < 100000, 'candidate score')
    local alive, ent = false, nil
    -- (the dog and every sentry mostly see the same enemies: each is looked up once per frame)
    if reg_frame ~= FRAME then reg_frame, reg_seen, REG.fresh, REG.pos = FRAME, {}, {}, {} end
    local known = reg_seen[id]
    if known ~= nil and (id ~= fresh or REG.fresh[id]) then alive, ent = known ~= false, known or nil
    else
      local kx = REG.ix[id]
      local ri
      if kx and FRAME < kx[2] and id ~= fresh then ri = kx[1]
      -- (one the game itself has down as dead and the map didn't have: not asked again for a while - the dead stay
      -- listed ~1 s, and were each looked up every frame)
      elseif REG.gone[id] and FRAME < REG.gone[id] and bit.band(flags, 1) == 0 then ri = nil
      else
        REG.fresh[id] = true
        ri = map_lookup(registry + 73808, id, 32768, reg_head, true)
        if ri then
          -- (staggered by id, so they don't all come due in the same frame)
          if not kx then
            kx = {}; REG.ix[id] = kx; REG.n = REG.n + 1
            if REG.n > 4096 then REG.ix, REG.n = { [id] = kx }, 1 end   -- (a long mission: started afresh)
          end
          kx[1], kx[2] = ri, FRAME + REG.keep + id % 8
        else
          if kx then REG.ix[id] = nil; REG.n = REG.n - 1 end
          if bit.band(flags, 1) == 0 then
            if not REG.gone[id] then REG.gn = REG.gn + 1; if REG.gn > 1024 then REG.gone, REG.gn = {}, 1 end end
            REG.gone[id] = FRAME + REG.keep
          end
        end
      end
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
        if alive then ent = re
        elseif REG.ix[id] then REG.ix[id] = nil; REG.n = REG.n - 1 end   -- (not it any more: the map again next time)
      end
      reg_seen[id] = ent or false
    end
    local x, y, z = bf32(off + 4), bf32(off + 8), bf32(off + 12)
    local pos, d2
    if x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6 then
      -- ((5.1.5 Test 19) one place table per enemy a frame when the lists agree on where it is (they mostly do): every
      -- sentry made its own copy. Nothing changes a place table once made, so sharing it is safe)
      local sp = REG.pos[id]
      if sp and sp[1] == x and sp[2] == y and sp[3] == z then pos = sp
      else pos = { x, y, z }; REG.pos[id] = pos end
      if origin then d2 = (x - origin[1]) ^ 2 + (y - origin[2]) ^ 2 + (z - origin[3]) ^ 2 end
    end
    local n = #candidates + 1
    local c = items and items[n]
    if not c then c = {}; if items then items[n] = c end end
    local o = off + 76
    c.id, c.pos, c.d2, c.entry = id, pos, d2, pbase + off
    c.mask_addr, c.mask = pbase + o, string.char(PBUF[o], PBUF[o + 1], PBUF[o + 2], PBUF[o + 3])
    c.alive, c.score = alive and bit.band(flags, 1) ~= 0, score
    c.group, c.flags, c.off, c.ent = group, flags, off, ent
    c.kind = ent and ent:sub(1, 8) or nil
    -- the dog's own line of sight: set while it can see the enemy, cleared when cover blocks it; the
    -- float after it is how well it still remembers the enemy (1 = seen now, runs down to 0 over ~1 s)
    c.visible = PBUF[off + 48] ~= 0 or (ent ~= nil and SGD.cloaks[ent:sub(1, 8)] == true)
    c.memory = bf32(off + 64)
    c.eligible = alive and bit.band(flags, 1) ~= 0 and bit.band(faction, filter) ~= 0 and score > 0
    -- (what other parts note on an entry, cleared for its reuse: the live place, guarded by the frame anyway)
    c.live_f, c.live_p, c.dp = nil, nil, nil
    candidates[n] = c
  end
  for _, grp in ipairs(GROUPS) do
    local c = bu32(grp[1])
    need(c <= 16, 'candidate group')
    for k = 0, c - 1 do add(grp[2] + k * 80, grp[3]) end
  end
  for _, one in ipairs(SINGLES) do if bu32(one[1] + 72) ~= 0 then add(one[1], one[2]) end end
  if pool then pool.k = pk end
  -- (the faction list at its start, for the Tesla Tower's filter and its test notes)
  return candidates, want_header and ffi.string(PBUF, 264) or nil
end


-- (4.6.5, my note: no more firing at the spot for a second after a target is lost, for every dog and sentry) the AI keeps
-- shooting where its target was until 1 s after the loss time in its record (+408, stamped by the game; found on the
-- Gatling / pod / FRV guns, 4.6.2-4.6.3; the dump shows other sentry AIs with the same check). Moving that time back
-- a second lets the game's own check end the firing at its next update. Only when +408 reads a time from the last
-- second (the loss just happened); returns its age in seconds, written or not, or nil (not a recent time)
function loss_cut(rec_addr, now)
  if (A.stride or 0) < 416 then return nil end
  local lt = read(rec_addr + 408, 8)
  if not lt then return nil end
  local age = now - u64(lt, 0)
  if age < 0 or age >= 1000000 then return nil, age end
  if not write(rec_addr + 408, u64bytes(now - 1000001)) then stats.write_failures = stats.write_failures + 1; return nil end
  return age / 1e6
end

-- ((5.1.5 Test 11) once a frame: the dog's look and the sentries' each asked, 4 reads a poll out of a mission)
local inm_frame, inm_v = -1, false
function in_mission()
  if inm_frame == FRAME then return inm_v end
  local mission_ptr = ptr_of(read(A.g.mission, 8), 0)
  local mission = mission_ptr and read(mission_ptr, 68)
  inm_frame, inm_v = FRAME, mission ~= nil and u32(mission, 8) ~= 0 and u32(mission, 64) ~= 0
  return inm_v
end

-- returns a state table, or nil + a short reason. Game-structure surprises raise an Abort error.
local locate_fail_until, locate_fail_why = 0, nil
function read_state()
  if not in_mission() then
    ctx = nil
    if next(unit_cache) then unit_cache = {} end   -- (4.6.3 review: with no dog out it was never emptied)
    return nil, 'not in a mission'
  end

  local t = os.clock()
  -- (4.6.3 review) after a failed look for your dog (none out, another backpack...) the next is LOCATE_SECONDS later:
  -- while a sentry kept the polls going every frame, it was repeated every frame
  if not ctx and t < locate_fail_until then
    -- ((5.1.5 Test 11) a dog that is put away: only the backpack's drone slot is looked at (2 reads), every 0.25 s)
    local K = IDLE.pack
    if not (K and locate_fail_why == 'dog not deployed' and t >= IDLE.pack_next) then return nil, locate_fail_why end
    IDLE.pack_next = t + IDLE.look
    local pp = ptr_of(read(K[1], 8), 0)
    local dv = pp == K[2] and read(K[3], 8)
    if dv and u32(dv, 4) == 32767 then return nil, locate_fail_why end
    locate_fail_until = 0   -- (launched, or its backpack changed: the full look now)
  end
  local rec
  for attempt = 1, 2 do
    if not ctx or t >= ctx_until or attempt == 2 then
      -- ((4.6.4 review) a look that aborts on a failed read waits LOCATE_SECONDS too, like one that finds nothing:
      -- before, a check that kept failing repeated the whole look - ~30 reads - every frame while a sentry was busy)
      local okl, c, why = pcall(locate)
      if not okl then
        ctx = nil
        locate_fail_until = t + LOCATE_SECONDS
        locate_fail_why = type(c) == 'table' and c[1] == Abort and ('read_failed: ' .. tostring(c[2])) or 'read_failed'
        error(c, 0)
      end
      -- ((5.1.5 Test 11) no dog out (none worn, put away, the option off...): the full look once a second, not four times)
      -- (a dog put away: every 5 s, as its drone slot is looked at in between)
      if not c then
        ctx = nil
        locate_fail_until, locate_fail_why = t + ((why == 'dog not deployed' and IDLE.pack) and 5.0 or IDLE.why[why] and 1.0 or LOCATE_SECONDS), why
        IDLE.pack_next = t + IDLE.look
        return nil, why
      end
      ctx, ctx_until, unit_cache, reg_rows = c, t + LOCATE_SECONDS, {}, {}
      c.peek_t, c.peek_full = t, t
    end
    rec = read(ctx.rec_addr, 160)
    if rec and u32(rec, 0) == ctx.want and u32(rec, 104) == ctx.drone_id then break end
    rec = nil
    if attempt == 2 then need(false, 'behavior record') end
  end
  local dog, rec_addr, pbase, registry = ctx.dog, ctx.rec_addr, ctx.pbase, ctx.registry
  local tstate = rd(ctx.tstate, 32, 'targeting state')
  local drone_pos = unit_position(ctx.drone_unit)
  local candidates = read_candidates(pbase, drone_pos, registry, nil, nil, u32(rec, 24))

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
  -- ((4.6.7 review) your position for the safety: when it can't be read for a moment, the last one read (up to 0.5 s
  -- old) - before, that frame had no safety check at all)
  local me = unit_position(ctx.player_unit, true)
  if me then ctx.me_last, ctx.me_t = me, t elseif ctx.me_last and t - (ctx.me_t or -99) < 0.5 then me = ctx.me_last end
  return {
    dog = dog, key = ctx.key,
    rec_addr = rec_addr, rec_head = rec:sub(1, 4), node = u32(rec, 8), target = target,
    synced = target ~= 0 and u32(tstate, 0) == target and rec:byte(121) == 1 and bit.band(u32(rec, 96), 1) ~= 0,
    candidates = candidates, now = now, deadline = deadline,
    player_pos = me, drone_pos = drone_pos, fire_node = fire_node, fire_pose = fire_pose,
    -- (4.5.3 Test 12) where the game aims the dog's gun (its targeting state; already read): the laser's fallback
    -- points there, and test builds check the beam against it (only built with a fire node: nothing else uses it)
    aim = fire_node and target ~= 0 and u32(tstate, 0) == target and { f32(tstate, 20), f32(tstate, 24), f32(tstate, 28) } or nil,
    mates = team_wanted() and teammates(ctx, t) or {}, mates_found = team_state and team.found or 0,
  }
end

-- ------------------------------------------------------------------ idle (5.1.5 Test 11)
-- IDLE.range: no dog or sentry engages farther than the mortars' 125 m, so with no enemy within 150 m of a gun it has
-- nothing to do. IDLE.look: how often a part with nothing to do looks again. IDLE.settle: how long a part must have had
-- nothing to do before it idles (a red safety flash or a gray marker still showing, a target just lost)
IDLE = { range = 150, look = 0.25, settle = 1.0, pack = nil, pack_next = 0, drone = nil, dog_asleep = false, dog_next = 0, dog_since = nil, dog_skip = nil,
  on = false, wake_scan = false, last_row = nil, working = nil, state = nil, notes = 0, frames = 0, work_frames = 0, idle_s = 0,
  -- (the reasons the dog's full look waits a second: no dog worn, or one put away (its drone slot is looked at every
  -- IDLE.look s, read_state). Not a helldiver missing for a moment or a vehicle you may step out of: those stay at 0.25 s)
  why = { ['no backpack worn'] = true, ['dog not deployed'] = true, ['backpack is not a supported dog'] = true, ['no loadout'] = true,
    ['guard dogs option off (left alone)'] = true } }
session.idle, SGD.idle = IDLE, IDLE
-- is an enemy this gun may pick within r m of 'origin'? One read (its perception record): an entry with an id, its
-- alive flag and a faction it fights, not in 'skip' (the bodies in its list when it went idle). Not only those the game
-- rates above 0 now: a dog still picks the others now and then. true too when the record can't be read or looks wrong
-- (better awake than blind); a hidden entry (the mod's blank mask) isn't counted, but a gun with anything hidden never idles
function IDLE.near_hostile(pbase, origin, r, skip)
  if not (pbase and origin and pbase >= 65536 and pread(pbase)) then return true end
  local fcount = bu32(0)
  if fcount > 32 then return true end
  local filter = 0
  for j = 0, fcount - 1 do
    local f = bu32(8 + j * 8)
    if f >= 32 then return true end
    filter = bit.bor(filter, bit.lshift(1, f))
  end
  local r2, ox, oy, oz = r * r, origin[1], origin[2], origin[3]
  local function hot(off)
    local id = bu32(off)
    if id == 0 or bit.band(bu32(off + 72), 1) == 0 or bit.band(bu32(off + 76), filter) == 0 or (skip and skip[id]) then return false end
    local x, y, z = bf32(off + 4), bf32(off + 8), bf32(off + 12)
    if not (x == x and y == y and z == z) then return true end
    return (x - ox) ^ 2 + (y - oy) ^ 2 + (z - oz) ^ 2 < r2
  end
  for _, grp in ipairs(GROUPS) do
    local c = bu32(grp[1])
    if c > 16 then return true end
    for k = 0, c - 1 do if hot(grp[2] + k * 80) then return true end end
  end
  for _, one in ipairs(SINGLES) do if bu32(one[1] + 72) ~= 0 and hot(one[1]) then return true end end
  return false
end
-- the dog's look while it idles: true while it still has nothing to do (its AI record still its own, no target, no
-- enemy within IDLE.range of it); nil wakes it. Once a second its AI and perception records are checked to be where
-- they were (the game moves them now and then; an old copy is no longer kept up to date) and the drone's place read
-- (the 150 m leave room for a second of walking); the full look (locate) every 5 s
local function same_records()
  local beh, per = rptr(A.g.behaviours, 'behaviours'), rptr(A.g.perception, 'perception')
  return map_lookup(beh + 64, ctx.drone_id, 32768) == ctx.bi and map_lookup(per + 48, ctx.drone_id, 32768) == ctx.pi
    and rptr(beh + 96, 'behavior records') + ctx.bi * A.stride == ctx.rec_addr and rptr(per + 80, 'perception records') + ctx.pi * 5112 == ctx.pbase
end
function IDLE.dog_peek(t)
  if not ctx or not in_mission() then return nil end
  if t - (ctx.peek_full or ctx.peek_t or 0) >= 5.0 then
    local okl, c = pcall(locate)
    if not (okl and c and c.rec_addr == ctx.rec_addr and c.drone_id == ctx.drone_id and c.pbase == ctx.pbase and c.key == ctx.key) then return nil end
    ctx.peek_full, ctx.peek_t, ctx.peek_pos = t, t, nil
  elseif t - (ctx.peek_t or 0) >= 1.0 then
    local okc, same = pcall(same_records)
    if not (okc and same) then return nil end
    ctx.peek_t, ctx.peek_pos = t, nil
  end
  if not ctx.peek_pos then ctx.peek_pos = unit_position(ctx.drone_unit); if not ctx.peek_pos then return nil end end
  local rec = read(ctx.rec_addr, 108)
  if not (rec and u32(rec, 0) == ctx.want and u32(rec, 104) == ctx.drone_id and u32(rec, 24) == 0) then return nil end
  if IDLE.near_hostile(ctx.pbase, ctx.peek_pos, IDLE.range, IDLE.dog_skip) then return nil end
  return true
end
-- (waking: the dog is looked up afresh before anything is acted on)
function IDLE.dog_wake() ctx_until = 0 end

-- ------------------------------------------------------------------ the damage check (5.1.5 Test 5)
-- (my ask: "is there a way for sentries to know when they are actually dealing damage?" ... "It should still keep
-- its targeting, but if after a short delay, its realizing its firing at something that isnt taking damage, it should
-- change targets") The game keeps every enemy's health in its health component (manager at the 'health' global, from
-- the 2026-09-24 module dump, our own reading): entity id -> index in a hash map at +0x1030 (slots, capacity, empty,
-- multiplier), the entity objects at +0x1048 (id at +8), the records at +0x1058 (0x1b8 bytes; +0x14 = health now, an
-- integer, which goes negative while bleeding out) and the settings at +0x1060 (0x1c bytes; +0x14 = full health).
-- A shooter's target whose health hasn't gone down over a while of firing at it isn't being hurt: a wall, a rock,
-- cover or armor in the way. Only armed once a health value has been seen going down this mission (so the check never
-- acts where the records don't follow the fight, e.g. if a joined game doesn't keep them up to date).
HEALTH = { proven = false, off = false, reads = 0, found = 0, bad = 0 }
-- ((5.1.5 review) enemies whose shield takes the hits first, so their health stays put for a while under fire that is
-- working: the Overseer and the Harvester (shield 1,500), the Gatekeeper and the Veracitor (1,300) - the Codex's
-- shield parts. A Test 5 log had a Laser Sentry and a Gatling drop the same Overseer at 598 of 600 health. They are
-- left out of the damage check (the Heavy Devastator's shield already was, with the burst rule)
HEALTH.shielded = {}
for _, h in ipairs({ 'da40bb347c7447f2', '965eae5a51acdd4a', '453fe22c634eb30f', '20b9c7734daead65' }) do
  HEALTH.shielded[(h:gsub('..', function(x) return string.char(tonumber(x, 16)) end)):reverse()] = true
end
session.health = HEALTH
local function s32(v) return v >= 2147483648 and v - 4294967296 or v end
-- ((5.1.5 Test 18) the health manager, its map's header and its array header once a frame (HEALTH.fc), not per look-up)
local function hp_raw(g, id)
  local C = HEALTH.fc
  if not C or C.f ~= FRAME or C.g ~= g then
    C = C or {}; HEALTH.fc = C
    C.f, C.g = FRAME, g
    C.mgr = ptr_of(read(g, 8), 0)
    C.mh = C.mgr and read(C.mgr + 0x1030, 20)
    C.hdr = C.mgr and read(C.mgr + 0x1010, 0x58)
  end
  local mgr, hdr = C.mgr, C.hdr
  if not (mgr and C.mh) then return nil end
  local idx = map_lookup(mgr + 0x1030, id, 1048576, C.mh, true)
  if not idx then return nil end
  if not hdr or idx >= u32(hdr, 0) then return nil end
  local ents, recs, sets = ptr_of(hdr, 0x38), ptr_of(hdr, 0x48), ptr_of(hdr, 0x50)
  if not (ents and recs and sets) then return nil end
  local eo = ptr_of(read(ents + idx * 8, 8), 0)
  local ek = eo and read(eo + 8, 4)
  if not ek or u32(ek, 0) ~= id then return nil end
  local r, m = read(recs + idx * 0x1b8 + 0x14, 4), read(sets + idx * 0x1c + 0x14, 4)
  if not (r and m) then return nil end
  return s32(u32(r, 0)), s32(u32(m, 0))
end
-- an enemy's health now and its full health (nil when it has no health record or it can't be read)
function HEALTH.of(id)
  if HEALTH.off then return nil end
  local g = A and A.g and A.g.health
  if not g then HEALTH.off = true; note('damage check: off (the health records were not found in this game build)'); return nil end
  HEALTH.reads = HEALTH.reads + 1
  local ok, hp, mx = pcall(hp_raw, g, id)
  if not ok or not hp then
    -- ((5.1.5 review) not one record found in 200 looks: the records are not where this build is read from (a game
    -- update that moved them, say) - the check goes off rather than looking up every target for nothing)
    if HEALTH.found == 0 and HEALTH.reads >= 200 then HEALTH.off = true; note('damage check: off (no health record found in 200 looks: this game build keeps them elsewhere)') end
    return nil
  end
  if mx <= 0 or mx > 10000000 or hp > mx * 2 + 10 or hp < -10000000 then
    HEALTH.bad = HEALTH.bad + 1
    if HEALTH.bad >= 20 then HEALTH.off = true; note('damage check: off (the health records do not read as expected in this game build)') end
    return nil
  end
  HEALTH.found = HEALTH.found + 1
  return hp, mx
end
-- ((5.1.5 Test 6, test builds: I can't watch every sentry) how each drop turned out, judged by the game's
-- health values: was the next enemy it went for hurt within 3 s (the switch paid off), did anyone else hurt the
-- dropped one while it was left alone (it wasn't immune), and when it came back to it, did it hurt it within its wait
-- (then the drop was likely wrong, or the enemy had come out of cover). Kept for 15 s per drop, tallied per kind.
HEALTH.tally, HEALTH.open = {}, {}
function HEALTH.track_new(key, kind, id, wait, info)
  local T = HEALTH.tally[kind]
  if not T then T = { drops = 0, meter_moving = 0, meter_still = 0, meter_unknown = 0, unseen = 0, mate = 0, rise = 0, next_hurt = 0, next_none = 0,
    back = 0, back_hurt = 0, others_hurt = 0 }; HEALTH.tally[kind] = T end
  T.drops = T.drops + 1
  if info.meter == nil then T.meter_unknown = T.meter_unknown + 1 elseif info.meter then T.meter_moving = T.meter_moving + 1 else T.meter_still = T.meter_still + 1 end
  if info.unseen then T.unseen = T.unseen + 1 end
  if info.mate then T.mate = T.mate + 1 end
  if info.rise then T.rise = T.rise + 1 end
  if #HEALTH.open < 60 then
    HEALTH.open[#HEALTH.open + 1] = { key = key, kind = kind, id = id, t0 = info.t, wait = wait, hp = info.hp, hold = info.hold, next_hp = {}, back_f = nil }
  end
end
-- each frame for a shooter (key) that has open drops: its target now, and how long it has fired at it
function HEALTH.track_step(key, target, fired, t)
  local L = HEALTH.open
  local i = 1
  while i <= #L do
    local D = L[i]
    local done = false
    if D.key == key and t >= (D.next or 0) then
      D.next = t + 0.2
      local T = HEALTH.tally[D.kind]
      -- the dropped enemy: anyone hurting it while it is left alone
      if not D.others and t - D.t0 <= D.hold then
        local hp = HEALTH.of(D.id)
        if hp and D.hp and hp < D.hp and target ~= D.id then D.others = true; T.others_hurt = T.others_hurt + 1 end
      end
      -- the next enemy it fires at, within 3 s
      if not D.next_done and target ~= 0 and target ~= D.id and t - D.t0 <= 3 then
        local hp = HEALTH.of(target)
        local h0 = D.next_hp[target]
        if hp and not h0 then D.next_hp[target] = hp elseif hp and h0 and hp < h0 then D.next_done = true; T.next_hurt = T.next_hurt + 1 end
      end
      if not D.next_done and t - D.t0 > 3 then D.next_done = true; T.next_none = T.next_none + 1 end
      -- back on the dropped one after its hold: hurt within its wait of firing?
      if target == D.id and t - D.t0 > D.hold * 0.9 and not D.back_done then
        local hp = HEALTH.of(D.id)
        if not D.back_f then D.back_f, D.back_hp = fired, hp; T.back = T.back + 1
        elseif hp and D.back_hp and hp < D.back_hp then D.back_done = true; T.back_hurt = T.back_hurt + 1
        elseif fired - D.back_f >= D.wait then D.back_done = true end
      end
      done = t - D.t0 > 15
    elseif t - D.t0 > 30 then done = true end
    if done then table.remove(L, i) else i = i + 1 end
  end
end

-- W: the shooter's own watch (a table it keeps); fired: how long it has fired at its current target 'id' (counted from
-- when it picked it). Returns how many seconds of firing at 'id' have gone by without its health changing, added up
-- over its turns on that enemy (the Rover's fire spreading leaves an enemy after about 0.6 s and comes back), or nil:
-- not known, or not armed yet. An enemy not fired at for 5 s is forgotten.
function HEALTH.watch(W, id, fired, t, who)
  if HEALTH.off then return nil end
  W.e = W.e or {}
  local e = W.e[id]
  if not e then e = { acc = 0, f = fired, next = 0 }; W.e[id] = e end
  if W.cur ~= id then W.cur = id; e.f = fired end
  e.t = t
  if t - (W.clean or 0) > 2 then
    W.clean = t
    for k, x in pairs(W.e) do if t - x.t > 5 then W.e[k] = nil end end
  end
  if t < e.next then return e.secs end
  e.next = t + 0.1
  local df = math.max(0, fired - e.f)
  e.f = fired
  local hp, mx = HEALTH.of(id)
  if not hp then e.hp, e.acc, e.secs = nil, 0, nil; return nil end
  if e.hp and hp < e.hp and not HEALTH.proven then
    HEALTH.proven = true
    note(string.format('damage check: on (%s\'s target %d went from %d to %d health of %d)', who or '?', id, e.hp, hp, mx))
  end
  -- ((5.1.5 Test 16) when it last hurt it: a sentry finishes the enemy it is hurting before switching by priority)
  if e.hp and hp < e.hp then e.hurt_t = t end
  if not e.hp or hp ~= e.hp then e.hp, e.acc = hp, 0 else e.acc = e.acc + df end
  W.hp, W.mx = hp, mx
  e.secs = HEALTH.proven and e.acc or nil
  return e.secs
end
end
