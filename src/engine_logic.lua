
-- ======================================================================================================
-- Deciding: fast switching (Rover) and player safety (all dogs)
-- ======================================================================================================
-- (4.6.3) the names other files use are declared here; the rest of this file sits in a do-block so its own
-- helpers stop counting toward Lua's 200 locals of the main chunk once the file ends
local SAFE, dot3, segment_distance, M, TEAM, P, PRIORITY, union, plan, BLANK, hidden, hider_restore, hider_apply, restore, apply, steer
do
local FAST = { fire = 0.15, lock = 0.5, recent = 8, recent_seconds = 3.0, near = 20, reach = 35 }
-- The Rover spreads its fire: once an enemy is alight it moves on to one within 'reach' metres that it hasn't
-- set alight in the last 'recent_seconds' (it remembers its last 'recent' targets). Only when there is no such
-- enemy (the last one nearby, or every other one already burning) does it keep firing at the one it is on.
SAFE = { body_bottom = 0.2, body_top = 1.75, aim_heights = { 0.0, 0.5 } }

local function sub3(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
function dot3(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
-- shortest distance between segments p1-q1 and p2-q2 (plain numbers throughout: it runs for every enemy and every
-- protected body each frame, so it makes no tables)
function segment_distance(p1, q1, p2, q2)
  local d1x, d1y, d1z = q1[1] - p1[1], q1[2] - p1[2], q1[3] - p1[3]
  local d2x, d2y, d2z = q2[1] - p2[1], q2[2] - p2[2], q2[3] - p2[3]
  local rx, ry, rz = p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]
  local a = d1x * d1x + d1y * d1y + d1z * d1z
  local e = d2x * d2x + d2y * d2y + d2z * d2z
  local f = d2x * rx + d2y * ry + d2z * rz
  local s, t
  if a <= 1e-9 and e <= 1e-9 then s, t = 0, 0
  elseif a <= 1e-9 then s, t = 0, clamp01(f / e)
  else
    local c = d1x * rx + d1y * ry + d1z * rz
    if e <= 1e-9 then s, t = clamp01(-c / a), 0
    else
      local b = d1x * d2x + d1y * d2y + d1z * d2z
      local den = a * e - b * b
      s = den ~= 0 and clamp01((b * f - c * e) / den) or 0
      t = (b * s + f) / e
      if t < 0 then t, s = 0, clamp01(-c / a) elseif t > 1 then t, s = 1, clamp01((b - c) / a) end
    end
  end
  local x = (p1[1] + d1x * s) - (p2[1] + d2x * t)
  local y = (p1[2] + d1y * s) - (p2[2] + d2y * t)
  local z = (p1[3] + d1z * s) - (p2[3] + d2z * t)
  return math.sqrt(x * x + y * y + z * z)
end

-- ------------------------------------------------------------------------------------------------------
-- Where the dog will be a moment from now. It flies to a fixed spot beside you (learned here in your own
-- frame), so when you spin quickly its spot swings around and the dog follows it: every point along that
-- swing is checked, not just where the dog is at this instant.
-- ------------------------------------------------------------------------------------------------------
-- the look-ahead only kicks in for genuinely fast turns (about 85+ degrees a second): during ordinary movement
-- the dog repositions a lot, and checking its whole path then flagged enemies that were never in the way
local MOTION = { steady_turn = 0.6, steady_move = 1.5, fast_turn = 1.5, fast_keep = 0.6, spin_min = 1.5,
  lookahead = { 0.12 }, arc = { 0.25, 0.5, 0.75, 1.0 }, ahead_after = 0.5, arc_max = 1.0 }
M = {}
local TAU = 2 * math.pi
local function wrap(a) a = (a + math.pi) % TAU; return a - math.pi end
local function heading(v) return math.atan2(v[2], v[1]) end
local function axes_heading(axes)
  for _, ax in ipairs(axes) do if ax[1] * ax[1] + ax[2] * ax[2] > 0.5 then return heading(ax) end end
end
local function around(P, angle, radius, height) return { P[1] + radius * math.cos(angle), P[2] + radius * math.sin(angle), P[3] + height } end

local function dog_positions(st)
  local P, D = st.player_pos, st.drone_pos
  local out = { D }
  local t = os.clock()
  if st.key ~= M.key then M = { key = st.key, turn = 0, spin = 0 } end
  local o = sub3(D, P)
  local ang, yaw = heading(o), P.axes and axes_heading(P.axes)
  local dt = M.t and t - M.t or 0
  local rel_speed = 0
  if dt > 0.001 and dt < 0.5 then
    M.spin = 0.5 * M.spin + 0.5 * wrap(ang - M.ang) / dt
    if yaw and M.yaw then M.turn = 0.5 * M.turn + 0.5 * wrap(yaw - M.yaw) / dt end
    local d = sub3(o, M.o); rel_speed = math.sqrt(dot3(d, d)) / dt
  end
  M.t, M.ang, M.yaw, M.o = t, ang, yaw, o
  local r0 = math.sqrt(o[1] * o[1] + o[2] * o[2])
  -- (4.5.3 Test 9) a slow dog (Guard Dog, K-9) gets the look-ahead at all times except the early part of its line-up
  -- (4.6.3 review: the comment said only late line-up and firing; the code, tested in game, also keeps it while it has
  -- no target or is in any other step): early in its line-up it isn't about to shoot, and checked then it hid nearly every enemy whenever you
  -- turned, each hide restarting its slow line-up (a tester's log: the Guard Dog fired 7% of the time it had a
  -- target, every hold in its lining-up step). Left off for the whole line-up, it fired through you more in the
  -- simulator (it starts firing while still swinging round). Its line from where it is now is always checked, and the
  -- Rover, which fires as it turns, keeps the look-ahead throughout
  local ahead = st.dog.fast or st.node ~= 6 or (st.lineup_acc or 0) >= (st.dog.ahead_after or MOTION.ahead_after)
  -- 1) the spot it is flying to, and the swing from here to there
  if P.axes then
    local ax = P.axes
    local here = { dot3(o, ax[1]), dot3(o, ax[2]), dot3(o, ax[3]) }
    if math.abs(M.turn) < MOTION.steady_turn and rel_speed < MOTION.steady_move then
      if M.spot then for i = 1, 3 do M.spot[i] = M.spot[i] * 0.9 + here[i] * 0.1 end else M.spot = here end
    end
    if math.abs(M.turn) > MOTION.fast_turn then M.fast_until = t + (st.dog.safety_keep or MOTION.fast_keep) end
    local L = M.spot
    local size = L and math.sqrt(dot3(L, L)) or 0
    if ahead and size > 1 and size < 10 and t < (M.fast_until or 0) then
      local S = { P[1] + ax[1][1] * L[1] + ax[2][1] * L[2] + ax[3][1] * L[3],
                  P[2] + ax[1][2] * L[1] + ax[2][2] * L[2] + ax[3][2] * L[3],
                  P[3] + ax[1][3] * L[1] + ax[2][3] * L[2] + ax[3][3] * L[3] }
      local gap = sub3(S, D)
      if dot3(gap, gap) > 0.25 then
        local so = sub3(S, P)
        local a1, r1 = heading(so), math.sqrt(so[1] * so[1] + so[2] * so[2])
        local da = wrap(a1 - ang)
        -- (4.5.3 Test 15) only the first arc_max radians (about 57 degrees) of its swing around you: 0.7 let it fire through
        -- you on a 180-degree flick in the simulator (2-3 frames), 1.0 doesn't:
        -- the whole way round to its spot took in points well behind you, from where an enemy straight ahead lined up
        -- through you - a tester's Guard Dog held fire on an enemy in front of them while it was on their right
        local fmax = math.abs(da) > MOTION.arc_max and MOTION.arc_max / math.abs(da) or 1
        for _, f in ipairs(MOTION.arc) do
          local g = f * fmax
          out[#out + 1] = around(P, ang + da * g, r0 + (r1 - r0) * g, o[3] + (so[3] - o[3]) * g)
        end
        if fmax == 1 then out[#out + 1] = { (D[1] + S[1]) / 2, (D[2] + S[2]) / 2, (D[3] + S[3]) / 2 } end   -- in case it cuts straight across
      end
    end
  end
  -- 2) wherever its current swing carries it next
  if ahead and math.abs(M.spin) > MOTION.spin_min then
    for _, dt2 in ipairs(MOTION.lookahead) do
      local turn = math.max(-math.pi, math.min(math.pi, M.spin * dt2))
      out[#out + 1] = around(P, ang + turn, r0, o[3])
    end
  end
  return out
end

-- teammates (version 3): the same body check against the other players' helldivers. Their positions arrive
-- over the network a little late, so their body is a bit wider and also checked where they are heading.
TEAM = { margin = 0.1, lead = 0.2, reach = 90 }

-- the bodies to keep out of the line of fire: you, then each teammate near enough to matter
local function bodies_of(st)
  local me = st.player_pos
  -- (you only with the Safety option on; teammates with the Teammate safety option on)
  local out = {}
  if OPT.safety() then out[1] = { lo = { me[1], me[2], me[3] + SAFE.body_bottom }, hi = { me[1], me[2], me[3] + SAFE.body_top }, at = me, extra = 0 } end
  local D = st.drone_pos
  for _, m in ipairs(st.mates or {}) do
    if (m[1] - D[1]) ^ 2 + (m[2] - D[2]) ^ 2 < TEAM.reach ^ 2 then
      out[#out + 1] = { lo = { m[1], m[2], m[3] + SAFE.body_bottom }, hi = { m[1], m[2], m[3] + SAFE.body_top }, at = m, extra = TEAM.margin, mate = true }
      local v = m.vel
      if v and v[1] * v[1] + v[2] * v[2] > 1 then
        local a = { m[1] + v[1] * TEAM.lead, m[2] + v[2] * TEAM.lead, m[3] + v[3] * TEAM.lead }
        out[#out + 1] = { lo = { a[1], a[2], a[3] + SAFE.body_bottom }, hi = { a[1], a[2], a[3] + SAFE.body_top }, at = a, extra = TEAM.margin, mate = true }
      end
    end
  end
  return out
end

-- enemies the dog must not shoot right now because you (or a teammate) are in the way, now or in a moment
local function unsafe_enemies(st)
  local U, count = {}, 0
  st.unsafe_why, st.safe_gap = {}, {}
  local me, dog = st.player_pos, st.dog
  if not (me and st.drone_pos) then return U, 0 end
  local spots = dog_positions(st)
  st.dog_spots = #spots
  local bodies = bodies_of(st)
  st.mates_near = #bodies - ((bodies[1] and not bodies[1].mate) and 1 or 0)
  local radius = dog.radius or 0.4
  local D0 = st.drone_pos
  for _, c in ipairs(st.candidates) do
    local p = c.pos
    -- (only enemies the dog could pick: dead ones and entries of no interest are skipped, saving most of the work)
    if p and (c.alive or c.mask == '    ' or c.id == st.target) then
      local closest, why = math.huge, nil
      -- a teammate farther from the dog than the enemy (plus the dog's swing and a body height) can't be in between
      local reach2 = (math.sqrt((p[1] - D0[1]) ^ 2 + (p[2] - D0[2]) ^ 2 + (p[3] - D0[3]) ^ 2) + 8) ^ 2
      for bi, b in ipairs(bodies) do
        local a = b.at
        if not b.mate or (a[1] - D0[1]) ^ 2 + (a[2] - D0[2]) ^ 2 + (a[3] - D0[3]) ^ 2 < reach2 then
          for i, D in ipairs(spots) do
            for _, h in ipairs(SAFE.aim_heights) do
              local d = segment_distance(D, { p[1], p[2], p[3] + h }, b.lo, b.hi) - b.extra
              if d < closest then closest = d end
            end
            if dog.chain then
              -- arcs jump onward from the target: unsafe if someone stands just past it, as seen from the dog
              local vx, vy = p[1] - D[1], p[2] - D[2]
              local wx, wy, wz = a[1] - p[1], a[2] - p[2], a[3] + 1.0 - p[3]
              if vx * wx + vy * wy > 0 and math.sqrt(wx * wx + wy * wy + wz * wz) < dog.chain then
                closest = 0; why = why or ('arc would chain to ' .. (b.mate and 'a teammate' or 'you'))
              end
            end
            if closest < radius then
              if TESTER and i > 1 and not why then st.unsafe_from = st.unsafe_from or {}; st.unsafe_from[c.id] = D end
              why = why or (i == 1 and (b.mate and 'a teammate is in its line of fire' or 'you are in its line of fire')
                or (b.mate and 'a teammate would be in its line after the turn' or 'you would be in its line after the turn'))
              break
            end
          end
          if closest < radius then break end
        end
      end
      st.safe_gap[c.id] = closest
      if closest < radius then U[c.id] = true; count = count + 1; st.unsafe_why[c.id] = why end
    end
  end
  return U, count
end

P = {}   -- per-dog policy memory
local stuck_logged
local function reset_policy(key) P = { key = key, target = 0, fire = 0, lock = 0, last = nil, recent = {}, hold = nil, kicked = nil, ignored = 0, stuck = {},
  lineup = {}, noshot = {} } end
reset_policy(nil)

local function remember(id, t)
  for i = #P.recent, 1, -1 do if P.recent[i].id == id then table.remove(P.recent, i) end end
  P.recent[#P.recent + 1] = { id = id, t = t }
  while #P.recent > FAST.recent do table.remove(P.recent, 1) end
end
local function recently(id, t)
  for _, r in ipairs(P.recent) do if r.id == id and t - r.t < FAST.recent_seconds then return r.t end end
  return nil
end

-- best other enemy to switch to (nil if none)
local function pick_other(st, U, t, from)
  local pool = {}
  for _, c in ipairs(st.candidates) do
    if c.eligible and c.id ~= st.target and not U[c.id] then pool[#pool + 1] = c end
  end
  if #pool == 0 then return nil end
  -- prefer enemies near the dog when the one it is leaving was far away
  if from and from.d2 and from.d2 > FAST.near ^ 2 then
    local near = {}
    for _, c in ipairs(pool) do if c.d2 and c.d2 <= FAST.near ^ 2 then near[#near + 1] = c end end
    if #near > 0 then pool = near end
  end
  -- skip enemies hit in the last few seconds while others are available (their burn is still ticking)
  local fresh = {}
  for _, c in ipairs(pool) do if not recently(c.id, t) then fresh[#fresh + 1] = c end end
  if #fresh > 0 then pool = fresh end
  local best, bestd
  local me = st.player_pos
  for _, c in ipairs(pool) do
    local d
    if st.dog.fast and me and c.pos then
      -- the Rover lights the unlit enemies closest to you first
      d = (c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + (c.pos[3] - me[3]) ^ 2
    elseif from and from.pos and c.pos then d = (c.pos[1] - from.pos[1]) ^ 2 + (c.pos[2] - from.pos[2]) ^ 2 + (c.pos[3] - from.pos[3]) ^ 2
    else d = c.d2 or math.huge end
    if #fresh == 0 then d = (recently(c.id, t) or 0) * 1e9 + d end   -- all recent: oldest first
    if not best or d < bestd then best, bestd = c, d end
  end
  return best
end

PRIORITY = { range = 25, band = 3, linger = 0.4, urgent = 10 }   -- metres from you / extra metres / seconds /
-- while the dog is already shooting, it is only pulled off for a closer enemy that is within 'urgent' metres of you;
-- otherwise it finishes its burst and its next pick (within a second) is the closer one
local COVER = true            -- hide enemies the dog has lost sight of
local BURST = { fire = 1.0, rest = 3.0 }   -- Guard Dog vs Heavy Devastators: fire this long, then leave it this long
local RANGE_SLACK = 2         -- metres past a dog's range before an enemy counts as out of range
local COVER_GRACE = 0.6       -- ...but its current target only once it has been out of sight ~0.4 s (the game's
                              -- memory of it runs from 1 down to 0 in about a second), so an enemy that just
                              -- passes behind something for a moment doesn't make the dog start over
local CALM_SECONDS = 0.5      -- at most one optional redirect (closer threat, out of sight) per this long
local UNSAFE_LINGER = 0.4     -- an enemy stays hidden this long after it was last in line with you
local ENGAGE = { every = 0.25, tries = 3, pause = 1.0 }   -- 3.0: no target but something shootable in sight: pick now
local HOLD_SECONDS = 0.25     -- how long a forced re-selection may take before we try again
local BACKOFF_SECONDS = 1.0   -- slow down after the dog ignores two redirects in a row
-- closest first, but never at the cost of not shooting at all: after it is pulled to a closer enemy, the next
-- such pull waits until it has fired at its target for 'burst' seconds (or that target is gone, or 'timeout'
-- passes); and if it has not fired for 'after' seconds it is left to finish lining up on its current target.
-- It then goes back to closest first and catches up with the closer enemies.
local COMMIT = { after = 1.0, burst = 0.6, timeout = 4.0 }
-- no shot: an enemy the dog keeps lining up without ever firing at (the game still lists it, but the dog can't
-- get a shot: e.g. an enemy stuck under the map). Line-up time on it adds up over repeated picks; once it passes
-- the limit the enemy rests hidden for a while so the dog moves on. The Guard Dog and K-9 get longer (a Guard
-- Dog was seen lining up a Berserker for ~3 s before firing normally).
-- (beyond 'far_m' from the dog the Guard Dog and K-9 get the short limit too: far line-ups rarely end in a shot)
-- line-up time without a shot before an enemy is set aside (3.0: shortened on a tester's call, for fewer pauses on
-- enemies it can't reach): Rover 1 s; Guard Dog/K-9 1 s beyond 25 m and 2 s closer (they line up slower); and the
-- current pick must have had at least 'fair' seconds of it in one go (so line-ups cut short by the mod's own
-- switching don't add up to setting everything aside)
local NOSHOT = { rover = 1.0, far = 1.0, other = 2.0, fair = 0.6, far_m = 25, rest = 4.0, forget = 5.0 }

function union(...)
  local out = {}
  for _, set in ipairs({ ... }) do for id in pairs(set) do out[id] = true end end
  return out
end

-- first few target losses go to the log with the dog's AI step, to confirm what the game does on a kill
local lost_logged = 0
local function note_lost(st, how)
  if lost_logged >= 6 then return end
  lost_logged = lost_logged + 1
  event(string.format('target lost: %s, %s (AI step %d, %.2fs left on its timer)', st.dog.name, how, st.node,
    math.max(0, st.deadline - st.now) / 1e6))
end

-- the first target changes of each dog also go to the log, with what had become of the old target
local change_logged = {}
local function note_change(st, old, held)
  local n = change_logged[st.dog.name] or 0
  if old == 0 or n >= 8 then return end
  change_logged[st.dog.name] = n + 1
  local c
  for _, x in ipairs(st.candidates) do if x.id == old then c = x end end
  local what = not c and 'gone from its list' or string.format('%s, %s, score %.2f',
    c.alive and 'valid' or 'not valid', c.eligible and 'pickable' or 'not pickable', c.score or -1)
  event(string.format('target change: %s %d -> %d after %.1fs; old target %s; AI step %d; %.2fs left on timer',
    st.dog.name, old, st.target, held or 0, what, st.node, (st.deadline - st.now) / 1e6))
end

-- returns { block = set of enemy ids to hide from the dog, kick = force a re-selection now, reason = text }
function plan(st)
  local t = os.clock()
  if st.key ~= P.key then reset_policy(st.key) end
  local dt = P.last and math.min(math.max(t - P.last, 0), 0.25) or 0
  P.last = t
  if st.target ~= P.target then
    note_change(st, P.target, P.target_since and t - P.target_since)
    for _, c in ipairs(st.candidates) do
      if TESTER and c.id == st.target and c.kind then
        local k = hexr(c.kind) .. (LABELS[c.kind] and (' ' .. LABELS[c.kind]) or '')
        if session.types[k] or next(session.types) == nil or #session.type_list < 40 then
          if not session.types[k] then session.type_list[#session.type_list + 1] = k end
          session.types[k] = (session.types[k] or 0) + 1
        end
      end
    end
    P.target, P.fire, P.lock, P.target_since = st.target, 0, 0, t
  end
  local attacking = st.target ~= 0 and (st.node == 6 or st.node == 7)
  if attacking then P.lock = P.lock + dt end
  if st.node == 7 and st.synced then P.fire = P.fire + dt; P.last_fire_t = t end
  -- (4.6.3 review) measured from when it last had no target: before, time spent idle counted too, so the first enemy
  -- it picked after a quiet spell was committed to at once and a closer threat couldn't pull it during its line-up
  if st.target == 0 or not P.out_since then P.out_since = t end
  if st.target ~= 0 and P.commit ~= st.target and st.node == 6 and t - math.max(P.last_fire_t or -99, P.out_since) >= COMMIT.after then
    P.commit = st.target   -- it has gone too long without a shot: let it finish this one
  end
  if P.commit and (P.commit ~= st.target or P.fire >= COMMIT.burst) then P.commit = nil end
  -- (counted on the enemy it was pulled to, not the one it was pulled from)
  if P.need_fire and ((st.target ~= P.need_fire_from and (P.fire >= COMMIT.burst or st.target == 0)) or t - P.need_fire >= COMMIT.timeout) then P.need_fire = nil end
  -- (4.6.3 review: and only once it is on another enemy - while the game hadn't yet answered the pull it was still on
  -- the one it was pulled from, so 'focus' hid every other enemy, the closer one too, and the dog sat with nothing)
  local committed = not st.dog.fast and ((P.commit ~= nil and P.commit == st.target) or (P.need_fire ~= nil and st.target ~= 0 and st.target ~= P.need_fire_from))
  -- line-up time without a shot, per enemy (kept across re-picks, reset as soon as the dog fires at it)
  if st.target ~= 0 then
    local L = P.lineup[st.target] or { acc = 0 }
    if st.node == 6 then L.acc = L.acc + dt elseif st.node == 7 and st.synced then L.acc = 0 end
    L.t = t; P.lineup[st.target] = L
  end
  for id, L in pairs(P.lineup) do if t - L.t > NOSHOT.forget then P.lineup[id] = nil end end
  local tgt_c
  for _, c in ipairs(st.candidates) do if c.id == st.target then tgt_c = c end end
  local noshot_limit = st.dog.fast and NOSHOT.rover or ((tgt_c and tgt_c.d2 and tgt_c.d2 > NOSHOT.far_m ^ 2) and NOSHOT.far or NOSHOT.other)
  local L_now = st.target ~= 0 and P.lineup[st.target]
  if L_now and L_now.acc >= noshot_limit and P.fire == 0 and P.lock >= math.min(noshot_limit, NOSHOT.fair) then
    P.noshot[st.target] = t + NOSHOT.rest
    st.noshot_new, st.noshot_acc = st.target, L_now.acc
    L_now.acc = 0
  end
  st.lineup_acc = L_now and L_now.acc or 0
  st.target_for = P.target_since and t - P.target_since or 0

  local U_now, unsafe_count = unsafe_enemies(st)
  -- what stays hidden: enemies the dog could pick that were unsafe within the last moment (so a hidden enemy
  -- is not un-hidden and re-hidden every time you shift a little), plus whatever it is aiming at right now
  P.unsafe_seen = P.unsafe_seen or {}
  for id in pairs(U_now) do P.unsafe_seen[id] = t end
  local U = {}
  for _, c in ipairs(st.candidates) do
    local seen = P.unsafe_seen[c.id]
    -- (an enemy we already hid reads as not pickable, so it counts too)
    -- (only while its line still passes close to you: once you are clearly out of the way it comes back at once)
    local near_line = (st.safe_gap[c.id] or 0) < (st.dog.radius or 0.4) + 0.3
    if seen and t - seen < (st.dog.linger or UNSAFE_LINGER) and near_line and (c.eligible or c.mask == '    ' or c.id == st.target) then U[c.id] = true end
  end
  for id, seen in pairs(P.unsafe_seen) do if t - seen >= (st.dog.linger or UNSAFE_LINGER) then P.unsafe_seen[id] = nil end end

  -- enemies it cannot hurt (too heavily armoured) and enemies it cannot see (behind cover): hidden while they
  -- are, so the dog spends its ammo on what it can actually hit. The game refreshes line of sight about
  -- twice a second, so an enemy stepping out of cover comes back within half a second.
  local N, C = {}, {}
  for _, c in ipairs(st.candidates) do
    -- (every live one, not just those the dog rates worth shooting right now: it still picks those now and then)
    if c.alive or c.mask == '    ' or c.id == st.target then
      if cannot_hurt(st.dog, c) then N[c.id] = true
      -- (its current target gets a short grace while it is lining up, but none while it is firing: the moment an
      -- enemy it is shooting at drops out of sight it stops, the same as when its target dies)
      elseif COVER and not c.visible and (c.id ~= st.target or (c.memory or 0) <= COVER_GRACE or st.node == 7) then C[c.id] = true end
    end
  end
  st.armored, st.covered = N, C
  -- short bursts (Guard Dog vs Heavy Devastators): after a burst the enemy rests hidden for a while
  P.rest = P.rest or {}
  for _, c in ipairs(st.candidates) do
    if P.rest[c.id] and t < P.rest[c.id] and (c.alive or c.mask == '    ' or c.id == st.target) then N[c.id] = true end
  end
  for id, until_t in pairs(P.rest) do if t >= until_t then P.rest[id] = nil end end
  local S = {}
  for _, c in ipairs(st.candidates) do
    if P.noshot[c.id] and t < P.noshot[c.id] and (c.alive or c.mask == '    ' or c.id == st.target) then S[c.id] = true end
  end
  for id, until_t in pairs(P.noshot) do if t >= until_t then P.noshot[id] = nil end end
  -- (never at the cost of not shooting at all: when every enemy it could pick is set aside, they all come back)
  if next(S) then
    local other = false
    for _, c in ipairs(st.candidates) do
      if not S[c.id] and not U[c.id] and (c.eligible or (c.mask == '    ' and c.alive and (c.score or 0) > 0)) then other = true; break end
    end
    if not other then S = {} end
  end
  -- out of range: the Guard Dog only opens fire within ~32 m of itself (the Rover reliably within ~35 m), but both
  -- happily pick enemies farther out and then wait, "lining up", until they come closer. While anything is in
  -- range, hide what isn't.
  local R = {}
  local range = st.dog.range
  local in_range_alt = false
  if range then
    local any
    for _, c in ipairs(st.candidates) do
      -- (only enemies it could actually shoot right now count: one hidden because you are in the way or because it
      -- can't get a shot at it must not keep the farther ones hidden too, or the dog is left with nothing at all)
      local open = c.eligible or (c.mask == '    ' and c.alive and (c.score or 0) > 0)
      if open and not N[c.id] and not C[c.id] and not U[c.id] and not S[c.id] and c.d2 and c.d2 <= range ^ 2 then any = true; break end
    end
    in_range_alt = any and true or false
    if any or st.dog.hard_range then
      for _, c in ipairs(st.candidates) do
        -- (a Rover already firing at a far enemy is hitting it: leave that one alone, its fire spreading moves it on)
        local firing_at = st.dog.fast and c.id == st.target and st.node == 7 and st.synced
        if (c.eligible or c.mask == '    ' or c.id == st.target) and c.d2 and c.d2 > (range + RANGE_SLACK) ^ 2 and not firing_at then R[c.id] = true end
      end
    end
  end
  -- priority: when an enemy is close to you, hide the ones clearly farther from you than it, so the dog
  -- deals with the nearest threat first (enemies already hidden by us count as pickable here). With the Target
  -- Prioritization option (Intelligence) only.
  local F = {}
  P.far_seen = P.far_seen or {}
  local me = st.player_pos
  if me and OPT.priority() then
    local best
    for _, c in ipairs(st.candidates) do
      c.dp = nil
      if c.pos and (c.eligible or c.mask == '    ') and not U[c.id] and not N[c.id] and not C[c.id] and not R[c.id] and not S[c.id] then
        local dx, dy, dz = c.pos[1] - me[1], c.pos[2] - me[2], c.pos[3] - me[3]
        c.dp = math.sqrt(dx * dx + dy * dy + dz * dz)
        -- (for the Rover, enemies it has already set alight don't count as the close threat: once the close
        -- ones are burning it spreads its fire to the next ones out instead of staying on them)
        local lit = st.dog.fast and (recently(c.id, t) or (c.id == st.target and P.fire >= FAST.fire))
        -- (nor do enemies it has already spent a while lining up without a shot: they may be unreachable)
        local doubtful = P.lineup[c.id] and P.lineup[c.id].acc >= 0.5 * noshot_limit
        if (not best or c.dp < best) and not lit and not doubtful then best = c.dp end
      end
    end
    if best and best < PRIORITY.range then
      for _, c in ipairs(st.candidates) do
        if c.dp and c.dp > best + (st.dog.band or PRIORITY.band) then P.far_seen[c.id] = t end
      end
    end
    -- keep hiding for a moment after an enemy stops being "far" (no flicker), but only while it is still nearly
    -- as far; when the close threat dies or you move, the others come back straight away
    for _, c in ipairs(st.candidates) do
      local seen = P.far_seen[c.id]
      if seen and t - seen < PRIORITY.linger and best and best < PRIORITY.range and c.dp and c.dp > best + (st.dog.band or PRIORITY.band) - 1.5
        and (c.eligible or c.mask == '    ' or (c.id == st.target and (st.node ~= 7 or best <= PRIORITY.urgent))) then F[c.id] = true end
    end
  end
  for id, seen in pairs(P.far_seen) do if t - seen >= PRIORITY.linger then P.far_seen[id] = nil end end
  -- right after a redirect, leave the new target alone for a moment (it is not hidden, so it is not dropped
  -- without being asked to choose again)
  local calm = t - (P.last_kick_t or -1) < CALM_SECONDS
  if calm and st.target ~= 0 then
    if st.node ~= 7 then C[st.target] = nil end
    F[st.target], R[st.target] = nil, nil
  end
  if committed then F[st.target] = nil end
  -- focus: while committed (and its target is one it may shoot), keep the other enemies hidden so the game's own
  -- once-a-second re-pick doesn't move it on before it has fired its burst either
  local focus = {}
  if committed and st.target ~= 0 and P.fire < COMMIT.burst and not (U[st.target] or N[st.target] or C[st.target] or S[st.target] or R[st.target]) then
    for _, c in ipairs(st.candidates) do if c.id ~= st.target and (c.eligible or c.mask == '    ') then focus[c.id] = true end end
  end
  local hide = union(U, F, N, C, R, S, focus)
  st.hide_sets = { unsafe = U, closer_threat = F, armour = N, cover = C, range = R, no_shot = S, focus = focus }
  -- a re-selection we asked for is still pending: keep the same enemies hidden until the target changes
  if P.hold and st.target == P.hold.target and t < P.hold.until_t then
    return { block = union(P.hold.block, hide), kick = false, reason = P.hold.reason }
  end
  P.hold = nil

  local current
  for _, c in ipairs(st.candidates) do if c.id == st.target then current = c end end
  -- the enemies the Rover hit in the last few seconds (their burn is still ticking)
  local function recent_set()
    local set = {}
    for _, r in ipairs(P.recent) do if t - r.t < FAST.recent_seconds then set[r.id] = true end end
    return set
  end
  local function kick(block, reason)
    -- a repeat for the same target means the dog ignored the last redirect
    -- (a nudge after a kill, with no target set, doesn't count: there is nothing to have ignored)
    if st.target ~= 0 and P.kicked == st.target then P.ignored = P.ignored + 1 else P.kicked, P.ignored = st.target, 0 end
    if P.ignored >= 2 then
      -- it keeps ignoring us: keep the enemies hidden but stop forcing re-selection for a while
      P.kicked, P.ignored = nil, 0
      if reason == 'cannot_hurt' then
        -- some enemies (seen with armoured striders) stay the dog's target however often we hide them; pulling
        -- it off again and again only makes it start over each time, so stop redirecting it off that one (it
        -- stays hidden, so the dog still drops it whenever the game lets it)
        P.stuck[st.target] = true
        local c
        for _, x in ipairs(st.candidates) do if x.id == st.target then c = x end end
        local k = c and c.kind and hexr(c.kind) or '?'
        stuck_logged = stuck_logged or {}
        if not stuck_logged[k] then
          stuck_logged[k] = true
          local a = c and c.kind and ARMOR[c.kind]
          event(string.format('cannot steer: the %s keeps returning to %s (type %s); left to the game', st.dog.name, a and a.name or '?', k))
        end
        return { block = hide, kick = false, reason = reason }
      end
      P.hold = { target = st.target, block = block, until_t = t + BACKOFF_SECONDS, reason = reason }
      if reason:find('^safety') then P.safety_t, P.safety_enemy, P.safety_step, P.safety_now = t, st.target, st.node, (st.unsafe_why[st.target] or ''):find('after the turn') == nil end
      stats.ignored_redirects = stats.ignored_redirects + 1
      bump(session.actions, 'backing_off')
      event(string.format('backing off: %s ignored two redirects (target %d)', st.dog.name, st.target))
      return { block = union(block, hide), kick = false, reason = reason }
    end
    P.hold = { target = st.target, block = block, until_t = t + HOLD_SECONDS, reason = reason }
    P.last_kick_t = t
    if reason == 'out_of_sight' then P.cover_t, P.cover_enemy, P.cover_step = t, st.target, st.node end
    if reason:find('^safety') then P.safety_t, P.safety_enemy, P.safety_step, P.safety_now = t, st.target, st.node, (st.unsafe_why[st.target] or ''):find('after the turn') == nil end
    return { block = union(block, hide), kick = true, reason = reason }
  end

  -- 1) the dog's current target is on the other side of you: move it to a safe enemy, or make it stand down
  -- (only the target itself and the unsafe enemies are hidden; the dog picks freely among the rest)
  if st.target ~= 0 and U_now[st.target] and attacking then
    local other = pick_other(st, union(U, N, C, R, S), t, current)
    if other then return kick({ [st.target] = true }, 'safety_switch') end
    return kick({ [st.target] = true }, 'safety_hold')
  end
  -- 2) its target just died (or dropped out of sight): make it choose again now instead of shooting the
  --    body until its one-second selection timer runs out. Once per lost target, at most every 0.1 s.
  --    Seen two ways: the target is still set but no longer valid, or the game has already cleared it but the
  --    dog is still in its firing step with the old timer running (it keeps shooting where the enemy was).
  local prev = P.prev_target or 0
  P.prev_target = st.target
  if st.target ~= 0 and not (current and current.alive) and P.lost_target ~= st.target and t - (P.lost_t or 0) >= 0.1 then
    P.lost_target, P.lost_t, P.lost_tries = st.target, t, 0
    note_lost(st, 'target no longer valid')
    return kick({}, 'target_lost')
  end
  if st.target == 0 and prev ~= 0 then P.lost_from, P.lost_tries = prev, 0 end
  -- (4.5.1) only when it has something it may pick: asked with nothing to choose, the game gives it a fresh timer in
  -- its firing step and it fires at nothing (seen on the Supply FRV gun, the same rule); left alone it stops when its
  -- old timer runs out
  if st.target == 0 and P.lost_from and st.node == 7 and st.deadline > st.now and (P.lost_tries or 0) < 2 and t - (P.lost_t or 0) >= 0.15 then
    local any = false
    for _, c in ipairs(st.candidates) do
      if (c.eligible or (c.mask == '    ' and c.alive and (c.score or 0) > 0)) and not hide[c.id] then any = true; break end
    end
    if any then
      P.lost_t, P.lost_tries = t, (P.lost_tries or 0) + 1
      if P.lost_tries == 1 then note_lost(st, 'target cleared, timer still running') end
      return kick({}, 'target_lost')
    end
  end
  if st.target ~= 0 then P.lost_from = nil end
  -- 2b) it stood down for your safety and has no target: the moment something is safe to shoot again, make it
  --     choose right away instead of waiting out its selection timer (up to a second)
  if next(U) then P.safety_seen = t end
  if st.target == 0 and t - (P.safety_seen or -99) < 2.0 and t - (P.last_kick_t or -99) >= 0.1 then
    for _, c in ipairs(st.candidates) do
      if (c.eligible or (c.mask == '    ' and c.alive and (c.score or 0) > 0)) and not hide[c.id] then return kick({}, 'resume') end
    end
  end
  -- 2c) engage (3.0): no target, yet an enemy it could shoot is in sight and in range: make it choose now instead
  --     of waiting out its selection timer (up to a second). Not while it is docked on your back (reloading); at
  --     most every 0.25 s, and after 3 tries without it picking anything it waits a second.
  if st.target ~= 0 then P.engage_tries = 0 end
  if st.target == 0 and st.deadline > st.now and t - (P.last_kick_t or -99) >= ENGAGE.every and t >= (P.engage_pause or 0) then
    local P2, D = st.player_pos, st.drone_pos
    local docked = P2 and D and ((D[1] - P2[1]) ^ 2 + (D[2] - P2[2]) ^ 2) < 1.2 ^ 2
    local reach = st.dog.range and (st.dog.range + 2) ^ 2
    if not docked then
      for _, c in ipairs(st.candidates) do
        if c.visible and (c.eligible or (c.mask == '    ' and c.alive and (c.score or 0) > 0)) and not hide[c.id]
          and (not reach or (c.d2 and c.d2 <= reach)) then
          P.engage_tries = (P.engage_tries or 0) + 1
          if P.engage_tries > ENGAGE.tries then P.engage_tries, P.engage_pause = 0, t + ENGAGE.pause; break end
          return kick({}, 'engage')
        end
      end
    end
  end
  -- 3) it is shooting at something it cannot hurt, or at cover (it keeps firing at an enemy's last known
  --    spot for about a second after losing sight of it): make it choose again among what it can hit
  if st.target ~= 0 and attacking and ((N[st.target] and not P.stuck[st.target]) or (C[st.target] and (not calm or st.node == 7))) then
    return kick({ [st.target] = true }, N[st.target] and 'cannot_hurt' or 'out_of_sight')
  end
  -- (only redirected when there is something in range to go to: with nothing in range the far one just stays
  -- hidden, rather than asking the dog to choose again and again for nothing)
  if st.target ~= 0 and attacking and R[st.target] and not calm and in_range_alt then return kick({ [st.target] = true }, 'out_of_range') end
  if st.target ~= 0 and attacking and S[st.target] then return kick({ [st.target] = true }, 'no_shot') end
  if current and st.node == 7 and P.fire >= BURST.fire and burst_only(st.dog, current) then
    -- (the whole Devastator rests: its body and its shield are separate entries, rest_parts in engine_armor.lua)
    local parts = rest_parts(P.rest, st.candidates, current, t + BURST.rest)
    if TESTER and (P.burst_notes or 0) < 12 then
      P.burst_notes = (P.burst_notes or 0) + 1
      local near = {}
      for _, c in ipairs(st.candidates) do
        if c ~= current and c.pos and current.pos and #near < 5 and (c.pos[1] - current.pos[1]) ^ 2 + (c.pos[2] - current.pos[2]) ^ 2 + (c.pos[3] - current.pos[3]) ^ 2 < 9 then
          near[#near + 1] = string.format('%d %s%s', c.id, c.kind and hexr(c.kind) or '-', P.rest[c.id] and ' (rested)' or '')
        end
      end
      event(string.format('burst done: %s on %d %s; rested with it: %d; within 3 m: %s', st.dog.name, current.id,
        current.kind and hexr(current.kind) or '-', parts, #near > 0 and table.concat(near, ', ') or 'nothing'))
    end
    return kick({ [st.target] = true }, 'burst_done')
  end
  -- 4) it is busy with an enemy well behind a closer one: switch to the closer threat
  if st.target ~= 0 and F[st.target] and not calm and not committed then
    local closer = false
    for _, c in ipairs(st.candidates) do if c.eligible and not hide[c.id] then closer = true; break end end
    if closer then P.need_fire, P.need_fire_from = t, st.target; return kick({ [st.target] = true }, 'closer_threat') end
  end
  -- 5) fast switching (Rover): move on once the burn has been applied
  if st.dog.fast and attacking and (P.fire >= FAST.fire or P.lock >= FAST.lock) then
    local other = pick_other(st, union(U, N, C, R, S), t, current)
    if other and not (other.d2 and other.d2 <= FAST.reach ^ 2 and not recently(other.id, t)) then other = nil end
    if other then
      remember(st.target, t)
      -- hide the one it just burned and the other recently burned ones, as long as something is left to pick
      local block = recent_set()
      local left = false
      for _, c in ipairs(st.candidates) do if c.eligible and not block[c.id] and not hide[c.id] then left = true end end
      if not left then block = {} end
      block[st.target] = true
      -- (a line-up cut short by this switch counts half towards the no-shot rule: the mod moved it on, the enemy
      -- wasn't necessarily out of reach)
      if P.fire < FAST.fire and P.lineup[st.target] then P.lineup[st.target].acc = math.max(0, P.lineup[st.target].acc - 0.5 * P.lock) end
      return kick(block, P.fire >= FAST.fire and 'switch_after_burn' or 'switch_after_lock')
    end
  end
  -- 6) otherwise just keep unsafe (and, near a close threat, far-away) enemies hidden
  return { block = hide, kick = false, reason = unsafe_count > 0 and 'guarding' or nil }
end

-- ======================================================================================================
-- Steering: hide enemies from the dog by blanking their faction mask in its perception record, and
-- expire its target-selection timer when it has to choose again. Every blanked mask is remembered with
-- its original value and put back as soon as it is no longer needed, when the dog changes, and at exit.
-- ======================================================================================================
BLANK = '    '
hidden = {}   -- mask address -> { id, entry, before }
local hidden_key = nil

local function unhide(addr, h)
  local id_now = read(h.entry, 4)
  if id_now and u32(id_now, 0) == h.id and read(addr, 4) == BLANK then
    if not write(addr, h.before) then stats.write_failures = stats.write_failures + 1; return false end
  end
  return true
end

-- (the same bookkeeping serves the dog and each sentry: H maps mask address -> { id, entry, before })
function hider_restore(H)
  local ok = true
  for addr, h in pairs(H) do
    if not unhide(addr, h) then ok = false end
    H[addr] = nil
  end
  return ok
end

-- Riders (4.0): entries that come with a bigger enemy and sit on it - the Scout Strider's pilot (fb9937035d652c43,
-- spawned with its Strider, never a target itself). The game can choose the Strider through its pilot, so a Strider
-- hidden on its own was chosen again and again (test logs: hidden Strider re-picked, its pilot shown next to it).
-- A rider within 3 m of an enemy being hidden is hidden with it.
-- (hider_apply: declared at the top of this file)
do
  local RIDERS = { [type_hash('fb9937035d652c43')] = true }
  local function with_riders(candidates, block)
    local out = block   -- (copied before the first change: the caller's set is left as it was)
    for _, r in ipairs(candidates) do
      if r.kind and RIDERS[r.kind] and r.pos and not block[r.id] then
        for _, v in ipairs(candidates) do
          if v ~= r and v.pos and block[v.id] and (v.pos[1] - r.pos[1]) ^ 2 + (v.pos[2] - r.pos[2]) ^ 2 + (v.pos[3] - r.pos[3]) ^ 2 < 9 then
            if out == block then out = {}; for id in pairs(block) do out[id] = true end end
            out[r.id] = true; break
          end
        end
      end
    end
    return out
  end
hider_apply = function(H, candidates, block)
  -- (nothing hidden and nothing to hide - most frames for an idle dog or sentry: nothing to do)
  if not next(block) and not next(H) then return end
  if next(block) then block = with_riders(candidates, block) end
  local at = {}
  for _, c in ipairs(candidates) do at[c.mask_addr] = c end
  -- entries the game moved or dropped since the last poll
  local moved   -- (built only when something did move)
  for addr, h in pairs(H) do
    local c = at[addr]
    if not c or c.id ~= h.id then moved = moved or {}; moved[h.id] = h; H[addr] = nil end
  end
  if moved then
    for _, c in ipairs(candidates) do
      if c.mask == BLANK and not H[c.mask_addr] and moved[c.id] then
        H[c.mask_addr] = { id = c.id, entry = c.entry, before = moved[c.id].before }
      end
    end
  end
  -- put back what is no longer needed; note masks the game has refreshed on its own
  for addr, h in pairs(H) do
    local c = at[addr]
    if c.mask ~= BLANK then h.before = c.mask end
    if not block[h.id] then unhide(addr, h); H[addr] = nil end
  end
  -- hide what is needed
  for _, c in ipairs(candidates) do
    if block[c.id] and c.mask ~= BLANK then
      local id_now = read(c.entry, 4)
      if id_now and u32(id_now, 0) == c.id and read(c.mask_addr, 4) == c.mask then
        if write(c.mask_addr, BLANK) then H[c.mask_addr] = { id = c.id, entry = c.entry, before = c.mask }
        else stats.write_failures = stats.write_failures + 1 end
      end
    end
  end
end
end

function restore()
  local ok = hider_restore(hidden)
  hidden_key = nil
  return ok
end

function apply(st, block)
  if st.key ~= hidden_key then restore(); hidden_key = st.key end
  hider_apply(hidden, st.candidates, block)
end

local noted = {}
local function note_action(st, req)
  local unsafe = 0
  for _ in pairs(req.block) do unsafe = unsafe + 1 end
  bump(session.actions, req.reason)
  if req.reason == 'no_shot' then
    noted.no_shot = (noted.no_shot or 0) + 1
    local c
    for _, x in ipairs(st.candidates) do if x.id == st.target then c = x end end
    if TESTER and c then
      local d = c.d2 and math.sqrt(c.d2) or -1
      local band = d < 15 and '0-15 m' or (d < 25 and '15-25 m' or (d < 35 and '25-35 m' or '35+ m'))
      bump(session.noshots, string.format('%s %s%s, %s', st.dog.name, c.kind and hexr(c.kind) or '?', c.kind and LABELS[c.kind] and (' ' .. LABELS[c.kind]) or '', band))
    end
    if noted.no_shot > 12 then return end
    local me = st.player_pos
    local where = ''
    if c and c.pos and me then
      local dz = c.pos[3] - me[3]
      where = string.format(', %.0f m from you, %.1f m %s you', math.sqrt((c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + dz ^ 2),
        math.abs(dz), dz < 0 and 'below' or 'above')
    end
    local nm = c and c.kind and ((ARMOR[c.kind] and ARMOR[c.kind].name) or LABELS[c.kind])
    event(string.format('%sno_shot: %s (target %d, type %s%s%s, %s, score %.2f; %s)',
      READ_ONLY and 'would ' or '', st.dog.name, st.target, c and c.kind and hexr(c.kind) or '?', nm and (' ' .. nm) or '', where,
      c and (c.visible and 'in sight' or 'out of sight') or '?', c and c.score or -1,
      st.noshot_new == st.target and string.format('lined up %.1fs without firing, hidden %.0fs', st.noshot_acc or 0, NOSHOT.rest)
        or 'picked again while still set aside'))
    return
  end
  if req.reason == 'cannot_hurt' or req.reason == 'out_of_sight' or req.reason == 'out_of_range' or req.reason == 'closer_threat' then
    -- the first few of each go to the log, with what the enemy was
    noted[req.reason] = (noted[req.reason] or 0) + 1
    if noted[req.reason] > 8 then return end
    local c
    for _, x in ipairs(st.candidates) do if x.id == st.target then c = x end end
    local a = c and c.kind and ARMOR[c.kind]
    event(string.format('%s%s: %s (target %d%s, AI step %d, on it %.1fs%s)', READ_ONLY and 'would ' or '', req.reason, st.dog.name, st.target,
      a and (', ' .. a.name .. ', armour ' .. a.av) or '', st.node, st.target_for or 0,
      c and c.pos and st.player_pos and string.format(', %.0f m from you', math.sqrt((c.pos[1] - st.player_pos[1]) ^ 2 + (c.pos[2] - st.player_pos[2]) ^ 2)) or ''))
    return
  end
  if not req.reason:find('^safety') then return end   -- target switches are too frequent to list one by one
  if (st.unsafe_why and st.unsafe_why[st.target] or ''):find('teammate') then session.team.stops = session.team.stops + 1 end
  local c
  for _, x in ipairs(st.candidates) do if x.id == st.target then c = x end end
  local me = st.player_pos
  local where = ''
  if c and c.pos and me then
    where = string.format(', %.1f m from you', math.sqrt((c.pos[1] - me[1]) ^ 2 + (c.pos[2] - me[2]) ^ 2 + (c.pos[3] - me[3]) ^ 2))
  end
  local gap = st.safe_gap and st.safe_gap[st.target]
  if gap and gap < 50 then where = where .. string.format(', line %.2f m from a body', math.max(gap, 0)) end
  -- (4.5.3 Test 15, test builds) for a look-ahead hold: where the dog was predicted to be, and where it was, in your
  -- own frame (right/left, ahead/behind of you)
  local F = TESTER and st.unsafe_from and st.unsafe_from[st.target]
  if F and me and me.axes and st.drone_pos then
    local function at(p)
      local d = { p[1] - me[1], p[2] - me[2], p[3] - me[3] }
      local r, f = d[1] * me.axes[1][1] + d[2] * me.axes[1][2] + d[3] * me.axes[1][3], d[1] * me.axes[2][1] + d[2] * me.axes[2][2] + d[3] * me.axes[2][3]
      return string.format('%.1f m %s, %.1f m %s', math.abs(r), r >= 0 and 'right' or 'left', math.abs(f), f >= 0 and 'ahead' or 'behind')
    end
    where = where .. ', predicted dog ' .. at(F) .. ' (now ' .. at(st.drone_pos) .. ')'
  end
  event(string.format('%s%s: %s (target %d, %s%s; AI step %d; %d enemies seen, %d hidden)', READ_ONLY and 'would ' or '', req.reason,
    st.dog.name, st.target, st.unsafe_why and st.unsafe_why[st.target] or '?', where, st.node, #st.candidates, unsafe))
end

function steer(st, req)
  if req.kick then note_action(st, req) end
  if READ_ONLY then
    if req.kick then last_reason = 'would ' .. req.reason end
    if next(req.block) then stats.guarded_polls = stats.guarded_polls + 1 end
    return
  end
  if read(st.rec_addr, 4) ~= st.rec_head then return end
  apply(st, req.block)
  if next(req.block) then stats.guarded_polls = stats.guarded_polls + 1 end
  if not req.kick then return end
  last_reason = req.reason
  -- make the dog choose again right away (only when its timer looks sane)
  if st.deadline > st.now and st.deadline - st.now <= 1000000 then
    if not write(st.rec_addr + 152, u64bytes(st.now)) then stats.write_failures = stats.write_failures + 1 end
  end
  local r = req.reason
  if r == 'safety_switch' then stats.safety_switches = stats.safety_switches + 1
  elseif r == 'safety_hold' then stats.holds = stats.holds + 1
  elseif r == 'target_lost' then stats.retargets = stats.retargets + 1
  elseif r == 'out_of_sight' then stats.cover_switches = stats.cover_switches + 1
  elseif r == 'cannot_hurt' then stats.armor_switches = stats.armor_switches + 1
  elseif r == 'no_shot' then stats.noshot_switches = stats.noshot_switches + 1
  else stats.switches = stats.switches + 1 end
end
end
