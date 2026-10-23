-- TEC jewelry migration: controlled starter mode.
-- Usage: /mode jewelry wax|mold|bake|heat [live]
-- Preview is default. Live sends the initial command, then waits for text.
local M={usage="wax|mold|bake|heat [live]",desc="TEC jewelry crafting starter (preview by default)"}
local commands={wax="form wax",mold="mold clay",bake="heat clay over furnace",heat="heat cruc over furnace"}
local active, live, command, last_sent = false,false,nil,0
local function issue()
  if not active or not command then return end
  if time.since(last_sent) < 1000 then return end
  last_sent=time.now()
  if live then send(command) else log("[TEC jewelry preview] "..command) end
end
function M.on_start(args)
  local operation=(args[1] or ""):lower()
  command=commands[operation]
  if not command then log("[TEC jewelry] Choose wax, mold, bake, or heat"); return end
  live=args[2]=="live"
  active=true
  log("[TEC jewelry] "..operation.." "..(live and "LIVE" or "PREVIEW").."; manual stop: /mode off")
  issue()
end
function M.on_stop() active=false; log("[TEC jewelry] Stopped") end
-- Do not automatically repeat on generic busy echoes: completion,
-- storing, recovery and resource handling must be ported from TECeLite first.
M.reactions={}
return M
