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
  return VSPlugin[fn_name]
end

function VSPlugin:__tostring()
  local ret = ""
  for _, fn in vs.getFunctions(self):iter() do
    ret = ret .. tostring(Function(fn, self))
  end
  return ret
end

function VSPlugin:registerFunction(name, arguments, fn)
  local func = Function(name .. ";" .. arguments)
  local function wrapper(argsIn, argsOut)
    local succeeded, res = pcall(fn, func:unpack(argsIn))
    if succeeded then
      argsOut:set(res)
    else
      argsOut:setError(res)
    end
  end

  vs.registerFunction(name, arguments, wrapper, nil, self)
end

ffi.metatype("VSPlugin", VSPlugin)
