local ffi = require "ffi"
local vs = require "luasynth.vsapi"

local VSFrameRef = {}
VSFrameRef.__index = VSFrameRef

function VSFrameRef:__gc() vs.freeFrame(self) end
function VSFrameRef:format()        return vs.getFrameFormat(self)                         end
function VSFrameRef:props()         return vs.getFramePropsRW(self)                        end
function VSFrameRef:width(plane)    return vs.getFrameWidth(self, self:checkPlane(plane))  end
function VSFrameRef:height(plane)   return vs.getFrameHeight(self, self:checkPlane(plane)) end
function VSFrameRef:readPtr(plane)  return vs.getReadPtr(self, self:checkPlane(plane))     end
function VSFrameRef:writePtr(plane) return vs.getWritePtr(self, self:checkPlane(plane))    end
function VSFrameRef:stride(plane)   return vs.getStride(self, self:checkPlane(plane))      end
function VSFrameRef:copy()          return vs.copyFrame(self, vscore)                      end
function VSFrameRef:clone()         return vs.cloneFrameRef(self)                          end

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

ffi.metatype("VSFrameRef", VSFrameRef)
