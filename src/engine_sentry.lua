
-- ======================================================================================================
-- Sentries (4.0): your sentries get the same treatment as the dogs where it fits. They never fire through you or
-- (optionally) your teammates - including while they swing round to their next target - the mortars never pick an
-- enemy standing next to someone, the machine gun and Gatling sentries skip armour they can't hurt, and the
-- targeting laser shows what each one is aiming at. Like the dogs, a sentry is only ever steered by hiding enemies
-- from it (their faction mask in its own perception record) and by asking it to choose again (its selection
-- timer). Nothing else of the sentry is touched, so mods that change how sentries aim or fire keep working.
-- ======================================================================================================
-- (built inside a function of its own: its many helpers would not fit among the main chunk's locals)
local sentry_tick, sentry_restore, sentry_beams, sentry_after = (function()
  local sentry_tick, sentry_restore, sentry_beams, sentry_after
  local SCAN_SECONDS = 2.0          -- the game's list of AI agents is searched for sentries this often, and at once
                                    -- whenever the number of agents changes or one of ours drops out
  local HOLD, BACKOFF, LINGER = 0.25, 1.0, 0.3
  local BUSY_NODE = 10              -- an AI step in which sentries ignore being asked to choose again (test logs)
  -- (5.0) a sentry with 'laser_when_firing' (the Supply FRV's gun, stowed up on the roof until it swings down to
  -- fire, a tester's call) shows its laser only while firing, and this long after its last shot (seconds). (4.5, a
  -- tester's call: only while it fires - 0.6 -> 0.25, just enough to bridge single frames out of its firing step, and
  -- no longer kept on while it stays on the same target or after its target is gone: that looked janky)
  local LASER_FIRING_HOLD = 0.25
  local BEAM_SMOOTH = 0.06           -- seconds: how quickly a sentry's laser end catches up with where it should point
  local FIRE_NODE = 12              -- the AI step in which most sentries fire (the Laser Sentry: its fire_node, 13)
  local AIM_UP = { 0.3, 1.0 }       -- where on an enemy the shots may land (metres above its base)
  local BODY_MID = 0.9              -- the middle of a body (metres above its feet): for explosions
  local MUZZLE_UP = 1.2             -- if the muzzle can't be read: this far above the sentry's base
  -- (turns under 10 degrees are left to the line check: a sentry's barrel wanders a few degrees around its aim
  -- while tracking, and counting that as a turn made the Laser Sentry drop enemies it was already on)
  local SWEEP = { min_deg = 10, reach = 45, both_ways_deg = 170 }
  -- which way the barrel points: known from testing for the machine gun, Gatling and Laser sentries ('barrel_axis');
  -- for other kinds whose turns are checked (the Flame Sentry) it is learned while it fires at enemies in plain view
  -- (the part's axis that tracks its aim point best); until then the turn check waits
  local BARREL = { frames = 30, min_cos = 0.97, tries = 4 }
  -- priority by armour (with armour skipping on): the rocket and autocannon sentries go for armoured (Heavy or more)
  -- enemies first, the machine gun, Gatling and Laser sentries for unarmoured ones. Only enemies in sight within 'reach' metres count, and
  -- an enemy within 'near_you' metres of a helldiver is never pushed back (it is the threat right now).
  local PRIORITY = { reach = 80, near_you = 8, calm = 0.5 }
  -- short bursts (machine gun and Gatling vs Heavy Devastators: their shield eats the ammo): fire this long at one,
  -- then leave it alone this long - the same as the Guard Dog
  local BURST_S = { fire = 1.0, rest = 3.0 }
  -- out of sight: an enemy the sentry has lost sight of is hidden; its current target only once the game's memory of
  -- it has faded to 'grace' (or at once while it is firing). Firing time (bursts, fire spreading) only counts while
  -- the barrel is within ~6 degrees of its aim ('aligned' = cosine)
  -- An enemy the game keeps choosing straight back although it is hidden as out of sight (a Scout Strider, whose own
  -- front plate seems to block the sentry's view of its body) is trusted as in sight for 'trust' seconds instead of
  -- being dropped over and over
  local COVER_S = { grace = 0.6, aligned = 0.995, trust = 5.0 }
  -- enemies still aboard a dropship: within 'reach' m of it sideways, from 'below' m under it to 'above' m over it,
  -- and at least 'above_sentry' m higher than the sentry (so troops it has already set down don't count)
  local DROPSHIP = { reach = 14, below = 12, above = 4, above_sentry = 5 }
  -- self-defence: enemies within 'reach' m of the sentry come before every priority rule (gunships included)
  local SELF = { reach = 8 }
  -- fire spreading (Laser Sentry, like the Rover): its beam sets enemies alight and the burn does most of the damage,
  -- so once one is burning ('fire' seconds of beam, or 'lock' seconds on it without) it moves on to the unlit enemy
  -- nearest you within 'reach'. Enemies it lit in the last 'burn' seconds are left to burn while unlit ones are
  -- about. When everything near is already burning it holds its beam (and its heat) unless a burning enemy is
  -- within 'near_you' metres of a helldiver.
  local SPREAD = { fire = 0.3, lock = 1.0, burn = 3.0, reach = 50, near_you = 10 }
  -- Gunships come before everything else for the Gatling, autocannon, rocket and Laser sentries ('air_first')
  -- (Automaton Gunship; Illuminate Stingray)
  local AIR_FIRST = { [type_hash('282eb766c1ffa6a1')] = true, [type_hash('19e18b46ec55d94a')] = true }
  -- 1 = armoured, 0 = unarmoured; gunships rank above all ('air'). Every sentry has at least Medium penetration, so
  -- for them 'armoured' means Heavy (AV4) or more: Light and Medium enemies count as unarmoured
  local function armour_tier(c, heavy, air)
    if air and c.kind and AIR_FIRST[c.kind] then return heavy and 2 or -1 end
    local a = c.kind and ARMOR[c.kind]
    if a and not a.sentries_skip and a.av >= 4 then return 1 end
    return 0
  end
  -- gunships on the move ('air_still': the rocket sentry, whose slow rockets miss a moving gunship): it only fires at
  -- one that is hovering. Speed comes from how its position changes; above 'start' m/s it is moving, and it counts as
  -- hovering again below 'stop' m/s (or when its position hasn't changed for 'still_after' seconds)
  local AIR_MOVE = { start = 4.0, stop = 2.5, still_after = 0.6 }
  local air_seen = {}   -- enemy id -> { x, y, z, time, speed, moving, frame, first seen }
  local function air_moving(c, t)
    local a = air_seen[c.id]
    -- (one just seen counts as moving until it has been watched for 'still_after' seconds)
    if not a then air_seen[c.id] = { c.pos[1], c.pos[2], c.pos[3], t, 0, false, FRAME, t }; return true end
    if a[7] ~= FRAME then
      a[7] = FRAME
      local d2 = (c.pos[1] - a[1]) ^ 2 + (c.pos[2] - a[2]) ^ 2 + (c.pos[3] - a[3]) ^ 2
      local dt = t - a[4]
      if d2 > 0.0025 and dt >= 0.05 then
        a[5] = a[5] * 0.5 + math.sqrt(d2) / dt * 0.5
        a[1], a[2], a[3], a[4] = c.pos[1], c.pos[2], c.pos[3], t
      elseif dt > AIR_MOVE.still_after then
        a[5] = 0
      end
      if a[6] then a[6] = a[5] >= AIR_MOVE.stop else a[6] = a[5] > AIR_MOVE.start end
    end
    return a[6] or t - a[8] < AIR_MOVE.still_after
  end
  -- overheating (Laser Sentry): stand it down at 'stop' of its heat capacity and let it cool to 'resume'. Its heat
  -- is estimated from how long it has had a target; once the game's own heat meter has been read, that is used, and
  -- then it may run hotter ('stop_measured'). (The share of time it can fire is set by the game's heating and
  -- cooling rates whatever the band; a narrower band just means shorter bursts and shorter pauses. The game warns
  -- at about 80% and burns out at 100%; the estimate assumes the slowest cooling, so it errs on the safe side.)
  -- (measured in game, Test 20-27 logs: it heats ~8.0 degrees a second while firing and cools ~5.05 a second at every
  -- heat level, so it can fire ~39% of the time whatever the band; after a stop it keeps heating for about a second,
  -- ~10 degrees. With the game's meter it runs 90% -> 70% (a tester's choice: short gaps), estimated 70% -> 60%)
  local HEAT = { stop = 0.70, stop_measured = 0.90, resume = 0.60, resume_measured = 0.70, probe_every = 0.25 }
  local sentries = {}               -- by entity id: your sentries out right now
  local type_ai = {}                -- entity type -> AI id, looked up once per kind (to report unknown sentries)
  local barrel = {}                 -- per sentry kind: { axis, sign } once learned, or sums while learning
  local next_scan, pl, pl_until, last_count, last_scan = 0, nil, 0, nil, nil
  -- what we know about a sentry is kept by its entity id for a while after we lose track of it: the game moves a
  -- sentry's records around now and then, and a Laser Sentry must not come back with its heat reset to zero
  -- (that let one burn out: it kept "restarting" cold)
  local remembered = {}              -- id -> { heat, heat_measured, P, t, name }
  local refound_notes = 0
  local not_steered = {}             -- id -> the reason last logged for a sentry that couldn't be steered
  local other_teslas = {}            -- another player's Tesla Towers already noted (4.5)
  local function forget(id, s, why)
    s.spare_ids = nil
    pcall(hider_restore, s.H)
    pcall(tesla_unfilter, s)
    remembered[id] = { heat = s.heat, heat_measured = s.heat_measured, P = s.P, t = os.clock(), name = s.def.name, unit = s.unit, why = why }
    sentries[id] = nil
  end
  local function carry_over(ns, old, t)
    -- (an old record of the same sentry: its heat, cooled down for the time we lost it, and its policy)
    local h = ns.def.heat
    local gone = math.max(0, t - (old.t or t))
    -- (it may have kept firing while we couldn't see it: short gaps are not counted as cooling, and after a longer
    -- gap only the time beyond 5 s counts)
    ns.heat = h and math.max(0, (old.heat or 0) - h.cool * math.max(0, gone - 5)) or 0
    ns.heat_measured = gone < 1 and old.heat_measured or nil
    if old.P then ns.P = old.P; ns.P.hold = nil end
  end
  local noted_events = 0

  local function new_policy() return { unsafe_seen = {}, stuck = {}, sight_ok = {}, rest = {}, lit = {}, ignored = 0 } end
  -- a sentry's identity in its entity row: type, id, unit and the 'ours' flag (the rest of the row changes by itself)
  local function row_key(e) return e:sub(1, 16) .. string.char(bit.band(e:byte(21), 3)) end

  -- ------------------------------------------------------------------ finding your sentries
  local function build(f, targeting, behaviours, perception)
    need(map_lookup(targeting + 336, f.id, 16384) == f.slot, 'sentry targeting slot')
    local bi = map_lookup(behaviours + 64, f.id, 32768)
    if not bi then return nil, 'no AI record yet' end
    need(bi < 16384, 'sentry behaviour index')
    need(rptr(rptr(behaviours + 88, 'behaviour owners') + bi * 8, 'behaviour owner') == f.ptr, 'sentry behaviour owner')
    local rec_addr = rptr(behaviours + 96, 'behaviour records') + bi * A.stride
    local rec = rd(rec_addr, 160, 'sentry behaviour record')
    local ai = u32(rec, 0)
    if f.def.ai and ai ~= f.def.ai and not (f.def.ais and f.def.ais[ai]) then return nil, 'unexpected AI type ' .. ai end
    if u32(rec, 104) ~= f.id then return nil, 'perception owner' end
    local pi = map_lookup(perception + 48, f.id, 32768)
    if not pi then return nil, 'no perception yet' end
    need(pi < 16384, 'sentry perception index')
    need(rptr(rptr(perception + 72, 'perception owners') + pi * 8, 'perception owner') == f.ptr, 'sentry perception owner')
    local s = { def = f.def, id = f.id, unit = f.unit, row = f.row, ptr = f.ptr, ai = ai, rec_addr = rec_addr, bi = bi, pi = pi,
      pbase = rptr(perception + 80, 'perception records') + pi * 5112,
      tstate = rptr(targeting + 376, 'targeting states') + f.slot * 208, slot = f.slot, tstates = rptr(targeting + 376, 'targeting states'),
      H = {}, P = new_policy(), since = os.clock(), heat = 0 }
    -- the muzzle: the weapon's current fire node, a part in the sentry's pose array (optional)
    if A.g.weapons then
      pcall(function()
        local wm = rptr(A.g.weapons, 'weapons')
        local wi = map_lookup(wm + 48, f.id, 32768)
        if not wi or wi >= 16384 then return end
        if rptr(rptr(wm + 72, 'weapon owners') + wi * 8, 'weapon owner') ~= f.ptr then return end
        local wr_addr = rptr(wm + 88, 'weapon runtimes') + wi * 1008
        local wr = rd(wr_addr, 228, 'weapon runtime')
        s.wr_addr = wr_addr
        local count, index = u32(wr, 216), u32(wr, 220)
        if count > 0 and count <= 24 and index < count then
          local n = u32(wr, 120 + 4 * index)
          if n < 1024 then s.node = n end
          -- (the rocket sentry fires from several tubes in turn: the laser starts from their middle)
          s.nodes = {}
          for j = 0, count - 1 do
            local nj = u32(wr, 120 + 4 * j)
            if nj < 1024 then s.nodes[#s.nodes + 1] = nj end
          end
        end
      end)
    end
    -- (Laser Sentry) its heat meter: the game's own record of how hot it is and whether it has overheated
    if A.g.heatbar and f.def.heat then
      pcall(function()
        local hm = rptr(A.g.heatbar, 'heat meter')
        local hi = map_lookup(hm + 0x28, f.id, 32768)
        if hi and hi < 16384 and rptr(rptr(hm + 0x40, 'heat meter owners') + hi * 8, 'heat meter owner') == f.ptr then s.hb_mgr, s.hb_idx = hm, hi end
      end)
    end
    return s
  end

  -- are its records still where we found them? When the game removes an agent it moves the last record of each list
  -- into the freed place, and the old copy stays behind looking just like it (same AI, same owner) but no longer
  -- updated: a Laser Sentry read from such a copy showed 'no target' while it fired itself into overheating. So the
  -- lists' own index is checked every quarter second, and a sentry whose record moved is found again at once.
  local CHECK_EVERY = 0.25
  -- (4.5: the lists' own addresses are looked up once a frame and shared by every sentry's check; after the game's
  -- update, sentry_after, afresh)
  local RC = { frame = -1 }
  local function records_current(s)
    local g = A.g
    if RC.frame ~= FRAME then
      RC.frame = -1
      RC.beh = rptr(g.behaviours, 'behaviours') + 64
      RC.perc = rptr(g.perception, 'perception') + 48
      RC.targ = rptr(g.targeting, 'targeting')
      RC.tstates = rptr(RC.targ + 376, 'targeting states')
      RC.frame = FRAME
    end
    if map_lookup(RC.beh, s.id, 32768) ~= s.bi then return false end
    if map_lookup(RC.perc, s.id, 32768) ~= s.pi then return false end
    if s.hb_mgr and map_lookup(s.hb_mgr + 0x28, s.id, 32768) ~= s.hb_idx then return false end
    -- (5.0) its targeting state too: where it is aiming and whether that is in step with its AI. The Supply FRV's gun
    -- had it move (a Test 15 log: every poll 'not synced', so no laser); the old address then never matched again
    if s.slot and (map_lookup(RC.targ + 336, s.id, 16384) ~= s.slot or RC.tstates ~= s.tstates) then return false end
    return true
  end

  -- (4.5) Tesla Tower: it targets only what the mod has marked as an enemy. Hiding a helldiver's own entry wasn't
  -- enough: the game writes that entry afresh every frame, and test logs showed the tower picking you with your entry
  -- shown (7 times in one mission, once fatally). Taking the helldivers' faction off its list didn't work either: a
  -- Test 29 log showed its list is one faction (0) and helldivers and enemies carry the same bit (1). So its list is
  -- changed to one faction of the mod's own (MARK_ID, the count left as it is), and the entries of enemies in its
  -- list get that bit added to their masks. A helldiver's entry is never marked, so whatever the game writes into it,
  -- the tower can't pick it; if the game writes an enemy's entry afresh, that enemy is only passed over until it is
  -- marked again. The start of its perception record: a count at +0, then one faction id every 8 bytes from +8.
  -- All is put back when the tower is let go (only through records confirmed current: a record the game gave up may
  -- belong to another agent by now)
  local MARK_ID = 30
  local function count_action(k, n) session.actions[k] = (session.actions[k] or 0) + n end
  local MARK = bit.lshift(1, MARK_ID)
  local function pack32(v) return string.char(bit.band(v, 255), bit.band(bit.rshift(v, 8), 255), bit.band(bit.rshift(v, 16), 255), bit.band(bit.rshift(v, 24), 255)) end
  local function tesla_filter(s, st, bodies)
    local perc, P = st.perc, s.P
    if READ_ONLY or not perc then return end
    local n = u32(perc, 0)
    if n == 0 or n > 32 then return end
    -- its list: every place set to the mod's own faction
    local base, changed, rewritten = P.filter_orig, false, false
    if not base then base = {}; for j = 0, n - 1 do base[j] = u32(perc, 8 + j * 8) end end
    for j = 0, n - 1 do
      local now = u32(perc, 8 + j * 8)
      if now ~= MARK_ID then
        if P.filter_orig then rewritten = true end
        P.filter_orig = base
        if write(s.pbase + 8 + j * 8, pack32(MARK_ID)) then changed = true else stats.write_failures = stats.write_failures + 1 end
      end
    end
    if not P.filter_orig then return end
    if changed and not P.factions_noted then
      P.factions_noted = true
      local l = {}; for j = 0, n - 1 do l[#l + 1] = tostring(base[j]) end
      event(string.format('sentry: %s now targets only enemies the mod has marked (its factions %s -> %d)', s.def.name, table.concat(l, ' '), MARK_ID))
    end
    if rewritten then
      P.filter_rewrites = (P.filter_rewrites or 0) + 1
      bump(session.actions, 'tesla_factions_rewritten')
      if P.filter_rewrites <= 5 then event(string.format('sentry: %s had its factions written back by the game: set again (checked every frame from now on)', s.def.name)) end
    end
    -- the enemies in its list marked: only entries of a known enemy type - never a helldiver, nor an entry whose type
    -- can't be read (a helldiver's can read as one for a moment). Hidden ones are marked in what they get back when
    -- they are shown again. Only entries just marked (or all of them, the frame its list is changed) have whether it
    -- may pick them worked out again: the others were read against its list as it is
    local marked = P.marked or {}
    P.marked = marked
    -- (its records moved: the copy carries the marks, at the same places in the new record)
    if P.marked_base and P.marked_base ~= s.pbase then
      local d, moved_marks = s.pbase - P.marked_base, {}
      for addr, m in pairs(marked) do moved_marks[addr + d] = { id = m.id, entry = m.entry + d, before = m.before } end
      marked = moved_marks; P.marked = marked
    end
    P.marked_base = s.pbase
    local lost = 0
    local NOMARK = bit.bnot(MARK)
    for _, c in ipairs(st.candidates) do
      local k = c.kind
      local addr = c.mask_addr
      local h = s.H[addr]
      if h and h.id ~= c.id then h = nil end
      if k and k ~= AVATAR_TYPE then
        local fresh = changed
        if c.mask == BLANK then
          -- (Test 34: never onto an unknown or blank saved mask - a Test 33 log had your entry carry the mark on a blank
          -- mask, 60202020, and the tower pick you 12 times)
          local hb = h and u32(h.before, 0)
          if hb and h.before ~= BLANK and bit.band(hb, 0x20202020) ~= 0x20202020 and bit.band(hb, MARK) == 0 then
            local orig = h.before
            h.before = pack32(bit.bor(hb, MARK))
            marked[addr] = { id = c.id, entry = c.entry, before = orig }
            fresh = true
          end
        else
          local v = u32(c.mask, 0)
          if bit.band(v, MARK) == 0 then
            -- (an entry it had marked, written afresh by the game: counted - if it happens a lot, the tower passes
            -- enemies over)
            local m0 = marked[addr]
            if m0 and m0.id == c.id then lost = lost + 1 end
            local m = pack32(bit.bor(v, MARK))
            if write(addr, m) then
              marked[addr] = { id = c.id, entry = c.entry, before = c.mask }
              c.mask = m
              fresh = true
            else stats.write_failures = stats.write_failures + 1 end
          end
        end
        if fresh then
          -- (a hidden entry with nothing saved for it - hidden by something else - counts as not pickable: a Test 37 review)
          local m = c.mask == BLANK and (h and h.before) or c.mask
          c.eligible = c.alive and bit.band(c.flags or 0, 1) ~= 0 and m and m ~= BLANK and bit.band(u32(m, 0), MARK) ~= 0 and (c.score or 0) > 0 or false
        end
      else
        -- a helldiver's entry, or one whose type can't be read (Test 34: never marked - a helldiver's entry can read as
        -- one for a moment): the mark taken off if it carries it, in its entry and in what it would get back
        if c.mask ~= BLANK and bit.band(u32(c.mask, 0), MARK) ~= 0 then
          local m = pack32(bit.band(u32(c.mask, 0), NOMARK))
          if write(addr, m) then c.mask = m; count_action(k == AVATAR_TYPE and 'tesla_mark_taken_off_helldiver' or 'tesla_mark_taken_off_unknown', 1) else stats.write_failures = stats.write_failures + 1 end
        end
        if h and bit.band(u32(h.before, 0), MARK) ~= 0 then h.before = pack32(bit.band(u32(h.before, 0), NOMARK)) end
        marked[addr] = nil
        c.eligible = false
      end
    end
    if lost > 0 then
      P.marks_lost = (P.marks_lost or 0) + lost
      count_action('tesla_mark_rewritten', lost)
      if not P.lost_noted and P.marks_lost >= 20 then
        P.lost_noted = true
        event(string.format('sentry: %s: the game has written enemies\' entries afresh %d times (each passed over until marked again)', s.def.name, P.marks_lost))
      end
    end
    -- (forget marks on entries now holding something else)
    if (P.mark_clean or 0) <= FRAME then
      P.mark_clean = FRAME + 60
      for addr, m in pairs(marked) do
        local id_now = read(m.entry, 4)
        if not (id_now and u32(id_now, 0) == m.id) then marked[addr] = nil end
      end
    end
    P.filter_on = true
    -- (the helldivers' entries are hidden from it as well, every frame: a Test 32 log had it pick you 25 times with the
    -- marking on, right after its records moved twice. The code that let a tower that is safe by its marking alone off
    -- that - 'faction_safe', Test 25-32 - is gone, a Test 37 review: it can come back once the marking has held in game)
  end
  -- (the list is kept as it was found until it has been written back: if the tower's records can't be confirmed now -
  -- moved, say - the original goes with what is remembered about the tower, for when it is found again). The marks
  -- are taken off the enemies' entries still holding them (after the hidden ones have been shown again)
  local function tesla_unfilter(s)
    local P = s.P
    local o = P and P.filter_orig
    if not o then return end
    if READ_ONLY then return end
    local okc, cur = pcall(records_current, s)
    if okc and cur and not s.moved then
      for j, f in pairs(o) do if not write(s.pbase + 8 + j * 8, pack32(f)) then stats.write_failures = stats.write_failures + 1 end end
      for addr, m in pairs(P.marked or {}) do
        local id_now = read(m.entry, 4)
        local now = id_now and u32(id_now, 0) == m.id and read(addr, 4)
        if now and u32(now, 0) == bit.bor(u32(m.before, 0), MARK) then
          if not write(addr, m.before) then stats.write_failures = stats.write_failures + 1 end
        end
      end
      P.filter_orig, P.filter_on, P.marked, P.marked_base = nil, false, nil, nil
    end
  end

  local function scan(t)
    local g = A.g
    local targeting, behaviours, perception = rptr(g.targeting, 'targeting'), rptr(g.behaviours, 'behaviours'), rptr(g.perception, 'perception')
    local reg = rd(targeting + 308, 84, 'targeting registry')
    local tn, ta = u32(reg, 0), u32(reg, 12)
    need(ta <= tn and tn <= 8192, 'targeting registry')
    last_count = ta
    local ptrs = ta > 0 and rd(rptr(targeting + 360, 'targeting entities'), 8 * ta, 'targeting entities') or ''
    local seen, others = {}, 0
    for i = 0, ta - 1 do
      local p = ptr_of(ptrs, i * 8)
      local e = p and read(p, 24)
      if e then
        local ty = e:sub(1, 8)
        local def = SENTRY_BY_TYPE[ty]
        -- (the Tesla Tower is left to the game when the Sentries option is set to leave it out: it is simply not taken
        -- on, like another player's sentry)
        local skip = def and def.spares_helldivers and not OPT.tesla()
        if def and not skip then
          if is_local(e) then
            local id = u32(e, 8)
            seen[id] = true
            local s = sentries[id]
            if not (s and s.row == row_key(e) and s.ptr == p and not s.moved) then
              local ok, ns, why = pcall(build, { def = def, ptr = p, row = row_key(e), id = id, unit = u32(e, 12), slot = i }, targeting, behaviours, perception)
              if ok and ns then
                -- (the enemies hidden from it stay hidden if its perception record is the same one; otherwise they are
                -- put back and hidden again in its new record)
                if s and s.pbase == ns.pbase then ns.H = s.H elseif s then pcall(hider_restore, s.H) end
                sentries[id] = ns
                local d = session.sentries[def.name] or { placed = 0, out = 0, targeted = 0, stops = 0, mate_stops = 0, armour = 0 }
                session.sentries[def.name] = d
                local old = s and { heat = s.heat, heat_measured = s.heat_measured, P = s.P, t = t } or (remembered[id] and remembered[id].name == def.name and remembered[id].unit == u32(e, 12) and remembered[id])
                if old then
                  carry_over(ns, old, t)
                  if TESTER and refound_notes < 10 then
                    refound_notes = refound_notes + 1
                    event(string.format('sentry: %s found again (%s; heat kept at %.0f%%)', def.name,
                      s and (s.moved and 'its AI records moved' or s.ptr ~= p and 'its record moved' or 'its record changed') or ('lost for ' .. string.format('%.1fs', t - old.t) .. ', ' .. tostring(old.why)),
                      def.heat and 100 * ns.heat / def.heat.cap or 0))
                  end
                else
                  d.placed = d.placed + 1
                  event(string.format('sentry: %s out (AI %d%s)', def.name, ns.ai, ns.node and (', muzzle part ' .. ns.node) or ', muzzle not found: using its position'))
                end
                remembered[id] = nil
              else
                local why2 = ok and why or (type(ns) == 'table' and tostring(ns[2]) or tostring(ns))
                if s then forget(id, s, why2) end   -- (keeps its heat for when it is set up again)
                -- (once per sentry and reason: a sentry that can't be steered is tried again at every scan)
                if not (s and s.why == why2) and not remembered[id] and not_steered[id] ~= why2 then
                  not_steered[id] = why2
                  event(string.format('sentry: %s not steered (%s)', def.name, why2))
                end
              end
            end
          else
            others = others + 1
            -- (4.5) another player's Tesla Tower: their game runs it, so this mod can't keep it off helldivers - noted
            -- once each, so a zap from one can be told apart from one by yours
            if def.spares_helldivers then
              local id = u32(e, 8)
              if not other_teslas[id] then other_teslas[id] = true; event('sentry: another player\'s Tesla Tower is out (run by their game: not steered by this mod)') end
            end
          end
        elseif not def and is_local(e) and type_ai[ty] == nil then
          -- the first time a kind of agent shows up on your side: note it if it runs a sentry's AI but isn't known
          -- (that is how the Armed Resupply Pod's and the Supply FRV's guns were found, 4.0.6 Test 8)
          type_ai[ty] = false
          pcall(function()
            local bi = map_lookup(behaviours + 64, u32(e, 8), 32768)
            if not bi or bi >= 16384 then return end
            local ai = u32(rd(rptr(behaviours + 96, 'behaviour records') + bi * A.stride, 4, 'behaviour record'), 0)
            type_ai[ty] = ai
            if SENTRY_AI[ai] then event(string.format('unknown sentry-like agent on your side: type %s, AI %d (not steered)', hexr(ty), ai)) end
          end)
        end
      end
    end
    for id, s in pairs(sentries) do
      if not seen[id] then forget(id, s, 'not in the list') end
    end
    for id, r in pairs(remembered) do if t - r.t > 120 then remembered[id] = nil end end
    for id, a in pairs(air_seen) do if FRAME - a[7] > 600 then air_seen[id] = nil end end
    if others > session.other_sentries then session.other_sentries = others end
  end

  -- ------------------------------------------------------------------ reading one sentry
  local function norm(v) local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3]); if l < 1e-6 then return nil end return { v[1] / l, v[2] / l, v[3] / l }, l end
  local function finite3(x, y, z) return x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6 end

  local function read_sentry(s, registry)
    local e = read(s.ptr, 24)
    if not e or row_key(e) ~= s.row then return nil, 'gone' end
    local rec = read(s.rec_addr, 160)
    if not (rec and u32(rec, 0) == s.ai and u32(rec, 104) == s.id) then return nil, 'gone' end
    local base = unit_position(s.unit)
    if not base then return nil, 'no position' end
    local muzzle, axes
    if s.node and base.pose then
      local m = read(base.pose + 64 * s.node, 64)
      if m then
        local x, y, z = f32(m, 48), f32(m, 52), f32(m, 56)
        if finite3(x, y, z) and (x - base[1]) ^ 2 + (y - base[2]) ^ 2 + (z - base[3]) ^ 2 < 16 then
          muzzle, axes = { x, y, z }, {}
          for r = 0, 2 do
            local a = norm({ f32(m, r * 16), f32(m, r * 16 + 4), f32(m, r * 16 + 8) })
            if not a then axes = nil; break end
            axes[r + 1] = a
          end
        end
      end
    end
    -- the middle of all its fire points (several tubes or barrels): where the laser starts
    local centre = muzzle
    if muzzle and s.nodes and #s.nodes > 1 and laser_wanted() then
      local sx, sy, sz, n = 0, 0, 0, 0
      for _, nd in ipairs(s.nodes) do
        local m = read(base.pose + 64 * nd, 64)
        local x, y, z = m and f32(m, 48), m and f32(m, 52), m and f32(m, 56)
        if m and finite3(x, y, z) and (x - base[1]) ^ 2 + (y - base[2]) ^ 2 + (z - base[3]) ^ 2 < 16 then sx, sy, sz, n = sx + x, sy + y, sz + z, n + 1 end
      end
      if n > 0 then centre = { sx / n, sy / n, sz / n } end
    end
    local st = { base = base, muzzle = muzzle or { base[1], base[2], base[3] + (s.def.muzzle_up or MUZZLE_UP) }, axes = axes, has_muzzle = muzzle ~= nil }
    st.centre = centre or st.muzzle
    st.candidates, st.perc = read_candidates(s.pbase, st.muzzle, registry)
    st.target, st.node, st.rec_head = u32(rec, 24), u32(rec, 8), rec:sub(1, 4)
    st.deadline = u64(rec, 152)
    local ts = st.target ~= 0 and read(s.tstate, 32) or nil
    st.synced = st.target ~= 0 and ts ~= nil and u32(ts, 0) == st.target and rec:byte(121) == 1 and bit.band(u32(rec, 96), 1) ~= 0
    if st.synced then
      local x, y, z = f32(ts, 20), f32(ts, 24), f32(ts, 28)     -- where it is actually aiming (with lead)
      if finite3(x, y, z) and (x ~= 0 or y ~= 0 or z ~= 0) then st.aim = { x, y, z } end
    end
    for _, c in ipairs(st.candidates) do if c.id == st.target then st.current = c end end
    return st
  end

  -- which axis of the muzzle part is the barrel (per sentry kind, learned while it fires at enemies in view). (4.5)
  -- Decided only once it has aimed at least 30 degrees apart: aimed one way only, an axis that happens to point that
  -- way matches just as well as the barrel
  local BARREL_SPREAD = 0.87
  local function barrel_dir(s, st)
    local b = barrel[s.def.name]
    if not b then b = { sums = {}, n = 0, tries = 0 }; barrel[s.def.name] = b end
    if not st.axes then return nil end
    -- (kinds whose barrel axis is already known from testing don't need to learn it: axis 2+ for the machine gun,
    -- Gatling and Laser sentries and the pod and FRV guns; a Laser Sentry swung between targets a lot once failed to
    -- learn it, 0.905)
    if not b.axis and s.def.barrel_axis then b.axis, b.sign = s.def.barrel_axis, 1 end
    if b.axis then local a = st.axes[b.axis]; return { a[1] * b.sign, a[2] * b.sign, a[3] * b.sign } end
    if b.tries >= BARREL.tries or not s.def.sweep then return nil end   -- (only sentries whose turns are checked need it)
    local c = st.current
    if st.synced and st.aim and c and c.visible then
      local v, len = norm({ st.aim[1] - st.muzzle[1], st.aim[2] - st.muzzle[2], st.aim[3] - st.muzzle[3] })
      -- (only while its aim is steady: while it swings round, the barrel lags the aim)
      local p = s.last_aim_dir
      s.last_aim_dir = v
      if v and len > 5 and p and v[1] * p[1] + v[2] * p[2] + v[3] * p[3] > 0.9995 then
        for r = 1, 3 do
          local cos = dot3(st.axes[r], v)
          b.sums[2 * r - 1] = (b.sums[2 * r - 1] or 0) + cos
          b.sums[2 * r] = (b.sums[2 * r] or 0) - cos
        end
        b.n = b.n + 1
        if not b.d0 then b.d0 = v end
        b.spread = math.min(b.spread or 1, dot3(b.d0, v))
        if b.n >= BARREL.frames and b.spread <= BARREL_SPREAD then
          local best, bk
          for k, sum in pairs(b.sums) do if not best or sum > best then best, bk = sum, k end end
          b.tries = b.tries + 1
          local mean = best / b.n
          if mean >= BARREL.min_cos then
            b.axis, b.sign = math.floor((bk + 1) / 2), bk % 2 == 1 and 1 or -1
            note(string.format('%s: barrel found (axis %d%s, match %.3f)', s.def.name, b.axis, b.sign > 0 and '+' or '-', mean))
          elseif b.tries >= BARREL.tries then
            note(string.format('%s: barrel not found (best match %.3f); its turns are not checked', s.def.name, mean))
          end
          b.sums, b.n, b.d0, b.spread = {}, 0, nil, nil
        end
      end
    end
    return nil
  end

  -- ------------------------------------------------------------------ who must not be hit
  local function bodies_for(me, mates)
    local out = {}
    local function body(p, extra, mate)
      out[#out + 1] = { lo = { p[1], p[2], p[3] + SAFE.body_bottom }, hi = { p[1], p[2], p[3] + SAFE.body_top }, at = p, extra = extra, mate = mate }
    end
    if me and OPT.safety() then body(me, 0, false) end   -- (you: with the Safety option on)
    for _, m in ipairs(mates or {}) do
      body(m, TEAM.margin, true)
      local v = m.vel
      if v and v[1] * v[1] + v[2] * v[2] > 1 then body({ m[1] + v[1] * TEAM.lead, m[2] + v[2] * TEAM.lead, m[3] + v[3] * TEAM.lead }, TEAM.margin, true); out[#out].lead = true end
    end
    return out
  end

  -- does turning the barrel from 'f' onto 'aim' carry its line over the body? (the turn follows the shortest way
  -- round; when the enemy is almost straight behind it, either way is possible and the whole height band counts)
  local function sweep_hits(M, f, aim, b, def)
    local d, L = norm({ aim[1] - M[1], aim[2] - M[2], aim[3] - M[3] })
    if not d then return false end
    local T = math.acos(math.max(-1, math.min(1, dot3(f, d))))
    if T < math.rad(SWEEP.min_deg) then return false end
    local both = T > math.rad(SWEEP.both_ways_deg)
    local n = not both and norm({ f[2] * d[3] - f[3] * d[2], f[3] * d[1] - f[1] * d[3], f[1] * d[2] - f[2] * d[1] })
    if not both and not n then return false end
    for _, z in ipairs({ b.lo[3], (b.lo[3] + b.hi[3]) / 2, b.hi[3] }) do
      local v, r = norm({ b.at[1] - M[1], b.at[2] - M[2], z - M[3] })
      if v and r > 0.3 and r < L + 1 and r < SWEEP.reach then
        local alpha = math.atan((def.line + def.spread * r + b.extra) / r)
        local off
        if both then
          local ev, ef, ed = math.asin(v[3]), math.asin(math.max(-1, math.min(1, f[3]))), math.asin(d[3])
          off = (ev >= math.min(ef, ed) - alpha and ev <= math.max(ef, ed) + alpha) and 0 or math.huge
        else
          local s = dot3(v, n)
          local vp = norm({ v[1] - n[1] * s, v[2] - n[2] * s, v[3] - n[3] * s })
          if not vp then off = math.pi / 2
          else
            local a1 = math.acos(math.max(-1, math.min(1, dot3(f, vp))))
            local a2 = math.acos(math.max(-1, math.min(1, dot3(vp, d))))
            if math.abs(a1 + a2 - T) < 1e-3 then off = math.asin(math.min(1, math.abs(s)))
            else off = math.min(math.acos(math.max(-1, math.min(1, dot3(v, f)))), math.acos(math.max(-1, math.min(1, dot3(v, d))))) end
          end
        end
        if off < alpha then return true end
      end
    end
    return false
  end

  -- (5.0 test builds) where a helldiver is relative to a vehicle's gun: position in the vehicle's own axes (from the
  -- vehicle's centre; which axis is forward isn't known yet), the muzzle's height above their feet and, for a shot
  -- line, how high above their feet it passes them and how far from the muzzle. To tell the driver's seat, the other
  -- seats (people lean out of the windows to shoot) and people standing next to it apart before the safety treats
  -- riders differently. Up to 25 safety stops, and a sample every 3 s while someone is within 6 m (up to 25)
  local function rider_note(s, st, a, M, p, what)
    local V = unit_position(s.unit, true)
    local ax = V and V.axes
    local rel = { a[1] - st.base[1], a[2] - st.base[2], a[3] - st.base[3] }
    local loc = ax and string.format('%.2f %.2f %.2f', rel[1] * ax[1][1] + rel[2] * ax[1][2] + rel[3] * ax[1][3],
      rel[1] * ax[2][1] + rel[2] * ax[2][2] + rel[3] * ax[2][3], rel[1] * ax[3][1] + rel[2] * ax[3][2] + rel[3] * ax[3][3]) or '?'
    local line = ''
    if p then
      local h = math.sqrt((a[1] - M[1]) ^ 2 + (a[2] - M[2]) ^ 2)
      local H = math.sqrt((p[1] - M[1]) ^ 2 + (p[2] - M[2]) ^ 2)
      if H > 0.1 then line = string.format(', line passes %.2f m above your feet %.1f m from the muzzle', M[3] + (p[3] + AIM_UP[2] - M[3]) * math.min(1, h / H) - a[3], h) end
    end
    note(string.format('rider (test) at %.0fs: %s: %s; you in its axes %s (level %.1f m from its centre), muzzle %.2f m above your feet%s',
      os.clock() - T0, s.def.name, what, loc, math.sqrt(rel[1] ^ 2 + rel[2] ^ 2), M[3] - a[3], line))
  end

  -- (5.0) someone sitting in the Supply FRV: its gun can't hit them (a tester's check in game) - only a passenger
  -- aiming out of a window, whose head, arms and gun are then outside the cab. Seats measured in game (Test 10
  -- riders log, in the FRV's own axes: side, fore-aft, up from its centre): the front pair at (+-0.36, -1.51, -1.08),
  -- the back pair at (+-0.36, -0.70, -1.08); getting out showed (-1.76, ..., -1.45). Anyone inside that box is a
  -- rider. A rider counts as aiming out when any part of their body (the parts of their unit's pose) is more than
  -- 'window' metres to the side of the FRV's centre on their side (the seats are 0.36 m out; the value is a first
  -- guess, the test builds log each rider's reach to tune it). Seated: left out of this gun's safety altogether.
  -- Aiming out: their usual body, plus one around the parts outside the cab. Anyone outside the box: as always
  -- (4.5, a tester: the safety still stopped the gun now and then while he sat in it. Seated reaches of up to 0.93 m
  -- were logged, aiming out 1.44 m and more: 'window' 0.95 -> 1.15. And the driver - the front seat on the +x side,
  -- where a tester always sat driving alone - can't aim out of the window at all: always seated)
  local RIDE = { side = 0.9, fore = { -2.3, 0.1 }, up = { -1.4, -0.7 }, window = 1.15, parts = 96, driver_fore = -1.1 }
  -- how far (metres, sideways from the FRV's centre, on the seat's side) the rider's body reaches, and the parts that
  -- stick out of the cab (a vertical segment around them), or nil if their pose can't be read
  local function reach_out(a, V, ax, side_sign)
    local pose = a.pose
    if not pose and a.unit then local q = unit_position(a.unit); pose = q and q.pose end
    if not pose then return nil end
    local n, m = RIDE.parts, nil
    while n >= 16 and not m do m = read(pose, 64 * n); if not m then n = n - 32 end end
    if not m then return nil end
    local best, lo, hi, sx, sy, k = -99, nil, nil, 0, 0, 0
    for i = 0, n - 1 do
      local x, y, z = f32(m, 64 * i + 48), f32(m, 64 * i + 52), f32(m, 64 * i + 56)
      if x == x and y == y and z == z and (x - a[1]) ^ 2 + (y - a[2]) ^ 2 + (z - a[3]) ^ 2 < 2.5 ^ 2 then
        local r1, r2, r3 = x - V[1], y - V[2], z - V[3]
        local sd = (r1 * ax[1][1] + r2 * ax[1][2] + r3 * ax[1][3]) * side_sign
        if sd > best then best = sd end
        if sd > RIDE.window then
          lo, hi = math.min(lo or z, z), math.max(hi or z, z)
          sx, sy, k = sx + x, sy + y, k + 1
        end
      end
    end
    if best == -99 then return nil end
    local outside = k > 0 and { lo = { sx / k, sy / k, lo - 0.1 }, hi = { sx / k, sy / k, hi + 0.1 }, at = { sx / k, sy / k, lo - 0.1 }, extra = 0 } or nil
    return best, outside
  end
  local function riders(s, st, bodies, def)
    -- (nobody within 3 m of it, level: nothing to work out, and the FRV's axes aren't read)
    local B, near = st.base, false
    for _, b in ipairs(bodies) do
      local a = b.at
      if (a[1] - B[1]) ^ 2 + (a[2] - B[2]) ^ 2 < 9 then near = true; break end
    end
    if not near then return bodies end
    local V = unit_position(s.unit, true)
    local ax = V and V.axes
    if not ax then return bodies end
    local out, changed, last = {}, false, nil
    for _, b in ipairs(bodies) do
      local a = b.at
      local r1, r2, r3 = a[1] - V[1], a[2] - V[2], a[3] - V[3]
      local x = r1 * ax[1][1] + r2 * ax[1][2] + r3 * ax[1][3]
      local y = r1 * ax[2][1] + r2 * ax[2][2] + r3 * ax[2][3]
      local z = r1 * ax[3][1] + r2 * ax[3][2] + r3 * ax[3][3]
      local seated = math.abs(x) <= RIDE.side and y >= RIDE.fore[1] and y <= RIDE.fore[2] and z >= RIDE.up[1] and z <= RIDE.up[2]
      if b.lead then
        -- (a moving teammate's look-ahead body: while they ride, they are where the FRV is)
        if last == 'seated' then changed = true
        elseif last == 'leaning' then changed = true; out[#out + 1] = out[#out]
        else out[#out + 1] = b end
      elseif seated then
        changed = true
        -- (how far a seated rider reaches is read at most every 0.1 s; someone aiming out is read every frame, so
        -- the body parts outside the cab follow them)
        s.reach_seen = s.reach_seen or {}
        local key = a.pose or a.unit or 0
        local seen = s.reach_seen[key]
        local reach, outside
        if x > 0 and y < RIDE.driver_fore then reach = nil   -- (the driver: never read, see below)
        elseif seen and seen.t > os.clock() - 0.1 and seen.reach <= RIDE.window then reach = seen.reach
        else
          reach, outside = reach_out(a, V, ax, x < 0 and -1 or 1)
          if reach then
            if not s.reach_seen[key] then
              s.reach_n = (s.reach_n or 0) + 1
              if s.reach_n > 32 then s.reach_seen, s.reach_n = {}, 1 end   -- (old riders' entries don't pile up)
            end
            s.reach_seen[key] = { t = os.clock(), reach = reach }
          end
        end
        a.reach = reach
        -- (a pose that can't be read: treated as aiming out, the safe side; the driver is always seated)
        local driver = x > 0 and y < RIDE.driver_fore
        if driver or (reach and reach <= RIDE.window) then a.ride, last = driver and 'driving' or 'seated', 'seated'
        else
          a.ride, last = 'aiming out', 'leaning'
          out[#out + 1] = b
          if outside then outside.mate = b.mate; out[#out + 1] = outside end
        end
      else
        out[#out + 1] = b; last = nil
      end
    end
    return changed and out or bodies
  end

  -- enemies this sentry must not shoot right now (id -> true), why, and how close each came (for the linger rule)
  local AIM_LO, AIM_HI = { 0, 0, 0 }, { 0, 0, 0 }
  local function unsafe_for(s, st, bodies)
    local U, why, gap = {}, {}, {}
    local def, M, fwd = s.def, st.muzzle, st.fwd
    local all = bodies
    if def.vehicle then bodies = riders(s, st, bodies, def) end
    if TESTER and def.vehicle and (s.rider_samples or 0) < 25 and os.clock() >= (s.rider_next or 0) then
      for _, b in ipairs(all) do
        local a = b.at
        if (a[1] - st.base[1]) ^ 2 + (a[2] - st.base[2]) ^ 2 < 36 then
          s.rider_samples, s.rider_next = (s.rider_samples or 0) + 1, os.clock() + 3
          pcall(rider_note, s, st, a, M, nil, (b.mate and 'a teammate nearby' or 'you nearby') .. (a.ride and (' (' .. a.ride .. (a.reach and string.format(', reaching %.2f m out', a.reach) or '') .. ')') or ''))
          session.dirty = true
          break
        end
      end
    end
    for _, c in ipairs(st.candidates) do
      local p = c.pos
      -- (only enemies it could pick: ones its own scoring rates 0 are skipped, which saves most of the work)
      if p and (c.eligible or c.mask == BLANK or c.id == st.target) then
        local closest, reason = math.huge, nil
        local dM = math.sqrt((p[1] - M[1]) ^ 2 + (p[2] - M[2]) ^ 2 + (p[3] - M[3]) ^ 2)
        for _, b in ipairs(bodies) do
          local who = b.mate and 'a teammate' or 'you'
          local a = b.at
          local near = math.sqrt((a[1] - p[1]) ^ 2 + (a[2] - p[2]) ^ 2 + (a[3] + BODY_MID - p[3]) ^ 2) - b.extra
          if def.blast then
            local m = near - def.blast
            if m < closest then closest = m end
            if m < 0 then reason = reason or (who == 'you' and 'you would be inside the blast' or 'a teammate would be inside the blast') end
          else
            local dB = math.sqrt((a[1] - M[1]) ^ 2 + (a[2] - M[2]) ^ 2 + (a[3] + BODY_MID - M[3]) ^ 2)
            if dB < dM + 3 then
              local r = def.line + def.spread * dB + b.extra
              -- (the two heights its shots may land at, and its actual aim point: reused scratch points, no new tables)
              AIM_LO[1], AIM_LO[2], AIM_LO[3] = p[1], p[2], p[3] + AIM_UP[1]
              AIM_HI[1], AIM_HI[2], AIM_HI[3] = p[1], p[2], p[3] + AIM_UP[2]
              local m = math.min(segment_distance(M, AIM_LO, b.lo, b.hi), segment_distance(M, AIM_HI, b.lo, b.hi))
              if c.id == st.target and st.aim then m = math.min(m, segment_distance(M, st.aim, b.lo, b.hi)) end
              m = m - r
              if m < closest then closest = m end
              if closest < 0 then reason = reason or (who == 'you' and 'you are in its line of fire' or 'a teammate is in its line of fire') end
            end
            if def.splash and near < def.splash then
              closest = math.min(closest, near - def.splash)
              reason = reason or (who == 'you' and 'you would be caught in the explosion' or 'a teammate would be caught in the explosion')
            end
            -- (a sentry with a firing step - the Laser Sentry - only sweeps its beam across someone while it is firing:
            -- while it turns onto a target with the beam off it can't hit anyone)
            if def.sweep and fwd and not reason and dB < dM + 1 and (not def.fire_node or st.node == def.fire_node) then
              local q = (c.id == st.target and st.aim) or AIM_HI
              if q == AIM_HI then AIM_HI[1], AIM_HI[2], AIM_HI[3] = p[1], p[2], p[3] + AIM_UP[2] end
              if sweep_hits(M, fwd, q, b, def) then
                closest = math.min(closest, 0)
                reason = who == 'you' and 'it would swing its fire across you' or 'it would swing its fire across a teammate'
              end
            end
          end
          if reason then
            if TESTER and def.vehicle and (s.rider_stops or 0) < 25 and os.clock() >= (s.rider_stop_next or 0) then
              s.rider_stops, s.rider_stop_next = (s.rider_stops or 0) + 1, os.clock() + 1   -- (one a second at most)
              session.dirty = true
              pcall(rider_note, s, st, a, M, p, reason .. (a.ride and (' (' .. a.ride .. (a.reach and string.format(', reaching %.2f m out', a.reach) or '') .. ')') or ''))
            end
            break
          end
        end
        gap[c.id] = closest
        if reason then U[c.id] = true; why[c.id] = reason end
      end
    end
    return U, why, gap
  end

  -- ------------------------------------------------------------------ overheating (Laser Sentry)
  -- the heat meter record: +4 = heat so far, +8 = overheated. Its unit is learned: degrees (it rises about as fast
  -- as the wiki's rate) or a share of the capacity; the capacity is taken from the value at which it overheats.
  local meter = {}   -- per sentry kind: { scale = capacity in the meter's unit }
  local function meter_read(s)
    if not s.hb_mgr then return nil end
    local owners = ptr_of(read(s.hb_mgr + 0x40, 8), 0)
    local own = owners and ptr_of(read(owners + s.hb_idx * 8, 8), 0)
    if own ~= s.ptr then return nil end
    local arr = ptr_of(read(s.hb_mgr + 0x58, 8), 0)
    local r = arr and read(arr + s.hb_idx * 12, 12)
    if not r then return nil end
    local v = f32(r, 4)
    if v ~= v or v < 0 or v > 100000 then return nil end
    return v, r:byte(9) ~= 0
  end
  local function heat_probe(s, st, t)
    local def = s.def
    if s.hb_mgr then
      if t < (s.probe_next or 0) then return end
      s.probe_next = t + HEAT.probe_every
      local v, over = meter_read(s)
      if not v then return end
      local m = meter[def.name] or {}
      meter[def.name] = m
      -- the unit: from how fast it climbs while firing
      if not m.scale then
        local p = s.meter_prev
        if p and st.target ~= 0 and p.target ~= 0 and t > p.t and v > p.v then
          local r = (v - p.v) / (t - p.t)
          m.n, m.sum = (m.n or 0) + 1, (m.sum or 0) + r
          if m.n >= 8 then
            local rate = m.sum / m.n
            if rate > 2 and rate < 40 then m.scale = def.heat.cap elseif rate > 0.008 and rate < 0.16 then m.scale = 1 end
            if m.scale then note(string.format('%s: heat meter read (%s, rising %.3g a second while firing)', def.name, m.scale == 1 and 'share of capacity' or 'degrees', rate)) end
          end
        end
        s.meter_prev = { v = v, t = t, target = st.target }
      end
      -- it overheated: the meter's value now is its true capacity
      if over and not s.was_over then
        m.scale = math.max(v, 1e-6)
        event(string.format('%s OVERHEATED (heat meter %.3g; the mod had it at %.0f%%)', def.name, v, 100 * (s.heat_measured or (s.heat / def.heat.cap))))
      end
      s.was_over = over
      if m.scale then s.heat_measured = v / m.scale end
      if TESTER and t >= (s.sample_next or 0) and (s.samples or 0) < 45 then
        s.sample_next, s.samples = t + 2, (s.samples or 0) + 1
        event(string.format('heat sample: %s meter %.3g%s, estimate %.0f%%, %s, AI step %d', def.name, v, over and ' OVERHEATED' or '',
          100 * s.heat / def.heat.cap, st.target ~= 0 and 'on a target' or 'no target', st.node))
      end
      return
    end
  end
  local function heat_update(s, st, t, dt)
    local h = s.def.heat
    if not h then return end
    if st.target ~= 0 then s.heat = math.min(h.cap, s.heat + h.rate * dt) else s.heat = math.max(0, s.heat - h.cool * dt) end
    pcall(heat_probe, s, st, t)
    st.heat = s.heat_measured or (s.heat / h.cap)
    st.heat_from = s.heat_measured and 'measured' or 'estimated'
  end

  -- ------------------------------------------------------------------ deciding and steering
  -- (helpers for plan_sentry, built once rather than every frame)
  local NONE = {}   -- an empty set shared by every set nothing was put in (never written to: see 'put')
  local function put(set, id) if set == NONE then set = {} end set[id] = true; return set end
  -- could the sentry pick it (its own scoring doesn't rate it 0), is it in play, and is it fair game right now
  local function pickable(c, st) return c.eligible or c.mask == BLANK or c.id == st.target end
  local function in_play(c, st) return c.alive or c.mask == BLANK or c.id == st.target end
  local function open(c) return c.eligible or (c.mask == BLANK and c.alive and (c.score or 0) > 0) end
  local function near_body(bodies, p, r2)
    if not p then return false end
    for _, b in ipairs(bodies) do
      if (b.at[1] - p[1]) ^ 2 + (b.at[2] - p[2]) ^ 2 + (b.at[3] - p[3]) ^ 2 < r2 then return true end
    end
    return false
  end
  local function near_sentry(s, st, c)
    return not s.def.blast and c.pos and (c.pos[1] - st.base[1]) ^ 2 + (c.pos[2] - st.base[2]) ^ 2 + (c.pos[3] - st.base[3]) ^ 2 < SELF.reach ^ 2
  end
  -- (test builds) other entries within 3 m of an enemy the sentry kept: parts or a pilot the game may be choosing it
  -- through (a Scout Strider was chosen again and again while hidden)
  local function near_note(st, c)
    if not (c and c.pos) then return '' end
    local out = {}
    for _, x in ipairs(st.candidates) do
      if x ~= c and x.pos and #out < 4 and (x.pos[1] - c.pos[1]) ^ 2 + (x.pos[2] - c.pos[2]) ^ 2 + (x.pos[3] - c.pos[3]) ^ 2 < 9 then
        out[#out + 1] = string.format('%d %s %s%s', x.id, x.kind and hexr(x.kind) or '-', x.mask == BLANK and 'hidden' or 'shown', x.visible and ' in sight' or '')
      end
    end
    return #out > 0 and ('; next to it: ' .. table.concat(out, ', ')) or ''
  end
  -- ask it to drop its target (with the hold and back-off rules)
  local function kick(s, st, t, hide, block, reason)
    local P = s.P
    if st.target ~= 0 and P.kicked == st.target then P.ignored = P.ignored + 1 else P.kicked, P.ignored = st.target, 0 end
    if TESTER and st.target ~= 0 and P.ignored > 0 and (P.ignore_notes or 0) < 12 then
      -- (test builds: why a sentry kept an enemy it was asked to drop)
      P.ignore_notes = (P.ignore_notes or 0) + 1
      local c = st.current
      local now = u64(rd(rptr(A.g.clock, 'clock') + 24, 8, 'clock'), 0)
      event(string.format('sentry kept its target: %s target %d (%s) AI step %d, its mask %s, timer %.2fs, %s', s.def.name, st.target,
        c and c.kind and hexr(c.kind) or '?', st.node, c and (c.mask == BLANK and 'hidden' or 'shown') or 'not listed',
        (st.deadline - now) / 1e6, reason) .. near_note(st, c))
    end
    if P.ignored >= 2 then
      P.kicked, P.ignored = nil, 0
      if reason == 'sentry_cannot_hurt' then P.stuck[st.target] = true; return { block = hide, kick = false, reason = reason } end
      if reason == 'sentry_out_of_sight' then
        -- (the game can see it after all: let it keep this one, shown again, for a while)
        P.sight_ok[st.target] = t + COVER_S.trust
        bump(session.actions, 'sentry_sight_trusted')
        local keep = {}
        for id in pairs(hide) do if id ~= st.target then keep[id] = true end end
        return { block = keep, kick = false, reason = reason }
      end
      P.hold = { target = st.target, block = block, until_t = t + BACKOFF, reason = reason }
      bump(session.actions, 'sentry_backing_off')
      return { block = union(block, hide), kick = false, reason = reason }
    end
    P.hold = { target = st.target, block = block, until_t = t + HOLD, reason = reason }
    P.last_kick_t = t
    if reason == 'sentry_safety' then P.safety_t, P.safety_enemy = t, st.target end
    return { block = union(block, hide), kick = true, reason = reason }
  end

  -- bodies: who must not be hit (follows the Safety option); people: where the helldivers are, you always included
  -- (for the rules about enemies near a helldiver: priority and fire spreading)
  local function plan_sentry(s, st, bodies, t, people)
    local P, def, cands, target = s.P, s.def, st.candidates, st.target
    local armour_on = rawget(_G, 'SmarterGuardDogsArmor') == true   -- (Armor Intelligence: skipping, bursts, dropships)
    local prio_on = OPT.priority()                                   -- (Target Prioritization: gunships, armor tiers, self-defence)
    -- (test builds: which kinds of enemy each sentry goes for, by type id, for bug reports)
    if TESTER and target ~= P.seen_target then
      P.seen_target = target
      local c = st.current
      if c and c.kind then
        local a = ARMOR[c.kind]
        bump(session.sentry_types, def.name .. ': ' .. hexr(c.kind) .. ((a and (' ' .. a.name .. ' AV' .. a.av)) or (LABELS[c.kind] and (' ' .. LABELS[c.kind])) or ''))
      end
    end
    -- (enemies it could not be steered off: forgotten once they are gone from its list)
    if t >= (P.stuck_clean or 0) and next(P.stuck) then
      P.stuck_clean = t + 2
      local listed = {}
      for _, c in ipairs(cands) do listed[c.id] = true end
      for id in pairs(P.stuck) do if not listed[id] then P.stuck[id] = nil end end
    end
    local U_now, why, gap = unsafe_for(s, st, bodies)
    st.unsafe_why, st.gap = why, gap
    for id in pairs(U_now) do P.unsafe_seen[id] = t end
    for id, seen in pairs(P.unsafe_seen) do if t - seen >= LINGER then P.unsafe_seen[id] = nil end end
    for id, until_t in pairs(P.sight_ok) do if t >= until_t then P.sight_ok[id] = nil end end

    -- ---- the sentry's own state first (nothing here depends on which enemies are about)
    -- overheating: stand down (hide everything) until it has cooled
    if def.heat and st.heat then
      local measured = st.heat_from == 'measured'
      local stop, resume = measured and HEAT.stop_measured or HEAT.stop, measured and HEAT.resume_measured or HEAT.resume
      if not P.cooling and st.heat >= stop then
        P.cooling = true
        local d = session.sentries[def.name]; if d then d.cooldowns = (d.cooldowns or 0) + 1 end
        event(string.format('%ssentry_cooling: %s at %.0f%% heat (%s); holds fire until it is down to %.0f%%', READ_ONLY and 'would ' or '', def.name, 100 * st.heat, st.heat_from, 100 * resume))
      elseif P.cooling and st.heat <= resume then
        P.cooling = false
        event(string.format('sentry: %s cooled down (%.0f%%, %s), firing again', def.name, 100 * st.heat, st.heat_from))
      end
    end
    local cooling = def.heat and st.heat and P.cooling
    -- time on the current target (it fires the whole time it is aimed at it)
    local dt = st.dt or 0
    if target ~= P.on_target then P.on_target, P.on_fire, P.on_lock = target, 0, 0 end
    if target ~= 0 then
      P.on_lock = P.on_lock + dt
      -- (only while its barrel is actually on the target: while it is still swinging round it hits nothing)
      local on = true
      if st.fwd and st.aim then
        local v = norm({ st.aim[1] - st.muzzle[1], st.aim[2] - st.muzzle[2], st.aim[3] - st.muzzle[3] })
        on = not v or st.fwd[1] * v[1] + st.fwd[2] * v[2] + st.fwd[3] * v[3] >= COVER_S.aligned
      end
      if on and st.synced and (not def.fire_node or st.node == def.fire_node) then P.on_fire = P.on_fire + dt end
    end
    -- short bursts at Heavy Devastators (machine gun, Gatling: 'bursts'; with armour skipping on): fire this long at
    -- one, then rest it
    local bursts = def.bursts and armour_on
    if bursts then
      local c = st.current
      local a = c and c.kind and ARMOR[c.kind]
      -- (the whole Devastator rests: body, shield and parts are separate entries, rest_parts in engine_armor.lua)
      if a and a.burst and P.on_fire >= BURST_S.fire then rest_parts(P.rest, cands, c, t + BURST_S.rest); P.burst_now = target end
    end
    for id, until_t in pairs(P.rest) do if t >= until_t then P.rest[id] = nil end end
    -- fire spreading (Laser Sentry): its target counts as lit once it has had enough beam
    if def.spreads_fire then
      -- (a gunship doesn't burn down like the rest: it keeps the beam on it)
      local air = st.current and st.current.kind and AIR_FIRST[st.current.kind]
      if target ~= 0 and not air and (P.on_fire >= SPREAD.fire or P.on_lock >= SPREAD.lock) then P.lit[target] = P.lit[target] or t; P.lit_now = target end
      for id, t0 in pairs(P.lit) do if t - t0 >= SPREAD.burn then P.lit[id] = nil end end
    end

    -- ---- one pass over the enemies: every reason that depends on the enemy alone
    --  U unsafe (linger), N can't hurt, O out of sight, C cooling, B resting between bursts, G moving gunship
    -- out of sight (behind a wall or cover; not for mortars, which lob over it): hidden while it is, like the dogs.
    -- Its current target gets a short grace while it is only turning towards it, none while it is firing
    local sight = not def.blast
    local firing = st.node == (def.fire_node or FIRE_NODE) or st.node == def.salvo_node
    -- still aboard a dropship (not for the rocket and autocannon sentries, 'hits_carried': their splash also hurts the
    -- dropship): the dropships are found in the same pass
    local ships_wanted = not def.hits_carried and armour_on
    local air_still = def.air_still and prio_on
    local U, N, O, C, B, G, D, SP, Q, HV = NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE
    local spare = def.spares_helldivers
    local spare_all = spare and team_wanted()
    -- (with the Safety option off you are fair game: your own entry, within 1.5 m of you, isn't hidden)
    local me_open = spare and st.me and not OPT.safety() and { { at = st.me } } or nil
    local ships
    for _, c in ipairs(cands) do
      local id = c.id
      local play = in_play(c, st)
      local seen = P.unsafe_seen[id]
      if seen and t - seen < LINGER and (gap[id] or 0) < 0.3 and pickable(c, st) then U = put(U, id) end
      if play then
        if cannot_hurt(def, c) then N = put(N, id) end
        if sight and not c.visible and (id ~= target or firing or (c.memory or 0) <= COVER_S.grace) and not (P.sight_ok[id] and t < P.sight_ok[id]) then O = put(O, id) end
        if cooling then C = put(C, id) end
        if bursts and P.rest[id] and t < P.rest[id] then B = put(B, id) end
        if air_still and c.pos and c.kind and AIR_FIRST[c.kind] and air_moving(c, t) then G = put(G, id) end
      end
      -- (Tesla Tower) a helldiver in its list - you, or a teammate with Teammate safety on - is hidden from it
      -- (any helldiver with Teammate safety on; otherwise one within 6 m of you: the list's positions lag behind a
      -- running helldiver, and a helldiver it picks is zapped at once, so this errs on the wide side)
      -- (4.5: only while it isn't safe by its factions - then helldivers can't be picked, whatever their entries say)
      if spare and c.kind == AVATAR_TYPE and (spare_all or near_body(bodies, c.pos, 36)) and not (me_open and c.pos and near_body(me_open, c.pos, 2.25)) then HV = put(HV, id) end
      -- (4.5) and an entry whose type can't be read that stands where a helldiver is (it may be one)
      if spare and not c.kind and near_body(bodies, c.pos, 2.25) then HV = put(HV, id) end
      if ships_wanted and c.pos and c.kind then
        local a = ARMOR[c.kind]
        if a and a.sentries_skip and a.av < 10 then ships = ships or {}; ships[#ships + 1] = c.pos end
      end
    end
    -- enemies still aboard a dropship: near a dropship's body and well above the sentry, which can't be the ground
    -- troops it has just set down (those are below its hover height)
    if ships then
      local reach2, lo = DROPSHIP.reach ^ 2, st.base[3] + DROPSHIP.above_sentry
      for _, c in ipairs(cands) do
        local p = c.pos
        if p and p[3] >= lo then
          local a = c.kind and ARMOR[c.kind]
          if not (a and a.sentries_skip) then
            for _, q in ipairs(ships) do
              local dz = p[3] - q[3]
              if (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= reach2 and dz >= -DROPSHIP.below and dz <= DROPSHIP.above then D = put(D, c.id); break end
            end
          end
        end
      end
    end
    -- fire spreading (Laser Sentry, like the Rover): once one is burning it moves on to an unlit one. While something
    -- unlit is about, or nothing burning is close to anyone, the burning ones are left alone (one burning right at the
    -- sentry is kept on until it is dead)
    if def.spreads_fire then
      local reach2, near2 = SPREAD.reach ^ 2, SPREAD.near_you ^ 2
      local unlit, necessary = false, false
      for _, c in ipairs(cands) do
        local id = c.id
        if c.pos and c.visible and open(c) and not U[id] and not N[id] and not C[id] and not D[id] and c.d2 and c.d2 <= reach2 then
          if P.lit[id] then
            if near_body(people, c.pos, near2) or near_sentry(s, st, c) then necessary = true end
          else unlit = true end
        end
      end
      st.spread_state = unlit and 'spreading' or (necessary and 'finishing a close one' or 'letting them burn')
      if unlit or not necessary then
        for _, c in ipairs(cands) do
          if P.lit[c.id] and in_play(c, st) and (unlit or not near_body(people, c.pos, near2)) and not near_sentry(s, st, c) then SP = put(SP, c.id) end
        end
      end
    end
    -- priority by armour (rocket/autocannon: armoured first; machine gun/Gatling/Laser: unarmoured first). Enemies
    -- that are burning, resting between short bursts or hidden for any other reason don't count as the better choice
    if def.prefer and prio_on then
      local heavy = def.prefer == 'heavy'
      local reach2, near2 = PRIORITY.reach ^ 2, PRIORITY.near_you ^ 2
      -- self-defence first: while an enemy it can hurt (and isn't holding off for any reason) is right at the sentry,
      -- everything farther away waits
      local close, want
      for _, c in ipairs(cands) do
        local id = c.id
        if c.visible and open(c) and not U[id] and not N[id] and not C[id] and not O[id] and not D[id]
          and not B[id] and not SP[id] and not G[id] then
          if near_sentry(s, st, c) then close = close or {}; close[id] = true
          elseif not close and c.pos and c.kind and c.d2 and c.d2 <= reach2 then
            local k = armour_tier(c, heavy, def.air_first)
            if not want or (heavy and k > want) or (not heavy and k < want) then want = k end
          end
        end
      end
      if close then
        for _, c in ipairs(cands) do
          if c.pos and not close[c.id] and pickable(c, st) and not near_body(people, c.pos, near2) then Q = put(Q, c.id) end
        end
      elseif want then
        for _, c in ipairs(cands) do
          -- (an enemy whose type can't be read, e.g. one being removed, is never reordered: it isn't known to be lighter)
          local id = c.id
          if c.pos and c.kind and pickable(c, st) and not U[id] and not N[id] and not B[id] and not SP[id] and not G[id] then
            local k = armour_tier(c, heavy, def.air_first)
            if ((heavy and k < want) or (not heavy and k > want)) and not near_body(people, c.pos, near2) then Q = put(Q, c.id) end
          end
        end
      end
    end
    local hide = union(U, N, Q, C, B, SP, G, O, D, HV)
    if TESTER then st.hide_sets = { unsafe = U, armour = N, priority = Q, cooling = C, burst_rest = B, burning = SP, gunship_moving = G, out_of_sight = O, on_dropship = D, helldiver = HV } end
    -- (the helldivers' entries, hidden again right after the game's update: sentry_after)
    -- (4.5: by id, not by place - the game moves entries up its list when one before them goes, e.g. an enemy it
    -- just killed, and a helldiver's entry moved into a new place would have been left shown there)
    if spare and next(HV) then s.spare_ids = HV end
    if next(HV) then
      for id in pairs(HV) do
        if not P.spared then P.spared = {} end
        if not P.spared[id] then P.spared[id] = true; bump(session.actions, 'sentry_spared_helldiver')
          if TESTER then event(string.format('sentry: %s had a helldiver among its targets (id %d): hidden from it', def.name, id)) end
        end
      end
    end
    -- (Tesla Tower) while it is on a helldiver, ask it to choose again every frame: no hold, no back-off (it is logged once)
    if target ~= 0 and HV[target] then
      local first = P.spare_target ~= target
      -- (4.5) counted in the log: this should stay at 0; if it doesn't, the hiding came too late for the game's pick
      if first then
        bump(session.actions, 'tesla_aimed_at_helldiver')
        -- (listed up to 10 times a session, counted after that)
        if session.actions.tesla_aimed_at_helldiver <= 10 then
        -- (for everyone: rare, and the details say which way the hiding failed - shown = its entry wasn't hidden in
        -- time, hidden = picked in spite of it)
        local c, me = st.current, st.me
        local mine = c and c.pos and me and (c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + (c.pos[3] - me[3]) ^ 2 < 2.25
        -- (Test 33: and what its entry and its faction list held, to see how it could pick it)
        local fl = {}
        local perc = st.perc
        if perc then local n = u32(perc, 0); if n <= 32 then for j = 0, n - 1 do fl[#fl + 1] = tostring(u32(perc, 8 + j * 8)) end end end
        event(string.format('sentry: %s aimed at a helldiver (%s, id %d, AI step %d, its entry %s when read (mask %s, %s), its factions %s, enemy marking %s): asked to choose again every frame',
          def.name, mine and 'you' or 'a teammate', target, st.node, c and (c.mask == BLANK and 'hidden' or 'shown') or 'not listed',
          c and string.format('%08x', u32(c.mask, 0)) or '-', c and tostring(c.group) or '-', table.concat(fl, ' '), P.filter_on and 'on' or 'off'))
        end
      end
      P.spare_target, P.safety_t, P.safety_enemy, P.last_kick_t = target, t, target, t
      return { block = union({ [target] = true }, hide), kick = true, reason = 'sentry_safety', quiet = not first }
    end
    P.spare_target = nil
    -- (5.0) its target just died: choose again now instead of firing at the body until its selection timer runs out
    -- (like the dogs: once per lost target, at most every 0.1 s; checked before any hold, which mustn't keep it on a body). Also when the game has already cleared the target
    -- but it is still in its firing step with the old timer running (it keeps shooting where the enemy was): up to two
    -- asks. Not in the steps where it ignores being asked. Counted, not listed in the events (it happens every kill)
    local prev = P.prev_target or 0
    P.prev_target = target
    local cur = st.current
    if target ~= 0 and not (cur and cur.alive) and P.lost_target ~= target and t - (P.lost_t or 0) >= 0.1
      and st.node ~= BUSY_NODE and st.node ~= def.salvo_node then
      P.lost_target, P.lost_t, P.lost_tries = target, t, 0
      local r = kick(s, st, t, hide, {}, 'sentry_target_lost')
      if r.kick then r.quiet = true; bump(session.actions, 'sentry_target_lost') end
      return r
    end
    if target == 0 and prev ~= 0 then P.lost_from, P.lost_tries = prev, 0 end
    if target ~= 0 then P.lost_from = nil end
    if target == 0 and P.lost_from and st.node == (def.fire_node or FIRE_NODE) and (P.lost_tries or 0) < 2 and t - (P.lost_t or 0) >= 0.15 then
      local now = u64(rd(rptr(A.g.clock, 'clock') + 24, 8, 'clock'), 0)
      if st.deadline > now then
        P.lost_t, P.lost_tries = t, (P.lost_tries or 0) + 1
        bump(session.actions, 'sentry_target_lost')
        return { block = hide, kick = true, reason = 'sentry_target_lost', quiet = true }
      end
    end
    if P.hold and target == P.hold.target and t < P.hold.until_t then
      return { block = union(P.hold.block, hide), kick = false, reason = P.hold.reason }
    end
    P.hold = nil
    if target ~= 0 then
      -- its target is unsafe (someone in the line, in the blast, or in the way of its turn): choose again now
      if U_now[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_safety') end
      -- (in some AI steps the game doesn't choose again: step 10 for every kind, and the rocket sentry's salvo step.
      -- The other reasons wait until that step is over - asking then was only ignored, and after two ignored asks it
      -- was put on hold for longer. The target stays hidden meanwhile.)
      if st.node == BUSY_NODE or st.node == def.salvo_node then return { block = hide, kick = false } end
      -- its target is still aboard a dropship: choose again now
      if D[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_on_dropship') end
      -- its target went out of sight (it would be firing into the wall): choose again now
      if O[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_out_of_sight') end
      -- short burst done (Heavy Devastator): leave it for a while
      if B[target] and P.burst_now == target then P.burst_now = nil; return kick(s, st, t, hide, { [target] = true }, 'sentry_burst_done') end
      -- fire spreading: its target is alight, move on (or hold the beam while everything near is burning)
      if SP[target] and P.lit_now == target then P.lit_now = nil; return kick(s, st, t, hide, { [target] = true }, 'sentry_spread') end
      -- overheating: drop its target so it stops firing and cools
      if C[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_cooling') end
      -- armour it can't hurt
      if N[target] and not P.stuck[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_cannot_hurt') end
      -- a gunship it is on started moving (rocket sentry): switch to something else until it hovers again
      if G[target] then return kick(s, st, t, hide, { [target] = true }, 'sentry_gunship_moving') end
      -- a better-suited enemy (by armour) is in sight: switch to it (at most every 'calm' seconds)
      if Q[target] and t - (P.prio_t or -99) >= PRIORITY.calm then
        P.prio_t = t
        return kick(s, st, t, hide, { [target] = true }, 'sentry_priority')
      end
    end
    -- it stood down for someone's safety and has nothing: the moment something is safe, choose right away
    if next(U) then P.safety_seen = t end
    if target == 0 and t - (P.safety_seen or -99) < 2.0 and t - (P.last_kick_t or -99) >= 0.1 then
      for _, c in ipairs(cands) do
        if open(c) and not hide[c.id] then return kick(s, st, t, hide, {}, 'sentry_resume') end
      end
    end
    return { block = hide, kick = false }
  end

  local function note_sentry(s, st, req, me)
    bump(session.actions, req.reason)
    local d = session.sentries[s.def.name]
    if req.reason == 'sentry_cannot_hurt' then
      if d then d.armour = d.armour + 1 end
    elseif req.reason == 'sentry_safety' and d then
      d.stops = d.stops + 1
      if (st.unsafe_why[st.target] or ''):find('teammate') then d.mate_stops = d.mate_stops + 1 end
    end
    if req.reason == 'sentry_burst_done' or req.reason == 'sentry_spread' or req.reason == 'sentry_gunship_moving' or req.reason == 'sentry_out_of_sight' or req.reason == 'sentry_on_dropship' then
      if d then d[req.reason] = (d[req.reason] or 0) + 1 end
      return
    end
    if req.reason == 'sentry_priority' then
      if d then d.priority = (d.priority or 0) + 1 end
      return
    end
    if req.reason == 'sentry_resume' or req.reason == 'sentry_cooling' or noted_events >= 40 then return end
    noted_events = noted_events + 1
    local c = st.current
    local where = ''
    if c and c.pos and me then where = string.format(', %.1f m from you', math.sqrt((c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + (c.pos[3] - me[3]) ^ 2)) end
    local what
    if req.reason == 'sentry_safety' then
      local g = st.gap[st.target]
      local why = st.unsafe_why[st.target] or '?'
      what = why .. where .. ((g and g < 50 and not s.def.blast and g > -5 and not why:find('swing')) and string.format(', %.2f m inside the safety margin', math.max(0, -g)) or '')
    else
      local a = c and c.kind and ARMOR[c.kind]
      what = (a and (a.name .. ', armour ' .. a.av) or '?') .. where
    end
    event(string.format('%s%s: %s (target %d, %s; AI step %d)', READ_ONLY and 'would ' or '', req.reason, s.def.name, st.target, what, st.node))
  end

  local function steer_sentry(s, st, req, me)
    if req.kick and not req.quiet then note_sentry(s, st, req, me) end
    if READ_ONLY then return end
    if read(s.rec_addr, 4) ~= st.rec_head then return end
    hider_apply(s.H, st.candidates, req.block)
    if req.kick then
      local now = u64(rd(rptr(A.g.clock, 'clock') + 24, 8, 'clock'), 0)
      if st.deadline > now and st.deadline - now <= 1000000 then
        if not write(s.rec_addr + 152, u64bytes(now)) then stats.write_failures = stats.write_failures + 1 end
      end
    end
  end

  -- ------------------------------------------------------------------ each frame
  -- st_dog: the dog's state this frame (nil when no dog is out); returns true while any sentry of yours is out
  -- the nearest live enemy inside a sentry's minimum range (nil if none), worked out once per frame
  local function too_close(s, st)
    if st.close_checked then return st.close_enemy end
    st.close_checked = true
    local r2, best = s.def.min_range ^ 2, nil
    for _, c in ipairs(st.candidates) do
      local p = c.pos
      if p and c.alive and c.kind ~= AVATAR_TYPE then
        local d2 = (p[1] - st.base[1]) ^ 2 + (p[2] - st.base[2]) ^ 2 + (p[3] - st.base[3]) ^ 2
        if d2 < r2 then best, r2 = c, d2 end
      end
    end
    st.close_enemy = best
    return best
  end
  sentry_tick = function(st_dog, t, dt)
    -- (the Sentries option off: your sentries are left to the game)
    if not OPT.sentries() then
      if next(sentries) then sentry_restore() end
      return false
    end
    if not st_dog and not in_mission() then
      if next(sentries) then sentry_restore() end
      pl = nil
      noted_events = 0   -- (up to 40 sentry events are logged per mission)
      other_teslas = {}
      return false
    end
    -- (a new sentry changes the number of agents: rescan then, at most twice a second; otherwise every 2 s)
    local tg = ptr_of(read(A.g.targeting, 8), 0)
    local ch = tg and read(tg + 320, 4)
    local count = ch and u32(ch, 0)
    -- (only a rising count can mean a new sentry: a falling one is noted so the next rise is seen; a sentry that is
    -- removed is dropped by its own failed read, and the regular scan catches anything else)
    if count and last_count and count < last_count then last_count = count end
    if t >= next_scan or (count and count > (last_count or -1) and t >= (last_scan or 0) + 0.5) then
      next_scan, last_scan = t + SCAN_SECONDS, t
      scan(t)
    end
    if not next(sentries) then return false end
    local me, mates
    if st_dog then me, mates = st_dog.player_pos, st_dog.mates
    else
      if not pl or t >= pl_until then
        local ok, p = pcall(find_player)
        pl, pl_until = ok and p or nil, t + 0.25
      end
      if pl then
        me = unit_position(pl.player_unit)
        mates = team_wanted() and teammates(pl, t) or {}
        -- (5.0) the log's teammates line: counted here too while no dog is out (only the dog's poll counted them)
        if #mates > session.team.max then session.team.max = #mates end
      end
    end
    local bodies = bodies_for(me, mates)
    -- (with Safety on, the same list; otherwise you are added back for the priority rules)
    local people = bodies
    if me and not OPT.safety() then
      people = { { at = me } }
      for _, b in ipairs(bodies) do people[#people + 1] = b end
    end
    local registry = rptr(A.g.registry, 'registry')
    -- (its records moved: found again straight away, in this same frame, so it is never left a frame unsteered;
    -- nothing is read or written through the old copies, and its last frame's laser is dropped)
    local moved
    for id, s in pairs(sentries) do
      -- (a Tesla Tower: every frame, 4.5; and one found moved right after the game's update, sentry_after)
      -- (a Tesla Tower not yet safe by its factions: every frame, unless its records were confirmed right after the
      -- game's last update, sentry_after)
      if s.moved_after then s.moved_after, moved = nil, true
      -- (4.5, Test 30: and every sentry while it is busy - a tester found the FRV gun's safety a moment late, and its
      -- records move often: until a move is found, its asks go to the old copy)
      elseif t >= (s.check_next or 0) or s.busy or (s.def.spares_helldivers and s.after_ok ~= FRAME - 1) then
        s.check_next = t + CHECK_EVERY
        local okc, cur = pcall(records_current, s)
        if okc and not cur then s.moved, s.spare_ids, s.st, moved = true, nil, nil, true end
      end
    end
    if moved then
      next_scan, last_scan = t + SCAN_SECONDS, t
      scan(t)
      if not next(sentries) then return false end
    end
    -- (4.0.6) busy: some sentry has a target, is still in its firing step, has enemies (alive) in its list or enemies
    -- hidden from it - then the main loop checks every frame; otherwise a few times a second (idle sentries were
    -- over 95% of all checks in a long mission). An enemy shows up in a sentry's list before it can be picked
    local busy = false
    for id, s in pairs(sentries) do
      -- (4.5) each sentry at its own pace: every frame while it is busy, otherwise ten times a second (before 4.5 one
      -- busy sentry - a Tesla Tower always was - had every idle one read every frame too)
      if s.moved or s.busy ~= false or not s.st or t >= (s.next_read or 0) then
        local sdt = s.read_t and math.min(t - s.read_t, 0.5) or dt
        s.read_t, s.next_read = t, t + 0.1
        local ok, st, why
        s.spare_ids = nil   -- (set again by plan_sentry from this frame's read)
        if s.moved then ok, st, why = true, nil, nil else ok, st, why = pcall(read_sentry, s, registry) end
        if ok and st then
          s.st = st
          st.me = me
          st.fwd = barrel_dir(s, st)
          heat_update(s, st, t, sdt)
          st.dt = sdt
          if s.def.spares_helldivers then tesla_filter(s, st, bodies) end
          local req = plan_sentry(s, st, bodies, t, people)
          steer_sentry(s, st, req, me)
          local d = session.sentries[s.def.name]
          if d then
            d.out = d.out + sdt; if st.target ~= 0 then d.targeted = d.targeted + sdt end
            if s.def.min_range and too_close(s, st) then d.too_close = (d.too_close or 0) + sdt end
          end
          if TESTER then bump(session.sentry_nodes, s.def.name .. ': ' .. (st.target == 0 and 'no target' or ('AI step ' .. st.node .. (st.synced and '' or ' (not synced)')))) end
          -- busy: a target, still in its firing step, enemies hidden from it or alive in its list, or a Tesla Tower
          -- (a helldiver walking into its list is hidden the frame it shows up)
          local b = st.target ~= 0 or st.node == (s.def.fire_node or FIRE_NODE) or next(s.H) ~= nil or s.def.spares_helldivers or false
          if not b then for _, c in ipairs(st.candidates) do if c.alive or c.mask == BLANK then b = true; break end end end
          s.busy = b
        elseif not s.moved then
          -- gone (destroyed, out of ammo, picked up) or unreadable: put its masks back and forget it
          if not ok then event('sentry: ' .. s.def.name .. ' dropped after a read error: ' .. tostring(type(st) == 'table' and st[2] or st)) end
          forget(id, s, ok and tostring(why) or 'read error')
          next_scan = 0   -- look for it again straight away (usually the game has only moved its records)
        end
      end
      if s.moved or s.busy then busy = true end
    end
    return next(sentries) ~= nil, busy
  end

  sentry_restore = function()
    local ok = true
    for _, s in pairs(sentries) do if not hider_restore(s.H) then ok = false end; pcall(tesla_unfilter, s) end
    sentries, remembered, air_seen, not_steered = {}, {}, {}, {}
    return ok
  end

  -- the laser for each sentry (appended to 'beams'): green along its barrel while it is on a target, flashing red
  -- toward an enemy it was just kept off for someone's safety; the Tesla Tower's reach as a green ring (plus a laser to
  -- its target), and a flashing red ring around the rocket sentry while an enemy is inside its minimum range
  local function add_beam(beams, M, to, argb, dot)
    local v, len = norm({ to[1] - M[1], to[2] - M[2], to[3] - M[3] })
    if v and len > 1 then beams[#beams + 1] = { from = { M[1] + v[1] * 0.2, M[2] + v[2] * 0.2, M[3] + v[3] * 0.2 }, to = to, argb = argb, dot = dot } end
  end
  -- (Tesla Tower) its reach as a ring on the ground around it
  local RING_SEGMENTS = 40
  -- (the rings are ~10% brighter than the lasers, a tester's call: alpha, red, green, blue)
  -- (4.0.6: the Tesla Tower's ring is yellow, a tester's call; before, green)
  local RING_YELLOW, RING_RED = { 150, 124, 112, 22 }, { 170, 141, 21, 21 }
  -- (a sentry doesn't move once it is set up, so each ring is built once per sentry, radius and colour and reused:
  -- rebuilt only if its base moved more than 0.2 m)
  -- (the Tesla Tower's ring is drawn as two rings 8 cm apart, a tester's call: thicker, so it reads at a distance;
  -- 'bands' lists the offsets from the radius, in metres. Three bands 6 cm apart cost 50% more drawing for about the
  -- same look)
  local RING_BANDS = { 0 }
  local TESLA_BANDS = { -0.04, 0.04 }
  -- height above the sentry's base (metres). (4.0.6: the Tesla Tower's ring sits about a foot higher, a tester's call:
  -- on uneven ground the lower ring disappeared into the terrain; 4.5: four feet, 1.22 m, a tester's call)
  local RING_RISE, TESLA_RISE = 0.15, 1.22
  local function add_ring(beams, s, c, r, argb, bands, rise)
    bands, rise = bands or RING_BANDS, rise or RING_RISE
    s.rings = s.rings or {}
    local ring = s.rings[argb]
    if not ring or ring.r ~= r or ring.rise ~= rise or (ring.x - c[1]) ^ 2 + (ring.y - c[2]) ^ 2 + (ring.z - c[3]) ^ 2 > 0.04 then
      ring = { r = r, rise = rise, x = c[1], y = c[2], z = c[3] }
      -- (each segment starts at the point the one before it ends at, the same table: the laser builds each point once)
      local z = c[3] + rise
      for _, off in ipairs(bands) do
        local rr = r + off
        local first = { c[1] + rr, c[2], z }
        local prev = first
        for k = 1, RING_SEGMENTS do
          local a = 2 * math.pi * k / RING_SEGMENTS
          local p = k == RING_SEGMENTS and first or { c[1] + rr * math.cos(a), c[2] + rr * math.sin(a), z }
          ring[#ring + 1] = { from = prev, to = p, argb = argb }
          prev = p
        end
      end
      s.rings[argb] = ring
    end
    -- (the laser keeps the rings in a line object of its own, rebuilt only when they change)
    local list = beams.rings
    if not list then list = {}; beams.rings = list end
    list[#list + 1] = ring
  end
  sentry_beams = function(beams, t)
    for _, s in pairs(sentries) do
      local st = s.st
      -- (when and at what it last fired, kept with its policy so a move of its records keeps it: 'laser_when_firing'
      -- guns show their laser only then; while firing, it may point at its target even if its aim isn't synced)
      if st and st.node == (s.def.fire_node or FIRE_NODE) then s.P.fired_t, s.P.fired_target = t, st.target end
      if st and not s.def.no_laser then
        local M = st.centre
        local P = s.P
        if s.def.ring then
          -- lit yellow the whole time it is out, engaging or not, so you always know where its reach ends (no red,
          -- and no dimming while idle: a tester's call)
          add_ring(beams, s, st.base, s.def.ring, RING_YELLOW, TESLA_BANDS, TESLA_RISE)
          -- and a laser to the target it is on
          local c = st.current
          if st.target ~= 0 and c and c.pos then
            add_beam(beams, M, { c.pos[1], c.pos[2], c.pos[3] + AIM_UP[2] }, GREEN, true)
          end
        elseif P.safety_t and t - P.safety_t < RED_SECONDS then
          local e
          for _, c in ipairs(st.candidates) do if c.id == P.safety_enemy then e = c end end
          if e and e.pos and math.floor((t - P.safety_t) * FLASH_HZ * 2) % 2 == 0 then add_beam(beams, M, { e.pos[1], e.pos[2], e.pos[3] + AIM_UP[2] }, RED) end
        elseif s.def.min_range and too_close(s, st) then
          -- an enemy inside its minimum range (rocket sentry): it can't fire until that one is dealt with, so its
          -- minimum range flashes red as a ring around it (like the Tesla Tower's)
          if math.floor(t * FLASH_HZ * 2) % 2 == 0 then add_ring(beams, s, st.base, s.def.min_range, RING_RED) end
        elseif st.current and st.current.pos and (st.synced or (s.def.laser_when_firing and st.target == s.P.fired_target))
          and (not s.def.laser_when_firing or t - (s.P.fired_t or -99) < LASER_FIRING_HOLD) then
          local c = st.current
          local to = (not s.def.blast and st.aim) or { c.pos[1], c.pos[2], c.pos[3] + AIM_UP[1] }
          -- sentries whose shots fly slowly or drop (rockets, cannon shells, mortars) aim well ahead of or above the
          -- enemy: their laser points at the enemy itself, not along the barrel
          if s.def.laser_at_enemy then to = { c.pos[1], c.pos[2], c.pos[3] + AIM_UP[2] } end
          if st.fwd and s.def.laser_follows_barrel then
            -- (Laser Sentry: its own beam comes out along the barrel, so ours does too, all the way, turning with it;
            -- lightly smoothed so the barrel's wobble doesn't shake it)
            local f = st.fwd
            local p = s.beam_fwd
            if p then f = norm({ p[1] * 0.5 + f[1] * 0.5, p[2] * 0.5 + f[2] * 0.5, p[3] * 0.5 + f[3] * 0.5 }) or st.fwd end
            s.beam_fwd = f
            local len = math.sqrt((to[1] - M[1]) ^ 2 + (to[2] - M[2]) ^ 2 + (to[3] - M[3]) ^ 2)
            to = { M[1] + f[1] * len, M[2] + f[2] * len, M[3] + f[3] * len }
          elseif st.fwd and not s.def.laser_at_enemy then
            -- follow the barrel, so the beam shows where it really points (never ending well away from the enemy).
            -- (5.0: blended rather than switched: while the barrel is near the aim point the beam follows it, further
            -- off it slides over to the aim point, and beyond the limit it points at the aim point. Switching made the
            -- beam jump back and forth on the Gatling and the pod/FRV guns, whose barrels shake while they fire)
            local len = math.sqrt((to[1] - M[1]) ^ 2 + (to[2] - M[2]) ^ 2 + (to[3] - M[3]) ^ 2)
            local e = { M[1] + st.fwd[1] * len, M[2] + st.fwd[2] * len, M[3] + st.fwd[3] * len }
            local off = math.sqrt((e[1] - to[1]) ^ 2 + (e[2] - to[2]) ^ 2 + (e[3] - to[3]) ^ 2)
            local lim = math.max(1.5, 0.06 * len)
            local w = math.max(0, math.min(1, (lim - off) / (0.4 * lim)))   -- 1 = along the barrel, 0 = at the aim point
            to = { to[1] + (e[1] - to[1]) * w, to[2] + (e[2] - to[2]) * w, to[3] + (e[3] - to[3]) * w }
          end
          -- (5.0) the end point is smoothed over about a tenth of a second, so the barrel's shake and the aim point's
          -- jumps between body parts don't make the beam twitch; a new target starts it afresh
          local E = s.beam_end
          -- (not for the Laser Sentry: its beam follows its barrel with smoothing of its own)
          if E and not s.def.laser_follows_barrel and s.beam_target == st.target and t - (s.beam_t or 0) < 0.25 then
            local k = 1 - math.exp(-(t - s.beam_t) / BEAM_SMOOTH)
            to = { E[1] + (to[1] - E[1]) * k, E[2] + (to[2] - E[2]) * k, E[3] + (to[3] - E[3]) * k }
          end
          s.beam_end, s.beam_target, s.beam_t = to, st.target, t
          add_beam(beams, M, to, GREEN, true)
        end
      end
    end
  end

  -- test builds: one line per sentry for an F8 marker
  sentry_marker_text = function(me)
    local out = {}
    local function enemies_of(st)
      local rows = {}
      for _, c in ipairs(st.candidates) do
        if c.pos and c.d2 and c.d2 < 80 ^ 2 and (c.alive or c.mask == BLANK) then rows[#rows + 1] = c end
      end
      table.sort(rows, function(a, b) return a.d2 < b.d2 end)
      local lines = {}
      for i = 1, math.min(#rows, 10) do
        local c, why = rows[i], {}
        for k, set in pairs(st.hide_sets or {}) do if set[c.id] then why[#why + 1] = k end end
        local a = c.kind and ARMOR[c.kind]
        lines[#lines + 1] = string.format('%d %s %4.0f m %s%s%s', c.id, c.kind and hexr(c.kind) or '-', math.sqrt(c.d2),
          #why > 0 and ('hidden: ' .. table.concat(why, ',')) or '-', a and ('  ' .. a.name .. ' AV' .. a.av) or (c.kind and LABELS[c.kind] and ('  ' .. LABELS[c.kind]) or ''),
          c.id == st.target and '  <- target' or '')
      end
      return lines
    end
    for _, s in pairs(sentries) do
      local st = s.st
      if st then
        local c = st.current
        local hid = {}
        for k, set in pairs(st.hide_sets or {}) do local n = 0; for _ in pairs(set) do n = n + 1 end; if n > 0 then hid[#hid + 1] = k .. ' ' .. n end end
        local off = ''
        if st.fwd and st.aim then
          local v = norm({ st.aim[1] - st.muzzle[1], st.aim[2] - st.muzzle[2], st.aim[3] - st.muzzle[3] })
          if v then off = string.format(', barrel %.0f deg off its aim', math.deg(math.acos(math.max(-1, math.min(1, dot3(v, st.fwd)))))) end
        end
        out[#out + 1] = string.format('%s: target %d%s, AI step %d%s%s, %d enemies listed, hidden: %s%s', s.def.name, st.target,
          c and c.kind and (' type ' .. hexr(c.kind) .. (LABELS[c.kind] and (' ' .. LABELS[c.kind]) or '')) or '',
          st.node, st.synced and ', aiming' or '', off, #st.candidates, #hid > 0 and table.concat(hid, ', ') or 'none',
          me and string.format(', %.0f m from you', math.sqrt((st.base[1] - me[1]) ^ 2 + (st.base[2] - me[2]) ^ 2)) or '')
          .. (st.heat and string.format(', heat %.0f%% (%s)%s', 100 * st.heat, st.heat_from, s.P.cooling and ', cooling' or '') or '')
          .. (st.spread_state and (', ' .. st.spread_state) or '')
        for _, l in ipairs(enemies_of(st)) do out[#out] = out[#out] .. '\n        ' .. l end
      end
    end
    return out
  end
  -- (Tesla Tower) run right after the game's own update: the game writes a helldiver's entry in the tower's list afresh
  -- every frame, so the helldivers hidden from it are hidden again straight after the game's update as well as before
  -- it (both chances to be hidden when the tower next picks). 4.5: the tower's whole list is read again here and each
  -- of those helldivers is hidden wherever its entry now is; and its records are checked every frame first (a record
  -- the game moved during its update is found again by the next poll, before the tower's next pick - before 4.5 a
  -- moved record could go up to a quarter of a second with its helldivers shown)
  sentry_after = function()
    if READ_ONLY then return end
    RC.frame = -1   -- (the game's update may have moved its lists)
    for _, s in pairs(sentries) do
      local ids = not s.moved and s.spare_ids
      if ids and next(ids) then
        local okc, cur = pcall(records_current, s)
        if okc and not cur then s.moved, s.moved_after, s.spare_ids, s.st = true, true, nil, nil
        elseif okc then
          s.after_ok = FRAME
          local perc = read(s.pbase, 5112)
          if perc then
            -- (the groups' entries and the three single entries after them)
            local offs, no = s.offs or {}, 0
            s.offs = offs
            for _, grp in ipairs(GROUPS) do
              local n = u32(perc, grp[1])
              if n <= 16 then for k = 0, n - 1 do no = no + 1; offs[no] = grp[2] + k * 80 end end
            end
            for _, one in ipairs(SINGLES) do if u32(perc, one[1] + 72) ~= 0 then no = no + 1; offs[no] = one[1] end end
            for i = 1, no do
              local off = offs[i]
              local id = u32(perc, off)
              if id ~= 0 and ids[id] then
                local m = perc:sub(off + 77, off + 80)
                if m ~= BLANK then
                  -- (a helldiver's mask is never given back with the tower's mark in it)
                  if bit.band(u32(m, 0), MARK) ~= 0 then m = pack32(bit.band(u32(m, 0), bit.bnot(MARK))) end
                  local addr = s.pbase + off + 76
                  local h = s.H[addr]
                  if h and h.id == id then h.before = m else s.H[addr] = { id = id, entry = s.pbase + off, before = m } end
                  if not write(addr, BLANK) then stats.write_failures = stats.write_failures + 1 end
                end
              end
            end
          end
        end
      end
    end
  end
  return sentry_tick, sentry_restore, sentry_beams, sentry_after
end)()
