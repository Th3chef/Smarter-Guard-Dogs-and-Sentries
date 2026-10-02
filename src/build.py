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
GLOW_MODULE = 'mods/chef/smarter_guard_dogs_glow'
# (4.5.3) Laser Brightness: one tiny addon per sub-option, all under the same name (only one is installed at a time)
BRIGHT_MODULE = 'mods/chef/smarter_guard_dogs_brightness'
BRIGHTS = [('Normal (100%)', 1.0, 'Laser Brightness 100'), ('Dim (50%)', 0.5, 'Laser Brightness 50'), ('Softer (75%)', 0.75, 'Laser Brightness 75'),
           ('Bright (150%)', 1.5, 'Laser Brightness 150'), ('Brightest (200%)', 2.0, 'Laser Brightness 200')]
def bright_source(v):
    return ('-- HD2-Addon: %s\n'
            '-- Smarter Guard Dogs & Sentries - Laser Brightness (optional part): the targeting laser at %d%%.\n'
            "rawset(_G, 'SmarterGuardDogsLaserBrightness', %s)\n" % (BRIGHT_MODULE, round(v * 100), repr(v))).encode('utf-8')
VERSION = '4.6.1'
NAME_SUFFIX = ''   # '' for releases, e.g. ' Test 3' for test builds
ARCHIVE = '9ba626afa44a3aa3.patch_0'        # the game archive the shared loader reads addons from
LUA_TYPE, MAGIC = 0xa14e8dfa2cd117e2, 0xF0000011
PARTS = ['engine_head', 'engine_body', 'layout_data', 'engine_layout', 'engine_state', 'engine_laser', 'engine_research', 'engine_armor', 'engine_logic', 'engine_sentry', 'engine_main']
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

def source(read_only, tester=False):
    src = ''.join(open(os.path.join(HERE, p + '.lua'), encoding='utf-8').read() for p in PARTS)
    if tester:
        # personal tester build: F8 markers and the extra test logging on, and marked as such in the log (with the
        # test number, so the log shows which build wrote it)
        for a, b in (("local TESTER = false", "local TESTER = true "), ("local VERSION = '%s'" % VERSION, "local VERSION = '%s%s (tester)'" % (VERSION, NAME_SUFFIX))):
            assert src.count(a) == 1, a
            src = src.replace(a, b)
    assert src.startswith('-- HD2-Addon: ' + MODULE + '\n')
    flag = "local READ_ONLY = false"
    assert src.count(flag) == 1
    if read_only: src = src.replace(flag, "local READ_ONLY = true ")
    return src.encode('utf-8')

TITLE = 'Smarter Guard Dogs & Sentries'   # (4.0: the mod was "Smarter Guard Dogs" up to 3.0; same GUID and internal names)
FILE_BASE = 'Smarter-Guard-Dogs-and-Sentries'
DESC_COMMON = ('Smarter, safer aiming for your guard dog (Guard Dog, Rover, K-9), your sentries and the resupply pod and Supply FRV guns. '
    'They never shoot through you or your teammates, skip the dead, cover and armor they can\'t hurt, and pick the right targets. '
    'The Tesla Tower stops zapping you. Optional targeting laser. Each part can be turned on or off in the options '
    '(also in game with Mod Options Menu). Requires Bingus Shared Loader v15 or newer.')
CORE_DIR, LASER_DIR, ARMOR_DIR, TEAM_DIR, SAFETY_DIR = 'Smarter Guard Dogs', 'Targeting Laser', 'Armor Intelligence', 'Teammate Safety', 'Safety'
DOGS_DIR, SENTRIES_DIR, TESLA_DIR, PRIORITY_DIR = 'Guard Dogs', 'Sentries', 'Tesla Tower', 'Target Prioritization'
GLOW_DIR = 'Targeting Laser Glow'
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
    brights = [(folder, lua_archive_bytes(BRIGHT_MODULE, bright_source(v))) for _, v, folder in BRIGHTS]
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
            {'Name': 'Targeting Laser', 'Description': 'Laser out of the barrel of your guard dog and your sentries (not the mortars) toward their targets, shown '
             'only on your screen: green while they fire, flashing red when the safety stops a shot (and a red ring around the rocket '
             'sentry while an enemy is too close for it to fire), flashing yellow when the dog\'s target goes out of sight (cover or smoke), off '
             'while the dog reloads. The Tesla Tower shows its reach as a yellow ring instead. Turn off to hide it.',
             'Image': 'options/option_laser.png',
             # (4.5: line or glow, a pick-one list; the first entry, the line, is the default)
             'SubOptions': [
                 {'Name': 'Line', 'Description': 'A thin, plain line with a small cross where it hits. Simple to look at, but walls and '
                  'objects hide it.',
                  'Image': 'options/option_laser.png', 'Include': [LASER_DIR]},
                 {'Name': 'Glow', 'Description': 'A soft glowing beam with a bright spot on the target. It looks much better than '
                  'the line, but it shows through walls and objects (the game draws it on top of the world).',
                  'Image': 'options/option_laser.png', 'Include': [LASER_DIR, GLOW_DIR]},
             ]},
            # (armor skipping and target priority as one item: a pick-one list; the first entry is the default)
            {'Name': 'Intelligence', 'Description': 'How your dogs and sentries choose what to shoot. Armor Intelligence: they '
             'leave alone armor they can\'t get through (Hulks, Chargers, Tanks and similar; the Rover also Scout Striders; the Laser '
             'Sentry only what is above Heavy), fire only short bursts at Heavy Devastators, and no sentry wastes ammo on dropships '
             '(only the Rocket and Autocannon sentries shoot enemies still aboard one). Target Prioritization: your dog goes for the '
             'closest threat to you first; your sentries deal with enemies at their feet first, go for Gunships and Stingrays first '
             '(the Rocket Sentry only while one hovers), then the armor that suits the gun (Heavy for the Rocket and Autocannon, '
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
    order = [CORE_OPTION, 'Guard Dogs', 'Sentries', 'Intelligence', 'Safety', 'Targeting Laser', 'Laser Brightness']
    manifest['Options'].sort(key=lambda o: order.index(o['Name']))
    with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('manifest.json', json.dumps(manifest, indent=2))
        z.write(os.path.join(HERE, 'build', 'thumbnail.png'), 'thumbnail.png')
        images = {opt['Image'] for opt in manifest['Options']} | {sub['Image'] for opt in manifest['Options'] for sub in opt.get('SubOptions', [])}
        for img in sorted(images):   # option icons (options_icons.py, options_icons2.py)
            z.write(os.path.join(HERE, 'build', img.replace('/', os.sep)), img)
        for folder, pak in [(CORE_DIR, core), (SAFETY_DIR, safety), (TEAM_DIR, team), (DOGS_DIR, dogs), (SENTRIES_DIR, sentries), (TESLA_DIR, tesla), (PRIORITY_DIR, priority), (LASER_DIR, laser), (GLOW_DIR, glow), (ARMOR_DIR, armor)] + brights:
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
        open(os.path.join(out, ('diag_' if ro else ('tester_' if tester else 'live_')) + 'smarter_guard_dogs.lua'), 'wb').write(src)
        print(fn, len(pak), 'bytes archive, resource', hex(resource_hash(MODULE)))
