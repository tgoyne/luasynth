local ffi = require "ffi"
local vs = require "luasynth.vsapi"
local Function = require "luasynth.function"

local VSCore = {
  colorFamily    = vs:readEnum("cm"),
  sampleType     = vs:readEnum("st"),
  presetFormat   = vs:readEnum("pf"),
  nodeFlags      = vs:readEnum("nf"),
  getPropErrors  = vs:readEnum("pe"),
  propAppendMode = vs:readEnum("pa")
}

function VSCore:__gc() vs.freeCore(self) end
function VSCore:info() return vs.getCoreInfo(self) end

function VSCore:newVideoFrame(format, width, height, propSrc)
  return vs.newVideoFrame(format, width, height, propSrc, self)
end

function VSCore:__index(plugin_name)
  if VSCore[plugin_name] then return VSCore[plugin_name] end
  local plugin = vs.getPluginNs(plugin_name, self)
  if plugin == nil then
    error('Plugin with namespace "' .. plugin_name .. '" not found', 2)
  end
  return plugin
end

function VSCore:__tostring()
  local ret = ""
  local plugins = vs.getPlugins(self)
  for i = 1, #plugins do
    local plugin = plugins:string(plugins[i])
    namespace, identifier, description = plugin:match("(.*);(.*);(.*)")
    ret = string.format("%s%s\n\tnamespace:  %s\n\tidentifier: %s\n", ret, description, namespace, identifier)
    ret = ret .. tostring(vs.getPluginId(identifier, self))
  end
  return ret
end

function VSCore:findFunction(fn_name)
  local plugins = vs.getPlugins(self)
  for i = 1, #plugins do
    local plugin_str = plugins:string(plugins[i])
    identifier = plugin_str:match(".*;(.*);.*")
    local plugin = vs.getPluginId(identifier, self)
    local functions = vs.getFunctions(plugin)
    for i = 1, #functions do
      local fn = functions[i]
      if fn_name == ffi.string(fn) then
        return Function(functions:string(fn), plugin)
      end
    end
  end
end

local core = vs.createCore(vapourSynthThreadCount or 0)

ffi.metatype("VSCore", VSCore)

return core
