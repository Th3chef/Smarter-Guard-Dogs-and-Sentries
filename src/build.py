"""Build the Smarter Guard Dogs Arsenal packages (live + read-only diagnostic) from sgd/*.lua."""
import struct, json, os, zipfile, sys

def resource_hash(name):
    """Stingray resource id: MurmurHash64A (seed 0) of the resource name."""
    data = name.encode('utf-8'); mask, m = (1 << 64) - 1, 0xC6A4A7935BD1E995
    h = (len(data) * m) & mask
    n8 = len(data) // 8 * 8
    for (k,) in struct.iter_unpack('<Q', data[:n8]):
        k = (k * m) & mask; k ^= k >> 47; k = (k * m) & mask
        h = ((h ^ k) * m) & mask
    if data[n8:]:
        h = ((h ^ int.from_bytes(data[n8:], 'little')) * m) & mask
    h ^= h >> 47; h = (h * m) & mask; h ^= h >> 47
    return h

MODULE = 'mods/chef/smarter_guard_dogs'
LASER_MODULE = 'mods/chef/smarter_guard_dogs_laser'
ARMOR_MODULE = 'mods/chef/smarter_guard_dogs_armor'
TEAM_MODULE = 'mods/chef/smarter_guard_dogs_teammates'
SAFETY_MODULE = 'mods/chef/smarter_guard_dogs_safety'
DOGS_MODULE = 'mods/chef/smarter_guard_dogs_dogs'
SENTRIES_MODULE = 'mods/chef/smarter_guard_dogs_sentries'
TESLA_MODULE = 'mods/chef/smarter_guard_dogs_tesla'
PRIORITY_MODULE = 'mods/chef/smarter_guard_dogs_priority'
SENTRY_SAFETY_MODULE = 'mods/chef/smarter_guard_dogs_sentry_safety'   # (4.6.5)
SEAF_SAFETY_MODULE = 'mods/chef/smarter_guard_dogs_seaf_safety'   # (4.7.0)
PING_MODULE = 'mods/chef/smarter_guard_dogs_ping'   # (5.0.0)
MARKER_MODULE = 'mods/chef/smarter_guard_dogs_marker'   # (5.0.0 Test 13)
GLOW_MODULE = 'mods/chef/smarter_guard_dogs_glow'
# (4.5.3) Laser Brightness: one tiny addon per sub-option, all under the same name (only one is installed at a time)
BRIGHT_MODULE = 'mods/chef/smarter_guard_dogs_brightness'
BRIGHTS = [('Normal (100%)', 1.0, 'Laser Brightness 100'), ('Dim (50%)', 0.5, 'Laser Brightness 50'), ('Softer (75%)', 0.75, 'Laser Brightness 75'),
           ('Bright (150%)', 1.5, 'Laser Brightness 150'), ('Brightest (200%)', 2.0, 'Laser Brightness 200')]
# (5.0.0 Test 15) Marker Opacity: the same way, one tiny addon per sub-option under one name
OPAC_MODULE = 'mods/chef/smarter_guard_dogs_marker_opacity'
OPACS = [('Full (100%)', 1.0, 'Marker Opacity 100'), ('Medium (75%)', 0.75, 'Marker Opacity 75'), ('Light (50%)', 0.5, 'Marker Opacity 50'),
         ('Faint (25%)', 0.25, 'Marker Opacity 25')]
def opac_source(v):
    return ('-- HD2-Addon: %s\n'
            '-- Smarter Guard Dogs & Sentries - Marker Opacity (optional part): the targeting markers at %d%% opacity.\n'
            "rawset(_G, 'SmarterGuardDogsMarkerOpacity', %s)\n" % (OPAC_MODULE, round(v * 100), repr(v))).encode('utf-8')
def bright_source(v):
    return ('-- HD2-Addon: %s\n'
            '-- Smarter Guard Dogs & Sentries - Laser Brightness (optional part): the targeting laser at %d%%.\n'
            "rawset(_G, 'SmarterGuardDogsLaserBrightness', %s)\n" % (BRIGHT_MODULE, round(v * 100), repr(v))).encode('utf-8')
VERSION = '5.0.0'
NAME_SUFFIX = ''   # '' for releases, e.g. ' Test 3' for test builds
ARCHIVE = '9ba626afa44a3aa3.patch_0'        # the game archive the shared loader reads addons from
LUA_TYPE, MAGIC = 0xa14e8dfa2cd117e2, 0xF0000011
PARTS = ['engine_head', 'engine_body', 'layout_data', 'engine_layout', 'engine_state', 'icon_data', 'engine_laser', 'engine_research', 'engine_armor', 'engine_logic', 'engine_sentry', 'engine_main']
GUID_LIVE = '6f1d2c8e-5a47-4b93-9e0a-3c7b1f4d8a21'
GUID_DIAG = 'b2e84f17-0c6d-4a59-8f3e-91d5a7c2e640'
GUID_TEST = '29dde155-0b2a-4534-aa21-25a8244297f3'   # test builds: sits next to the release in Arsenal
HERE = os.path.dirname(os.path.abspath(__file__))

def archive(entries):
    """Stingray patch archive holding Lua resources: 72-byte header, one type row, 80-byte file rows, data."""
    n = len(entries)
    rows_at = 72 + 32
    cursor = rows_at + 80 * n
    rows, body = b'', b''
    for i, (rid, data) in enumerate(entries):
        pad = -cursor % 16; body += b'\0' * pad; cursor += pad
        rows += struct.pack('<7Q6I', rid, LUA_TYPE, cursor, 0, 0, 0, 0, len(data), 0, 0, 16, 16, i)
        body += data; cursor += len(data)
    def header(total):
        h = struct.pack('<III', MAGIC, 1, n) + b'\0' * 20 + struct.pack('<I', total) + b'\0' * 36
        assert len(h) == 72
        return h + struct.pack('<QQQII', 0, LUA_TYPE, n, 16, 16)
    total = cursor
    return header(total) + rows + body

# (4.6.6 Test 2+) research probe (engine_probe.lua): numbered Tester builds only, never a release or a release's Tester
PROBE_PART, PROBE_BEFORE = 'engine_probe5', 'engine_main'   # (5.0.0 Test 4: gunship lead and body parts; engine_probe.lua, the ping probe, is shelved)

def source(read_only, tester=False):
    parts = list(PARTS)
    if tester and NAME_SUFFIX:
        parts.insert(parts.index(PROBE_BEFORE), PROBE_PART)
    src = ''.join(open(os.path.join(HERE, p + '.lua'), encoding='utf-8').read() for p in parts)
    # ((5.0 Test 9) Mod Options Menu refuses a row whose description is over 400 characters ("invalid description":
    # the Targeting Laser row was missing from the menu in Tests 4-8))
    import re
    for m in re.finditer(r"key = '(\w+)'.*?description = '((?:[^'\\]|\\.)*)'", open(os.path.join(HERE, 'engine_main.lua'), encoding='utf-8').read(), re.S):
        assert len(m.group(2).replace("\\'", "'")) <= 400, 'menu description too long: %s (%d)' % (m.group(1), len(m.group(2)))
    # ((4.6.6 review) the test switches must be off in the source, so a plain build can never ship one switched on:
    # before, each was only checked when the build turned it on)
    for flag in ("local TESTER = false", "local TEST_BUILD = false", "local RESEARCH = false", "local READ_ONLY = false"):
        assert src.count(flag) == 1, 'expected exactly one "%s" in the source' % flag
    assert (PROBE_PART in parts) == ('SGD.probe_step = function' in src), 'probe part in the wrong builds'
    # (4.6.4 review) the VERSION line must match build.py's VERSION in every build, and carries the test number in
    # numbered test builds (release or not), so the log always says which build wrote it
    v = "local VERSION = '%s'" % VERSION
    assert src.count(v) == 1, 'engine_head.lua VERSION does not match build.py: ' + VERSION
    src = src.replace(v, "local VERSION = '%s%s%s'" % (VERSION, NAME_SUFFIX, ' (tester)' if tester else ''))
    if tester:
        # personal tester build: F8 markers and the extra test logging on, and marked as such in the log
        a = "local TESTER = false"
        assert src.count(a) == 1, a
        src = src.replace(a, "local TESTER = true ")
    if NAME_SUFFIX:
        # (4.6.4) numbered test builds log to Logs\test; releases (and the release's Tester) to Logs
        a = "local TEST_BUILD = false"
        assert src.count(a) == 1
        src = src.replace(a, "local TEST_BUILD = true ")
    assert src.startswith('-- HD2-Addon: ' + MODULE + '\n')
    flag = "local READ_ONLY = false"
    assert src.count(flag) == 1
    if read_only: src = src.replace(flag, "local READ_ONLY = true ")
    return src.encode('utf-8')

TITLE = 'Smarter Guard Dogs & Sentries'   # (4.0: the mod was "Smarter Guard Dogs" up to 3.0; same GUID and internal names)
FILE_BASE = 'Smarter-Guard-Dogs-and-Sentries'
DESC_COMMON = ('Smarter, safer aiming for your guard dog (Guard Dog, Rover, K-9), your sentries and the resupply pod and Supply FRV guns. '
    'They never shoot through you, your teammates or other sentries, skip the dead, cover and armor they can\'t hurt, and pick the right targets. '
    'The Tesla Tower stops zapping you. Optional targeting laser. Each part can be turned on or off in the options '
    '(also in game with Mod Options Menu). Requires Bingus Shared Loader v15 or newer.')
CORE_DIR, LASER_DIR, ARMOR_DIR, TEAM_DIR, SAFETY_DIR = 'Smarter Guard Dogs', 'Targeting Laser', 'Armor Intelligence', 'Teammate Safety', 'Safety'
DOGS_DIR, SENTRIES_DIR, TESLA_DIR, PRIORITY_DIR = 'Guard Dogs', 'Sentries', 'Tesla Tower', 'Target Prioritization'
GLOW_DIR = 'Targeting Laser Glow'
SENTRY_SAFETY_DIR = 'Sentry Safety'
SEAF_SAFETY_DIR = 'SEAF Safety'
PING_DIR = 'Ping Targeting'
MARKER_DIR = 'Targeting Marker'
CORE_OPTION = 'Smarter Guard Dogs and Sentries'   # label of the main option in the mod manager

def lua_archive_bytes(module, src):
    return archive([(resource_hash(module), struct.pack('<II', len(src), 2) + src)])

def addon_source(fn, module):
    src = open(os.path.join(HERE, fn), encoding='utf-8').read()
    assert src.startswith('-- HD2-Addon: ' + module + '\n')
    return src.encode('utf-8')

def package(read_only, out_zip, tester=False):
    src = source(read_only, tester)
    core = lua_archive_bytes(MODULE, src)
    laser = lua_archive_bytes(LASER_MODULE, addon_source('laser_addon.lua', LASER_MODULE))
    armor = lua_archive_bytes(ARMOR_MODULE, addon_source('armor_addon.lua', ARMOR_MODULE))
    team = lua_archive_bytes(TEAM_MODULE, addon_source('teammate_addon.lua', TEAM_MODULE))
    safety = lua_archive_bytes(SAFETY_MODULE, addon_source('safety_addon.lua', SAFETY_MODULE))
    dogs = lua_archive_bytes(DOGS_MODULE, addon_source('dogs_addon.lua', DOGS_MODULE))
    sentries = lua_archive_bytes(SENTRIES_MODULE, addon_source('sentries_addon.lua', SENTRIES_MODULE))
    tesla = lua_archive_bytes(TESLA_MODULE, addon_source('tesla_addon.lua', TESLA_MODULE))
    priority = lua_archive_bytes(PRIORITY_MODULE, addon_source('priority_addon.lua', PRIORITY_MODULE))
    glow = lua_archive_bytes(GLOW_MODULE, addon_source('glow_addon.lua', GLOW_MODULE))
    sentry_safety = lua_archive_bytes(SENTRY_SAFETY_MODULE, addon_source('sentry_safety_addon.lua', SENTRY_SAFETY_MODULE))
    seaf_safety = lua_archive_bytes(SEAF_SAFETY_MODULE, addon_source('seaf_safety_addon.lua', SEAF_SAFETY_MODULE))
    ping = lua_archive_bytes(PING_MODULE, addon_source('ping_addon.lua', PING_MODULE))
    marker = lua_archive_bytes(MARKER_MODULE, addon_source('marker_addon.lua', MARKER_MODULE))
    brights = [(folder, lua_archive_bytes(BRIGHT_MODULE, bright_source(v))) for _, v, folder in BRIGHTS]
    opacs = [(folder, lua_archive_bytes(OPAC_MODULE, opac_source(v))) for _, v, folder in OPACS]
    name = TITLE + (' (DIAGNOSTIC - read only)' if read_only else '')
    desc = (('TEST BUILD (disable the release while testing). ' if NAME_SUFFIX else '')
            + ('PERSONAL TESTER BUILD: the release plus F8 markers and extra test logging. Install instead of the release, not next to it. ' if tester else '')
            + ('DIAGNOSTIC BUILD for troubleshooting: reads and logs only, never changes anything in the game. ' if read_only else '')
            + DESC_COMMON)
    manifest = {
        'Version': 1, 'Guid': GUID_DIAG if read_only else (GUID_TEST if (NAME_SUFFIX or tester) else GUID_LIVE),
        'Name': name + ' ' + VERSION + NAME_SUFFIX + (' (Tester)' if tester else ''),
        'Description': desc, 'IconPath': 'thumbnail.png',
        'Options': [
            {'Name': CORE_OPTION, 'Description': 'The guard dog and sentry improvements (safety, closest threat first, '
             'no shooting the dead, no shooting into cover, Guard Dog range, Rover fire spreading; sentries that don\'t fire '
             'through you or swing their fire across you, stop firing into walls, deal with enemies at their feet first, a Laser '
             'Sentry that sets enemies alight and moves on like the Rover and cools down before it burns out, and a Tesla Tower '
             'that leaves helldivers and enemies next to them alone). Keep this on.',
             'Image': 'options/option_core.png', 'Include': [CORE_DIR]},
            # (the two safety parts as one item: a pick-one list of who they protect; the first entry is the default)
            {'Name': 'Safety', 'Description': 'Who your dog and your sentries never fire through: they hold fire while that '
             'helldiver is in their line of fire, don\'t swing their fire across them, mortars and the rocket sentry leave enemies '
             'next to them alone, and the Tesla Tower doesn\'t zap them or arc into them. Turn off at your own risk: they will '
             'fire through anyone. Everything else keeps working.',
             'Image': 'options/option_safety.png',
             'SubOptions': [
                 {'Name': 'You and your teammates', 'Description': 'Protects you and the other players.',
                  'Image': 'options/option_teammates.png', 'Include': [SAFETY_DIR, TEAM_DIR]},
                 {'Name': 'Only you', 'Description': 'Protects you; they may fire through other players.',
                  'Image': 'options/option_safety.png', 'Include': [SAFETY_DIR]},
                 {'Name': 'Only your teammates', 'Description': 'Protects the other players; they may fire through you.',
                  'Image': 'options/option_teammates.png', 'Include': [TEAM_DIR]},
             ]},
            # (4.6.5) its own on/off item, after Safety (on by default, like the other on/off items)
            {'Name': 'Sentry Safety', 'Description': 'Your sentries don\'t shoot through other sentries, yours or other players\': '
             'they hold fire while one is in their line of fire, don\'t swing their fire across one, and the mortars and the rocket, '
             'autocannon and flame sentries leave alone enemies right next to one. Turn off to let them fire through sentries. Everything '
             'else keeps working.',
             'Image': 'options/option_sentry_safety.png', 'Include': [SENTRY_SAFETY_DIR]},
            # (4.7.0) its own on/off item, after Sentry Safety (on by default)
            {'Name': 'SEAF Safety', 'Description': 'Your guard dog and your sentries don\'t shoot through SEAF soldiers or civilians: they hold fire while one '
             'is in their line of fire, don\'t swing their fire across one, and the mortars, the Tesla Tower and the rocket, autocannon and flame '
             'sentries leave alone enemies right next to one. Turn off to let them fire through SEAF soldiers and civilians. Everything else keeps working.',
             'Image': 'options/option_seaf_safety.png', 'Include': [SEAF_SAFETY_DIR]},
            # (5.0.0) its own on/off item, after Intelligence (on by default)
            {'Name': 'Ping Targeting', 'Description': 'Your sentries go for an enemy you or a teammate ping: each sentry that can hurt it '
             'and has it in reach and in view turns to it first, for up to 20 seconds after the ping (the mortars fire on it wherever it is in '
             'their range). The safety rules still come first, and a ping waits while an enemy is at the sentry\'s feet or right next to a helldiver. Turn off to let them pick their own targets. Everything else keeps working.',
             'Image': 'options/option_ping.png', 'Include': [PING_DIR]},
            {'Name': 'Targeting Laser', 'Description': 'Laser out of the barrel of your guard dog and your sentries (not the mortars) toward their targets, shown '
             'only on your screen: a red beam along the barrel while they fire, flashing green when a friendly is in the way and the '
             'safety holds the shot, off while the dog reloads. The Tesla Tower shows its reach as a red ring, and a red ring flashes around the rocket sentry while an enemy is too '
             'close for it to fire. Turn off to hide it.',
             'Image': 'options/option_laser.png',
             # (4.5: line or glow, a pick-one list; the first entry is the default. (5.0 Test 14, the author: "make glow laser the
             # first choice, it looks better and the markers already draw into the map, the laser would help you know what
             # angle somethings coming in at") the glow first)
             'SubOptions': [
                 {'Name': 'Glow', 'Description': 'A soft glowing beam with a bright spot on the target. It shows through walls and '
                  'objects like the markers do, so you can see where your guns are firing from and at.',
                  'Image': 'options/option_laser.png', 'Include': [LASER_DIR, GLOW_DIR]},
                 {'Name': 'Line', 'Description': 'A thin, plain line with a small cross where it hits. Walls and objects hide it.',
                  'Image': 'options/option_laser.png', 'Include': [LASER_DIR]},
             ]},
            # (5.0.0 Test 13, the author: "Targeting Marker should be an option that can be toggled") its own on/off item
            {'Name': 'Targeting Marker', 'Description': 'The gun\'s stratagem icon over the enemy your guard dog or sentry is on, '
             'shown only on your screen, like a ping: yellow while it is on that enemy, gray when the enemy goes out of sight (cover or '
             'smoke). Only on enemies it can hurt and has in reach. Works with or without the Targeting Laser. Turn off to hide the '
             'markers. Everything else keeps working.',
             'Image': 'options/option_marker.png', 'Include': [MARKER_DIR]},
            # (armor skipping and target priority as one item: a pick-one list; the first entry is the default)
            {'Name': 'Intelligence', 'Description': 'How your dogs and sentries choose what to shoot. Armor Intelligence: they '
             'leave alone armor they can\'t get through (Tanks and similar; on Hulks and Chargers, judged by the part they aim at: a Hulk\'s '
             'heatsink and a Charger\'s rear and underside are fair game; the Rover also Scout Striders; the Laser '
             'Sentry only what is above Heavy), fire only short bursts at Heavy Devastators, and no sentry wastes ammo on dropships '
             '(only the Rocket and Autocannon sentries shoot enemies still aboard one). Target Prioritization: your dog goes for the '
             'closest threat to you first; your sentries deal with enemies at their feet first, go for Gunships and Stingrays first '
             'then the armor that suits the gun (Heavy for the Rocket and Autocannon, '
             'lighter for the Machine Gun, Gatling and Laser; the closest first for the Flame Sentry). Turn off to leave both to the game. Everything else keeps working.',
             'Image': 'options/option_armour.png',
             'SubOptions': [
                 {'Name': 'Armor Intelligence and Target Prioritization', 'Description': 'Both.',
                  'Image': 'options/option_armour.png', 'Include': [ARMOR_DIR, PRIORITY_DIR]},
                 {'Name': 'Only Armor Intelligence', 'Description': 'Skip armor they can\'t hurt and dropships; the game decides the order.',
                  'Image': 'options/option_armour.png', 'Include': [ARMOR_DIR]},
                 {'Name': 'Only Target Prioritization', 'Description': 'The right target first; they may shoot armor they can\'t hurt.',
                  'Image': 'options/option_priority.png', 'Include': [PRIORITY_DIR]},
             ]},
            {'Name': 'Laser Brightness', 'Description': 'How bright the targeting laser is: its beams and rings, line or glow.',
             'Image': 'options/option_laser.png',
             'SubOptions': [{'Name': name, 'Description': 'The laser at %d%% of its normal brightness.' % round(v * 100) if v != 1 else 'The laser as it has always been.',
                             'Image': 'options/option_laser.png', 'Include': [folder]} for name, v, folder in BRIGHTS]},
            # (5.0.0 Test 15, the author: "add targeting marker opacity as well, in case people want to tune how it appears")
            {'Name': 'Marker Opacity', 'Description': 'How solid the targeting markers are drawn. Full is how they are designed; '
             'lower lets more of the game show through them.',
             'Image': 'options/option_marker.png',
             'SubOptions': [{'Name': name, 'Description': 'The markers at %d%% opacity.' % round(v * 100) if v != 1 else 'The markers as designed.',
                             'Image': 'options/option_marker.png', 'Include': [folder]} for name, v, folder in OPACS]},
            {'Name': 'Guard Dogs', 'Description': 'The mod handles your guard dog (Guard Dog, Rover, K-9). Turn off to leave '
             'your dog to the game; your sentries and the rest of the mod keep working.',
             'Image': 'options/option_dogs.png', 'Include': [DOGS_DIR]},
            {'Name': 'Sentries', 'Description': 'The mod handles your sentries (Machine Gun, Gatling, Autocannon, Rocket, Laser, '
             'Flame, Mortar, EMS Mortar and the Tesla Tower), plus the guns on armed resupply pods and the Supply FRV. Turn off to leave your sentries to the game; your guard dog and the '
             'rest of the mod keep working.',
             'Image': 'options/option_sentries.png',
             'SubOptions': [
                 {'Name': 'All sentries', 'Description': 'Every sentry, the Tesla Tower included.',
                  'Image': 'options/option_sentries.png', 'Include': [SENTRIES_DIR, TESLA_DIR]},
                 {'Name': 'All but the Tesla Tower', 'Description': 'Every sentry except the Tesla Tower, which is left to the game.',
                  'Image': 'options/option_tesla.png', 'Include': [SENTRIES_DIR]},
             ]},
        ],
    }
    # (the order shown in the mod manager: the mod, what it handles, intelligence, safety, the laser)
    order = [CORE_OPTION, 'Guard Dogs', 'Sentries', 'Intelligence', 'Ping Targeting', 'Safety', 'Sentry Safety', 'SEAF Safety', 'Targeting Laser', 'Laser Brightness', 'Targeting Marker', 'Marker Opacity']
    manifest['Options'].sort(key=lambda o: order.index(o['Name']))
    with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('manifest.json', json.dumps(manifest, indent=2))
        z.write(os.path.join(HERE, 'build', 'thumbnail.png'), 'thumbnail.png')
        images = {opt['Image'] for opt in manifest['Options']} | {sub['Image'] for opt in manifest['Options'] for sub in opt.get('SubOptions', [])}
        for img in sorted(images):   # option icons (options_icons.py, options_icons2.py)
            z.write(os.path.join(HERE, 'build', img.replace('/', os.sep)), img)
        for folder, pak in [(CORE_DIR, core), (SAFETY_DIR, safety), (TEAM_DIR, team), (SENTRY_SAFETY_DIR, sentry_safety), (SEAF_SAFETY_DIR, seaf_safety), (PING_DIR, ping), (MARKER_DIR, marker), (DOGS_DIR, dogs), (SENTRIES_DIR, sentries), (TESLA_DIR, tesla), (PRIORITY_DIR, priority), (LASER_DIR, laser), (GLOW_DIR, glow), (ARMOR_DIR, armor)] + brights + opacs:
            z.writestr(folder + '/' + ARCHIVE, pak)
            z.writestr(folder + '/' + ARCHIVE + '.gpu_resources', b'')
            z.writestr(folder + '/' + ARCHIVE + '.stream', b'')
    return core, src

if __name__ == '__main__':
    out = os.path.join(HERE, 'build')
    tag = NAME_SUFFIX.replace(' (release candidate)', '-RC').replace(' ', '-')
    builds = [(False, False, '%s-%s%s.zip' % (FILE_BASE, VERSION, tag)), (True, False, '%s-%s%s-DIAGNOSTIC.zip' % (FILE_BASE, VERSION, tag))]
    if 'tester' in sys.argv[1:]: builds.append((False, True, '%s-%s%s-Tester.zip' % (FILE_BASE, VERSION, tag)))
    for ro, tester, fn in builds:
        pak, src = package(ro, os.path.join(out, fn), tester)
        lua_path = os.path.join(out, ('diag_' if ro else ('tester_' if tester else 'live_')) + 'smarter_guard_dogs.lua')
        open(lua_path, 'wb').write(src)
        # ((4.6.7 review) every built chunk must load - LuaJIT's 200-locals / 60-upvalues limits only show when it is
        # compiled, and the Tester can carry code the release doesn't): checked with the dev LuaJIT when it is there
        lj = os.path.join(HERE, '..', 'luajit', 'src', 'luajit')
        if os.path.exists(lj):
            import subprocess
            r = subprocess.run([lj, '-e', 'assert(loadfile(%r))' % lua_path.replace('\\', '/')], capture_output=True, text=True, timeout=60)
            assert r.returncode == 0, '%s does not load: %s' % (os.path.basename(lua_path), r.stderr.strip())
        else:
            print('(LuaJIT not found next to the kit: the built chunks were not test-loaded)')
        print(fn, len(pak), 'bytes archive, resource', hex(resource_hash(MODULE)))
