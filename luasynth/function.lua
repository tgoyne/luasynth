local ffi = require "ffi"
local vs = require "luasynth.vsapi"

local function class(constructor)
  local klass = {}
  klass.__index = function(self, idx)
    return klass[idx] or self:__index(idx)
  end
  setmetatable(klass, {
    __call = function(class_tbl, ...)
      local obj = {}
      constructor(obj, ...)
      setmetatable(obj, klass)
      return obj
    end
  })
  return klass
end

local Function = class(function(self, sig, plugin)
  self.name, self.args = sig:match("(.-);(.*)")
  self.plugin = plugin
end)

function Function:__tostring()
  return string.format("\t\t%s(%s)\n", self.name, self.args:gsub(";", "; "):gsub(":", " "):gsub("; $", ""))
end

local function positionalPicker(...)
  local argn = 0
  local args = { ... }
  return function(name)
    if not name then
      return argn < #args
    end

    argn = argn + 1
    return args[argn]
  end
end

local function namedPicker(args)
  return function(name)
    if not name then
      return #args ~= 0
    end

    local value = args[name]
    args[name] = nil
    return value
  end
end

function Function:__call(...)
  local argMap = vs.newMap()
  local picker
  if select('#', ...) == 1 and type(...) == "table" then
    picker = namedPicker(...)
  else
    picker = positionalPicker(...)
  end

  for arg in self.args:gmatch("[^;]+") do
    local name, ty, opt = arg:match("([^:]+):([^:]+):?(.*)")
    local value = picker(name)
    if not value and opt ~= "opt" then
      error('Not enough arguments')
    elseif value then
      argMap:set(name, ty, value)
    end
  end

  if picker(nil) then
    error('Too many arguments')
  end

  local ret = vs.invoke(self.plugin, self.name, argMap)

  local err = vs.getError(ret)
  if err ~= nil then -- NULL does not decay to false
    error(ffi.string(err), 2)
  end

  return #ret > 0 and ret:value(ret[1])
end

function Function:unpack(map)
  local ret = {}
  for arg in self.args:gmatch("[^;]+") do
    local name, ty = arg:match("([^:]+):([^:]+):?.*")
    ret[#ret + 1] = ty:sub(-2) == "[]" and map:array(name) or map:value(name)
  end
  return unpack(ret)
end

return Function
