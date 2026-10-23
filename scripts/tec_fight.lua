-- Unified TEC combat engine. Source: TECeLite /fight (4410-5384) and
-- /combat script.combatmaster (8741-9009). No blind attack timer.
-- /mode tec_fight <build> [live] [target:<name>]
local M={usage="<build> [live] [target:<name>]",desc="TEC unified combat with recovery and state tracking"}
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
local c={}
local function has(t,s) return t:lower():find(s:lower(),1,true)~=nil end
local function any(t,list)
 for _,s in ipairs(list) do if has(t,s) then return true end end
 return false
end
local function report(s) log("[TEC fight] "..s) end
local function cancel()
 if c.timer then clear_timer(c.timer);c.timer=nil end
end
local function pause(reason)
 c.paused=true;c.pending=nil;cancel();report("PAUSED: "..reason)
end
local function command(s)
 if c.live then send(s) else report("PREVIEW "..s) end
 c.last=time.now()
end
local function status()
 state.set("tec_status",(c.paused and "PAUSED" or c.pending or "ready")..
   " | move "..tostring(c.pos).."/"..tostring(#c.moves))
end
local function issue(s,kind)
 if c.paused or c.pending then return end
 c.pending=kind or "attack";c.last_command=s;command(s);status()
 cancel()
 c.timer=set_timeout(function()
   if c.pending then pause("No confirmation for "..c.last_command.."; inspect game output") end
   status()
 end,15000)
end
local function nextmove()
 if c.paused or c.pending or c.stunned then return end
 local cmd,kind
 -- Priority is intentional: standing, grappling, entanglement, pickup,
 -- rearm, stance, range, target and only then an attack.
 if c.down then cmd="stand";kind="stand"
 elseif c.grappled then cmd="free";kind="free"
 elseif c.entangled then
   cmd=(c.weapon=="tridents" and "fling "..c.weapon) or (c.weapon=="dual axes" and "flankhew") or "free";kind="free"
 elseif c.dropped then cmd="take "..c.weapon;kind="take"
 elseif c.disarmed then
   cmd=c.dual and "dualwield" or "wield "..c.weapon;kind="wield"
 elseif c.shield_disarmed and c.shield then cmd="wield "..c.shield;kind="shield"
 elseif c.stance then cmd=c.stance;kind="stance"
 elseif c.approach then cmd="approach "..(c.target or "");kind="approach"
 elseif c.retarget and c.target then cmd="target "..c.target;kind="target"
 else
   if c.chamber then cmd=c.chamber;c.chamber=nil;kind="chamber"
   else cmd=c.moves[c.pos];kind="attack" end
 end
 if cmd and cmd~="" then issue(cmd,kind) end
end
local function confirm(kind)
 if not c.pending then return end
 if kind and c.pending~=kind then return end
 local k=c.pending
 cancel();c.pending=nil
 if k=="attack" then c.pos=c.pos%#c.moves+1
 elseif k=="chamber" then
   -- An inserted chamber does not advance the normal rotation.
 elseif k=="stand" then c.down=false
 elseif k=="take" then c.dropped=false;c.disarmed=true
 elseif k=="wield" then c.disarmed=false
 elseif k=="shield" then c.shield_disarmed=false
 elseif k=="stance" then c.stance=nil
 elseif k=="free" then c.entangled=false;c.grappled=false
 elseif k=="approach" then c.approach=false
 elseif k=="target" then c.retarget=false end
 status();nextmove()
end
local function reject()
 if not c.pending then return end
 cancel();c.pending=nil;status()
end
local function event(t)
 if c.paused then return end
 -- Keep all state detectors in one callback: Praetor only runs first match.
 if any(t,{"You are stunned","You get stunned"}) then
   c.stunned=true;reject();status();return
 end
 if has(t,"You are no longer stunned") then c.stunned=false;nextmove();return end
 if any(t,{"knocking you down","knocks you to the ground","You must be standing","You stumble and fall","falling flat on your face"}) then
   c.down=true;reject();nextmove();return
 end
 if any(t,{"You stand up","You are already standing","Rising from your prone position"}) then
   c.down=false;if c.pending=="stand" then confirm("stand") else nextmove() end;return
 end
 if any(t,{"You fumble! You drop","You fumble, dropping","flinging away your weapon","You must be carrying something to wield it"}) then
   c.dropped=true;c.disarmed=false;reject();nextmove();return
 end
 if any(t,{"disarming you","lose your grip on","loosens your grip on","knocking it out of your grip","You must be wielding a weapon","You must be wielding your weapon in two hands"}) then
   if any(t,{"shield","buckler"}) then c.shield_disarmed=true
   else c.disarmed=true end
   reject();nextmove();return
 end
 if c.dual and any(t,{"You must be actively wielding a weapon in each hand","already wielding that in your right hand"}) then
   c.disarmed=true;reject();nextmove();return
 end
 if has(t,"You take") and c.pending=="take" and has(t,c.weapon) then confirm("take");return end
 if any(t,{"You wield","You are already wielding"}) then
   if c.pending=="wield" then
     if c.dual and has(t,"right hand") then reject();c.disarmed=true;nextmove()
     else confirm("wield") end
   elseif c.pending=="shield" then confirm("shield") end
   return
 end
 if any(t,{"You cannot attack with an entangled weapon","manages to lock the tines","catching your weapon"}) then
   c.entangled=true;reject();nextmove();return
 end
 if any(t,{"you manage to wrench away","you wrench away","If you are trying to free an entangled weapon"}) then
   c.entangled=false;if c.pending=="free" then confirm("free") end;return
 end
 if any(t,{"You cannot use that action while grappling","grabs you with both arms"}) then
   c.grappled=true;reject();nextmove();return
 end
 if has(t,"you free yourself from") then c.grappled=false;if c.pending=="free" then confirm("free") end;return end
 if has(t,"You are not in the correct stance") then
   local stances={{"Falx Kelestian Siege Stance","siege"},{"Trident Harpoon Stance","harpoon"},{"Wide Grip Stance","wgrip"},{"Falcata Striker's Stance","striker"},{"Cestus Weaving Stance","weave"},{"Avros Dueling Stance","duel"},{"Nelsor Tiger Stance","tiger"},{"Pardelian Turtle Stance","turtle"},{"Chainblade Winged Stance","winged"},{"Hoplite Combat Stance","hoplite"},{"Pankration Basic Stance","pank"},{"Sky Circle Stance","scircle"}}
   for _,p in ipairs(stances) do if has(t,p[1]) then c.stance=p[2] end end
   reject()
   if c.stance then nextmove() else pause("Unknown required weapon stance") end
   return
 end
 if any(t,{"You are already in that stance","Combat mode changed to"}) and c.pending=="stance" then confirm("stance");return end
 if any(t,{"is not close enough","but can't get close"}) then
   c.approach=true;reject()
   if c.target then nextmove() else pause("Need a target for approach") end
   return
 end
 if any(t,{"You stop next to","You advance toward","You are already engaging"}) and c.pending=="approach" then confirm("approach");return end
 if has(t,"Your new macro target is") and c.pending=="target" then confirm("target");return end
 if any(t,{"falls unconscious","is already dead","has left the area","You cannot kill that which has no life"}) then
   reject();pause("Target KO/death or left area; reacquire target");return
 end
 -- Dry fire: preserve rotation index and retry after readiness.
 if any(t,{"You can't do that right now","You are in the middle of something","You will be busy for","You start to fumble, but manage to maintain"}) then
   reject();return
 end
 if has(t,"You are no longer busy") then
   -- Only normal attacks and chambers advance on readiness.
   if c.pending=="attack" or c.pending=="chamber" then confirm()
   elseif not c.pending then nextmove() end
   return
 end
end
function M.on_start(args)
 cancel()
 local name=(args[1] or ""):lower()
 local sequence=presets[name]
 if not sequence then report("Unknown build: "..name);return end
 c={moves={},pos=1,live=false,paused=false,down=false,stunned=false,
   disarmed=false,dropped=false,grappled=false,entangled=false}
 for move in sequence:gmatch("[^,]+") do c.moves[#c.moves+1]=move end
 c.weapon=(name:find("falx") and "falx") or (name:find("dual") and "dagger") or
   (name:find("dax") and "dual axes") or (name=="warhammer" and "warhammer")
 c.dual=name:find("dual")~=nil or name:find("dax")~=nil
 for i=2,#args do
   if args[i]=="live" then c.live=true
   elseif args[i]:sub(1,7)=="target:" then c.target=args[i]:sub(8) end
 end
 state.set("tec_build",name);state.display("tec_build","TEC build")
 state.display("tec_status","Combat status")
 report(name.." loaded ("..(c.live and "LIVE" or "PREVIEW")..")")
 status();nextmove()
end
function M.on_stop() cancel();c.paused=true;report("Stopped") end
M.reactions={{match="*",action=event}}
return M
