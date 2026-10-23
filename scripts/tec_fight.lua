-- TEC rotation configuration for Praetor. Preview only; does not send commands.
local M = {usage="<build>", desc="Preview saved TEC move rotations"}
local presets = {
  falxaoe="break,wstrike,wslash,spinh,slash,chop,strike",
  falxsingle="break,slashh,chop,strike,bashhead,ankle,fslashh,wslash,spinh",
  falxaziri="chop,strike,slashh,break,wstrike,wslash,spinh,fslash,ankle",
  dual="dswat,flicker,heartseeker,dchop,tendon,gorgerip,dstrike,djab,dblood,hookdisarm",
  dualdamage="flicker,heartseeker,bloods,dstrike,dblood,heartseeker,djab,dstrike,dblood,heartseeker,bloods,dswat,dblood",
  daxe="rotchop,offchop,onslaught,offpivot,pollsmash,harrow,rotchop,offcrush,sweepcleave",
  daxspeed="rotchop,offchop,onslaught,offpivot,pollsmash,offcrush",
}
function M.on_start(args)
  local name = (args[1] or ""):lower()
  local moves = presets[name]
  if not moves then log("[TEC] Unknown build: " .. name); return end
  state.set("tec_build",name)
  state.display("tec_build","TEC build")
  log("[TEC] Preview of " .. name .. ": " .. moves)
end
M.reactions = {}
return M
