local ffi = require "ffi"
local vs = require "luasynth.vsapi"

local function map_getter(fn)
  local err = ffi.new("int[1]")
  return function(self, key, index)
    local ret = fn(self, key, (index or 1) - 1, err)
    if err[0] ~= 0 then
      error('TODO: prop read err message')
    end
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

local VSMap = {
  int      = map_getter(vs.propGetInt),
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
function VSMap:key(index)       return vs.propGetKey(self, index) end
function VSMap:numElements(key) return vs.propNumElements(self, key) end
function VSMap:deleteKey(key)   return vs.propDeleteKey(self, key) end

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

local PROP_APPEND = vs:readEnum("pa").Append

function VSMap:set(key, type, value)
  local arr
  if type:sub(-2) == "[]" then
    arr = true
    type = type:sub(1, -3)
  end

  local setter = VSMapSet[type]
  if not setter then error('Invalid data type: ' .. type, 2) end

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

ffi.metatype("VSMap", VSMap)
