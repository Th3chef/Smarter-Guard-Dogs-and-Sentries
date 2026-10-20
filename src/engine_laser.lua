
-- ======================================================================================================
-- Targeting laser (drawn only on your screen). (5.0, my colors) red from the gun to the enemy it is firing at,
-- amber while it is locked on but not firing yet (lining up, turning), flashing green to the enemy it is being kept
-- off because a friendly (you, a teammate, a sentry, a SEAF soldier or civilian) is in the way, gray when it lost
-- sight of its target. Uses the engine's own line drawing; if that is not
-- available in this game build, the laser simply stays off and the log says why.
-- ======================================================================================================
-- the laser is switched on by the optional 'Targeting laser' part of the mod (a tiny second addon that sets
-- this flag); it is read every frame, so load order does not matter
-- ((5.0 Test 13) the drawing runs for the Targeting Laser or the Targeting Marker option: the two are separate options, see
-- laser.step in engine_main.lua for what each keeps)
local function laser_wanted() return rawget(_G, 'SmarterGuardDogsLaser') == true or rawget(_G, 'SmarterGuardDogsMarker') == true end
local RED_SECONDS = 0.6         -- how long the red warning stays up after the safety steps in
-- (4.0: colors about 25% dimmer than before, a tester's call; the sentries' rings are a little brighter, see
-- engine_sentry.lua)
-- (5.0) the beam's meaning (each table is the key the drawing looks its look up by; alpha, red, green, blue)
local FIRE = { 255, 220, 16, 12 }     -- firing at an enemy: red
local FRIEND = { 255, 0, 200, 20 }    -- held off an enemy because a friendly is in the way: green (flashing)
-- ((5.1.0 Test 1, my ask: "make the laser inversion an option. Put it back to how I had it, and make it an option I can
-- change" - "suboptions under targeting laser") the '... green while firing' choices under Targeting Laser set this flag:
-- firing green and the safety's flashing beam red, as before 5.0. The tables above stay the keys; only the look swaps)
local LOST = { 255, 150, 150, 150 }   -- a shot stopped because the target went out of sight (cover or smoke): gray
local LOCK = { 255, 230, 140, 0 }     -- locked on, not firing yet (lining up, turning onto it): amber
local LASER_RISE = 0.0               -- meters above the drone's center where the beam starts
local LASER_FORWARD = 0.45           -- meters out from the drone's center toward its target (its front face)
local AIM_RISE = 0.5                 -- meters above an enemy's base when not following a barrel (low: most bugs are small);
                                     -- a dog can set its own (the Guard Dog's shots land ~1.2-1.4 m up, measured in game)
local ATTACK_STEPS = { [6] = true, [7] = true }   -- the dog's AI steps for lining up a shot and firing
local FIRE_STEP = 7                               -- the step where it is actually shooting (6: lining it up)
local FLASH_HZ = 6

local laser = { state = 'not started', worlds = {},
  -- (4.6.7 Test 1, my note: the Rover's laser shook while it aimed) seconds: how quickly a dog's beam end catches up
  -- with where it should point (as BEAM_SMOOTH does for the sentries since 5.0 Test 14; the dogs had none)
  dog_smooth = 0.1, dog_beam = {} }
-- ((5.0 Test 9, my note: the markers "need to move more in real time like actual pings"; the laser "sometimes floating
-- in front of the enemies") an enemy's place as the game draws it this frame - its unit's root - instead of the copy in
-- the gun's perception record, which the AI refreshes only ~6 times a second (the Test 8 probe: a gunship's place held
-- still every other sample). The perception copy when the unit can't be read
laser.live = function(c)
  local e = c and c.ent
  if e then
    local p = unit_position(u32(e, 12))
    if p then return p end
  end
  return c and c.pos
end
-- ((5.0 Test 9) how far into the enemy a beam fixed on a barrel runs past the point nearest its centre: the line is
-- depth-tested, so its visible end is where it meets the enemy's body)
laser.INTO = 0.4
-- ((5.1.5 Test 22, my note: "some enemies I've seen the laser above their heads") the beam runs along the barrel, and a
-- barrel pitched up for a long shot - or a short enemy under the beam's usual height - had it pass over the enemy's
-- head. When the beam's end is beside the enemy (within its width) but above its top, the end comes down onto its upper
-- body; a beam off to the side stays as it is. Tops (meters above the feet) by enemy name, 2 m when unknown; 0 = flying
-- or huge, left alone (laser.kind_name is set by the sentry code, which knows the armor table)
local LASER_TOPS = {
  { 'Bile Titan', 9 }, { 'Factory Strider', 12 }, { 'War Strider', 6 }, { 'Scout Strider', 4.2 }, { 'Harvester', 7 },
  { 'Tank', 3.2 }, { 'Hulk', 3.4 }, { 'Charger', 3.0 }, { 'Impaler', 3.5 }, { 'Spewer', 2.6 }, { 'Commander', 2.4 },
  { 'Hive Guard', 1.8 }, { 'Warrior', 1.6 }, { 'Hunter', 1.1 }, { 'Scavenger', 0.8 }, { 'Pouncer', 1.0 }, { 'Stalker', 2.8 },
  { 'Berserker', 2.4 }, { 'Devastator', 2.6 }, { 'Overseer', 2.6 }, { 'Fleshmob', 2.8 }, { 'Crescent', 2.6 },
  { 'Voteless', 1.8 }, { 'Gatekeeper', 3.2 }, { 'Veracitor', 3.5 }, { 'Emplacement', 2.5 },
  { 'Gunship', 0 }, { 'Dropship', 0 }, { 'Stingray', 0 }, { 'Warp Ship', 0 }, { 'Leviathan', 0 }, { 'Watcher', 0 },
  { 'Elevated', 0 }, { 'Shrieker', 0 }, { 'Dragonroach', 0 }, { 'Hive Lord', 0 }, { 'Vox Engine', 0 },
}
local LASER_TOP = { n = 0 }
laser.top_of = function(kind)
  if not kind then return 2.0 end
  local v = LASER_TOP[kind]
  if v then return v end
  v = 2.0
  local nm = laser.kind_name and laser.kind_name(kind)
  if nm then for _, e in ipairs(LASER_TOPS) do if nm:find(e[1], 1, true) then v = e[2]; break end end end
  if LASER_TOP.n < 500 then LASER_TOP[kind], LASER_TOP.n = v, LASER_TOP.n + 1 end
  return v
end
laser.fit_end = function(e, c)
  local p = e and c and c.pos and laser.live(c)
  if not p then return e end
  local T = laser.top_of(c.kind)
  if T <= 0 or e[3] <= p[3] + T then return e end
  local dx, dy, w = e[1] - p[1], e[2] - p[2], math.max(1.2, 0.4 * T)
  if dx * dx + dy * dy > w * w then return e end
  return { e[1], e[2], p[3] + T * 0.6 }
end
laser.MARK_SETTLE = 0.25   -- ((5.1.0 Test 1) seconds a dog keeps a target before its marker shows over it
-- (4.5.3) Laser Brightness (the option's sub-options, or Bingus' Mod Options Menu): a multiplier on every beam's and ring's
-- color - the lines' red, green and blue (the engine ignores their transparency), the glow's transparency. 1 = as
-- before; read every frame
-- (5.0 Test 15, my ask: "add targeting marker opacity as well, in case people want to tune how it appears") the Marker
-- Opacity option (its sub-options, or the Mod Options Menu): a multiplier on the markers' transparency. 1 = as designed
laser.marker_opacity = function()
  local o = rawget(_G, 'SmarterGuardDogsMarkerOpacity')
  if type(o) ~= 'number' or o ~= o then return 1 end
  return math.max(0.1, math.min(1, o))
end
-- (5.1.0 Test 1, my ask: "Add an option in the options menu to adjust the size of the targeting marker") the Marker
-- Size option (its sub-options, or the Mod Options Menu): a multiplier on the markers' size. 1 = as designed
laser.marker_size = function()
  local o = rawget(_G, 'SmarterGuardDogsMarkerSize')
  if type(o) ~= 'number' or o ~= o then return 1 end
  return math.max(0.25, math.min(3, o))
end
laser.inverted = function() return rawget(_G, 'SmarterGuardDogsLaserInvert') == true end
laser.brightness = function()
  local b = rawget(_G, 'SmarterGuardDogsLaserBrightness')
  if type(b) ~= 'number' or b ~= b then return 1 end
  return math.max(0.1, math.min(3, b))
end
local SR = rawget(_G, 'stingray')

-- (4.0.1) how a beam looks. The engine draws 1-pixel lines, ignores their transparency and renders their colors
-- far brighter than given (Test 2 and 4 screenshots: every green came out as pure neon green), so a beam is a thin core
-- line with a strand 4 mm to either side of it: a real beam's width, which perspective makes about 3 pixels up close
-- and a single pixel far away. (Test 1-4 kept the width constant on screen from an estimate of the camera's position;
-- with you far from the sentry, e.g. dead, that estimate put the strands centimeters apart and the beam split in two.)
-- (4.5) One solid color from end to end (the 4.0.1-4.0.6 fade toward the far end is gone, a tester's call), and the
-- green is a neon laser-pointer green, (0,200,20). A beam on a target ends in a small cross just in front of the
-- enemy. The line object is depth-tested: walls and terrain hide the beam like a real one.
do
  -- (5.0 Test 5, my note: Test 4's thick beam "looks super cartoony") a laser's look: one hot core line inside four
  -- strands 3 mm out in the beam's own color (no darker edge: the engine draws lines solid, so a dim edge only made a
  -- dark outline), ending in a small bright cross on the enemy. Only firing and safety holds have a beam; locked on
  -- (about to fire) and target lost are a marker over the enemy instead, like the game's ping. Every beam and marker
  -- fades with its distance from you (FADE: full up to 'near' m, down to 'low' at 'far' m and beyond)
  -- (5.0 Test 6, my ask: "less intense", like a real laser - a thin line with a soft glow and a bright point where
  -- it leaves the gun) the strands are dimmer than the core, the core is only lightly whitened, and a small star
  -- marks the emitter. The marker is the gun's own stratagem icon ("I won't know what sentry/dog it is"), facing you
  -- and kept about the same size on screen at any distance, over a small chevron pointing at the enemy
  local BEAM = {
    inner = 0.003, strands = 0,   -- ((5.0 Test 8) no strands: lines 3 mm apart broke the beam into dashes on screen)
    dot = 0.035, dot_back = 0.08,   -- the cross on the target: its half-size, and how far in front of the end
    flare = 0.045, flare_v = 0.028,  -- the star at the emitter: its half-width and half-height (meters)
    mark_up = 1.0,                   -- the chevron's point, over the enemy's aim point (meters)
    icon_per_m = 0.05, icon_min = 0.5, icon_max = 7.0,   -- ((5.1.5 Test 30: "the mortar marker still sometimes doesnt show at range") was 3.5: past 70 m the marker shrank (17 px at a mortar's 125 m); the same size on screen now to 140 m
      -- ((5.0 Test 8) about 40 px at 1080p, was 30)   -- the icon's height: this much per meter from you, within these
    icon_scale = 0.75,               -- ((5.2, my ask: "make the default size of the in-game markers 25% smaller") about 30 px at 1080p; Marker Size multiplies this
  }
  local FADE = { near = 25, far = 70, low = 0.45, steps = 4 }
  laser.fade_of = function(from)
    local me = laser.me
    if not me then return 1 end
    local d = math.sqrt((from[1] - me[1]) ^ 2 + (from[2] - me[2]) ^ 2 + (from[3] - me[3]) ^ 2)
    if d <= FADE.near then return 1 end
    local f = math.max(FADE.low, 1 - (1 - FADE.low) * (d - FADE.near) / (FADE.far - FADE.near))
    return math.floor(f * FADE.steps + 0.5) / FADE.steps   -- (a few levels only: each is a color made once)
  end
  -- colors (alpha, red, green, blue; the engine ignores the alpha) by the beam's base color: core, side strands,
  -- the cross on the target
  -- (4.5: green is (0,200,20) throughout, a tester's pick, shown as neon green in game; red and yellow keep
  -- the color-chart shades a tester picked in 4.0.1: core post 9, sides post 8, cross post 10)
  -- core, inner strands, outer (soft edge) strands, the ring and dot on the target
  local function shade(c, k) return { c[1], math.floor(c[2] * k + 0.5), math.floor(c[3] * k + 0.5), math.floor(c[4] * k + 0.5) } end
  -- (the core whitened a little: a laser's hottest line; the strands dimmer, the glow round it. Test 6: less whitening
  -- (35% before) and dimmer strands (the pure color before) - "the lasers should be less intense". 'body': the icon's
  -- sentry or backpack, half as bright as its weapon glyph, the HUD icon's two tones)
  local function look(c, k)
    local a = shade(c, k)
    local w = { a[1], math.floor(a[2] + (255 - a[2]) * 0.12), math.floor(a[3] + (255 - a[3]) * 0.12), math.floor(a[4] + (255 - a[4]) * 0.12) }
    return { core = w, side = shade(c, k * 0.72), dot = w, body = shade(c, k * 0.5) }
  end
  local STYLE = {
    [FIRE] = look(FIRE, 0.9), [FRIEND] = look(FRIEND, 0.9),
    [LOST] = look(LOST, 0.8), [LOCK] = look(LOCK, 1),
  }
  -- ((5.1.0 Test 1) the swapped colors: firing in the safety's green, the safety's beam in the firing red)
  local STYLE_INV = { [FIRE] = STYLE[FRIEND], [FRIEND] = STYLE[FIRE], [LOST] = STYLE[LOST], [LOCK] = STYLE[LOCK] }
  -- the icons (icon_data.lua), unpacked once: per icon its glyph and body as flat lists of (height, left, right),
  -- the height 0..1 from the bottom and the sides -0.5..0.5 across
  local ICONS = {}
  do
    local val = {}
    for k = 1, #ICON_DATA.abc do val[ICON_DATA.abc:sub(k, k)] = k - 1 end
    local R, C = ICON_DATA.rows, ICON_DATA.cols
    local function unpack_runs(str)
      local out = {}
      for k = 1, #str - 2, 3 do
        out[#out + 1] = (val[str:sub(k, k)] + 0.5) / R
        out[#out + 1] = val[str:sub(k + 1, k + 1)] / C - 0.5
        out[#out + 1] = val[str:sub(k + 2, k + 2)] / C - 0.5
      end
      return out
    end
    -- ((5.1.0 Test 1, my ask: "clean up the marker a bit, its kind of low-resolution") the icons as filled shapes
    -- (tools/icons_vec.py): triangles traced from the 256-pixel HUD icons, smooth edges at any size, and a rounded dark
    -- edge. Each triangle six numbers (across, up), turned counterclockwise as the band quads are)
    local vval = {}
    if ICON_DATA.vabc then for k = 1, #ICON_DATA.vabc do vval[ICON_DATA.vabc:sub(k, k)] = k - 1 end end
    -- ((5.1.0 release review) each corner once - the triangles share most of them - and the triangles as three corner
    -- numbers: { v = { across, up, ... }, i = { corner, corner, corner, ... } })
    local function unpack_tris(str)
      if not str then return nil end
      local v, idx, at = {}, {}, {}
      local function corner(k)
        local key = str:sub(k, k + 3)
        local n = at[key]
        if not n then
          n = #v / 2 + 1; at[key] = n
          v[#v + 1] = (vval[str:sub(k, k)] * 64 + vval[str:sub(k + 1, k + 1)]) / 4095 - 0.5
          v[#v + 1] = (vval[str:sub(k + 2, k + 2)] * 64 + vval[str:sub(k + 3, k + 3)]) / 4095
        end
        return n
      end
      for k = 1, #str - 11, 12 do
        local a, b, c = corner(k), corner(k + 4), corner(k + 8)
        local ax, ay, bx, by, cx, cy = v[a * 2 - 1], v[a * 2], v[b * 2 - 1], v[b * 2], v[c * 2 - 1], v[c * 2]
        if (bx - ax) * (cy - ay) - (by - ay) * (cx - ax) < 0 then b, c = c, b end
        idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = c
      end
      return { v = v, i = idx }
    end
    for name, d in pairs(ICON_DATA) do
      if type(d) == 'table' then
        local ic = { g = unpack_runs(d.g), b = unpack_runs(d.b), rows = R, tg = unpack_tris(d.tg), tb = unpack_tris(d.tb), te = unpack_tris(d.te) }
        -- ((5.0 Test 8) per band, its leftmost to rightmost run: the dark edge behind the GUI marker, one quad a band)
        local span, sh = {}, {}
        for _, L in ipairs({ ic.g, ic.b }) do
          for k = 1, #L, 3 do
            local h = L[k]
            local sp = span[h]
            if not sp then span[h] = { L[k + 1], L[k + 2] } else sp[1], sp[2] = math.min(sp[1], L[k + 1]), math.max(sp[2], L[k + 2]) end
          end
        end
        for h, sp in pairs(span) do sh[#sh + 1] = h; sh[#sh + 1] = sp[1]; sh[#sh + 1] = sp[2] end
        ic.sh = sh
        ICONS[name] = ic
      end
    end
  end
  -- which icon each gun shows (by its name in DEFS/DOGS); ((5.1.5 Test 7, my ask: "It should use the Booster icon")
  -- the pod gun shows the Armed Resupply Pods booster's pod and gun (it ran the Gatling's)
  local ICON_OF = {
    ['Machine Gun Sentry'] = 'mg', ['Gatling Sentry'] = 'gatling', ['Autocannon Sentry'] = 'ac', ['Rocket Sentry'] = 'rocket',
    ['Laser Sentry'] = 'laser', ['Flame Sentry'] = 'flame', ['Tesla Tower'] = 'tesla', ['Mortar Sentry'] = 'mortar',
    ['EMS Mortar Sentry'] = 'ems', ['Gas Mortar Sentry'] = 'gasmortar',   -- ((5.1.5 Test 12) its own icon, from the wiki's (the game's is out of reach)
    ['Resupply Pod Gun'] = 'pod', ['Supply FRV Gun'] = 'frv',
    ['Guard Dog'] = 'dog', ['Rover'] = 'rover', ['K-9'] = 'k9',
  }
  -- the strands' directions round the beam, and the ring's, worked out once
  local SC, SS = {}, {}
  for k = 1, BEAM.strands do local a = 2 * math.pi * (k - 0.5) / BEAM.strands; SC[k], SS[k] = math.cos(a), math.sin(a) end

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
  -- the marker over an enemy: line(color, fade, ...) as for the beams. The gun's icon stands upright facing you (its
  -- lines run across your view, so the bands read as a filled shape), about 30 pixels tall at any distance; a small
  -- chevron under it points at the enemy
  -- where a marker goes: its icon, the chevron's point (x, y, z), your right (rx, ry), its size and the chevron's
  -- half-width. ((5.0 Test 8) several guns on one enemy: their icons side by side - b.slot of b.slots, set by
  -- laser.prepare)
  -- ((5.0 Test 15, my ask: "the marker only appears vertically up and down, it should display to you the same whether
  -- you are flat on the ground or looking down from the top of a skyscraper") the marker faces your eyes, tilted as
  -- well as turned: its right stays level, its 'up' (ux, uy, uz) leans back as you look down on it. Your eyes: 1.7 m
  -- over your helldiver (the camera is close to that). Straight down on it, the last right is kept
  local EYE_UP = 1.7
  laser.mark_right = { 1, 0 }
  laser.marker_geom = function(b)
    local t = b.to
    local me = laser.me
    local x, y, z = t[1], t[2], t[3] + BEAM.mark_up
    local rx, ry, dist = laser.mark_right[1], laser.mark_right[2], 20
    local ux, uy, uz = 0, 0, 1
    if me then
      local fx, fy, fz = x - me[1], y - me[2], z - (me[3] + EYE_UP)
      dist = sqrt(fx * fx + fy * fy + fz * fz)
      local l = sqrt(fx * fx + fy * fy)
      if l > 0.05 * dist and l > 0.05 then rx, ry = fy / l, -fx / l; laser.mark_right[1], laser.mark_right[2] = rx, ry end   -- (your right, looking at it)
      if dist > 0.1 then
        fx, fy, fz = fx / dist, fy / dist, fz / dist
        -- up = right x forward (right is level: its z is 0)
        ux, uy, uz = ry * fz, -rx * fz, rx * fy - ry * fx
        local ul = sqrt(ux * ux + uy * uy + uz * uz)
        if ul > 1e-3 then ux, uy, uz = ux / ul, uy / ul, uz / ul else ux, uy, uz = 0, 0, 1 end
      end
    end
    local sz = math.min(BEAM.icon_max, math.max(BEAM.icon_min, dist * BEAM.icon_per_m)) * BEAM.icon_scale * laser.marker_size()
    local n = b.slots or 1
    if n > 1 then
      local o = ((b.slot or 1) - (n + 1) / 2) * sz * 1.1
      x, y = x + rx * o, y + ry * o
    end
    local ic = ICONS[ICON_OF[b.icon or ''] or ''] or ICONS.mg   -- (b.icon: the gun's name)
    return ic, x, y, z, rx, ry, sz, sz * 0.12, ux, uy, uz
  end
  -- the marker as lines (when the game build has no world GUI): line(color, fade, ...) as for the beams. The gun's icon
  -- stands upright facing you, about 30 pixels tall at any distance; a small chevron under it points at the enemy
  -- ((5.1.3, my ask: "being able to hide the markers ... behind walls") the game's lines are the only drawing
  -- walls hide (the world GUI can't be depth tested from a mod), so Behind walls draws the marker with them: the traced
  -- icon (edge, body, glyph) cut into rows, one line per row and color - lines a pixel or so apart, so it reads as filled
  -- - with a row's pieces never overlapping (lines in one plane would fight). Each icon is cut once into 96 rows
  -- (0.3-1.8 ms; warmed one icon a frame while Behind walls is on, see laser.warm_markers); smaller markers take every
  -- 2nd, 3rd or 4th row (48, 32, 24 rows), about one row per pixel of the marker's height on screen
  local BASE_ROWS = 96
  local MARK_LINES = 500   -- ((5.1.4) the most lines all Behind walls markers may use in a frame, the chevrons aside)
  local SCAN, CUT = {}, {}
  local function by_start(p, q) return p[1] < q[1] end
  local function cut_icon(ic)
    local base = CUT[ic]
    if base then return base end
    base = {}
    local layers = { ic.te, ic.tb, ic.tg }
    for r = 1, BASE_ROWS do
      local y = (r - 0.5) / BASE_ROWS
      local iv = {}
      for L = 1, 3 do
        local v, I = layers[L].v, layers[L].i
        local list = {}
        for k = 1, #I, 3 do
          local lo, hi
          for e = 0, 2 do
            local p, q = I[k + e], I[k + (e + 1) % 3]
            local px, py, qx, qy = v[p * 2 - 1], v[p * 2], v[q * 2 - 1], v[q * 2]
            if (py <= y and qy > y) or (qy <= y and py > y) then
              local x = px + (y - py) * (qx - px) / (qy - py)
              if not lo or x < lo then lo = x end
              if not hi or x > hi then hi = x end
            end
          end
          if lo and hi > lo then list[#list + 1] = { lo, hi } end
        end
        table.sort(list, by_start)
        local merged = {}
        for _, sg in ipairs(list) do
          local m = merged[#merged]
          if m and sg[1] <= m[2] + 1e-4 then if sg[2] > m[2] then m[2] = sg[2] end else merged[#merged + 1] = { sg[1], sg[2] } end
        end
        iv[L] = merged
      end
      -- the glyph on top, then the body outside it, then the edge outside both: { across from, across to, layer, ... }
      local row, covered = {}, {}
      for L = 3, 1, -1 do
        for _, sg in ipairs(iv[L]) do
          local pieces = { { sg[1], sg[2] } }
          for _, c in ipairs(covered) do
            local np = {}
            for _, pc in ipairs(pieces) do
              if c[2] <= pc[1] or c[1] >= pc[2] then np[#np + 1] = pc
              else
                if c[1] > pc[1] then np[#np + 1] = { pc[1], c[1] } end
                if c[2] < pc[2] then np[#np + 1] = { c[2], pc[2] } end
              end
            end
            pieces = np
          end
          for _, pc in ipairs(pieces) do
            if pc[2] - pc[1] > 1e-4 then row[#row + 1] = pc[1]; row[#row + 1] = pc[2]; row[#row + 1] = L end
          end
        end
        for _, sg in ipairs(iv[L]) do covered[#covered + 1] = sg end
      end
      base[r] = row
    end
    CUT[ic] = base
    return base
  end
  -- an icon in 'rows' rows (24, 32, 48 or 96): a flat list { up, across from, across to, layer, ... }
  local function scan_icon(ic, rows)
    local byrows = SCAN[ic]
    if not byrows then byrows = {}; SCAN[ic] = byrows end
    local out = byrows[rows]
    if out then return out end
    local base, k = cut_icon(ic), BASE_ROWS / rows
    out = {}
    for r = 1, rows do
      local row = base[(r - 1) * k + math.floor(k / 2) + 1]
      local y = (r - 0.5) / rows
      for j = 1, #row, 3 do out[#out + 1] = y; out[#out + 1] = row[j]; out[#out + 1] = row[j + 1]; out[#out + 1] = row[j + 2] end
    end
    byrows[rows] = out
    return out
  end
  -- (while Behind walls is on) one icon not cut yet, cut this frame: all of them ready in a dozen frames, before most
  -- markers are first needed - no frame cuts more than one unless a marker needs its icon at once
  laser.warm_markers = function()
    for _, ic in pairs(ICONS) do
      if ic.tg and not CUT[ic] then cut_icon(ic); return end
    end
    laser.markers_warm = true   -- ((release review) all cut: laser.step stops calling this
  end
  -- the solid colors (alpha ignored by the lines): the GUI marker's glyph and body; its see-through black edge as a dark shade
  local LMARK = {
    [LOCK] = { { 255, 40, 32, 8 }, { 255, 255, 214, 60 }, { 255, 255, 248, 170 } },
    [LOST] = { { 255, 40, 40, 40 }, { 255, 214, 214, 214 }, { 255, 250, 250, 250 } },
  }
  local function marker(b, S, line)
    local fd = b.fade or 1
    local ic, x, y, z, rx, ry, sz, cw, ux, uy, uz = laser.marker_geom(b)
    local C = LMARK[b.argb]
    if ic.tg and C then
      -- (the marker's own colors, not dimmed with distance or by Laser Brightness: the brightness is undone here)
      fd = 1 / laser.brightness()
      local me, t = laser.me, b.to
      local dist = me and sqrt((t[1] - me[1]) ^ 2 + (t[2] - me[2]) ^ 2 + (t[3] - me[3]) ^ 2) or 20
      local px = 40 * sz / (math.max(dist, 1) * BEAM.icon_per_m)   -- (its height in pixels, about)
      local rows = px <= 24 and 24 or px <= 32 and 32 or px <= 48 and 48 or 96
      local R = scan_icon(ic, rows)
      -- ((5.1.4, players: "the performance is much worse") the marker lines a frame are capped (MARK_LINES for all of
      -- them together): a lone close marker keeps every row, several at once step down in rows until they fit. A fixed
      -- cap per marker would have striped every nearby marker - 24 rows is already 60-110 lines)
      local used = laser.mark_lines or 0
      while rows > 24 and used + #R / 4 > MARK_LINES do
        rows = rows == 96 and 48 or rows == 48 and 32 or 24
        R = scan_icon(ic, rows)
      end
      laser.mark_lines = used + #R / 4
      local base = cw + sz * 0.1
      for k = 1, #R, 4 do
        local h, a, c = base + R[k] * sz, R[k + 1] * sz, R[k + 2] * sz
        line(C[R[k + 3]], fd, x + rx * a + ux * h, y + ry * a + uy * h, z + uz * h, x + rx * c + ux * h, y + ry * c + uy * h, z + uz * h)
      end
      -- the chevron: each bar a few lines across its thickness, the dark edge on either side
      local tk = sz * 0.035
      local n = math.max(1, math.floor(rows * 0.035 + 0.5))
      for side = -1, 1, 2 do
        for j = -n - 1, n + 1 do
          local o = tk * j / n
          local col = (j < -n or j > n) and C[1] or C[3]
          line(col, fd, x + rx * cw * side + ux * (cw + o), y + ry * cw * side + uy * (cw + o), z + uz * (cw + o), x + ux * o, y + uy * o, z + uz * o)
        end
      end
      return
    end
    -- (a point a along your right and h along the marker's up, from the chevron's tip)
    line(S.core, fd, x - rx * cw + ux * cw, y - ry * cw + uy * cw, z + uz * cw, x, y, z)
    line(S.core, fd, x + rx * cw + ux * cw, y + ry * cw + uy * cw, z + uz * cw, x, y, z)
    local base = cw + sz * 0.1
    for pass = 1, 2 do
      local L, col = pass == 1 and ic.b or ic.g, pass == 1 and S.body or S.core
      for k = 1, #L, 3 do
        local h, a, c = base + L[k] * sz, L[k + 1] * sz, L[k + 2] * sz
        line(col, fd, x + rx * a + ux * h, y + ry * a + uy * h, z + uz * h, x + rx * c + ux * h, y + ry * c + uy * h, z + uz * h)
      end
    end
  end
  -- adds one styled beam (or marker) as lines: line(color, fade, x1, y1, z1, x2, y2, z2) draws one line in a color dimmed
  -- by 'fade'. A beam: its strands, a small cross on the target, the star at the gun, and the core last, on top
  laser.draw_styled = function(b, line)
    local S = (laser.inv and STYLE_INV or STYLE)[b.argb]   -- ((release review) laser.inv: read once a frame, laser.step)
    if b.marker then return marker(b, S, line) end
    local f, t = b.from, b.to
    local dx, dy, dz = t[1] - f[1], t[2] - f[2], t[3] - f[3]
    local len = sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.05 then return end
    dx, dy, dz = dx / len, dy / len, dz / len
    local ux, uy, uz, vx, vy, vz = perp(dx, dy, dz)
    local fd = b.fade or 1
    local w = BEAM.inner
    for k = 1, BEAM.strands do
      local cu, cv = SC[k] * w, SS[k] * w
      local ox, oy, oz = ux * cu + vx * cv, uy * cu + vy * cv, uz * cu + vz * cv
      line(S.side, fd, f[1] + ox, f[2] + oy, f[3] + oz, t[1] + ox, t[2] + oy, t[3] + oz)
    end
    if b.dot then
      -- a small bright cross where it hits, just in front of the end
      local back = math.min(BEAM.dot_back, len * 0.5)
      local qx, qy, qz = t[1] - dx * back, t[2] - dy * back, t[3] - dz * back
      local d = BEAM.dot
      line(S.dot, fd, qx - ux * d, qy - uy * d, qz - uz * d, qx + ux * d, qy + uy * d, qz + uz * d)
      line(S.dot, fd, qx - vx * d, qy - vy * d, qz - vz * d, qx + vx * d, qy + vy * d, qz + vz * d)
    end
    if not b.no_flare then
      -- ((5.0 Test 6) the star where it leaves the gun: a short level line and a shorter upright one, across the beam)
      local h, g = BEAM.flare, BEAM.flare_v
      line(S.core, fd, f[1] - ux * h, f[2] - uy * h, f[3] - uz * h, f[1] + ux * h, f[2] + uy * h, f[3] + uz * h)
      line(S.core, fd, f[1] - vx * g, f[2] - vy * g, f[3] - vz * g, f[1] + vx * g, f[2] + vy * g, f[3] + vz * g)
    end
    line(S.core, fd, f[1], f[2], f[3], t[1], t[2], t[3])
  end

end

-- every world the engine reports right now (re-read each frame, so a closed world is never touched again)
local ONE_WORLD = {}   -- ((4.6.4 review) the usual answer, one table kept: nothing is made on the frames it is asked)
local function live_worlds()
  local A = SR and SR.Application
  if type(A) ~= 'table' then return nil, 'no stingray.Application' end
  if type(A.main_world) == 'function' then
    local ok, w = pcall(A.main_world)
    if ok and w ~= nil then laser.world_source = 'main_world()'; ONE_WORLD[1] = w; return ONE_WORLD end
  end
  local list, seen = {}, {}
  local function add(w) if w ~= nil and not seen[w] then seen[w] = true; list[#list + 1] = w end end
  local src = {}
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
    laser.state, laser.why = 'off', 'cannot build engine vectors/colors: ' .. tostring(okv and okc or (not okv and v) or c)
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
  -- ((5.1.2 review) the laser off after an error: what it drew last is taken off the screen first - a line object goes on
  -- showing its last dispatch, so a ring or beam stayed until the game restarted. Each object once, emptied, in a
  -- pcall of its own (they belong to worlds that were live last frame); the glow's retained triangles too)
  local LO = SR and SR.LineObject
  for _, objs in ipairs({ laser.worlds or {}, laser.ring_lo or {} }) do
    for w, lo in pairs(objs) do
      if LO then pcall(function() LO.reset(lo); LO.dispatch(w, lo) end) end
    end
  end
  if laser.glow and laser.glow.clear then pcall(laser.glow.clear) end
  laser.worlds, laser.ring_lo, laser.has, laser.ring_sig = {}, {}, false, nil
  note('laser: stopped after an error: ' .. laser.why)
  event('laser stopped: ' .. laser.why)
end

-- draw this frame's beams (a list of { from, to, argb }) in every live world; an empty list clears them
-- beams: this frame's beams (a list of { from, to, argb }); beams.rings: the sentries' rings, each a list of such segments
-- that a sentry builds once and reuses. (4.0.6) The rings go in a line object of their own that is rebuilt only when
-- the set of rings changes and otherwise just drawn again, instead of 40-80 lines rebuilt every frame. redraw: nothing
-- new this frame (the mod is checking only a few times a second, idle sentries): both line objects are drawn again as
-- they are. An empty list clears everything
-- ((4.6.4 review) the drawing in a named function, called through pcall: a new closure every frame before)
-- (5.0, my ask: "smoother motion") before a frame's beams are drawn: each styled beam gets its fade with distance from you,
-- and a beam that has a 'key' (whose it is: the dog, a sentry) and changed target ('tg') swings its end over to the
-- new target over SWITCH seconds (eased) instead of jumping there
local SWITCH = 0.14
local MARK_HOLD = 0.4
laser.ends = {}
laser.mark_last = {}
local function SLOT_ORDER(a, c) return a.sk < c.sk end
laser.prepare = function(beams)
  local t = os.clock()
  local E_ = laser.ends
  -- ((5.0 Test 8, my note: the marker is "not showing consistently") a locked-on marker missing for a frame or two
  -- (the gun's records between two states) stays up to MARK_HOLD s where it was, so it doesn't blink)
  local MH = laser.mark_last
  -- ((5.0 release review) the held entries are reused, not made anew each frame: m.f = the frame stamp it was last seen)
  laser.mark_frame = (laser.mark_frame or 0) + 1
  local fr = laser.mark_frame
  for _, b in ipairs(beams) do
    if b.marker and b.key then
      local m = MH[b.key]
      if m then m.b, m.t, m.f = b, t, fr else MH[b.key] = { b = b, t = t, f = fr } end
    end
  end
  for k, m in pairs(MH) do
    if m.f ~= fr then
      if t - m.t < MARK_HOLD then beams[#beams + 1] = m.b else MH[k] = nil end
    end
  end
  -- ((5.0 Test 8) markers on the same enemy (or the same spot) side by side)
  local groups
  for _, b in ipairs(beams) do
    if b.marker then
      local k = b.tg or string.format('%.0f/%.0f/%.0f', b.to[1] * 2, b.to[2] * 2, b.to[3] * 2)
      groups = groups or {}
      local g = groups[k]
      if not g then g = {}; groups[k] = g end
      g[#g + 1] = b
    end
  end
  -- ((5.0 Test 17, test builds; my note: with 3 or more guns on one enemy "it doesnt display more than 2, or at least the dog
  -- marker didnt show") how many markers stand on one enemy, and how often the dog's is up while it has a target
  if TESTER then
    local MS = laser.mstat or { n = 0, dog_t = 0, dog_m = 0, most = 0, three = 0, logged = 0 }
    laser.mstat = MS
    MS.n = MS.n + 1
    local top = 0
    for _, g in pairs(groups or {}) do if #g > top then top = #g end end
    if top > MS.most then MS.most = top end
    if top >= 3 then MS.three = MS.three + 1 end
    if laser.dog_target then MS.dog_t = MS.dog_t + 1; if MH.mdog and MH.mdog.f == fr then MS.dog_m = MS.dog_m + 1 end end
    if MS.n >= (rawget(_G, 'SGD_SIM_EVERY') or 1800) and MS.logged < 8 then   -- (the simulator logs sooner)
      MS.logged = MS.logged + 1
      event(string.format('markers (test): over %d frames the dog\'s marker was up on %d of its %d frames with a target; most markers on one enemy %d (3 or more on %d frames)',
        MS.n, MS.dog_m, MS.dog_t, MS.most, MS.three))
      MS.n, MS.dog_t, MS.dog_m, MS.most, MS.three = 0, 0, 0, 0, 0
    end
  end
  if groups then
    for _, g in pairs(groups) do
      if #g > 1 then
        for _, b in ipairs(g) do b.sk = tostring(b.icon) .. tostring(b.key) end   -- (the sort key made once, not per comparison)
        table.sort(g, SLOT_ORDER)
        for i, b in ipairs(g) do b.slot, b.slots = i, #g end
      else
        g[1].slot, g[1].slots = nil, nil   -- ((5.0 release review) a held marker left alone goes back over its enemy)
      end
    end
  end
  for _, b in ipairs(beams) do
    if laser.styled(b) then
      b.fade = laser.fade_of(b.from)
      local key = b.key
      if key then
        local E = E_[key]
        if E and t - E.t < 0.3 then
          -- ((5.0 Test 7) not a beam fixed on its gun's barrel: the barrel turning moves it, as a real one)
          if E.tg ~= b.tg and not b.fixed then E.sw_from, E.sw_t = E.to, t end
          if b.fixed then E.sw_t = nil end
          if E.sw_t then
            local x = (t - E.sw_t) / SWITCH
            if x >= 1 then E.sw_t = nil
            else
              local k = x * x * (3 - 2 * x)
              local a, e = E.sw_from, b.to
              b.to = { a[1] + (e[1] - a[1]) * k, a[2] + (e[2] - a[2]) * k, a[3] + (e[3] - a[3]) * k }
            end
          end
        else
          E = {}
          E_[key] = E
        end
        -- (Testers: how far each beam's end moves a frame while it stays on the same target - the dog's and the
        -- sentries' apart; one line each per 300 frames, up to 6 a session)
        if TESTER and E.to and E.tg == b.tg and not E.sw_t then
          local who = key == 'dog' and 'dog' or 'sentries'
          laser.st5 = laser.st5 or {}
          local S = laser.st5[who] or { n = 0, d = 0, logged = 0 }
          laser.st5[who] = S
          local o, e = E.to, b.to
          local d = math.sqrt((e[1] - o[1]) ^ 2 + (e[2] - o[2]) ^ 2 + (e[3] - o[3]) ^ 2)
          if d < 3 then S.n, S.d = S.n + 1, S.d + d end
          if S.n >= 300 and S.logged < 6 then
            S.logged = S.logged + 1
            event(string.format('laser steadiness (test): the %s beam end moved %.1f cm a frame on the same target (%d frames)', who, 100 * S.d / S.n, S.n))
            S.n, S.d = 0, 0
          end
        end
        E.to, E.tg, E.t = b.to, b.tg, t
      end
    end
  end
  -- (ends not drawn for a while are forgotten)
  if (laser.ends_clean or 0) < t then
    laser.ends_clean = t + 5
    for k, E in pairs(E_) do if t - E.t > 5 then E_[k] = nil end end
  end
end

local function laser_draw_body(beams, redraw)
    local worlds, why = live_worlds()
    if not worlds then
      if laser.wait_reason ~= why then laser.wait_reason = why; event('laser waiting: ' .. tostring(why)) end
      return
    end
    local rings = beams.rings
    if not redraw then laser.prepare(beams) end
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
        -- ((5.0) 'fd': the beam's fade with distance from you, a few levels; each color and level is made once a frame)
        local function colour(a, fd)
          fd = fd or 1
          local byf = colours[a]
          if not byf then byf = {}; colours[a] = byf end
          local c = byf[fd]
          if not c then
            local B2 = BR * fd
            if B2 == 1 then c = SR.Color(a[1], a[2], a[3], a[4])
            else
              -- (4.6.3 review) past full strength a channel can't go brighter (the neon green's 200 reached 255 at about
              -- 130%, so Bright and Brightest looked the same): what is left over whitens the color instead, as the
              -- glow does
              local r, g, b = a[2] * B2, a[3] * B2, a[4] * B2
              local m = math.max(r, g, b)
              if m > 255 then
                local w = math.min(0.6, (m - 255) / m)
                r, g, b = math.min(255, r), math.min(255, g), math.min(255, b)
                r, g, b = r + (255 - r) * w, g + (255 - g) * w, b + (255 - b) * w
              end
              c = SR.Color(a[1], math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
            end
            byf[fd] = c
          end
          return c
        end
        if not redraw then
          LO.reset(lo)
          -- (each color is built once per frame)
          local function line(a, fd, x1, y1, z1, x2, y2, z2) LO.add_line(lo, colour(a, fd), V(x1, y1, z1), V(x2, y2, z2)) end
          -- (4.5: with the glow chosen, the dogs' and sentries' beams are left to it)
          local lines = not (laser.glow and laser.glow.on())
          for _, b in ipairs(beams) do
            -- (the dogs' and sentries' beams: core, cross. (5.0 Test 8) markers are drawn by the world GUI - filled, and seen
            -- through walls like the game's own pings - and as lines only where the game build has none)
            -- ((5.1.3) and as lines - which walls hide - with Targeting Marker: Behind walls)
            if laser.styled(b) then if (b.marker and (laser.walls or not laser.glow.markers_ok())) or (lines and not b.marker) then laser.draw_styled(b, line) end
            else LO.add_line(lo, colour(b.argb), V(b.from[1], b.from[2], b.from[3]), V(b.to[1], b.to[2], b.to[3])) end   -- (any other line)
          end
        end
        LO.dispatch(w, lo)
        -- the rings: rebuilt when they change (a ring's segments share their end points: each point is made once)
        local rlo = laser.ring_lo and laser.ring_lo[w]
        local emptied = false   -- (4.6.8) reset this frame: sent once more, even empty, so the old rings go
        if not redraw and (not same or (rings and not rlo)) then
          if rings and not rlo then rlo = SR.World.create_line_object(w, false) end
          if rlo then
            LO.reset(rlo)
            laser.ring_has = rings ~= nil and #rings > 0   -- ((4.6.7 review) whether it holds anything to show)
            emptied = not laser.ring_has
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
        -- ((4.6.7 review) an empty ring object isn't sent to the engine every frame. (4.6.8) But the engine keeps showing
        -- a line object's last dispatch until it is dispatched again: 4.6.7 never sent the emptied object, so the last
        -- rings (a Rocket Sentry's red minimum-range ring) stayed on screen for the rest of the session, ship and later
        -- missions included. The frame it is emptied, it is sent once, empty)
        if rlo then keep_r[w] = rlo; if laser.ring_has or emptied then LO.dispatch(w, rlo) end end
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
end
local function laser_draw(beams, redraw)
  if not laser_ready() then return end
  local ok, err = pcall(laser_draw_body, beams, redraw)
  if not ok then laser_fail(err) end
end

-- ((4.6.4 review) out of a mission: the line objects and world GUIs kept per world are dropped without being touched -
-- their worlds are gone, and a new mission's world could come back at the same address, where using a stale one would
-- crash the game)
laser.forget = function()
  laser.worlds, laser.ring_lo, laser.has, laser.ring_sig = {}, {}, false, nil
  laser.mark_last = {}
  if laser.glow then laser.glow.guis, laser.glow.ids, laser.glow.last = {}, {}, nil end
end

local function laser_clear()
  -- (4.6.3 review: only when something is on screen - before, every poll with nothing to show redrew empty line objects)
  if laser.state == 'ready' and laser.has and next(laser.worlds) then laser_draw({}) end
end
-- ((5.1.2) the mission ending: everything off the screen at once - the markers held up to MARK_HOLD s too, which an
-- ordinary clear still draws for a moment)
laser.clear_now = function()
  laser.mark_last = {}
  laser_clear()
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
  -- alpha, red, green, blue by the beam's color: the narrow core, the wide halo, the spot on the target
  local LOOK = {
    -- ((5.0) red firing, green held for a friendly, gray lost, amber locked on)
    [FIRE] = { core = { 210, 255, 110, 90 }, halo = { 55, 255, 40, 30 }, dot = { 230, 255, 170, 150 } },
    [FRIEND] = { core = { 210, 110, 255, 130 }, halo = { 55, 60, 255, 90 }, dot = { 230, 170, 255, 170 } },
    [LOST] = { core = { 160, 210, 210, 210 }, halo = { 40, 170, 170, 170 }, dot = { 180, 230, 230, 230 } },
    [LOCK] = { core = { 180, 255, 190, 70 }, halo = { 45, 255, 150, 20 }, dot = { 200, 255, 210, 120 } },
  }
  local WIDTH = { core = 0.006, halo = 0.03 }   -- half-widths in meters
  local FADE_TO, SPOT = 0.3, 0.03   -- alpha falls to this share at the far end; the spot's half-size
  -- ((5.1.4, players: "the performance is much worse") the pieces along each strip, each one a step of the fade: 4 for
  -- the faint halo and 6 for the core (10 each before, 86 triangles a beam; now 46, the same look in the preview)
  local PIECES = { halo = 4, core = 6 }
  local PARTS = { 'halo', 'core' }              -- (the core drawn last, on top)
  local LOOKS = {}
  for base, c in pairs(LOOK) do
    local S = { dot = c.dot }
    for _, part in ipairs(PARTS) do
      local steps = {}
      for k = 1, PIECES[part] do
        local f = 1 + (FADE_TO - 1) * (k - 0.5) / PIECES[part]
        steps[k] = { math.floor(c[part][1] * f + 0.5), c[part][2], c[part][3], c[part][4] }
      end
      S[part] = steps
    end
    LOOKS[base] = S
  end
  local LOOKS_INV = { [FIRE] = LOOKS[FRIEND], [FRIEND] = LOOKS[FIRE], [LOST] = LOOKS[LOST], [LOCK] = LOOKS[LOCK] }   -- ((5.1.0 Test 1) swapped)

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
  -- ((5.0 Test 8) the markers are always the world GUI's when it works, Line or Glow)
  G.markers_ok = function() return not G.off and usable() end
  -- the marker's colors (alpha, red, green, blue): the weapon glyph solid, the sentry/backpack body see-through, the
  -- chevron as the glyph. Locked on: the game's ping yellow; lost: gray
  -- ((5.0 Test 8, my ask: "marker is pretty rough") a pale yellow weapon glyph on a deeper yellow body, both over a
  -- dark see-through edge so it reads on sky, snow or smoke)
  -- ((5.0 Test 14, my note: the markers "sometimes get really dark and hard to see") lighter all round: the dark edge at
  -- about half its strength (a thin shadow, not a dark plate), the body more solid, the target-lost gray near white;
  -- and the markers are no longer dimmed by Laser Brightness (they are their own option now)
  local MARK = {
    [LOCK] = { glyph = { 255, 255, 248, 170 }, body = { 225, 255, 214, 60 }, edge = { 85, 0, 0, 0 } },
    [LOST] = { glyph = { 255, 250, 250, 250 }, body = { 215, 214, 214, 214 }, edge = { 75, 0, 0, 0 } },
  }
  for _, M in pairs(MARK) do M.glyph.mark, M.body.mark, M.edge.mark = true, true, true end

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
    local OP = laser.marker_opacity()
    local function tri(p0, p1, p2, a)
      local c = colours[a]
      if not c and a.mark then c = SR.Color(math.floor(a[1] * OP + 0.5), a[2], a[3], a[4]); colours[a] = c end   -- (a marker: its own opacity, no brightness)
      if not c then
        -- (4.5.3 Test 11) brightness on the glow: its transparency alone hardly showed (a tester: the setting didn't
        -- change it - the core is nearly solid already), so dimmer also darkens its color and brighter whitens it
        -- toward its hottest; the strips are widened too (WIDTH below)
        local r, gg, bb = a[2], a[3], a[4]
        if BR < 1 then r, gg, bb = r * BR, gg * BR, bb * BR
        elseif BR > 1 then local w = math.min(0.6, (BR - 1) * 0.4); r, gg, bb = r + (255 - r) * w, gg + (255 - gg) * w, bb + (255 - bb) * w end
        c = SR.Color(math.min(255, math.floor(a[1] * BR + 0.5)), math.floor(r + 0.5), math.floor(gg + 0.5), math.floor(bb + 0.5)); colours[a] = c
      end
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
    -- ((5.0 Test 8) the markers: each run of the icon a filled quad, upright, facing you; no gaps between the bands)
    local glow = G.on()
    -- ((5.0 Test 15) facing your eyes: a along your right, h along the marker's up, from the chevron's tip) ((5.0 release
    -- review) one function for every marker, reading the marker being drawn from these locals - not one made per marker)
    local x, y, z, rx, ry, ux, uy, uz
    local function P(a, h) return V(x + rx * a + ux * h, y + ry * a + uy * h, z + uz * h) end
    local PV = G.pv or {}; G.pv = PV   -- ((5.1.0 release review) a marker's corners, reused)
    for _, b in ipairs(beams) do
      local M = b.marker and not laser.walls and MARK[b.argb]   -- ((5.1.3) Behind walls: lines instead
      if M then
        local ic, sz, cw
        ic, x, y, z, rx, ry, sz, cw, ux, uy, uz = laser.marker_geom(b)
        local hb = sz / ic.rows * 0.5 + 0.0005   -- (half a band, a hair over so the bands meet)
        local base = cw + sz * 0.1
        local e = sz * 0.05                      -- (the dark edge's width)
        if ic.tg then
          -- ((5.1.0 Test 1) the traced shapes: edge, body, glyph; (release review) each corner placed once, PV reused)
          for pass = 1, 3 do
            local T = pass == 1 and ic.te or pass == 2 and ic.tb or ic.tg
            local col = pass == 1 and M.edge or pass == 2 and M.body or M.glyph
            local v, I = T.v, T.i
            for k = 1, #v, 2 do PV[(k + 1) / 2] = P(v[k] * sz, base + v[k + 1] * sz) end
            for k = 1, #I, 3 do tri(PV[I[k]], PV[I[k + 1]], PV[I[k + 2]], col) end
          end
        else
        for pass = 1, 3 do
          local L = pass == 1 and ic.sh or pass == 2 and ic.b or ic.g
          local col = pass == 1 and M.edge or pass == 2 and M.body or M.glyph
          local ex = pass == 1 and e or 0
          for k = 1, #L, 3 do
            local h, a, c = base + L[k] * sz, L[k + 1] * sz - ex, L[k + 2] * sz + ex
            local p1, p2 = P(a, h - hb - ex), P(c, h - hb - ex)
            local p3, p4 = P(c, h + hb + ex), P(a, h + hb + ex)
            tri(p1, p2, p3, col); tri(p1, p3, p4, col)
          end
        end
        end
        -- the chevron: two short bars meeting at the point
        for pass = 1, 2 do
          local tk = sz * 0.035 + (pass == 1 and e or 0)
          local col = pass == 1 and M.edge or M.glyph
          for side = -1, 1, 2 do
            local q1, q2 = P(cw * side, cw + tk), P(cw * side, cw - tk)
            local q3, q4 = P(0, -tk), P(0, tk)
            tri(q1, q2, q3, col); tri(q1, q3, q4, col)
          end
        end
      end
    end
    for _, b in ipairs(beams) do
      local S = glow and not b.marker and laser.styled(b) and (laser.inv and LOOKS_INV or LOOKS)[b.argb]
      local f, e = b.from, b.to
      local dx, dy, dz = e[1] - f[1], e[2] - f[2], e[3] - f[3]
      local len = S and sqrt(dx * dx + dy * dy + dz * dz) or 0
      if len >= 0.05 then
        dx, dy, dz = dx / len, dy / len, dz / len
        local ux, uy, uz, vx, vy, vz = perp(dx, dy, dz)
        for _, part in ipairs(PARTS) do
          local wd, steps = WIDTH[part] * (BR > 1 and 1 + (BR - 1) * 0.5 or 1), S[part]
          for pass = 1, 2 do   -- a strip lying level, then one standing up
            local ax, ay, az = ux * wd, uy * wd, uz * wd
            if pass == 2 then ax, ay, az = vx * wd, vy * wd, vz * wd end
            local pa, pb = V(f[1] + ax, f[2] + ay, f[3] + az), V(f[1] - ax, f[2] - ay, f[3] - az)
            local n = PIECES[part]
            for k = 1, n do
              local s = len * k / n
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
  -- ((4.6.4 review) a retained GUI keeps its last triangles: with the glow off they go now, not left on screen)
  G.clear = function()
    if G.immediate then return end
    for w, ids in pairs(G.ids) do
      local g = G.guis[w]
      if g then for _, id in ipairs(ids) do pcall(SR.Gui.destroy_triangle, g, id) end end
      G.ids[w] = {}
    end
  end
  G.draw = function(w, beams, redraw)
    -- ((5.0 Test 8) also with the Glow off when there are markers to draw)
    local any = G.on()
    if not any and G.markers_ok() then
      for _, b in ipairs(redraw and (G.last or beams) or beams) do if b.marker and not laser.walls then any = true; break end end
    end
    if not any then if next(G.ids) then G.clear() end; G.last = nil; return end
    -- (a retained GUI still holds the last frame's triangles: nothing to do on a redraw)
    if redraw and G.guis[w] and not G.immediate then return end
    if redraw then beams = G.last or beams else G.last = beams end
    local ok, err = pcall(draw, w, beams)
    if not ok then off(tostring(err)) end
  end
  -- ((5.1.5 Test 20) all calls into the game's GUI: not for the compiler, see engine_main.lua)
  local j = rawget(_G, 'jit')
  if type(j) == 'table' and type(j.off) == 'function' then pcall(j.off, draw, true) end
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
-- starts again; off: the laser end may sit at most this far (meters, or this share of the distance) from the
-- enemy, otherwise it falls back to pointing straight at it
local GUN = { nodes = 40, reach = 2.5, frames = 24, min_cos = 0.997, keep_cos = 0.985, min_range = 8, off = 1.5, off_share = 0.06,
  fire_cos = 0.95, fire_keep = 0.9, tries = 6 }
-- (4.5.3 Test 9) fire_cos / fire_keep: on the game's own fire node (the muzzle) only its three axes are tried, so a
-- barrel that lags its aim a little still counts; the wrong axes point well away
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
  if mean >= (g.fire and GUN.fire_cos or GUN.min_cos) then
    g.node, g.axis, g.sign = math.floor(bk / 6), math.floor((bk % 6) / 2) + 1, bk % 2 == 0 and 1 or -1
    note(string.format('laser: barrel found for %s (part %d, axis %d%s, match %.3f)', g.name, g.node, g.axis, g.sign > 0 and '+' or '-', mean))
    event('laser: following the barrel of the ' .. g.name)
  elseif g.tries <= 3 then
    note(string.format('laser: no barrel found for %s yet (best match %.3f)', g.name, mean))
  end
  g.sums, g.n = {}, 0
end

-- (4.5.3 Test 12) from the muzzle toward the game's own aim point when it is near the enemy (as far as the enemy),
-- else straight at the enemy: the Rover's and K-9's beam, and anyone's until its barrel axis is known. (On the laser
-- table, built once: 4.6.0 review)
laser.straight = function(st, to, from)
  local A = st.aim
  if A and A[1] == A[1] and (A[1] - to[1]) ^ 2 + (A[2] - to[2]) ^ 2 + (A[3] - to[3]) ^ 2 < 9 then
    local ax, ay, az = A[1] - from[1], A[2] - from[2], A[3] - from[3]
    local al = math.sqrt(ax * ax + ay * ay + az * az)
    local tl = math.sqrt((to[1] - from[1]) ^ 2 + (to[2] - from[2]) ^ 2 + (to[3] - from[3]) ^ 2)
    if al > 0.5 then return { from[1] + ax / al * tl, from[2] + ay / al * tl, from[3] + az / al * tl }, from, true end
  end
  return to, from, true
end

-- the point the barrel is aimed at, level with the enemy (nil if unknown); also where the beam starts and whether
-- its end is on the enemy (for the cross)
local function gun_point(st, to, learn)
  local D = st.drone_pos
  if not (D and D.pose) then return nil end
  local g = gun[st.dog.name]
  if not g then g = { name = st.dog.name, sums = {}, n = 0 }; gun[st.dog.name] = g end
  -- (4.5.3 Test 9) the game's own fire node (the muzzle) when its weapon record was found: the beam starts there,
  -- along the barrel once its axis is known and straight at the enemy until then. Otherwise the barrel part is
  -- guessed from all the drone's parts, as before
  local fn = st.fire_node
  if fn ~= g.fire then g.fire, g.node, g.sums, g.n, g.tries, g.check, g.check_n = fn, nil, {}, 0, 0, 0, 0 end
  local nd
  local straight = laser.straight
  if fn then
    local nodes = read_nodes(st.fire_pose or D.pose, D, fn)
    nd = nodes and nodes[fn]
    if not nd then return nil end
    -- ((5.0 Test 5) a dog with a set barrel axis (the Rover, the K-9): its muzzle part's axis, followed as it is - the beam
    -- goes where the gun points, as a laser mounted on it would, sweeping with it)
    local B = st.dog.barrel
    if B then
      local a = nd.axes and nd.axes[B[1]]
      if not a then return straight(st, to, nd.pos) end
      local dir = { a[1] * B[2], a[2] * B[2], a[3] * B[2] }
      local v = { to[1] - nd.pos[1], to[2] - nd.pos[2], to[3] - nd.pos[3] }
      local len = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
      -- ((5.0 Test 7, my ask: "like a fixed laser") along the barrel however far off the enemy it points - before, a
      -- barrel more than 60 degrees off fell back to pointing at the enemy)
      if len < 1 then return straight(st, to, nd.pos) end
      -- ((5.0 Test 9) as far as the point on the barrel's line nearest the enemy, and into it: the beam meets the
      -- enemy's body instead of stopping in front of it)
      local sp = v[1] * dir[1] + v[2] * dir[2] + v[3] * dir[3]
      if sp > 1 then len = sp + laser.INTO end
      local p = { nd.pos[1] + dir[1] * len, nd.pos[2] + dir[2] * len, nd.pos[3] + dir[3] * len }
      local off = math.sqrt((p[1] - to[1]) ^ 2 + (p[2] - to[2]) ^ 2 + (p[3] - to[3]) ^ 2)
      return p, nd.pos, off <= math.max(GUN.off, GUN.off_share * len), true
    end
    if not g.node then
      if learn and (g.tries or 0) < GUN.tries then gun_learn(g, nodes, to) end
      if g.node ~= fn then g.node = nil; return straight(st, to, nd.pos) end
    end
  else
    if not g.node and (g.tries or 0) >= GUN.tries then return nil end
    local nodes = read_nodes(D.pose, D, g.node)
    if not nodes then return nil end
    if not g.node then
      if learn then gun_learn(g, nodes, to) end
      return nil
    end
    nd = nodes[g.node]
    if not nd then return nil end
  end
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
      if mean < (g.fire and GUN.fire_keep or GUN.keep_cos) then
        note(string.format('laser: part %d of the %s stopped matching its aim (%.3f), looking again', g.node, g.name, mean))
        g.node = nil
        if g.fire then return straight(st, to, nd.pos) end
        return nil
      end
    end
  end
  -- ((5.0 Test 7) a barrel turned well away still carries its laser; only one pointing back behind the drone doesn't)
  if s < -0.5 * len then
    if g.fire then return straight(st, to, nd.pos) end
    return nil
  end
  -- (4.5.3, a tester's call: the laser comes out of the barrel and runs along it, as far as the enemy, wherever the
  -- barrel points; before, it fell back to pointing at the enemy when the barrel was off. Also returned: where the
  -- beam starts (the barrel part) and whether its end is on the enemy, for the cross)
  if s > 1 then len = s + laser.INTO end   -- ((5.0 Test 9) into the enemy, as above)
  local p = { nd.pos[1] + dir[1] * len, nd.pos[2] + dir[2] * len, nd.pos[3] + dir[3] * len }
  local off = math.sqrt((p[1] - to[1]) ^ 2 + (p[2] - to[2]) ^ 2 + (p[3] - to[3]) ^ 2)
  return p, nd.pos, off <= math.max(GUN.off, GUN.off_share * len) + laser.INTO, true
end

-- what to show for this frame
local DOCKED = 1.2   -- meters (level) between the drone and you: it has flown back to the backpack to reload

-- adds the dog's beam (if any) to 'beams'; the main loop draws the dog's and the sentries' beams together
local function laser_frame(st, beams, safety_t, safety_enemy, safety_step, cover_t, cover_enemy, cover_step)
  local D = st.drone_pos
  if not D then return end
  -- no laser at all while the drone sits on your back reloading
  local me = st.player_pos
  if me and (D[1] - me[1]) ^ 2 + (D[2] - me[2]) ^ 2 < DOCKED ^ 2 then return end
  -- (an enemy by id, looked up only when a beam is drawn)
  local function by_id(id) for _, c in ipairs(st.candidates) do if c.id == id then return c end end end
  -- ((5.0 Test 9) its aim spot where the enemy is drawn this frame)
  local function spot(c) local p = laser.live(c); return { p[1], p[2], p[3] + (st.dog.aim_rise or AIM_RISE) } end
  local t = os.clock()
  -- the beam leaves its barrel when that is known (from: the barrel part; on: its end is on the enemy, for the cross),
  -- otherwise the front of the drone, facing whatever it points at
  local function beam(to, argb, from, on, at, fixed)
    -- (4.6.7 Test 1) the firing beam's end is smoothed over about a tenth of a second, so the game's aim point
    -- wandering over the enemy doesn't shake it; a new target (or a gap) starts it afresh. What is smoothed is where
    -- the end sits on the enemy (at: the enemy's aim spot), so it never trails behind a running enemy. The start
    -- stays on the muzzle, so the beam never leaves the drone
    -- ((4.6.7 review) the offset kept as plain numbers - no tables a frame but the smoothed end - and skipped with no
    -- aim spot: smoothed in world space instead, the end would trail a running enemy)
    if (argb == FIRE or argb == LOCK) and at and not fixed then
      local B = laser.dog_beam
      local raw = to
      local ox, oy, oz = raw[1] - at[1], raw[2] - at[2], raw[3] - at[3]
      if B.ox and B.dog == st.dog.name and B.target == st.target and t - B.t < 0.25 then
        local k = laser.dog_smooth > 0 and 1 - math.exp(-(t - B.t) / laser.dog_smooth) or 1
        ox, oy, oz = B.ox + (ox - B.ox) * k, B.oy + (oy - B.oy) * k, B.oz + (oz - B.oz) * k
        to = { at[1] + ox, at[2] + oy, at[3] + oz }
        -- (Tester: how much the end moves a frame before and after, and the start; one line per dog every 200 frames,
        -- up to 6 a session)
        if TESTER and B.raw and B.from and from then
          local L = laser.steady or {}
          laser.steady = L
          local S = L[st.dog.name] or { n = 0, raw = 0, out = 0, from = 0, logged = 0 }
          L[st.dog.name] = S
          local dr = math.sqrt((raw[1] - B.raw[1]) ^ 2 + (raw[2] - B.raw[2]) ^ 2 + (raw[3] - B.raw[3]) ^ 2)
          local d1 = math.sqrt((to[1] - B.to[1]) ^ 2 + (to[2] - B.to[2]) ^ 2 + (to[3] - B.to[3]) ^ 2)
          local df = math.sqrt((from[1] - B.from[1]) ^ 2 + (from[2] - B.from[2]) ^ 2 + (from[3] - B.from[3]) ^ 2)
          if dr < 3 and df < 1 then S.n, S.raw, S.out, S.from = S.n + 1, S.raw + dr, S.out + d1, S.from + df end
          if S.n >= 200 and S.logged < 6 then
            S.logged = S.logged + 1
            event(string.format('laser steadiness (test): %s beam end moved %.1f cm a frame before smoothing, %.1f cm after; its start %.1f cm (%d frames)',
              st.dog.name, 100 * S.raw / S.n, 100 * S.out / S.n, 100 * S.from / S.n, S.n))
            S.n, S.raw, S.out, S.from = 0, 0, 0, 0
          end
        end
      end
      B.ox, B.oy, B.oz, B.dog, B.target, B.t = ox, oy, oz, st.dog.name, st.target, t
      if TESTER then B.to, B.raw, B.from = to, raw, from end   -- (the steadiness stat's only)
    end
    -- ((5.0 Test 7) a beam fixed on the barrel: its direction lightly smoothed (half the last frame's), as the sentries',
    -- so the muzzle part's shake doesn't shake it; it still turns with the gun)
    if fixed and from then
      local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
      local len = math.sqrt(dx * dx + dy * dy + dz * dz)
      local P = laser.dog_dir
      if len > 0.1 then
        dx, dy, dz = dx / len, dy / len, dz / len
        if P and P.dog == st.dog.name and t - P.t < 0.25 then
          local x, y, z = P[1] + dx, P[2] + dy, P[3] + dz
          local l = math.sqrt(x * x + y * y + z * z)
          if l > 1e-3 then dx, dy, dz = x / l, y / l, z / l end
        end
        laser.dog_dir = { dx, dy, dz, dog = st.dog.name, t = t }
        to = { from[1] + dx * len, from[2] + dy * len, from[3] + dz * len }
      end
    end
    -- ((5.0) the firing and locked-on beams are the dog's ('key'), on its target ('tg'): a new target swings the end over)
    local mine = argb == FIRE or argb == LOCK
    if from then
      beams[#beams + 1] = { from = from, to = to, argb = argb, dot = mine and on ~= false, key = mine and 'dog' or nil, tg = st.target, fixed = fixed }
      return
    end
    local dx, dy, dz = to[1] - D[1], to[2] - D[2], to[3] - (D[3] + LASER_RISE)
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < LASER_FORWARD + 0.5 then return end
    local k = LASER_FORWARD / len
    -- (a dot where it hits: only on the enemy it is firing at)
    beams[#beams + 1] = { from = { D[1] + dx * k, D[2] + dy * k, D[3] + LASER_RISE + dz * k }, to = to, argb = argb, dot = mine, key = mine and 'dog' or nil, tg = st.target }
  end
  -- ((5.0 Test 5) locked on / target lost: a marker over the enemy, no beam)
  -- ((5.0 Test 10, my note: no marker "unless it can actually harm them... if it is outside of their range" - the Guard
  -- Dog marked bots at 35-40 m it never fired at) only on an enemy within the dog's range that it can hurt
  local function can_mark(c)
    local r = st.dog.range
    if r and not (c.d2 and c.d2 <= r * r) then return false end
    return not (laser.cannot_hurt and laser.cannot_hurt(st.dog, c, st.drone_pos, st.dog.name, c.id == st.target and st.aim or nil))
  end
  local function mark(to, argb, c)
    if c and not can_mark(c) then return end
    -- ((5.0 release review) grouped by the enemy it is over: a lost marker is over the old enemy, not the dog's new target)
    beams[#beams + 1] = { from = to, to = to, argb = argb, marker = true, key = argb == LOCK and 'mdog' or nil, tg = c and c.id or st.target,
      icon = st.dog and st.dog.name }
  end
  -- red only for a shot the safety actually stopped (it stepped in while the dog was lining up or firing),
  -- and not once the dog has gone on to something else such as reloading
  local warn = safety_t and t - safety_t < RED_SECONDS and ATTACK_STEPS[safety_step]
    and (ATTACK_STEPS[st.node] or st.target == 0)
  if warn then
    -- ((5.0 Test 7, my ask: "the color of the laser will change to green if a safety stops it") its laser, along the
    -- barrel, turned green. ((5.0 Test 20, my ask: "the safety laser should still flash green, not solid green") flashing)
    local e = by_id(safety_enemy)
    local lit = math.floor(t * FLASH_HZ * 2) % 2 == 0   -- ((5.0 release review) an even blink: safety_t is renewed with each hold)
    if e and e.pos and lit then
      local to = spot(e)
      local gp, gfrom, _, along = gun_point(st, to, false)
      gp = laser.fit_end(gp, e)
      beam(gp or to, FRIEND, gp and gfrom, nil, nil, along)
    end
  elseif cover_t and t - cover_t < RED_SECONDS and ATTACK_STEPS[cover_step] and (ATTACK_STEPS[st.node] or st.target == 0)
    and st.target ~= cover_enemy then
    -- flashing yellow toward the enemy it just stopped shooting at because it dropped out of sight (behind cover
    -- or in smoke: the game doesn't tell the two apart), until the dog is busy with its next target. (4.0.6 Test 6
    -- tried flashing green: it blended in with the firing beam, a tester's call)
    local e = by_id(cover_enemy)
    local on = math.floor((t - cover_t) * FLASH_HZ * 2) % 2 == 0
    -- (4.5.3 Test 9: these leave the barrel too)
    if e and e.pos and on and st.node ~= FIRE_STEP then
      mark(spot(e), LOST, e)
    end
    if st.target ~= 0 and st.node == FIRE_STEP then
      local e2 = by_id(st.target)
      if e2 and e2.pos then
        local to = spot(e2)
        local gp, gfrom, gon, along = gun_point(st, to, false)
        gp = laser.fit_end(gp, e2)
        beam(gp or to, FIRE, gp and gfrom, gon, to, along)
      end
    end
  elseif st.target ~= 0 and st.node == FIRE_STEP then   -- green only while it is actually firing
    local e = by_id(st.target)
    if e and e.pos then
      local to = spot(e)
      local far = e.d2 and e.d2 > GUN.min_range ^ 2
      local gp, gfrom, gon, along = gun_point(st, to, e.visible and far)
      gp = laser.fit_end(gp, e)
      laser.last_gun, laser.last_to = gp, to     -- (the research log compares the two)
      -- (4.5.3 Test 12, test builds) how far the beam points from where the game aims the gun (its targeting state's
      -- aim point): the angle between the two from the muzzle, and how far apart they pass at the aim point. Logged
      -- every 40 samples, up to 8 times a session
      local A = st.aim
      if TESTER and gp and gfrom and A and A[1] == A[1] then
        local bx, by, bz = gp[1] - gfrom[1], gp[2] - gfrom[2], gp[3] - gfrom[3]
        local ax, ay, az = A[1] - gfrom[1], A[2] - gfrom[2], A[3] - gfrom[3]
        local bl, al = math.sqrt(bx * bx + by * by + bz * bz), math.sqrt(ax * ax + ay * ay + az * az)
        if bl > 1 and al > 1 and al < 200 then
          local cos = math.max(-1, math.min(1, (bx * ax + by * ay + bz * az) / (bl * al)))
          local deg = math.deg(math.acos(cos))
          -- (per dog: 4.5.3 Test 18 - one dog used up the eight lines in a tester's Test 17 log)
          laser.align = laser.align or {}
          local L = laser.align[st.dog.name] or { n = 0, sum = 0, max = 0, gap = 0, logged = 0 }
          laser.align[st.dog.name] = L
          L.n, L.sum, L.max, L.gap = L.n + 1, L.sum + deg, math.max(L.max, deg), L.gap + al * math.sin(math.rad(deg))
          if L.n >= 40 and L.logged < 8 then
            L.logged = L.logged + 1
            event(string.format('laser alignment (test): %s beam vs the game\'s aim: %.2f degrees on average (most %.2f), %.2f m apart at the aim point, over %d samples',
              st.dog.name, L.sum / L.n, L.max, L.gap / L.n, L.n))
            L.n, L.sum, L.max, L.gap = 0, 0, 0, 0
          end
        end
      end
      beam(gp or to, FIRE, gp and gfrom, gon, to, along)
    end
  end
  -- ((5.0 Test 17, my ask: "Guard dog marker seems a little inconsistent") its icon over its target the whole time it has
  -- one - lining up, firing, held by the safety, moving to a better spot, after a target went out of sight - like the
  -- sentries' (before, only while lining up or firing: the icon blinked out whenever the dog did anything else)
  local Dp, Pp = st.drone_pos, st.player_pos
  local docked = Dp and Pp and ((Dp[1] - Pp[1]) ^ 2 + (Dp[2] - Pp[2]) ^ 2) < 1.2 ^ 2   -- (on your back, reloading)
  laser.dog_target = st.target ~= 0 and not docked   -- (the test builds' marker count)
  -- ((5.1.0 Test 1, my ask: "the marker with the guard dog rover and guard dog would constantly flick around to
  -- enemies it cant reach still") not over a target the mod is hiding from it this frame (out of range, a friendly in
  -- the way, out of sight, no shot, armor it can't hurt): the game kept picking those and the mod kept taking them away,
  -- so the icon jumped between them. And only once it has kept the same target for MARK_SETTLE seconds
  if st.target ~= laser.dog_mark_tg then laser.dog_mark_tg, laser.dog_mark_t = st.target, t end
  local H = st.hidden
  if st.target ~= 0 and not docked and not (H and H[st.target]) and t - laser.dog_mark_t >= laser.MARK_SETTLE then
    local e = by_id(st.target)
    if e and e.pos then mark(spot(e), LOCK, e) end
  end
end
