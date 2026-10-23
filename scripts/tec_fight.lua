-- TEC combat: response-driven rotation engine for Praetor Lua 5.1.
-- /mode tec_fight falxaziri live   (sends the first move)
-- /mode tec_fight falxaziri        (dry-run)
-- Change modes to stop; Praetor cancels queued mode commands on switch.
local M = {usage="<build> [live]", desc="TEC response-driven combat rotation"}
local presets = {
 falxaoe="break,wstrike,wslash,spinh,slash,chop,strike",
 falxaoe2="break,wstrike,wslash,spinh,rakeh",
 falxsingle="break,slashh,chop,strike,bashhead,ankle,fslashh,wslash,spinh",
 falxaziri="chop,strike,slashh,break,wstrike,wslash,spinh,fslash,ankle",
 warhammer="chop,swat,hafts,hcru,vcrush,wsmash,overhead",
 dual="dswat,flicker,heartseeker,dchop,tendon,gorgerip,dstrike,djab,dblood,hookdisarm",
 dual2="dswat,flicker,heartseeker,dchop,dstrike,djab,dblood,twinslash,hookdisarm",
 dualspar="dswat,flicker,heartseeker,dchop,dstrike,djab,dblood,twinslash",
 dualdance="twinslash,bloods,dblood,dstrike,dswat,dchop,heartseeker,flicker,hookdisarm",
 dualdance2="twinslash,dblood,dstrike,dswat,dchop,heartseeker,flicker",
 dualdamage="flicker,heartseeker,bloods,dstrike,dblood,heartseeker,djab,dstrike,dblood,heartseeker,bloods,dswat,dblood",
 dualknee="heartseeker,dswat,twinslash,dblood,heartseeker,dstrike,twinslash,dblood",
 dualeasy="dswat,dchop,djab,dstrike,heartseeker,twinslash",
 dualopcombo="heartseeker,dchop,djab,dblood,flicker,heartseeker,djab,dstrike,dblood,tendonslash,hookdisarm",
 daxe="rotchop,offchop,onslaught,offpivot,pollsmash,harrow,rotchop,offcrush,sweepcleave",
 daxspeed="rotchop,offchop,onslaught,offpivot,pollsmash,offcrush"
}
local active=false
local live=false
local moves={}
local position=1
local waiting=false
local last=0
local watchdog=nil
local function emit(command)
 if live then send(command) else log("[TEC fight preview] "..command) end
end
local function advance()
 if not active or waiting or #moves==0 then return end
 -- Guard against duplicate readiness messages.
 if last>0 and time.since(last)<750 then return end
 local move=moves[position]
 position=(position % #moves)+1
 waiting=true
 last=time.now()
 emit(move)
 -- Fail closed if no readiness response arrives; never attack on a timer.
 if watchdog then clear_timer(watchdog) end
 watchdog=set_timeout(function()
   if active and waiting then
     waiting=false
     active=false
     log("[TEC fight] Paused: no readiness response after 15 seconds. Restart mode to resume.")
   end
 end,15000)
end
local function ready()
 if not active then return end
 if watchdog then clear_timer(watchdog); watchdog=nil end
 waiting=false
 advance()
end
function M.on_start(args)
 active=false
 local name=(args[1] or ""):lower()
 local sequence=presets[name]
 if not sequence then
   log("[TEC fight] Unknown build: "..name)
   return
 end
 moves={}
 for move in sequence:gmatch("[^,]+") do moves[#moves+1]=move end
 position=1
 waiting=false
 last=0
 live=(args[2] or ""):lower()=="live"
 active=true
 state.set("tec_build",name)
 state.display("tec_build","TEC build")
 log("[TEC fight] "..name..": "..#moves.." moves, "..(live and "LIVE" or "PREVIEW"))
 advance()
end
function M.on_stop()
 active=false
 waiting=false
 if watchdog then clear_timer(watchdog); watchdog=nil end
 log("[TEC fight] Stopped")
end
M.reactions={
 {match="You are no longer busy.",action=ready},
 {match="You must be standing",action=function()
   if active then
     if watchdog then clear_timer(watchdog); watchdog=nil end
     waiting=true
     emit("stand")
     -- Wait for the game's next readiness confirmation.
     last=time.now()
   end
 end},
 {match="You are stunned",action=function()
   if active then active=false; log("[TEC fight] Paused: stunned; restart mode when recovered") end
 end}
}
return M
