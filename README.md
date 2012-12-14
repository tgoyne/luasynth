# LuaSynth

LuaSynth is a LuaJIT 2.0 binding for
[VapourSynth](http://www.vapoursynth.com/). It is currently a hacked together
mess which was mostly created in a single sitting with very little thought, and
will probably change a lot in the future if it continues to be developed.

## Installation

1. Install LuaJIT
2. Install VapourSynth
3. Copy the VaopurSynth dynamic library to somewhere in LuaJIT's module search
   path
4. Copy LuaSynth to somewhere in LuaJIT's module search path

## Usage

A basic script:

```lua
-- Import the LuaSynth module
local vs = require "luasynth"

-- Load FFMS2, using named parameters
vs.std.LoadPlugin{path="ffms2.dylib"}

-- Open a video file, this time using positional arguments
-- Note that named and positional arguments currently cannot be mixed
clip = vs.ffms2.Source("file.mkv")

-- Grab just the first 100 frames of the clip
-- Note that because this is Lua, everything is 1-indexed
trimmed = vs.std.Trim(clip, 1, 100)

-- Alternatively, with AVS-style chaining
-- This currently only supports positional arguments
-- If there are multiple functions with the same name in different
-- namespaces, which one will be picked is undefined
trimmed = clip:Trim(1, 100)

-- Write the clip to stdout as y4m
clip:output(io.stdout, true)
```

Then, to encode the script, run:

    luajit file.lua | x264 --demuxer y4m -o out.mkv -

## Stuff still to be done

1. Multithread VSNodeRef.output
2. Add a way to register lua functions as VS functions
3. Integrate with VS for the avifile magic
4. Packaging and installation
5. Probably a bunch of other little things
