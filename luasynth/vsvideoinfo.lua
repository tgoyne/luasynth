local ffi = require "ffi"

local VSVideoInfo = {}

function VSVideoInfo:__tostring()
  return string.format("FPS:    %d/%d\nSize:   %dx%d\nLength: %d Frames",
    tonumber(self.fpsNum), tonumber(self.fpsDen),
    self.width, self.height,
    self.numFrames)
end

ffi.metatype("VSVideoInfo", VSVideoInfo)
