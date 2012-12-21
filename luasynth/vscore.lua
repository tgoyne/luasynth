local ffi = require "ffi"
local vs = require "luasynth.vsapi"
local Function = require "luasynth.function"

local VSCore = {
  colorFamily      = vs:readEnum("cm"),
  sampleType       = vs:readEnum("st"),
  presetFormat     = vs:readEnum("pf"),
  nodeFlags        = vs:readEnum("nf"),
  getPropErrors    = vs:readEnum("pe"),
  propAppendMode   = vs:readEnum("pa"),
  filterMode       = vs:readEnum("fm"),
  activationReason = vs:readEnum("ar")
}

function VSCore:__gc() vs.freeCore(self) end
function VSCore:info() return vs.getCoreInfo(self) end

function VSCore:newVideoFrame(format, width, height, propSrc)
  return vs.newVideoFrame(format, width, height, propSrc, self)
end

function VSCore:__index(plugin_name)
  return VSCore[plugin_name] or vs.getPluginNs(plugin_name, self)
end

function VSCore:__tostring()
  local ret = ""
  for _, plugin in vs.getPlugins(self):iter() do
    local namespace, identifier, description = plugin:match("(.*);(.*);(.*)")
    ret = string.format("%s%s\n\tnamespace:  %s\n\tidentifier: %s\n", ret, description, namespace, identifier)
    ret = ret .. tostring(vs.getPluginId(identifier, self))
  end
  return ret
end

function VSCore:findFunction(fn_name)
  for _, plugin_str in vs.getPlugins(self):iter() do
    local identifier = plugin_str:match(".*;(.*);.*")
    local plugin = vs.getPluginId(identifier, self)
    for name, fn in vs.getFunctions(plugin):iter() do
      if fn_name == ffi.string(name) then
        return Function(fn, plugin)
      end
    end
  end
end

ffi.metatype("VSCore", VSCore)

return vs.createCore(vapourSynthThreadCount or 0)
