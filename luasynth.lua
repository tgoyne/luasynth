local ffi = require "ffi"
local bit = require "bit"

local vapoursynth_h = ""
for line in io.lines("VapourSynth.h") do
  -- ffi doesn't support the C preprocessor yet, so preprocess it manually
  if not line:match("^%s*#") then
    vapoursynth_h = vapoursynth_h .. line:gsub("VS_CC ", ""):gsub("VS_API%(([^)]+)%)", "%1") .. "\n"
  end
end

ffi.cdef(vapoursynth_h)
local vs = ffi.load "vapoursynth"

local vsapi = vs.getVapourSynthAPI(3)
if vsapi == nil then error("Failed to initialize VapourSynth") end

local vscore = vsapi.createCore(vapourSynthThreadCount or 0)

-------------------------------------------------------------------------------
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
  int      = map_getter(vsapi.propGetInt),
  float    = map_getter(vsapi.propGetFloat),
  data     = map_getter(vsapi.propGetData),
  dataSize = map_getter(vsapi.propGetDataSize),
  node     = map_getter(vsapi.propGetNode),
  frame    = map_getter(vsapi.propGetFrame),
  func     = map_getter(vsapi.propGetFunc),

  setInt   = map_setter(vsapi.propSetInt),
  setFloat = map_setter(vsapi.propSetFloat),
  setNode  = map_setter(vsapi.propSetNode),
  setFrame = map_setter(vsapi.propSetFrame),
  setFunc  = map_setter(vsapi.propSetFunc)
}
ffi.metatype("VSMap", VSMap)

function VSMap:__gc() vsapi.freeMap(self) end
function VSMap:__len() return vsapi.propNumKeys(self) end

function VSMap:numKeys()        return vsapi.propNumKeys(self) end
function VSMap:key(index)       return vsapi.propGetKey(self, index) end
function VSMap:numElements(key) return vsapi.propNumElements(self, key) end
function VSMap:deleteKey(key)   return vsapi.propDeleteKey(self, key) end

function VSMap:setData(key, value, append)
    local err = vsapi.propSetData(self, key, value, value:len(), append)
    if err ~= 0 then
      error('TODO: prop set err message')
    end
end

function VSMap:string(key, index)
  return ffi.string(self:data(key, index), self:dataSize(key, index))
end

function VSMap:type(key)
  return string.char(vsapi.propGetType(self, key))
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
      setter(self, key, v, vscore.propAppendMode.Append)
    end
  else
    setter(self, key, value, vscore.propAppendMode.Append)
  end
end

function VSMap:__index(key)
  if type(key) == "number" then
    return vsapi.propGetKey(self, key - 1)
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

-------------------------------------------------------------------------------
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
  local argMap = vsapi.newMap()
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

  local ret = vsapi.invoke(self.plugin, self.name, argMap)

  local err = vsapi.getError(ret)
  if err ~= nil then -- NULL does not decay to false
    error(ffi.string(err))
  end

  return #ret > 0 and ret:value(ret[1])
end

-------------------------------------------------------------------------------
local function readEnum(prefix)
  local ret = {}
  for tok in vapoursynth_h:gmatch(" " .. prefix .. "([A-Z][A-z0-9]*)") do
    ret[tok] = ffi.C[prefix .. tok]
  end
  return ret
end

local VSCore = {
  colorFamily    = readEnum("cm"),
  sampleType     = readEnum("st"),
  presetFormat   = readEnum("pf"),
  nodeFlags      = readEnum("nf"),
  getPropErrors  = readEnum("pe"),
  propAppendMode = readEnum("pa")
}

ffi.metatype("VSCore", VSCore)

function VSCore:__gc() vsapi.freeCore(self) end
function VSCore:info() return vsapi.getCoreInfo(self) end 

function VSCore:newVideoFrame(format, width, height, propSrc)
  return vsapi.newVideoFrame(format, width, height, propSrc, self)
end

function VSCore:__index(plugin_name)
  if VSCore[plugin_name] then return VSCore[plugin_name] end
  local plugin = vsapi.getPluginNs(plugin_name, self)
  if plugin == nil then
    error('Plugin with namespace "' .. plugin_name .. '" not found', 2)
  end
  return plugin
end

function VSCore:__tostring()
  local ret = ""
  local plugins = vsapi.getPlugins(self)
  for i = 1, #plugins do
    local plugin = plugins:string(plugins[i])
    namespace, identifier, description = plugin:match("(.*);(.*);(.*)")
    ret = string.format("%s%s\n\tnamespace:  %s\n\tidentifier: %s\n", ret, description, namespace, identifier)
    ret = ret .. tostring(vsapi.getPluginId(identifier, self))
  end
  return ret
end

function VSCore:findFunction(fn_name)
  local plugins = vsapi.getPlugins(self)
  for i = 1, #plugins do
    local plugin_str = plugins:string(plugins[i])
    identifier = plugin_str:match(".*;(.*);.*")
    local plugin = vsapi.getPluginId(identifier, self)
    local functions = vsapi.getFunctions(plugin)
    for i = 1, #functions do
      local fn = functions[i]
      if fn_name == ffi.string(fn) then
        return Function(functions:string(fn), plugin)
      end
    end
  end
end

-------------------------------------------------------------------------------
local VSPlugin = {}
ffi.metatype("VSPlugin", VSPlugin)

function VSPlugin:__index(fn_name)
  local functions = vsapi.getFunctions(self)
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
  local functions = vsapi.getFunctions(self)
  local ret = ""
  for i = 1, #functions do
    local fn = Function(functions:string(functions[i]), self)
    ret = ret .. tostring(fn)
  end
  return ret
end

-------------------------------------------------------------------------------
local VSNodeRef = {}
ffi.metatype("VSNodeRef", VSNodeRef)

function VSNodeRef:__gc() vsapi.freeNode(self) end
function VSNodeRef:clone() return vsapi.cloneNodeRef(self) end
function VSNodeRef:videoInfo() return vsapi.getVideoInfo(self) end

-- Make a ffi callback that frees itself after it's called
local function singleShotCallback(type, callback)
  local cb = ffi.cast(type, function(...)
    local ret = callback(...)
    cb:free()
    return ret
  end)
end

function VSNodeRef:frameAsync(frameNum, callback)
  vsapi.getFrameAsync(frameNum - 1, self, singleShotCallback(callback), nil)
end

function VSNodeRef:frame(frameNum)
  local errbuf = ffi.new("char[512]")
  local frame = vsapi.getFrame(frameNum - 1, self, errbuf, 512)
  if frame == nil then
    if errbuf[0] ~= 0 then
      error(ffi.string(errbuf))
    else
      error(string.format("Failed to fetch frame %d: No error message given", frameNum))
    end
  end
  return frame
end

function VSNodeRef:frameFilter(frameNum, context)
end

-- query completed frame?
--
function VSNodeRef:writeY4MHeader(file)
  local info = self:videoInfo()
  local format = info.format
  if not format or (format.colorFamily ~= vscore.colorFamily.YUV and format.colorFamily ~= vscore.colorFamily.GRAY) then
    error('y4m only supports YUV and Gray formats')
  end

  local y4mformat
  if format.colorFamily == GRAY then
      y4mformat = "mono"
      if format.bitsPerSample > 8 then
        y4mformat = y4mformat .. format.bitsPerSample
      end
  else
    local w = tostring(bit.rshift(4, format.subSamplingW))
    y4mformat = "4" .. w .. (format.subSamplingH == 0 and w or "0")
    if format.bitsPerSample > 8 then
        y4mformat = y4mformat .. "p" .. format.bitsPerSample
    end
  end

  file:write(string.format("YUV4MPEG2 C%s W%d H%d F%d:%d Ip A0:0\n",
    y4mformat, info.width, info.height, tonumber(info.fpsNum), tonumber(info.fpsDen)))
end

function VSNodeRef:output(file, y4m, prefetch, progress_sink)
  if #self <= 0 then error('Cannot output unknown length clip') end

  prefetch = prefetch or vscore:info().numThreads
  progress_sink = progress_sink or function() end
  progress_sink(0, #self)

  if y4m then
    self:writeY4MHeader(file)
  end

  for i = 1, #self do
    local frame = self[i]

    if y4m then
      file:write("FRAME\n")
    end

    local format = frame:format()
    for plane = 1, format.numPlanes do
      local pitch = frame:stride(plane)
      local readPtr = frame:readPtr(plane)
      local rowSize = frame:width(plane) * format.bytesPerSample
      local height = frame:height(plane)

      for y = 1, frame:height(plane) do
        file:write(ffi.string(readPtr, rowSize))
        readPtr = readPtr + pitch
      end
    end

    progress_sink(i, #self)
  end

  if y4m then
    file:write("\n")
  end
end

function VSNodeRef:__add(clip)
  if not ffi.istype("VSNodeRef", clip) then error("Clips can only be spliced to other clips", 2) end
  return vscore.std.Splice{clips={self, clip}}
end

function VSNodeRef:__mul(count)
  count = tonumber(count)
  if count == nil then error("Clips can only by multiplied by numbers", 2) end
  if count ~= math.floor(count) or count < 0 then
    error("Clips can only be repeated a positive integer number of times")
  end

  return vscore.std.Loop(self, count)
end

function VSNodeRef:__len()
  return self:videoInfo().numFrames
end

function VSNodeRef:__tostring()
  return tostring(self:videoInfo())
end

function VSNodeRef:__index(idx)
  if type(idx) == "number" then return self:frame(idx) end
  return VSNodeRef[idx] or vscore:findFunction(idx)
end

-------------------------------------------------------------------------------
local VSFrameRef = {}
VSFrameRef.__index = VSFrameRef
ffi.metatype("VSFrameRef", VSFrameRef)

function VSFrameRef:__gc() vsapi.freeFrame(self) end
function VSFrameRef:format()        return vsapi.getFrameFormat(self)                         end
function VSFrameRef:props()         return vsapi.getFramePropsRW(self)                        end
function VSFrameRef:width(plane)    return vsapi.getFrameWidth(self, self:checkPlane(plane))  end
function VSFrameRef:height(plane)   return vsapi.getFrameHeight(self, self:checkPlane(plane)) end
function VSFrameRef:readPtr(plane)  return vsapi.getReadPtr(self, self:checkPlane(plane))     end
function VSFrameRef:writePtr(plane) return vsapi.getWritePtr(self, self:checkPlane(plane))    end
function VSFrameRef:stride(plane)   return vsapi.getStride(self, self:checkPlane(plane))      end
function VSFrameRef:copy()          return vsapi.copyFrame(self, vscore)                      end
function VSFrameRef:clone()         return vsapi.cloneFrameRef(self)                          end

function VSFrameRef:checkPlane(plane)
  plane = plane or 1
  if plane <= 0 or plane > self:format().numPlanes then
    error(string.format("Plane must be between 1 and %d (got %d)", self:format().numPlanes, plane), 3)
  end
  return plane - 1
end

function VSFrameRef:__tostring()
  local f = self:format()
  return string.format("VideoFrame\n\tFormat: %s\n\tWidth:  %s\n\tHeight: %s\n",
    ffi.string(self:format().name), self:width(), self:height())
end

-------------------------------------------------------------------------------
local VSVideoInfo = {}
ffi.metatype("VSVideoInfo", VSVideoInfo)

function VSVideoInfo:__tostring()
  return string.format("FPS:    %d/%d\nSize:   %dx%d\nLength: %d Frames",
    tonumber(self.fpsNum), tonumber(self.fpsDen),
    self.width, self.height,
    self.numFrames)
end

-------------------------------------------------------------------------------
local VSFuncRef = {}
ffi.metatype("VSFuncRef", VSFuncRef)

function VSFuncRef:__gc() vsapi.freeFunc(self) end
function VSFuncRef:clone() return vsapi.cloneFuncRef(self) end

-------------------------------------------------------------------------------

return vscore
