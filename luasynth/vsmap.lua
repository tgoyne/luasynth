local ffi = require "ffi"
local vs = require "luasynth.vsapi"

local function map_getter(fn)
  local err = ffi.new("int[1]")
  return function(self, key, index)
    local ret = fn(self, key, (index or 1) - 1, err)
    if err[0] ~= 0 then return end
    return ret
  end
end

local function map_setter(fn)
  return function(self, key, value, append)
    local err = fn(self, key, value, append)
    if err ~= 0 then
      error('TODO: prop set err message')
    end
  end
end

local function get_int(fn)
  local getter = map_getter(fn)
  return function(self, key, index)
    return tonumber(getter(self, key, index))
  end
end

local VSMap = {
  int      = get_int(vs.propGetInt),
  float    = map_getter(vs.propGetFloat),
  data     = map_getter(vs.propGetData),
  dataSize = map_getter(vs.propGetDataSize),
  node     = map_getter(vs.propGetNode),
  frame    = map_getter(vs.propGetFrame),
  func     = map_getter(vs.propGetFunc),

  setInt   = map_setter(vs.propSetInt),
  setFloat = map_setter(vs.propSetFloat),
  setNode  = map_setter(vs.propSetNode),
  setFrame = map_setter(vs.propSetFrame),
  setFunc  = map_setter(vs.propSetFunc)
}

function VSMap:__gc() vs.freeMap(self) end
function VSMap:__len() return vs.propNumKeys(self) end

function VSMap:numKeys()        return vs.propNumKeys(self) end
function VSMap:key(index)       return vs.propGetKey(self, index - 1) end
function VSMap:numElements(key) return vs.propNumElements(self, key) end
function VSMap:deleteKey(key)   return vs.propDeleteKey(self, key) end
function VSMap:setError(msg)    return vs.setError(self, msg) end

function VSMap:setData(key, value, append)
    local err = vs.propSetData(self, key, value, value:len(), append)
    if err ~= 0 then
      error('TODO: prop set err message')
    end
end

function VSMap:string(key, index)
  return ffi.string(self:data(key, index), self:dataSize(key, index))
end

function VSMap:type(key)
  return string.char(vs.propGetType(self, key))
end

local VSMapGet = {
  i = VSMap.int,
  f = VSMap.float,
  s = VSMap.string,
  c = VSMap.node,
  v = VSMap.frame,
  m = VSMap.func
}

function VSMap:value(key)
  return VSMapGet[self:type(key)](self, key)
end

function VSMap:array(key)
  local getter = VSMapGet[self:type(key)]
  local ret = {}
  for i = 1, self:numElements(key) do
    ret[i] = getter(self, key, i)
  end
  return ret
end

local VSMapSet = {
  int   = VSMap.setInt,
  float = VSMap.setFloat,
  data  = VSMap.setData,
  clip  = VSMap.setNode,
  frame = VSMap.setFrame,
  func  = VSMap.setFunc
}

local VSMapCdataType = {
  [ffi.typeof("VSNodeRef")] = "node",
  [ffi.typeof("VSFrameRef")] = "frame",
  [ffi.typeof("VSFuncRef")] = "func"
}

local PROP_APPEND = vs:readEnum("pa").Append

local function getVSType(value)
  local ty = type(value)
  if ty == "number" then
    return "double"
  elseif ty == "string" then
    return "data"
  elseif ty == "table" then
    return getVSType(value[1]), true
  elseif ty == "cdata" then
    ty = ffi.typeof(value)
    -- This looks dumb, but ctypes don't actually work as table keys due to not
    -- being interned
    for k, v in pairs(VSMapCdataType) do
      if k == ty then
        return v
      end
    end
  end
  error("Type not convertable to VS type: " .. ty)
end

function VSMap:set(key, ty, value)
  local arr
  if not ty then
    value = key
    ty, arr = getVSType(value)
    key = ty
  end

  if ty:sub(-2) == "[]" then
    arr = true
    ty = ty:sub(1, -3)
  end

  local setter = VSMapSet[ty]
  if not setter then error('Invalid data ty: ' .. type, 2) end

  if arr then
    for _, v in ipairs(value) do
      setter(self, key, v, PROP_APPEND)
    end
  else
    setter(self, key, value, PROP_APPEND)
  end
end

function VSMap:__index(key)
  if type(key) == "number" then
    return vs.propGetKey(self, key - 1)
  end
  return VSMap[key]
end

function VSMap:__tostring()
  local ret = string.format("VSMap: %d\n", #self)
  for i = 1, #self do
    ret = string.format("%s\t%s (%s): %s\n", ret, ffi.string(self[i]), self:type(self[i]), self:value(self[i]))
  end
  return ret
end

function VSMap:iter()
  local i = 0
  local len = #self
  return function()
    i = i + 1
    if i > len then return end
    local key = self:key(i)
    return key, self:value(key)
  end
end

ffi.metatype("VSMap", VSMap)
