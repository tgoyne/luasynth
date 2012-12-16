local ffi = require "ffi"
local Function = require "luasynth.function"
local vs = require "luasynth.vsapi"
local core = require "luasynth.vscore"

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

local function packResult(name, argsIn, argsOut, succeeded, res, ...)
  if not succeeded then
    argsOut:setError(res)
    return
  end

  if type(res) ~= "function" then
    argsOut:set(res)
    return
  end

  -- User returned a filter, go into crazy mode
  local args = {res, ...}
  local init, getFrame, free
  local flags = core.filterMode.Serial

  if type(args[#args]) == "number" then
    flags = args[#args]
    args[#args] = nil
  end

  if #args > 1 then
    init = args[1]
    getFrame = args[2]
    free = args[3]
  else
    getFrame = args[1]
  end

  local initHandle = ffi.cast("VSFilterInit", function(_, _, _, node)
    local videoInfo = init and init()
    if videoInfo then
      if type(videoInfo) == "table" then
        vs.setVideoInfo(videoInfo, #videoInfo, node)
      else
        vs.setVideoInfo(videoInfo, 1, node)
      end
    end
  end)

  local getFrameHandle = ffi.cast("VSFilterGetFrame", function(frameNumber, activationReason, _, _, frameCtx)
    return getFrame(frameNumber + 1, activationReason, frameCtx)
  end)

  local freeHandle
  freeHandle = ffi.cast("VSFilterFree", function()
    if free then free() end
    initHandle:free()
    getFrameHandle:free()
    freeHandle:free()
  end)

  vs.createFilter(argsIn, argsOut, name, initHandle, getFrameHandle, freeHandle, flags, 0, nil, core)
end

function VSPlugin:registerFunction(name, arguments, fn)
  local func = Function(name .. ";" .. arguments)
  local function wrapper(argsIn, argsOut)
    packResult(name, argsIn, argsOut, pcall(fn, func:unpack(argsIn)))
  end

  vs.registerFunction(name, arguments, wrapper, nil, self)
end

ffi.metatype("VSPlugin", VSPlugin)
