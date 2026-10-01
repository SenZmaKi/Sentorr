import ctypes as c
import json
import sys
from pathlib import Path

# Read the actual compiled-in decoder list; no playback or system configuration.
lib = c.CDLL(str(Path(sys.argv[1]).resolve()))
lib.mpv_create.restype = c.c_void_p
lib.mpv_initialize.argtypes = [c.c_void_p]
lib.mpv_set_option_string.argtypes = [c.c_void_p, c.c_char_p, c.c_char_p]
lib.mpv_get_property_string.argtypes = [c.c_void_p, c.c_char_p]
lib.mpv_get_property_string.restype = c.c_void_p
lib.mpv_free.argtypes = [c.c_void_p]
lib.mpv_terminate_destroy.argtypes = [c.c_void_p]
handle = lib.mpv_create()
for key, value in [('vo', 'null'), ('ao', 'null'), ('config', 'no')]:
    lib.mpv_set_option_string(handle, key.encode(), value.encode())
assert lib.mpv_initialize(handle) >= 0

def property_string(key):
    pointer = lib.mpv_get_property_string(handle, key.encode())
    if not pointer:
        return None
    value = c.string_at(pointer).decode()
    lib.mpv_free(pointer)
    return value

try:
    count = int(property_string('decoder-list/count'))
    decoders = []
    for i in range(count):
        if property_string(f'decoder-list/{i}/codec') in ('truehd', 'mlp', 'ac3', 'eac3', 'dts'):
            decoders.append({key: property_string(f'decoder-list/{i}/{key}')
                             for key in ('codec', 'driver', 'description')})
    print(json.dumps({'mpv': property_string('mpv-version'),
                      'ffmpeg': property_string('ffmpeg-version'),
                      'decoderCount': count, 'relevantDecoders': decoders}, indent=2))
finally:
    lib.mpv_terminate_destroy(handle)
