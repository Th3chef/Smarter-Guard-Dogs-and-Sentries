
-- ======================================================================================================
-- Layout: where the game keeps things. Known build -> built-in table; new build -> scan the game's code.
-- ======================================================================================================
local function file_sha256(module)
  local path = ffi.new('uint16_t[4096]')
  local n = K32.SgdGetModuleFileNameW(module, path, 4096)
  assert(n > 0 and n < 4096, 'module path')
  local file = K32.SgdCreateFileW(path, 0x80000000, 7, nil, 3, 0x08000000, nil)
  assert(file ~= ffi.cast('void *', -1), 'cannot open module file')
  local alg, hash = ffi.new('void *[1]'), ffi.new('void *[1]')
  local ok, res = pcall(function()
    assert(BCRYPT.SgdBCryptOpenAlgorithmProvider(alg, ffi.new('uint16_t[?]', 7, { 83, 72, 65, 50, 53, 54, 0 }), nil, 0) == 0, 'sha256')
    assert(BCRYPT.SgdBCryptCreateHash(alg[0], hash, nil, 0, nil, 0, 0) == 0, 'sha256')
    local buf, got = ffi.new('uint8_t[262144]'), ffi.new('uint32_t[1]')
    while true do
      assert(K32.SgdReadFile(file, buf, 262144, got, nil) ~= 0, 'read module file')
      if got[0] == 0 then break end
      assert(BCRYPT.SgdBCryptHashData(hash[0], buf, got[0], 0) == 0, 'sha256')
    end
    local out = ffi.new('uint8_t[32]')
    assert(BCRYPT.SgdBCryptFinishHash(hash[0], out, 32, 0) == 0, 'sha256')
    local t = {}
    for i = 0, 31 do t[#t + 1] = string.format('%02X', out[i]) end
    return table.concat(t)
  end)
  if hash[0] ~= nil then BCRYPT.SgdBCryptDestroyHash(hash[0]) end
  if alg[0] ~= nil then BCRYPT.SgdBCryptCloseAlgorithmProvider(alg[0], 0) end
  K32.SgdCloseHandle(file)
  if not ok then error(res, 0) end
  return res
end

local function code_section(module)
  local b = ffi.cast('uint8_t *', module)
  local function r32(p) return tonumber(ffi.cast('uint32_t *', p)[0]) end
  local function r16(p) return tonumber(ffi.cast('uint16_t *', p)[0]) end
  local pe = r32(b + 0x3c)
  local count, optsize = r16(b + pe + 6), r16(b + pe + 20)
  local sec = b + pe + 24 + optsize
  for i = 0, count - 1 do
    local s = sec + 40 * i
    local vsize, rva, flags = r32(s + 8), r32(s + 12), r32(s + 36)
    if bit.band(flags, 0x20000000) ~= 0 and vsize > 0x100000 then
      local text = read(tonumber(ffi.cast('uintptr_t', b)) + rva, vsize)
      assert(text, 'cannot read code section')
      return text, rva
    end
  end
  error('no code section', 0)
end

local function compile(p)
  local segs, cur_off, cur = {}, nil, {}
  local n = #p / 2
  for k = 0, n - 1 do
    local h = p:sub(2 * k + 1, 2 * k + 2)
    if h == '??' then
      if cur_off then segs[#segs + 1] = { cur_off, table.concat(cur) }; cur_off, cur = nil, {} end
    else
      cur_off = cur_off or k
      cur[#cur + 1] = string.char(tonumber(h, 16))
    end
  end
  if cur_off then segs[#segs + 1] = { cur_off, table.concat(cur) } end
  local anchor = 1
  for j = 2, #segs do if #segs[j][2] > #segs[anchor][2] then anchor = j end end
  return segs, anchor, n
end

-- 0-based offset of the single place the pattern matches, or nil + why
local function find_once(text, p)
  local segs, anchor, n = compile(p)
  local a = segs[anchor]
  local init, found, count = 1, nil, 0
  while true do
    local s = string.find(text, a[2], init, true)
    if not s then break end
    local start = s - 1 - a[1]
    local ok = start >= 0 and start + n <= #text
    if ok then
      for j, seg in ipairs(segs) do
        if j ~= anchor and text:sub(start + seg[1] + 1, start + seg[1] + #seg[2]) ~= seg[2] then ok = false; break end
      end
    end
    if ok then
      count = count + 1; found = start
      if count > 1 then return nil, 'matches more than once' end
    end
    init = s + 1
  end
  if count == 0 then return nil, 'not found' end
  return found
end

local function su32(t, o) local a, b2, c, d = t:byte(o + 1, o + 4); return a + b2 * 256 + c * 65536 + d * 16777216 end
local function si32(t, o) local v = su32(t, o); return v >= 2147483648 and v - 4294967296 or v end

local function scan_layout(game, exe, dll_hash, exe_hash)
  local t0 = os.clock()
  local text, rva = code_section(game)
  local L = { dll_hash = dll_hash, exe_hash = exe_hash, globals = {} }
  local function at(p, what) local o, why = find_once(text, p); assert(o, what .. ': ' .. tostring(why)); return o end
  local function target(txt, base_rva, pats, what)
    local val
    for _, p in ipairs(pats) do
      local o = find_once(txt, p.p)
      if o then
        local v = base_rva + o + p.size + si32(txt, o + p.disp_at)
        assert(not val or val == v, what .. ': patterns disagree')
        val = v
      end
    end
    return assert(val, what .. ': not found')
  end
  for name, pats in pairs(PATTERNS.globals) do L.globals[name] = target(text, rva, pats, name) end
  for name, pats in pairs(PATTERNS.optional or {}) do
    local ok, v = pcall(target, text, rva, pats, name)
    if ok then L.globals[name] = v else note('optional game address not found (' .. name .. '): ' .. tostring(v)) end
  end
  L.stride = su32(text, at(PATTERNS.stride, 'behaviour stride') + 5)
  L.owner_index = su32(text, at(PATTERNS.owner_index, 'owner map') + 3) - 8
  L.owner_rows = su32(text, at(PATTERNS.owner_rows, 'owner entities') + 10) - 8
  -- the laser drones' AI behaviour id: the dispatcher case that calls the laser drone handler
  local d = at(PATTERNS.dispatch.p, 'behaviour dispatcher')
  local count, tbl = su32(text, d + PATTERNS.dispatch.count_at), su32(text, d + PATTERNS.dispatch.table_at)
  local handler = find_once(text, PATTERNS.laser_fn)
  if handler then
    for i = 0, count do
      local e = su32(text, tbl - rva + 4 * i) - rva
      if e >= 0 and e + 17 <= #text and text:sub(e + 1, e + 6) == '\139\215\72\139\203\232'
        and text:sub(e + 11, e + 17) == '\72\129\196\208\1\0\0' and e + 10 + si32(text, e + 6) == handler then
        assert(not L.laser_behaviour, 'laser handler found twice')
        L.laser_behaviour = i + 1
      end
    end
  end
  if not L.laser_behaviour then note('laser behaviour not identified; using the last known id'); L.laser_behaviour = KNOWN.laser_behaviour end
  text = nil
  local etext, erva = code_section(exe)
  L.exe_units = target(etext, erva, PATTERNS.exe_units, 'exe units')
  note(string.format('scan took %.2fs', os.clock() - t0))
  return L
end

local function serialize(v)
  if type(v) == 'number' then return string.format('%.17g', v) end
  if type(v) == 'string' then return string.format('%q', v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = '[' .. serialize(k) .. ']=' .. serialize(x) end
  return '{' .. table.concat(parts, ',') .. '}'
end

local function resolve_layout()
  local game, exe = K32.SgdGetModuleHandleA('game.dll'), K32.SgdGetModuleHandleA(nil)
  assert(game ~= nil and exe ~= nil, 'game modules not loaded')
  local gsha, esha = file_sha256(game), file_sha256(exe)
  note('game.dll ' .. gsha:sub(1, 16) .. '  exe ' .. esha:sub(1, 16))
  local L
  if gsha == KNOWN.dll_hash and esha == KNOWN.exe_hash then
    L = KNOWN; note('layout: built-in (known game version)')
  else
    local cache = LOGDIR and (LOGDIR .. '\\SmarterGuardDogsAndSentries.cache')
    local f = cache and io.open(cache, 'r')
    if f then
      local src = f:read('*a'); f:close()
      local fn = loadstring and loadstring('return ' .. src)
      local ok, c = pcall(fn or error)
      if ok and type(c) == 'table' and c.dll_hash == gsha and c.exe_hash == esha then L = c; note('layout: cached scan of this game version') end
    end
    if not L then
      note('layout: new game version, scanning game code...')
      L = scan_layout(game, exe, gsha, esha)
      if cache then local w = io.open(cache, 'w'); if w then w:write(serialize(L)); w:close() end end
    end
  end
  -- absolute addresses
  local gbase, ebase = tonumber(ffi.cast('uintptr_t', game)), tonumber(ffi.cast('uintptr_t', exe))
  local A = { stride = L.stride, owner_index = L.owner_index, owner_rows = L.owner_rows, laser_behaviour = L.laser_behaviour,
    exe_units = ebase + L.exe_units, g = {} }
  for k, v in pairs(L.globals) do A.g[k] = gbase + v end
  note(string.format('laser behaviour %d, guard dog behaviour %d', L.laser_behaviour, L.laser_behaviour + 1))
  return A
end
