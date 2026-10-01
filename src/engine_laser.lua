
-- ======================================================================================================
-- Targeting laser (drawn only on your screen): green from the dog to the enemy it is on, flashing red to
-- the enemy it is being kept off because you are in the way. Uses the engine's own line drawing; if that is not
-- available in this game build, the laser simply stays off and the log says why.
-- ======================================================================================================
-- the laser is switched on by the optional 'Targeting laser' part of the mod (a tiny second addon that sets
-- this flag); it is read every frame, so load order does not matter
local function laser_wanted() return rawget(_G, 'SmarterGuardDogsLaser') == true end
local RED_SECONDS = 0.6         -- how long the red warning stays up after the safety steps in
-- (4.0: colours about 25% dimmer than before, a tester's call; the sentries' rings are a little brighter, see
-- engine_sentry.lua)
local GREEN = { 150, 23, 113, 30 }   -- alpha, red, green, blue: laser-pointer green
local RED = { 170, 128, 19, 19 }
local YELLOW = { 170, 173, 150, 15 }   -- a shot stopped because the target went out of sight (cover or smoke)
local LASER_RISE = 0.0               -- metres above the drone's centre where the beam starts
local LASER_FORWARD = 0.45           -- metres out from the drone's centre toward its target (its front face)
local AIM_RISE = 0.5                 -- metres above an enemy's base when not following a barrel (low: most bugs are small);
                                     -- a dog can set its own (the Guard Dog's shots land ~1.2-1.4 m up, measured in game)
local ATTACK_STEPS = { [6] = true, [7] = true }   -- the dog's AI steps for lining up a shot and firing
local FIRE_STEP = 7                               -- the step where it is actually shooting
local FLASH_HZ = 6

local laser = { state = 'not started', worlds = {} }
-- (4.5.3) Laser Brightness (the option's sub-options, or Bingus' Mod Options Menu): a multiplier on every beam's and ring's
-- colour - the lines' red, green and blue (the engine ignores their transparency), the glow's transparency. 1 = as
-- before; read every frame
laser.brightness = function()
  local b = rawget(_G, 'SmarterGuardDogsLaserBrightness')
  if type(b) ~= 'number' or b ~= b then return 1 end
  return math.max(0.1, math.min(3, b))
end
local SR = rawget(_G, 'stingray')

-- (4.0.1) how a beam looks. The engine draws 1-pixel lines, ignores their transparency and renders their colours
-- far brighter than given (Test 2 and 4 screenshots: every green came out as pure neon green), so a beam is a thin core
-- line with a strand 4 mm to either side of it: a real beam's width, which perspective makes about 3 pixels up close
-- and a single pixel far away. (Test 1-4 kept the width constant on screen from an estimate of the camera's position;
-- with you far from the sentry, e.g. dead, that estimate put the strands centimetres apart and the beam split in two.)
-- (4.5) One solid colour from end to end (the 4.0.1-4.0.6 fade toward the far end is gone, a tester's call), and the
-- green is a neon laser-pointer green, (0,200,20). A beam on a target ends in a small cross just in front of the
-- enemy. The line object is depth-tested: walls and terrain hide the beam like a real one.
do
  local BEAM = {
    side = 0.004,     -- the side strands: metres from the core
    dot = 0.03,       -- the cross on the target: its half-size in metres
    dot_back = 0.3,   -- the cross sits this far in front of the aim point (metres, toward the beam's start)
  }
  -- colours (alpha, red, green, blue; the engine ignores the alpha) by the beam's base colour: core, side strands,
  -- the cross on the target
  -- (4.5: green is (0,200,20) throughout, a tester's pick, shown as neon green in game; red and yellow keep
  -- the colour-chart shades a tester picked in 4.0.1: core post 9, sides post 8, cross post 10)
  local NEON = { 255, 0, 200, 20 }
  local STYLE = {
    [GREEN] = { core = NEON, side = NEON, dot = NEON },
    [RED] = { core = { 255, 140, 90, 90 }, side = { 255, 100, 60, 60 }, dot = { 255, 180, 120, 120 } },
    [YELLOW] = { core = { 255, 140, 135, 90 }, side = { 255, 100, 95, 60 }, dot = { 255, 180, 175, 120 } },
  }
  local sqrt = math.sqrt
  -- two unit vectors at right angles to the unit vector d and to each other (the first one level)
  local function perp(dx, dy, dz)
    local ux, uy = -dy, dx
    local l = sqrt(ux * ux + uy * uy)
    if l < 1e-4 then ux, uy, l = 1, 0, 1 end
    ux, uy = ux / l, uy / l
    return ux, uy, 0, -dz * uy, dz * ux, dx * uy - dy * ux
  end
  laser.styled = function(b) return STYLE[b.argb] ~= nil end
  -- adds one styled beam: line(colour, x1, y1, z1, x2, y2, z2) draws one line. 3 lines (the core and two side strands),
  -- plus 2 for the cross; the core goes last, on top
  laser.draw_styled = function(b, line)
    local S = STYLE[b.argb]
    local f, t = b.from, b.to
    local dx, dy, dz = t[1] - f[1], t[2] - f[2], t[3] - f[3]
    local len = sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.05 then return end
    dx, dy, dz = dx / len, dy / len, dz / len
    local ux, uy, uz, vx, vy, vz = perp(dx, dy, dz)
    -- the two strands: one level to the side (u), one above (v), so the beam has width seen from the side or from above
    local w = BEAM.side
    local ax, ay, az, bx, by, bz = ux * w, uy * w, uz * w, vx * w, vy * w, vz * w
    line(S.side, f[1] + ax, f[2] + ay, f[3] + az, t[1] + ax, t[2] + ay, t[3] + az)
    line(S.side, f[1] + bx, f[2] + by, f[3] + bz, t[1] + bx, t[2] + by, t[3] + bz)
    if b.dot then
      -- a small cross at right angles to the beam
      local back = math.min(BEAM.dot_back, len * 0.5)
      local qx, qy, qz = t[1] - dx * back, t[2] - dy * back, t[3] - dz * back
      local r = BEAM.dot
      line(S.dot, qx - ux * r, qy - uy * r, qz - uz * r, qx + ux * r, qy + uy * r, qz + uz * r)
      line(S.dot, qx - vx * r, qy - vy * r, qz - vz * r, qx + vx * r, qy + vy * r, qz + vz * r)
    end
    line(S.core, f[1], f[2], f[3], t[1], t[2], t[3])
  end

end

-- every world the engine reports right now (re-read each frame, so a closed world is never touched again)
local function live_worlds()
  local A = SR and SR.Application
  if type(A) ~= 'table' then return nil, 'no stingray.Application' end
  local list, seen = {}, {}
  local function add(w) if w ~= nil and not seen[w] then seen[w] = true; list[#list + 1] = w end end
  local src = {}
  if type(A.main_world) == 'function' then
    local ok, w = pcall(A.main_world)
    if ok and w ~= nil then laser.world_source = 'main_world()'; return { w } end
  end
  if type(A.worlds) == 'function' then
    local ok, ws = pcall(A.worlds)
    if ok and type(ws) == 'table' then for _, w in pairs(ws) do add(w) end; src[#src + 1] = 'worlds()' end
  end
  for _, n in ipairs({ 'main_world', 'flow_callback_context_world' }) do
    if type(A[n]) == 'function' then local ok, w = pcall(A[n]); if ok and w ~= nil then add(w); src[#src + 1] = n .. '()' end end
  end
  laser.world_source = table.concat(src, ', ')
  if #list == 0 then return nil, 'no world available from stingray.Application' end
  return list
end

local function laser_ready()
  if laser.state == 'off' then return false end
  if laser.state == 'ready' then return true end
  local W, LO = SR and SR.World, SR and SR.LineObject
  if type(W) ~= 'table' or type(W.create_line_object) ~= 'function' or type(LO) ~= 'table'
    or type(LO.add_line) ~= 'function' or type(LO.dispatch) ~= 'function' or type(LO.reset) ~= 'function' then
    laser.state, laser.why = 'off', 'engine line drawing is not available in this game build'
    note('laser: off (' .. laser.why .. ')')
    return false
  end
  -- Vector3 and Color are callable in the engine but may be tables with a __call rather than functions
  local okv, v = pcall(SR.Vector3, 1, 2, 3)
  local okc, c = pcall(SR.Color, 255, 1, 2, 3)
  if not (okv and v ~= nil and okc and c ~= nil) then
    laser.state, laser.why = 'off', 'cannot build engine vectors/colours: ' .. tostring(okv and okc or (not okv and v) or c)
    note('laser: off (' .. laser.why .. ')')
    return false
  end
  laser.state = 'ready'
  -- (test builds: which of the engine's drawing and camera functions this game build offers, for future laser work)
  if TESTER then
    pcall(function()
      local function names(t, pat)
        local out = {}
        if type(t) == 'table' then for k in pairs(t) do if type(k) == 'string' and (not pat or k:lower():find(pat)) then out[#out + 1] = k end end end
        table.sort(out)
        return #out > 0 and table.concat(out, ' ') or '-'
      end
      note('laser (test): LineObject: ' .. names(SR.LineObject))
      note('laser (test): World (line/camera/viewport/debug): ' .. names(SR.World, 'line') .. ' | ' .. names(SR.World, 'camera') .. ' | ' .. names(SR.World, 'viewport') .. ' | ' .. names(SR.World, 'debug'))
      note('laser (test): Gui: ' .. names(SR.Gui) .. ' | World (gui): ' .. names(SR.World, 'gui') .. ' | Material: ' .. names(SR.Material))
      note('laser (test): Camera: ' .. names(SR.Camera) .. ' | Application (camera/viewport): ' .. names(SR.Application, 'camera') .. ' ' .. names(SR.Application, 'viewport'))
    end)
  end
  return true
end

local function laser_fail(err)
  laser.state, laser.why = 'off', tostring(err)
  laser.worlds = {}
  note('laser: stopped after an error: ' .. laser.why)
  event('laser stopped: ' .. laser.why)
end

-- draw this frame's beams (a list of { from, to, argb }) in every live world; an empty list clears them
-- beams: this frame's beams (a list of { from, to, argb }); beams.rings: the sentries' rings, each a list of such segments
-- that a sentry builds once and reuses. (4.0.6) The rings go in a line object of their own that is rebuilt only when
-- the set of rings changes and otherwise just drawn again, instead of 40-80 lines rebuilt every frame. redraw: nothing
-- new this frame (the mod is checking only a few times a second, idle sentries): both line objects are drawn again as
-- they are. An empty list clears everything
local function laser_draw(beams, redraw)
  if not laser_ready() then return end
  local ok, err = pcall(function()
    local worlds, why = live_worlds()
    if not worlds then
      if laser.wait_reason ~= why then laser.wait_reason = why; event('laser waiting: ' .. tostring(why)) end
      return
    end
    local rings = beams.rings
    local LO, V = SR.LineObject, SR.Vector3
    local keep, keep_r = {}, {}
    -- (has the set of rings changed since they were last built?)
    local sig = laser.ring_sig or {}
    local same = not redraw and #(rings or sig) == #sig and (rings ~= nil) == (#sig > 0)
    -- (a new brightness rebuilds the rings too)
    local BR = laser.brightness()
    if not redraw and laser.ring_bright ~= BR then same = false; laser.ring_bright = BR end
    if same and rings then for i, r in ipairs(rings) do if sig[i] ~= r then same = false; break end end end
    for _, w in ipairs(worlds) do
      local lo = laser.worlds[w]
      if not lo and not redraw and (#beams > 0 or rings) then
        lo = SR.World.create_line_object(w, false)
        if not laser.announced then
          laser.announced = true
          note(string.format('laser: on (%d world(s) from %s)', #worlds, laser.world_source or '?'))
          event('laser: on')
        end
      end
      if lo then
        keep[w] = lo
        local colours = {}
        local function colour(a)
          local c = colours[a]
          if not c then
            if BR == 1 then c = SR.Color(a[1], a[2], a[3], a[4])
            else c = SR.Color(a[1], math.min(255, math.floor(a[2] * BR + 0.5)), math.min(255, math.floor(a[3] * BR + 0.5)), math.min(255, math.floor(a[4] * BR + 0.5))) end
            colours[a] = c
          end
          return c
        end
        if not redraw then
          LO.reset(lo)
          -- (each colour is built once per frame)
          local function line(a, x1, y1, z1, x2, y2, z2) LO.add_line(lo, colour(a), V(x1, y1, z1), V(x2, y2, z2)) end
          -- (4.5: with the glow chosen, the dogs' and sentries' beams are left to it)
          local lines = not (laser.glow and laser.glow.on())
          for _, b in ipairs(beams) do
            if laser.styled(b) then if lines then laser.draw_styled(b, line) end   -- the dogs' and sentries' beams: core, side strands, cross
            else LO.add_line(lo, colour(b.argb), V(b.from[1], b.from[2], b.from[3]), V(b.to[1], b.to[2], b.to[3])) end   -- (any other line)
          end
        end
        LO.dispatch(w, lo)
        -- the rings: rebuilt when they change (a ring's segments share their end points: each point is made once)
        local rlo = laser.ring_lo and laser.ring_lo[w]
        if not redraw and (not same or (rings and not rlo)) then
          if rings and not rlo then rlo = SR.World.create_line_object(w, false) end
          if rlo then
            LO.reset(rlo)
            local points = {}
            for _, ring in ipairs(rings or {}) do
              for k = 1, #ring do
                local b = ring[k]
                local f, e = points[b.from], points[b.to]
                if not f then f = V(b.from[1], b.from[2], b.from[3]); points[b.from] = f end
                if not e then e = V(b.to[1], b.to[2], b.to[3]); points[b.to] = e end
                LO.add_line(rlo, colour(b.argb), f, e)
              end
            end
          end
        end
        if rlo then keep_r[w] = rlo; LO.dispatch(w, rlo) end
        if laser.glow then laser.glow.draw(w, beams, redraw) end
        if #beams > 0 or rings then stats.laser_frames = stats.laser_frames + 1 end
      end
    end
    if not redraw and not same then
      local copy = {}
      for i, r in ipairs(rings or {}) do copy[i] = r end
      laser.ring_sig = copy
    end
    laser.worlds, laser.ring_lo = keep, keep_r   -- line objects of worlds that went away are simply forgotten, never touched
    if not redraw then laser.has = #beams > 0 or rings ~= nil end
  end)
  if not ok then laser_fail(err) end
end

local function laser_clear()
  if laser.state == 'ready' and next(laser.worlds) then laser_draw({}) end
end
-- (4.0.6) on the frames the mod doesn't look at the game (idle sentries, a few checks a second): the laser as it was
do
  local NO_BEAMS = {}
  laser.redraw = function()
    if laser.has and laser.state == 'ready' and next(laser.worlds) then laser_draw(NO_BEAMS, true) end
  end
end

-- (4.5) the glow, chosen under Targeting Laser ('Glow'; 'Line', the default, leaves the beams as the lines above): the
-- dogs' and sentries' beams drawn as see-through strips (triangles in a world GUI) instead of 1-pixel lines - a narrow
-- bright core inside a wide faint halo, each two crossed strips (one level, one standing up), fading out toward the far
-- end by transparency, with a small bright spot on the target. A tester's pick (4.0.6 Test 2), back as a choice: the
-- game's GUI draws on top of the world (its GUI code switches its gui:DEPTH_TEST_ENABLED flag off; Gui.rect_3d was no
-- different, 4.0.6 Test 10; no GUI material could switch it back on, Test 18), and HD2 has no Lua raycasts to hide it
-- where a wall is in the way, so the glow shows through walls - the options say so. The rings stay lines. If the world
-- GUI can't be made, the beams go back to the lines (noted once in the log)
do
  local G = { guis = {}, ids = {} }   -- per world: its GUI, and (retained GUI) the triangles drawn last frame
  laser.glow = G
  -- alpha, red, green, blue by the beam's colour: the narrow core, the wide halo, the spot on the target
  local LOOK = {
    [GREEN] = { core = { 210, 110, 255, 130 }, halo = { 55, 60, 255, 90 }, dot = { 230, 170, 255, 170 } },
    [RED] = { core = { 210, 255, 90, 80 }, halo = { 55, 255, 50, 40 }, dot = { 230, 255, 160, 150 } },
    [YELLOW] = { core = { 210, 255, 230, 90 }, halo = { 55, 255, 210, 50 }, dot = { 230, 255, 240, 160 } },
  }
  local WIDTH = { core = 0.006, halo = 0.03 }   -- half-widths in metres
  local PIECES, FADE_TO, SPOT = 10, 0.3, 0.03   -- alpha falls to this share at the far end; the spot's half-size
  local PARTS = { 'halo', 'core' }              -- (the core drawn last, on top)
  local LOOKS = {}
  for base, c in pairs(LOOK) do
    local S = { dot = c.dot }
    for _, part in ipairs(PARTS) do
      local steps = {}
      for k = 1, PIECES do
        local f = 1 + (FADE_TO - 1) * (k - 0.5) / PIECES
        steps[k] = { math.floor(c[part][1] * f + 0.5), c[part][2], c[part][3], c[part][4] }
      end
      S[part] = steps
    end
    LOOKS[base] = S
  end

  local function off(why)
    G.off = true
    note('laser: glow off, the beams are lines (' .. why .. ')'); event('laser: glow off: ' .. why)
  end
  -- whether this game build has what the glow needs (checked once; missing switches the glow off)
  local function usable()
    if G.usable == nil then
      local W, Gui, M = SR and SR.World, SR and SR.Gui, SR and SR.Matrix4x4
      G.usable = type(W) == 'table' and type(W.create_world_gui) == 'function' and type(Gui) == 'table'
        and type(Gui.triangle) == 'function' and type(M) == 'table' and type(M.identity) == 'function'
      if not G.usable then off('no world GUI in this game build') end
    end
    return G.usable
  end
  -- true when the beams are the glow's (chosen, and it works)
  G.on = function() return rawget(_G, 'SmarterGuardDogsGlow') == true and not G.off and usable() end

  local sqrt = math.sqrt
  local function perp(dx, dy, dz)
    local ux, uy = -dy, dx
    local l = sqrt(ux * ux + uy * uy)
    if l < 1e-4 then ux, uy, l = 1, 0, 1 end
    ux, uy = ux / l, uy / l
    return ux, uy, 0, -dz * uy, dz * ux, dx * uy - dy * ux
  end
  local A3 = { {}, {}, {} }   -- (the spot's three axes, reused)

  -- this frame's glow in world w (inside laser_draw's protection; its own errors switch only the glow off)
  local function draw(w, beams)
    local Gui, V = SR.Gui, SR.Vector3
    local g = G.guis[w]
    if not g then
      local W, M = SR.World, SR.Matrix4x4
      local errs = {}
      for _, flags in ipairs({ { 'immediate' }, {} }) do
        local okc, r = pcall(W.create_world_gui, w, M.identity(), 1, 1, unpack(flags))
        if okc and r ~= nil then g, G.immediate = r, flags[1] == 'immediate'; break end
        errs[#errs + 1] = (flags[1] or 'no flags') .. ': ' .. tostring(r)
      end
      if not g then return off('create_world_gui failed: ' .. table.concat(errs, '; ')) end
      G.guis[w] = g   -- (a world that went away takes its GUI with it: never touched again)
      note('laser: glow on (' .. (G.immediate and 'immediate' or 'retained') .. ' world GUI)')
    end
    -- a retained GUI keeps what was drawn: last frame's pieces go first
    local ids = G.ids[w]
    if not G.immediate and ids and #ids > 0 then
      for _, id in ipairs(ids) do pcall(Gui.destroy_triangle, g, id) end
      ids = nil
    end
    if not G.immediate then ids = {}; G.ids[w] = ids end
    if #beams == 0 then return end
    local colours = {}
    local layered = G.layered
    local keep = ids
    local tri_fn = Gui.triangle
    local BR = laser.brightness()
    local function tri(p0, p1, p2, a)
      local c = colours[a]
      if not c then c = SR.Color(math.min(255, math.floor(a[1] * BR + 0.5)), a[2], a[3], a[4]); colours[a] = c end
      local id
      if layered then id = tri_fn(g, p0, p1, p2, 1, c)
      elseif layered == false then id = tri_fn(g, p0, p1, p2, c)
      else
        -- (the first triangle: with the layer argument, or without it)
        local ok1, r1 = pcall(tri_fn, g, p0, p1, p2, 1, c)
        if ok1 then layered, id = true, r1
        else
          local ok2, r2 = pcall(tri_fn, g, p0, p1, p2, c)
          if not ok2 then error('Gui.triangle failed: ' .. tostring(r1) .. ' / without the layer: ' .. tostring(r2)) end
          layered, id = false, r2
        end
        G.layered = layered
      end
      if keep and id ~= nil then keep[#keep + 1] = id end
    end
    for _, b in ipairs(beams) do
      local S = laser.styled(b) and LOOKS[b.argb]
      local f, e = b.from, b.to
      local dx, dy, dz = e[1] - f[1], e[2] - f[2], e[3] - f[3]
      local len = S and sqrt(dx * dx + dy * dy + dz * dz) or 0
      if len >= 0.05 then
        dx, dy, dz = dx / len, dy / len, dz / len
        local ux, uy, uz, vx, vy, vz = perp(dx, dy, dz)
        for _, part in ipairs(PARTS) do
          local wd, steps = WIDTH[part], S[part]
          for pass = 1, 2 do   -- a strip lying level, then one standing up
            local ax, ay, az = ux * wd, uy * wd, uz * wd
            if pass == 2 then ax, ay, az = vx * wd, vy * wd, vz * wd end
            local pa, pb = V(f[1] + ax, f[2] + ay, f[3] + az), V(f[1] - ax, f[2] - ay, f[3] - az)
            for k = 1, PIECES do
              local s = len * k / PIECES
              local x, y, z = f[1] + dx * s, f[2] + dy * s, f[3] + dz * s
              local na, nb = V(x + ax, y + ay, z + az), V(x - ax, y - ay, z - az)
              local col = steps[k]
              tri(pa, na, nb, col); tri(pa, nb, pb, col)
              pa, pb = na, nb
            end
          end
        end
        if b.dot then
          -- a small bright spot just in front of the target: three crossed squares
          local back = math.min(0.3, len * 0.5)
          local qx, qy, qz = e[1] - dx * back, e[2] - dy * back, e[3] - dz * back
          A3[1][1], A3[1][2], A3[1][3] = dx * SPOT, dy * SPOT, dz * SPOT
          A3[2][1], A3[2][2], A3[2][3] = ux * SPOT, uy * SPOT, uz * SPOT
          A3[3][1], A3[3][2], A3[3][3] = vx * SPOT, vy * SPOT, vz * SPOT
          for i = 1, 3 do
            local p, q = A3[i], A3[i % 3 + 1]
            local c1 = V(qx - p[1] - q[1], qy - p[2] - q[2], qz - p[3] - q[3])
            local c2 = V(qx + p[1] - q[1], qy + p[2] - q[2], qz + p[3] - q[3])
            local c3 = V(qx + p[1] + q[1], qy + p[2] + q[2], qz + p[3] + q[3])
            local c4 = V(qx - p[1] + q[1], qy - p[2] + q[2], qz - p[3] + q[3])
            tri(c1, c2, c3, S.dot); tri(c1, c3, c4, S.dot)
          end
        end
      end
    end
  end
  -- redraw: a frame the mod skipped (idle sentries) - the last frame's beams again (an immediate GUI draws only what it
  -- is given each frame)
  G.draw = function(w, beams, redraw)
    if not G.on() then return end
    -- (a retained GUI still holds the last frame's triangles: nothing to do on a redraw)
    if redraw and G.guis[w] and not G.immediate then return end
    if redraw then beams = G.last or beams else G.last = beams end
    local ok, err = pcall(draw, w, beams)
    if not ok then off(tostring(err)) end
  end
end

-- ------------------------------------------------------------------------------------------------------
-- Where the gun actually points. The drone's parts (body, yaw ring, pitch arm, gun mount) each have a
-- world pose right after the drone's own in the engine's pose array. While the dog fires at an enemy
-- in plain view, every part's axes are scored against the direction to that enemy; the part and axis
-- that track it best is the barrel. From then on the laser follows the barrel, so it ends exactly where
-- the gun is aimed, and falls back to "drone to enemy" until then or if the barrel can't be read.
-- ------------------------------------------------------------------------------------------------------
-- min_cos: how closely a part must track the enemy to count as the barrel (0.997 = within ~4 degrees on
-- average); keep_cos: below this, while firing at an enemy in plain view, the part is dropped and the search
-- starts again; off: the laser end may sit at most this far (metres, or this share of the distance) from the
-- enemy, otherwise it falls back to pointing straight at it
local GUN = { nodes = 40, reach = 2.5, frames = 24, min_cos = 0.997, keep_cos = 0.985, min_range = 8, off = 1.5, off_share = 0.06 }
local gun = {}     -- per dog name: { sums = {}, n = 0, node, axis, sign, tries }

local function parse_node(m, o, root)
  local x, y, z = f32(m, o + 48), f32(m, o + 52), f32(m, o + 56)
  if not (x == x and y == y and z == z and (x - root[1]) ^ 2 + (y - root[2]) ^ 2 + (z - root[3]) ^ 2 < GUN.reach ^ 2) then return nil end
  local axes = {}
  for r = 0, 2 do
    local a = { f32(m, o + r * 16), f32(m, o + r * 16 + 4), f32(m, o + r * 16 + 8) }
    local len = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
    if not (len > 0.5 and len < 2) then return nil end
    axes[r + 1] = { a[1] / len, a[2] / len, a[3] / len }
  end
  return { pos = { x, y, z }, axes = axes }
end

-- every part's pose while learning which one is the barrel; afterwards just the barrel's (one small read)
local function read_nodes(pose, root, only)
  if only then
    local m = read(pose + 64 * only, 64)
    local nd = m and parse_node(m, 0, root)
    return nd and { [only] = nd } or nil
  end
  local n, m = GUN.nodes, nil
  while n >= 8 and not m do m = read(pose, 64 * n); if not m then n = n - 8 end end
  if not m then return nil end
  local nodes = {}
  for i = 0, n - 1 do nodes[i] = parse_node(m, 64 * i, root) end
  return nodes
end

local function gun_learn(g, nodes, aim)
  for i, nd in pairs(nodes) do
    local v = { aim[1] - nd.pos[1], aim[2] - nd.pos[2], aim[3] - nd.pos[3] }
    local len = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
    for r = 1, 3 do
      local a = nd.axes[r]
      local cos = (a[1] * v[1] + a[2] * v[2] + a[3] * v[3]) / len
      local k = i * 6 + (r - 1) * 2
      g.sums[k] = (g.sums[k] or 0) + cos
      g.sums[k + 1] = (g.sums[k + 1] or 0) - cos
    end
  end
  g.n = g.n + 1
  if g.n < GUN.frames then return end
  local best, bk
  for k, sum in pairs(g.sums) do if not best or sum > best then best, bk = sum, k end end
  g.tries = (g.tries or 0) + 1
  if not best then
    if g.tries <= 3 then note('laser: no barrel found for ' .. g.name .. ' yet (no readable parts)') end
    g.sums, g.n = {}, 0
    return
  end
  local mean = best / g.n
  if mean >= GUN.min_cos then
    g.node, g.axis, g.sign = math.floor(bk / 6), math.floor((bk % 6) / 2) + 1, bk % 2 == 0 and 1 or -1
    note(string.format('laser: barrel found for %s (part %d, axis %d%s, match %.3f)', g.name, g.node, g.axis, g.sign > 0 and '+' or '-', mean))
    event('laser: following the barrel of the ' .. g.name)
  elseif g.tries <= 3 then
    note(string.format('laser: no barrel found for %s yet (best match %.3f)', g.name, mean))
  end
  g.sums, g.n = {}, 0
end

-- the point the barrel is aimed at, level with the enemy (nil if unknown)
local function gun_point(st, to, learn)
  local D = st.drone_pos
  if not (D and D.pose) then return nil end
  local g = gun[st.dog.name]
  if not g then g = { name = st.dog.name, sums = {}, n = 0 }; gun[st.dog.name] = g end
  if not g.node and (g.tries or 0) >= 6 then return nil end
  local nodes = read_nodes(D.pose, D, g.node)
  if not nodes then return nil end
  if not g.node then
    if learn then gun_learn(g, nodes, to) end
    return nil
  end
  local nd = nodes[g.node]
  if not nd then return nil end
  local a = nd.axes[g.axis]
  local dir = { a[1] * g.sign, a[2] * g.sign, a[3] * g.sign }
  local v = { to[1] - nd.pos[1], to[2] - nd.pos[2], to[3] - nd.pos[3] }
  local len = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  local s = v[1] * dir[1] + v[2] * dir[2] + v[3] * dir[3]
  if learn and len > 0 then
    -- keep checking the choice while the dog fires at enemies in plain view; a part that only roughly
    -- follows the aim (a body or mount rather than the barrel) is dropped and the search starts over
    g.check, g.check_n = (g.check or 0) + s / len, (g.check_n or 0) + 1
    if g.check_n >= GUN.frames then
      local mean = g.check / g.check_n
      g.check, g.check_n = 0, 0
      if mean < GUN.keep_cos then
        note(string.format('laser: part %d of the %s stopped matching its aim (%.3f), looking again', g.node, g.name, mean))
        g.node = nil
        return nil
      end
    end
  end
  if s < 1 then return nil end
  -- (4.5.3, a tester's call: the laser comes out of the barrel and runs along it, as far as the enemy, wherever the
  -- barrel points; before, it fell back to pointing at the enemy when the barrel was off. Also returned: where the
  -- beam starts (the barrel part) and whether its end is on the enemy, for the cross)
  local p = { nd.pos[1] + dir[1] * len, nd.pos[2] + dir[2] * len, nd.pos[3] + dir[3] * len }
  local off = math.sqrt((p[1] - to[1]) ^ 2 + (p[2] - to[2]) ^ 2 + (p[3] - to[3]) ^ 2)
  return p, nd.pos, off <= math.max(GUN.off, GUN.off_share * len)
end

-- what to show for this frame
local DOCKED = 1.2   -- metres (level) between the drone and you: it has flown back to the backpack to reload

-- adds the dog's beam (if any) to 'beams'; the main loop draws the dog's and the sentries' beams together
local function laser_frame(st, beams, safety_t, safety_enemy, safety_step, cover_t, cover_enemy, cover_step)
  local D = st.drone_pos
  if not D then return end
  -- no laser at all while the drone sits on your back reloading
  local me = st.player_pos
  if me and (D[1] - me[1]) ^ 2 + (D[2] - me[2]) ^ 2 < DOCKED ^ 2 then return end
  -- (an enemy by id, looked up only when a beam is drawn)
  local function by_id(id) for _, c in ipairs(st.candidates) do if c.id == id then return c end end end
  local t = os.clock()
  -- the beam leaves its barrel when that is known (from: the barrel part; on: its end is on the enemy, for the cross),
  -- otherwise the front of the drone, facing whatever it points at
  local function beam(to, argb, from, on)
    if from then
      beams[#beams + 1] = { from = from, to = to, argb = argb, dot = argb == GREEN and on ~= false }
      return
    end
    local dx, dy, dz = to[1] - D[1], to[2] - D[2], to[3] - (D[3] + LASER_RISE)
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < LASER_FORWARD + 0.5 then return end
    local k = LASER_FORWARD / len
    -- (a dot where it hits: only on the enemy it is firing at)
    beams[#beams + 1] = { from = { D[1] + dx * k, D[2] + dy * k, D[3] + LASER_RISE + dz * k }, to = to, argb = argb, dot = argb == GREEN }
  end
  -- red only for a shot the safety actually stopped (it stepped in while the dog was lining up or firing),
  -- and not once the dog has gone on to something else such as reloading
  local warn = safety_t and t - safety_t < RED_SECONDS and ATTACK_STEPS[safety_step]
    and (ATTACK_STEPS[st.node] or st.target == 0)
  if warn then
    local e = by_id(safety_enemy)
    local on = math.floor((t - safety_t) * FLASH_HZ * 2) % 2 == 0
    if e and e.pos and on then
      local to = { e.pos[1], e.pos[2], e.pos[3] + (st.dog.aim_rise or AIM_RISE) }
      local gp, gfrom = gun_point(st, to, false)
      beam(gp or to, RED, gp and gfrom)
    end
  elseif cover_t and t - cover_t < RED_SECONDS and ATTACK_STEPS[cover_step] and (ATTACK_STEPS[st.node] or st.target == 0)
    and st.target ~= cover_enemy then
    -- flashing yellow toward the enemy it just stopped shooting at because it dropped out of sight (behind cover
    -- or in smoke: the game doesn't tell the two apart), until the dog is busy with its next target. (4.0.6 Test 6
    -- tried flashing green: it blended in with the firing beam, a tester's call)
    local e = by_id(cover_enemy)
    local on = math.floor((t - cover_t) * FLASH_HZ * 2) % 2 == 0
    if e and e.pos and on and st.node ~= FIRE_STEP then beam({ e.pos[1], e.pos[2], e.pos[3] + (st.dog.aim_rise or AIM_RISE) }, YELLOW) end
    if st.target ~= 0 and st.node == FIRE_STEP then
      local e2 = by_id(st.target)
      if e2 and e2.pos then beam({ e2.pos[1], e2.pos[2], e2.pos[3] + (st.dog.aim_rise or AIM_RISE) }, GREEN) end
    end
  elseif st.target ~= 0 and st.node == FIRE_STEP then   -- green only while it is actually firing
    local e = by_id(st.target)
    if e and e.pos then
      local to = { e.pos[1], e.pos[2], e.pos[3] + (st.dog.aim_rise or AIM_RISE) }
      local far = e.d2 and e.d2 > GUN.min_range ^ 2
      local gp, gfrom, gon = gun_point(st, to, e.visible and far)
      laser.last_gun, laser.last_to = gp, to     -- (the research log compares the two)
      beam(gp or to, GREEN, gp and gfrom, gon)
    end
  end
end
