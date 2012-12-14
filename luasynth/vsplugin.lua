local ffi = require "ffi"
local Function = require "luasynth.function"
local vs = require "luasynth.vsapi"

local VSPlugin = {}

function VSPlugin:__index(fn_name)
  for fn, sig in vs.getFunctions(self):iter() do
    if fn_name == ffi.string(fn) then
      return Function(sig, self)
    end
  end

  error('There is no function named ' .. fn_name)
end

function VSPlugin:__tostring()
  local ret = ""
  for _, fn in vs.getFunctions(self):iter() do
    ret = ret .. tostring(Function(fn, self))
  end
  return ret
end

ffi.metatype("VSPlugin", VSPlugin)
