local ffi = require "ffi"
local vs = require "luasynth.vsapi"

local VSFuncRef = {}

function VSFuncRef:__gc() vs.freeFunc(self) end
function VSFuncRef:clone() return vs.cloneFuncRef(self) end

ffi.metatype("VSFuncRef", VSFuncRef)
