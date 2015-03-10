local bit = require "bit"
local ffi = require "ffi"
local lanes = require "lanes"
local core = require "luasynth.vscore"
local vs = require "luasynth.vsapi"
lanes.configure()

ffi.cdef([[
  size_t fwrite(const void *ptr, size_t size, size_t count, void *stream);
]])

local VSNodeRef = {}

function VSNodeRef:__gc() vs.freeNode(self) end
function VSNodeRef:clone() return vs.cloneNodeRef(self) end
function VSNodeRef:videoInfo() return vs.getVideoInfo(self) end

function VSNodeRef:frame(frameNum, context)
  if context then
    return vs.getFrameFilter(frameNum - 1, self, context)
  end

  local errbuf = ffi.new("char[512]")
  local frame = vs.getFrame(frameNum - 1, self, errbuf, 512)
  if frame == nil then
    if errbuf[0] ~= 0 then
      error(ffi.string(errbuf))
    else
      error(string.format("Failed to fetch frame %d: No error message given", frameNum))
    end
  end
  return frame
end

function VSNodeRef:requestFrame(frameNum, context)
  vs.requestFrameFilter(frameNum - 1, self, context)
end

function VSNodeRef:writeY4MHeader(file)
  local info = self:videoInfo()
  local format = info.format
  if not format or (format.colorFamily ~= core.colorFamily.YUV and format.colorFamily ~= core.colorFamily.GRAY) then
    error('y4m only supports YUV and Gray formats')
  end

  local y4mformat
  if format.colorFamily == core.colorFamily.GRAY then
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

local mq = lanes.linda()

local function tovoidptr(ffi, cdata)
  return tonumber(ffi.cast("intptr_t", cdata))
end

local function requestThread(getFrame, node)
  local ffi = require "ffi"
  local errbuf = ffi.new "char[512]"

  ffi.cdef(require "luasynth.vapoursynth")

  getFrame = ffi.cast("VSGetFrame", getFrame)
  node = ffi.cast("VSNodeRef *", node)

  local function get(frameNum)
    local frame = getFrame(frameNum - 1, node, errbuf, 512)
    if frame == nil then
      if errbuf[0] ~= 0 then
        return ffi.string(errbuf)
      else
        return "No error message given"
      end
    end

    return tovoidptr(ffi, frame)
  end

  while true do
    local k, frameNum = mq:receive "req"
    if k ~= "req" then return end -- Error occured
    if frameNum == 0 then return end

    mq:send(nil, frameNum, get(frameNum))
  end
end

local function writeFrame(file, frame, y4m)
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
      ffi.C.fwrite(readPtr, 1, rowSize, file)
      readPtr = readPtr + pitch
    end
  end

  vs.freeFrame(frame)
end

function VSNodeRef:output(file, y4m, prefetch, progress_sink)
  if #self <= 0 then error('Cannot output unknown length clip') end

  prefetch = prefetch or core:info().numThreads
  progress_sink = progress_sink or function() end
  progress_sink(0, #self)

  local startThread = lanes.gen("*", requestThread)

  if y4m then
    self:writeY4MHeader(file)
  end

  for i = 1, prefetch + 1 do
    startThread(vs:rawptr('getFrame'), tovoidptr(ffi, self))
    mq:send("req", i)
  end

  for i = 1, #self do
    local _, frame = mq:receive(nil, i)
    if type(frame) == "string" then
      error(string.format("Error fetching frame %d: %s", i, frame))
    end

    writeFrame(file, ffi.cast("VSFrameRef *", frame), y4m)
    progress_sink(i, #self)

    if i + prefetch < #self then
      mq:send("req", i + prefetch + 1)
    end
  end

  if y4m then
    file:write("\n")
  end
end

function VSNodeRef:__add(clip)
  if not ffi.istype("VSNodeRef", clip) then error("Clips can only be spliced to other clips", 2) end
  return core.std.Splice{clips={self, clip}}
end

function VSNodeRef:__mul(count)
  count = tonumber(count)
  if count == nil then error("Clips can only by multiplied by numbers", 2) end
  if count ~= math.floor(count) or count < 0 then
    error("Clips can only be repeated a positive integer number of times")
  end

  return core.std.Loop(self, count)
end

function VSNodeRef:__len()
  return self:videoInfo().numFrames
end

function VSNodeRef:__tostring()
  return tostring(self:videoInfo())
end

function VSNodeRef:__index(idx)
  if type(idx) == "number" then return self:frame(idx) end
  return VSNodeRef[idx] or core:findFunction(idx)
end

ffi.metatype("VSNodeRef", VSNodeRef)
