local ffi = require "ffi"

local VSFuncRef = {}

function VSFuncRef:__gc() vsapi.freeFunc(self) end
function VSFuncRef:clone() return vsapi.cloneFuncRef(self) end

ffi.metatype("VSFuncRef", VSFuncRef)
