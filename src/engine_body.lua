
-- ======================================================================================================
-- Windows API (declared under private names so they can never clash with another mod's declarations)
-- ======================================================================================================
for _, d in ipairs({
  'typedef struct { void *base; void *alloc_base; uint32_t alloc_protect; uint16_t partition; uint16_t pad; size_t size; uint32_t state; uint32_t protect; uint32_t type; } SgdRegion;',
  'void *SgdGetModuleHandleA(const char *name) __asm__("GetModuleHandleA");',
  'uint32_t SgdGetModuleFileNameW(void *module, uint16_t *path, uint32_t capacity) __asm__("GetModuleFileNameW");',
  'void *SgdGetCurrentProcess(void) __asm__("GetCurrentProcess");',
  'int SgdReadProcessMemory(void *process, const void *address, void *buffer, size_t size, size_t *done) __asm__("ReadProcessMemory");',
  'int SgdWriteProcessMemory(void *process, void *address, const void *buffer, size_t size, size_t *done) __asm__("WriteProcessMemory");',
  'size_t SgdVirtualQuery(const void *address, void *region, size_t size) __asm__("VirtualQuery");',
  'void *SgdCreateFileW(const uint16_t *path, uint32_t access, uint32_t share, void *security, uint32_t disposition, uint32_t flags, void *tmpl) __asm__("CreateFileW");',
  'int SgdReadFile(void *file, void *buffer, uint32_t size, uint32_t *done, void *overlapped) __asm__("ReadFile");',
  'int SgdCloseHandle(void *handle) __asm__("CloseHandle");',
  'int32_t SgdBCryptOpenAlgorithmProvider(void **alg, const uint16_t *id, const uint16_t *impl, uint32_t flags) __asm__("BCryptOpenAlgorithmProvider");',
  'int32_t SgdBCryptCloseAlgorithmProvider(void *alg, uint32_t flags) __asm__("BCryptCloseAlgorithmProvider");',
  'int32_t SgdBCryptCreateHash(void *alg, void **hash, void *obj, uint32_t objlen, const void *secret, uint32_t secretlen, uint32_t flags) __asm__("BCryptCreateHash");',
  'int32_t SgdBCryptHashData(void *hash, const void *data, uint32_t len, uint32_t flags) __asm__("BCryptHashData");',
  'int32_t SgdBCryptFinishHash(void *hash, void *out, uint32_t len, uint32_t flags) __asm__("BCryptFinishHash");',
  'int32_t SgdBCryptDestroyHash(void *hash) __asm__("BCryptDestroyHash");',
}) do pcall(ffi.cdef, d) end
local K32, BCRYPT = ffi.load('kernel32'), ffi.load('bcrypt')
local PROCESS = K32.SgdGetCurrentProcess()

-- ======================================================================================================
-- Log
-- ======================================================================================================
-- (4.5) the log lives with the other Bingus mods' logs, %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs (a tester's call);
-- straight in %LOCALAPPDATA% only if that folder isn't there. The files left in %LOCALAPPDATA% by earlier versions are
-- moved (the cached scan) or removed (the old logs), once
local LOGDIR
do
  local base = os.getenv('LOCALAPPDATA')
  if base then
    local dir = base .. '\\CowboyBingus\\Helldivers2\\Logs'
    local f = io.open(dir .. '\\SmarterGuardDogsAndSentries.log', 'a')
    if f then f:close(); LOGDIR = dir else LOGDIR = base end
    -- (not in the Smarter SEAF build: its files have their own names and there is nothing of its own to move)
    if not SGD.seaf_only then pcall(function()
      local old, new = base .. '\\SmarterGuardDogs', base .. '\\SmarterGuardDogsAndSentries'
      local g = io.open(old .. '.cache', 'r')
      if g then g:close(); os.rename(old .. '.cache', new .. '.cache'); os.remove(old .. '.cache') end
      os.remove(old .. '.log'); os.remove(old .. '-glow.txt'); os.remove(new .. '-glow.txt')
      if LOGDIR ~= base then
        local c = io.open(new .. '.cache', 'r')
        if c then c:close(); os.rename(new .. '.cache', LOGDIR .. '\\SmarterGuardDogsAndSentries.cache'); os.remove(new .. '.cache') end
        os.remove(new .. '.log'); os.remove(new .. '-research.log')
      end
    end) end
  end
end
local startup_notes = {}
local function note(s) startup_notes[#startup_notes + 1] = s end
local stats = { polls = 0, switches = 0, retargets = 0, safety_switches = 0, holds = 0, cover_switches = 0, armor_switches = 0, noshot_switches = 0, guarded_polls = 0, ignored_redirects = 0, memory_writes = 0, laser_frames = 0, write_failures = 0, read_errors = 0 }
local last_reason, last_error = '-', nil
local T0 = os.clock()
-- session summary: how long each state lasted, which dogs were seen, what the mod did, and recent events
local session = { statuses = {}, state_time = {}, dog_time = {}, actions = {}, events = {}, errors = {}, dirty = true,
  started = os.date('%Y-%m-%d %H:%M'), markers = {}, types = {}, type_list = {}, steps = {}, noshots = {},
  team = { max = 0, stops = 0, last = 0, notes = 0 }, sentries = {}, sentry_nodes = {}, sentry_types = {}, other_sentries = 0 }
local function event(msg)
  local line = string.format('%8.1fs  %s', os.clock() - T0, msg)
  local ev = session.events
  ev[#ev + 1] = line
  if #ev > 60 then table.remove(ev, 1) end
  -- errors are also kept apart (the first 10), so they don't scroll out of the recent events
  if msg:find('^error') and #session.errors < 10 then session.errors[#session.errors + 1] = line end
  session.dirty = true
end
local function bump(t, k) t[k] = (t[k] or 0) + 1 end
local function write_counts(f, title, t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(x, y) return t[x] > t[y] end)
  f:write(title .. ':' .. (#keys == 0 and ' none' or '') .. '\n')
  for _, k in ipairs(keys) do f:write(string.format('  %-34s %d\n', k, t[k])) end
end
local function mmss(s) return string.format('%dm%02ds', math.floor(s / 60), math.floor(s % 60)) end
local function write_log()
  session.dirty = false
  if not LOGDIR then return end
  local f = io.open(LOGDIR .. '\\SmarterGuardDogsAndSentries.log', 'w')
  if not f then return end
  f:write('Smarter Guard Dogs & Sentries ' .. VERSION .. (READ_ONLY and ' (read-only diagnostic build: actions below were NOT carried out)' or '') .. '\n')
  f:write('started ' .. tostring(session.started) .. ', running for ' .. mmss(os.clock() - T0) .. '\n')
  for _, n in ipairs(startup_notes) do f:write(n .. '\n') end
  f:write('status: ' .. tostring(SGD.status) .. (SGD.dog and (' (' .. SGD.dog .. ')') or '') .. ', last action: ' .. tostring(last_reason) .. '\n')
  f:write(string.format('health: polls=%d memory_writes=%d write_failures=%d read_errors=%d laser_frames=%d\n',
    stats.polls, stats.memory_writes, stats.write_failures, stats.read_errors, stats.laser_frames))
  if last_error then f:write('last error: ' .. tostring(last_error) .. '\n') end
  -- time rather than poll counts: polls run every frame while a dog is out, but only a few times a second otherwise
  local keys = {}
  for k in pairs(session.state_time) do keys[#keys + 1] = k end
  table.sort(keys, function(x, y) return session.state_time[x] > session.state_time[y] end)
  f:write('time in each state:' .. (#keys == 0 and ' none' or '') .. '\n')
  for _, k in ipairs(keys) do f:write(string.format('  %-34s %s\n', k, mmss(session.state_time[k]))) end
  if not SGD.seaf_only then   -- (the Smarter SEAF build handles no dogs or sentries)
  f:write('dogs:' .. (next(session.dog_time) and '' or ' none out yet') .. '\n')
  for name, d in pairs(session.dog_time) do
    f:write(string.format('  %-10s out %s, with a target %.0f%% of that, firing %.0f%% of the time it had one\n', name,
      mmss(d.out), d.out > 0 and 100 * d.targeted / d.out or 0, d.targeted > 0 and 100 * d.firing / d.targeted or 0))
  end
  f:write(session.team.off and 'teammates: not checked (teammate safety option off)\n'
    or (session.team.max > 0 and string.format('teammates: up to %d seen at once, safety stops for a teammate: %d\n', session.team.max,
      (function() local n = session.team.stops; for _, d in pairs(session.sentries) do n = n + (d.mate_stops or 0) end; return n end)())   -- (the dog's and the sentries')
    or 'teammates: none seen\n'))
  -- sentries (4.0): per kind, how long yours were out and what the mod did with them
  f:write('sentries:' .. (next(session.sentries) and '' or ' none of yours out yet') .. '\n')
  local snames = {}
  for name in pairs(session.sentries) do snames[#snames + 1] = name end
  table.sort(snames)
  for _, name in ipairs(snames) do
    local d = session.sentries[name]
    f:write(string.format('  %-18s placed %d, out %s, with a target %.0f%% of that; safety stops %d (for a teammate %d), armor skips %d, priority switches %d%s%s%s%s%s%s%s%s\n',
      name, d.placed, mmss(d.out), d.out > 0 and 100 * d.targeted / d.out or 0, d.stops, d.mate_stops, d.armour, d.priority or 0,
      d.cooldowns and string.format(', cool-downs %d', d.cooldowns) or '',
      d.sentry_burst_done and string.format(', short bursts %d', d.sentry_burst_done) or '',
      d.sentry_spread and string.format(', set alight and moved on %d', d.sentry_spread) or '',
      d.sentry_gunship_moving and string.format(', left a moving gunship %d', d.sentry_gunship_moving) or '',
      d.sentry_out_of_sight and string.format(', dropped one out of sight %d', d.sentry_out_of_sight) or '',
      d.sentry_on_dropship and string.format(', left one still on a dropship %d', d.sentry_on_dropship) or '',
      d.sentry_out_of_reach and string.format(', dropped one out of reach %d', d.sentry_out_of_reach) or '',
      d.too_close and d.too_close > 0 and string.format(', an enemy inside its minimum range %s', mmss(d.too_close)) or ''))
  end
  if session.other_sentries > 0 then
    f:write(string.format('  other players\' sentries seen (run by their own game, not changed from yours): up to %d\n', session.other_sentries))
  end
  end
  write_counts(f, READ_ONLY and 'actions it would have taken' or 'actions taken', session.actions)
  if #session.errors > 0 then
    f:write('errors (first 10):\n')
    for _, e in ipairs(session.errors) do f:write('  ' .. e .. '\n') end
  end
  if TESTER and session.timing and session.timing.n > 0 then
    local T = session.timing
    f:write(string.format('mod cost per frame (test): average %.3f ms, highest %.2f ms, over 1 ms in %d of %d frames\n', T.sum / T.n, T.max, T.over, T.n))
  end
  if TESTER and not SGD.seaf_only then write_counts(f, 'enemy types the dog picked (type id: times; for bug reports)', session.types) end
  if TESTER and next(session.steps) then write_counts(f, 'what the dog was doing while out (polls; AI step 6 = lining up, 7 = firing)', session.steps) end
  if TESTER and next(session.sentry_nodes) then write_counts(f, 'what the sentries were doing (polls; by AI step)', session.sentry_nodes) end
  if TESTER and next(session.sentry_types) then write_counts(f, 'enemy types the sentries went for (type id: times)', session.sentry_types) end
  if TESTER and next(session.noshots) then write_counts(f, 'no_shot by enemy type and distance from the dog', session.noshots) end
  if TESTER and session.seaf_text then
    local ok, lines = pcall(session.seaf_text)
    if ok then for _, l in ipairs(lines) do f:write(l .. '\n') end end
  end
  if TESTER and #session.markers > 0 then
    f:write('F8 markers:\n')
    for _, e in ipairs(session.markers) do f:write('  ' .. e .. '\n') end
  end
  f:write('recent events (last 60):\n')
  for _, e in ipairs(session.events) do f:write('  ' .. e .. '\n') end
  f:close()
end

-- ======================================================================================================
-- Memory access (ReadProcessMemory on our own process: a bad address fails cleanly instead of crashing)
-- ======================================================================================================
local SMALL = ffi.new('uint8_t[8192]')
local DONE = ffi.new('size_t[1]')
local read
do
  local PVOID = ffi.typeof('const void *')
  read = function(addr, n)
    if type(addr) ~= 'number' or addr < 65536 then return nil end
    local buf = n <= 8192 and SMALL or ffi.new('uint8_t[?]', n)
    if K32.SgdReadProcessMemory(PROCESS, ffi.cast(PVOID, addr), buf, n, DONE) == 0 or DONE[0] ~= n then return nil end
    return ffi.string(buf, n)
  end
end
-- (4.0.6) numbers are read straight out of the string's bytes, without first copying the piece into a new string
-- (reads past the end, which the old way turned into a short copy, still go the old way)
local U32, U64, F32 = ffi.new('uint32_t[1]'), ffi.new('uint64_t[1]'), ffi.new('float[1]')
local u32, u64, f32
do
  local cast = ffi.cast
  local PU8, PU32, PU64, PF32 = ffi.typeof('const uint8_t *'), ffi.typeof('const uint32_t *'), ffi.typeof('const uint64_t *'), ffi.typeof('const float *')
  u32 = function(s, o)
    if o + 4 > #s then ffi.copy(U32, s:sub(o + 1, o + 4), 4); return tonumber(U32[0]) end
    return tonumber(cast(PU32, cast(PU8, s) + o)[0])
  end
  u64 = function(s, o)
    if o + 8 > #s then ffi.copy(U64, s:sub(o + 1, o + 8), 8); return tonumber(U64[0]) end
    return tonumber(cast(PU64, cast(PU8, s) + o)[0])
  end
  -- (4.5) a float whose bits are an unusual NaN (0xffffffff, say: memory past the end of a list) came back from LuaJIT
  -- as nil, not as NaN, and a nil stopped the sentries in a Test 27 log: every such value is returned as a plain NaN
  local NAN = 0 / 0
  f32 = function(s, o)
    local v
    if o + 4 > #s then ffi.copy(F32, s:sub(o + 1, o + 4), 4); v = tonumber(F32[0])
    else v = tonumber(cast(PF32, cast(PU8, s) + o)[0]) end
    if v == nil or v ~= v then return NAN end
    return v
  end
end
local function ptr_of(s, o)
  local p = s and u64(s, o or 0)
  if not p or p < 65536 or p >= 140737488355328 then return nil end
  return p
end

-- all game reads go through need(): a failed read aborts the whole snapshot (nothing is written that tick)
local Abort = {}
local function need(v, what) if v == nil or v == false then error({ Abort, what }, 0) end return v end
local function rd(addr, n, what) return need(read(addr, n), what) end
local function rptr(addr, what) return need(ptr_of(read(addr, 8), 0), what) end

local REGION = ffi.new('SgdRegion[1]')
local function writable(addr, n)
  local a, stop = addr, addr + n
  while a < stop do
    if K32.SgdVirtualQuery(ffi.cast('const void *', a), REGION, ffi.sizeof('SgdRegion')) == 0 then return false end
    local r = REGION[0]
    -- committed, private, plain read/write memory only (never code, never mapped files)
    if r.state ~= 0x1000 or r.type ~= 0x20000 or r.protect ~= 0x04 then return false end
    local base = tonumber(ffi.cast('uintptr_t', r.base))
    local rend = base + tonumber(r.size)
    if rend <= a then return false end
    a = rend
  end
  return true
end
local function write(addr, bytes)
  if READ_ONLY then return false end
  if not writable(addr, #bytes) then return false end
  if K32.SgdWriteProcessMemory(PROCESS, ffi.cast('void *', addr), bytes, #bytes, DONE) == 0 or DONE[0] ~= #bytes then return false end
  stats.memory_writes = stats.memory_writes + 1
  return read(addr, #bytes) == bytes
end
local function u64bytes(v) U64[0] = v; return ffi.string(U64, 8) end

-- open-addressing hash map used by the game's component managers: { slots*, ?, capacity, empty_key, multiplier }
local function map_lookup(addr, key, max_capacity, header)
  local h = header or rd(addr, 20, 'map header')
  local cap, empty, mult = u32(h, 8), u32(h, 12), u32(h, 16)
  if cap == 0 then return nil end
  need(cap <= max_capacity and bit.band(cap, cap - 1) == 0, 'map capacity')
  local slots = need(ptr_of(h, 0), 'map slots')
  local hash = tonumber(ffi.cast('uint32_t', ffi.new('uint64_t', key) * ffi.new('uint64_t', mult)))
  for i = 0, math.min(cap, 128) - 1 do
    local e = rd(slots + 8 * bit.band(hash + i, cap - 1), 8, 'map slot')
    local k = u32(e, 0)
    if k == key then
      local v = u32(e, 4)
      return v ~= 4294967295 and v or nil
    end
    if k == empty then return nil end
  end
  error({ Abort, 'map probe' }, 0)
end

-- ======================================================================================================
-- Guard dog types (entity type hashes of the backpack and of the drone, stored byte-reversed in memory)
-- ======================================================================================================
local function type_hash(h) return (h:gsub('..', function(x) return string.char(tonumber(x, 16)) end)):reverse() end
local AVATAR_TYPE = type_hash('4d1c334d294dfa97')
-- names for common enemy types, only so logs are easier to read (identified in play; not used for any decision)
local LABELS = {}
for h, n in pairs({
  -- Illuminate (unit names from Filediver: Wretch = cha_bodyhorror_bladed, Crusher = cha_bodyhorror_helmetguy)
  cc188f0c80505c6c = 'Wretch', ['905809a4c28d8a45'] = 'Crusher', ['78e1497571012c47'] = 'Voteless',
  ['0adc9f9173ad8e1d'] = 'Voteless (v2)', ['44458a2c52b002fb'] = 'Voteless (v3)', ['67dc32dca4f02d33'] = 'Fleshmob',
  ['0883366204e1ccc5'] = 'Illuminate turret',
  -- Terminids
  a1f37bf2a40fbde4 = 'Warrior (plus)', aab438596f5e8fd9 = 'Scavenger (predator)', f79cd8bb654397df = 'Big Warrior (tier 2)',
  ['64090088502435dd'] = 'Shrieker', f540ca9d9d4a422e = 'Stalker', ['672f7da17f3ba34a'] = 'Impaler tentacle',
  ['5ca832447445c0ba'] = 'Hunter', ccae5264acd591b7 = 'Spewer (tier 2)', ['72a83e49ced6db3d'] = 'Spitter',
  ['10081acef6163ef6'] = 'Acid Warrior', dcf8e74212fbee3b = 'Impaler',
  -- Automatons
  a6a68d8af177f3a1 = 'Berserker', ['0002ba767df856f3'] = 'Trooper (tier 3)', d8cbc4a807a6d035 = 'Trooper (melee)', ['2c1a7790c435fd67'] = 'Automaton MG Emplacement', a71aafd82c6ebc92 = 'Conscript commander', ['746a7f3beda32699'] = 'Elite Rusher', ['282eb766c1ffa6a1'] = 'Gunship',
  ['856e9710e45e760f'] = 'Trooper (jump pack, melee)', d37e8d120d2836e3 = 'Factory Strider',
}) do LABELS[type_hash(h)] = n end
-- (4.0) names from the HD2 Enemy Codex (the enemy models matched to their wiki pages; names checked by a tester);
-- armoured enemies are named by the armour list (engine_armor.lua) instead
for h, n in pairs({
  ['67381f685e9b69a8'] = 'Agitator', ['9f44121c554dae89'] = 'Agitator',
  ['4fb6077f1597691d'] = 'Berserker (chainsaw)', ['54e107dacf6929cb'] = 'Berserker', a6a68d8af177f3a1 = 'Berserker',
  ['2d1636f2ee8a6306'] = 'Commissar (melee claw)', a71aafd82c6ebc92 = 'Commissar',
  cbce5f5f0310ef15 = 'Commissar (handgun)', e2e62fdd39407fe3 = 'Jet Brigade Trooper (jumppack)',
  ['426b3df007be9f18'] = 'MG Raider (backpack lmg)', ['68ba814ff35bf19c'] = 'MG Raider (lmg)',
  f4c0b6c9218fb571 = 'Pyro Trooper (flamer)', ['1338b552afe68f0a'] = 'Radical', ['746a7f3beda32699'] = 'Radical',
  ['71b285b6d2b161c9'] = 'Rocket Raider (cannon)', ['64ba5f030b114ec1'] = 'Trooper',
  ['9821303bd499cd62'] = 'Trooper', ['9f57782f00e6ed20'] = 'Trooper', b2b3056bdf28e57b = 'Trooper',
  bcb3210cf8ef49d3 = 'Trooper (smg)', e8f19a0aa958e46d = 'Crescent Overseer', ['905809a4c28d8a45'] = 'Crusher',
  ['604a794ec45bb820'] = 'Elevated Overseer', ['67dc32dca4f02d33'] = 'Fleshmob', ['453fe22c634eb30f'] = 'Gatekeeper',
  ['34dfd23365472e9e'] = 'Obtruder', da40bb347c7447f2 = 'Overseer', ['20b9c7734daead65'] = 'Veracitor',
  ['0adc9f9173ad8e1d'] = 'Voteless', ['44458a2c52b002fb'] = 'Voteless', ['78e1497571012c47'] = 'Voteless',
  ac60e78435098c9d = 'Watcher', cc188f0c80505c6c = 'Wretch', d522fd4748d443a5 = 'Brood Commander',
  ['72a83e49ced6db3d'] = 'Bile Spitter', ['10081acef6163ef6'] = 'Bile Warrior', a478d36a62a861f4 = 'Hunter',
  aab438596f5e8fd9 = 'Pouncer', d7e2c78b1ef4a8e1 = 'Predator Hunter', a35207c6f2150806 = 'Rupture Warrior',
  ['5b968cd78f8bc7a0'] = 'Scavenger', c14e0e887e7d2106 = 'Scavenger', ['64090088502435dd'] = 'Shrieker',
  c28b3482e73d1ea9 = 'Spore Burst Hunter', db964631be1cf501 = 'Spore Burst Scavenger',
  ['1baeef36a88ae579'] = 'Spore Burst Warrior', f540ca9d9d4a422e = 'Stalker', ['09872e66d1276e1f'] = 'Warrior',
  be39e313a1e46bb9 = 'Warrior (pale)', a1f37bf2a40fbde4 = 'Hive Guard', ['36aa99cce5e60146'] = 'Bile Spewer',
  ccae5264acd591b7 = 'Bile Spewer', cc7022fdd172089b = 'Nursing Spewer', a381a11c07d3eb94 = 'Rupture Spewer',
  f79cd8bb654397df = 'Alpha Commander', fb9937035d652c43 = 'Scout Strider pilot', ['4d1c334d294dfa97'] = 'Helldiver',
  -- (4.5, Codex check) the Illuminate's weapons and the Crusher's cleaver are entries of their own
  ['9c7ef47a463d5327'] = 'Overseer (lightspear)', ['0cf9b9b95edfef81'] = 'Elevated Overseer (rifle)',
  ['705362ad578943f6'] = 'Crescent Overseer (gun)', ['258bd988cd66c94b'] = 'Crusher (cleaver)'
}) do LABELS[type_hash(h)] = n end
local DOGS = {
  { name = 'Rover', pack = type_hash('af9b683ccb6ddc02'), drone = type_hash('5beec97f4c7f4ae9'), laser = true,
    fast = true, radius = 0.35, safety_keep = 0.4, linger = 0.3, range = 35,
    gun = type_hash('2c66c201b2543d2c'), beam_to_aim = true },   -- (4.5.3: its laser comes out of its barrel too, a tester's call)
    -- (4.5.3 Test 17: gun = its weapon's own entity, from a tester's Test 15 log; beam_to_aim: its muzzle part twists as
    -- it sweeps its beam over what it burns - the barrel axis was found and lost four times and the beam ran up to 19
    -- degrees off the game's aim - so its laser runs from its muzzle to where the game aims it)
    -- (its beam is thin, so its safety margin, look-ahead after a fast turn and hide time are a little shorter;
    -- beyond ~35 m it often lines up without firing, so farther enemies wait while something closer is available:
    -- it is a guard dog, the enemies near you come first)
  { name = 'K-9', pack = type_hash('c28da712b12e3dfa'), drone = type_hash('4b071633584e4594'), laser = true,
    fast = false, radius = 0.6, chain = 3.0, aim_rise = 1.0, gun = type_hash('a0532c3616528cbf'), beam_to_aim = true },   -- (gun: 4.5.3 Test 15 log)
    -- (4.5.3 Test 18: beam_to_aim like the Rover's - its arc weapon's muzzle part lost its barrel direction twice in a
    -- tester's Test 17 log (0.697, 0.883) and the laser twitched at times)   -- (4.5.3: out of its barrel too; its arc weapon sways, and so does the laser)
  { name = 'Guard Dog', pack = type_hash('255ebc5767d7ceec'), drone = type_hash('a0ff2f9a0ca6992a'), laser = false,
    fast = false, radius = 0.35, safety_keep = 0.4, linger = 0.3, range = 32, hard_range = true, aim_rise = 1.2,
    gun = type_hash('a32621e3bde13379') },   -- it only ever opens fire within ~32 m (measured from test logs); gun: its weapon's own entity (4.5.3 Test 11 log)
    -- (safety trimmed like the Rover's: slightly smaller margin, shorter look-ahead after a fast turn and hide time;
    -- hard_range: it never fires beyond ~32 m, so enemies farther out stay hidden even when nothing is closer)
}
local DOG_BY_PACK = {}
for _, d in ipairs(DOGS) do DOG_BY_PACK[d.pack] = d end

-- Sentries (4.0). Keyed by the sentry's entity type (the hash of its unit name, e.g. hellpod/turret_machinegun_gpmg;
-- the Gatling is hellpod/turret/gatling_turret) and checked against its AI behaviour id where known.
--  line/spread: how far (metres) a shot line must stay from a body, plus this much per metre from the muzzle
--  splash: the shot explodes; nobody may stand within this many metres of the enemy
--  min_range: it can't fire while an enemy is this close to it (metres; the rocket sentry, 10 m per the wiki): a red
--  ring of that radius flashes around it meanwhile
--  blast: mortars lob shells in an arc, so there is no line to check; nobody may stand within this of the enemy
--  sweep: keeps firing while it turns to its next target, so the turn must not pass over anyone either
--  barrel_axis: which axis of its muzzle part is the barrel, when known from testing (otherwise learned in play)
--  pen: the heaviest armour it can hurt (armour skipping); none = shoots everything the game lets it
--  prefer: 'heavy' = armoured enemies first (rocket, autocannon), 'light' = unarmoured enemies first (machine gun, Gatling)
--  heat: it overheats (Laser Sentry): rested before it burns out
--  spreads_fire: sets enemies alight and moves on, like the Rover (Laser Sentry); fire_node: its AI step while firing;
--  spares_helldivers: it would target helldivers itself (Tesla Tower): yours are hidden from it; ring: instead of a laser, a
--  ring of this radius (metres) around it, green while it engages and faint green while idle, plus the laser to its target
--  no_laser: no targeting laser (the mortars: they lob over cover, so their line is rarely in view; a tester's call)
--  salvo_node: an AI step of its own (besides step 10) in which it won't choose again: only safety stops are asked for then
--  hits_carried: may shoot enemies still aboard a dropship (rocket, autocannon: the splash hurts the dropship too);
--    the other sentries leave them until they land
--  bursts: short bursts at Heavy Devastators, like the Guard Dog (machine gun, Gatling)
--  air_first: gunships and Stingrays before everything else (Gatling, autocannon, rocket, Laser); air_still: only while the gunship hovers (rocket)
--  laser_at_enemy: no barrel axis to follow (rocket, autocannon): the laser runs from the muzzle to where the game aims
--  the gun. Every other sentry's laser comes out along its barrel (4.5.3)
-- The log says when a sentry-like AI shows up with a type that isn't in this list.
local SENTRIES = {
  { name = 'Machine Gun Sentry', type = type_hash('37cde43876ba26bb'), ai = 312, line = 0.45, spread = 0.01, sweep = true, barrel_axis = 2, pen = 3, bursts = true, prefer = 'light' },
  { name = 'Gatling Sentry', type = type_hash('ef85d6cf58e31d70'), ai = 213, line = 0.5, spread = 0.015, sweep = true, barrel_axis = 2, pen = 3, bursts = true, prefer = 'light', air_first = true },
  { name = 'Autocannon Sentry', type = type_hash('54d86057f5dacfb9'), ai = 5, line = 0.45, spread = 0.005, splash = 2.0, prefer = 'heavy', air_first = true, hits_carried = true, laser_at_enemy = true },   -- (type confirmed in game; unit hellpod/autocannon_turret/autocannon_turret)
  { name = 'Rocket Sentry', type = type_hash('37079568dc86e9c6'), ai = 611, line = 0.6, spread = 0.01, splash = 4.5, min_range = 10, prefer = 'heavy', air_first = true, hits_carried = true, air_still = true, laser_at_enemy = true,
    salvo_node = 13 },   -- (mid-salvo it ignores being asked to choose again)
  -- (heat: the wiki says it heats 8 degrees a second while firing, burns out at 250 and cools 3.8-7.5 a second; in game it
  -- overheated after about 28 s on targets, so the estimate uses 11 a second. The game's own heat meter is used when found)
  { name = 'Laser Sentry', type = type_hash('56070f36cfffa8a8'), ai = 308, line = 0.35, spread = 0.002, sweep = true, barrel_axis = 2, pen = 4, heat = { cap = 250, rate = 11, cool = 3.8 },
    prefer = 'light', air_first = true, spreads_fire = true, fire_node = 13 },   -- (ours runs along its barrel, over its own beam, turning with it)
  { name = 'Flame Sentry', type = type_hash('820cc3bafe962858'), ai = 207, line = 1.0, spread = 0.03, splash = 2.5, sweep = true,
    range = 30, prefer = 'near', spreads_fire = 'keep' },   -- ('range' = metres from its muzzle: 4.5.2 set 20, a tester's call as the game let it pick
    -- enemies well past its flames; 4.6.1 30, a tester's call as its flames reach about 34 m. 'near': closest first, no armor tiers;
    -- 4.6.2 'keep': it moves on from an enemy it has set alight to the next unlit one, a tester's call)
  -- (4.0) the Tesla Tower (hellpod/tesla_turret): its arc reaches 20 m and chains from its target to whoever stands
  -- next to it, and it zaps standing helldivers in range (wiki). 'spares_helldivers': it targets only enemies the mod
  -- has marked (4.5, engine_sentry.lua tesla_filter); the helldivers' entries are also hidden from it every frame, and
  -- it is asked to choose again whenever it is on one all the same. Enemies within 10 m of a helldiver are left alone
  -- (the arc's jump, 'splash'; 5 m before 4.5, a tester's call), and instead of a laser it shows its range as a ring
  -- ('ring', shown the whole time it is out). AI 661 (Test 28 log); its gun sits ~2.6 m up
  { name = 'Tesla Tower', type = type_hash('74599e56f72f9d7e'), ai = 661, line = 0.6, spread = 0.02, splash = 10.0, spares_helldivers = true,
    ring = 20, muzzle_up = 2.6, salvo_node = 4 },   -- (step 4: its 1.5 s of firing, in which it doesn't choose again)
  { name = 'Mortar Sentry', type = type_hash('51a0812e3bce2d74'), ai = 322, blast = 12, no_laser = true },   -- (AI 322 in game, Test 27 log)
  { name = 'EMS Mortar Sentry', type = type_hash('b2053a1838092f8b'), ai = 324, blast = 8, no_laser = true },   -- (AI 324 in game, Test 28 log)
  -- (5.0) the guns that come with a resupply pod (Armed Resupply Pods booster) and on the M-103 Supply FRV: both an
  -- automatic AR-23P Liberator Penetrator (medium armour penetration, 640 rpm, ~120-140 rounds, 30 m), run on the Gatling's
  -- AI template. Types from a 4.0.6 Test 8 log (AI 213 and 212); their units are unnamed, found in the resupply pod's
  -- archive (263277e5added56c, with the ammo rack) and the Supply FRV's (149f685717737cae). Treated like the machine gun:
  -- skips armour it can't hurt (saving its rounds), short bursts at Heavy Devastators, unarmoured enemies first. 'ais':
  -- either of the Gatling template's two ids is accepted. The FRV's gun moves with the vehicle and fires past its driver
  { name = 'Resupply Pod Gun', type = type_hash('73681ffd58fa1a90'), ai = 213, ais = { [212] = true, [213] = true }, line = 0.45, spread = 0.01, sweep = true, barrel_axis = 2, pen = 3, bursts = true, prefer = 'light',
    turn_hold = 30 },   -- (4.6.2: as the Supply FRV gun, whose AI it runs - turns to an enemy far round without firing)
  -- (4.5: barrel_axis 2 like the Gatling's, whose AI they run on: a Test 28 log found axis 2+ at 0.987 on the FRV gun;
  -- learning it on a moving vehicle failed as often as not)
  { name = 'Supply FRV Gun', type = type_hash('4df41f84668d07fb'), ai = 212, ais = { [212] = true, [213] = true }, line = 0.45, spread = 0.01, sweep = true, barrel_axis = 2, pen = 3, bursts = true, prefer = 'light',
    vehicle = true, laser_when_firing = true, turn_hold = 30 },   -- (test builds log where its riders sit relative to it and to its line of fire)
    -- (turn_hold, 4.6.2, a tester: it wasted ammo swinging from one enemy to the next while firing - after a kill, the
    -- next enemy more than this many degrees off its barrel is turned to without firing; see engine_sentry.lua)
}
local SENTRY_BY_TYPE = {}
for _, d in ipairs(SENTRIES) do d.sentry = true; SENTRY_BY_TYPE[d.type] = d end
-- AI behaviour ids built on the game's sentry template (from the game code): anything else with one of these that
-- turns up on your side is reported in the log, so a missing sentry can be added
local SENTRY_AI = { [5] = true, [207] = true, [212] = true, [213] = true, [308] = true, [312] = true, [319] = true, [320] = true,
  [321] = true, [322] = true, [323] = true, [324] = true, [603] = true, [611] = true, [661] = true, [680] = true, [685] = true }
-- (filled in by engine_sentry.lua: the sentry lines for an F8 marker)
local sentry_marker_text
