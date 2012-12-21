local ffi = require "ffi"

local vapoursynth_h = require "luasynth.vapoursynth"
ffi.cdef(vapoursynth_h)

local vs = ffi.load "vapoursynth"

local vsapi = vs.getVapourSynthAPI(3)
if vsapi == nil then error("Failed to initialize VapourSynth") end

local VSAPI = {}
VSAPI._ffi_module = vs -- Ensure there's a reference somewhere so it doesn't get gc'd

function VSAPI:readEnum(prefix)
  local ret = {}
  for tok in vapoursynth_h:gmatch(" " .. prefix .. "([A-Z][A-z0-9]*)") do
    ret[tok] = ffi.C[prefix .. tok]
  end
  return ret
end

function VSAPI:rawptr(idx)
  return tonumber(ffi.cast("intptr_t", vsapi[idx]))
end

local gcTypes = {
  ["ctype<const struct VSFrameRef *(*)()>"] = true,
  ["ctype<const struct VSFuncRef *(*)()>"] = true,
  ["ctype<const struct VSMap *(*)()>"] = true,
  ["ctype<const struct VSNodeRef *(*)()>"] = true,
  ["ctype<struct VSFrameRef *(*)()>"] = true,
  ["ctype<struct VSFuncRef *(*)()>"] = true,
  ["ctype<struct VSMap *(*)()>"] = true,
  ["ctype<struct VSNodeRef *(*)()>"] = true
}

local wrapperCache = {}
function VSAPI:__index(idx)
  local fn = VSAPI[idx] or wrapperCache[idx]
  if fn then return fn end

  fn = vsapi[idx]
  if not fn then return end

  -- This is probably exceptionally dumb and will explode in the future
  if not gcTypes[tostring(ffi.typeof(fn))] then
    wrapperCache[idx] = fn
  else
    wrapperCache[idx] = function(...)
      local ret = fn(...)
      ffi.gc(ret, ret.__gc)
      return ret
    end
  end

  return wrapperCache[idx]
end

return setmetatable({}, VSAPI)
