#!/usr/bin/env python3
"""Run a Lua test file with system liblua (no dependencies downloaded)."""
import ctypes
import ctypes.util
import sys
library = ctypes.util.find_library('lua5.4') or ctypes.util.find_library('lua5.3')
if not library:
    raise SystemExit('Install Lua 5.1+ and run lua tests/test.lua, or install liblua5.4.')
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
error = lua.luaL_loadfilex(state, (sys.argv[1] if len(sys.argv) > 1 else 'tests/test.lua').encode(), None)
if not error:
    error = lua.lua_pcallk(state, 0, -1, 0, 0, None)
if error:
    print(lua.lua_tolstring(state, -1, None).decode(), file=sys.stderr)
lua.lua_close(state)
raise SystemExit(bool(error))
