local ffi = require "ffi"
local Function = require "luasynth.function"
local vs = require "luasynth.vsapi"

local VSPlugin = {}

function VSPlugin:__index(fn_name)
  local functions = vs.getFunctions(self)
  for i = 1, #functions do
    local fn = functions[i]
    if fn_name == ffi.string(fn) then
      local signature = functions:string(fn)
      return Function(signature, self)
    end
  end

  error('There is no function named ' .. fn_name)
end

function VSPlugin:__tostring()
  local functions = vs.getFunctions(self)
  local ret = ""
  for i = 1, #functions do
    ret = ret .. tostring(Function(functions:string(functions[i]), self))
  end
  return ret
end

ffi.metatype("VSPlugin", VSPlugin)
