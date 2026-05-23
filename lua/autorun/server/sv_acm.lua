aCM = {}
AddCSLuaFile("apolloscombatmedic/config.lua")
include("apolloscombatmedic/config.lua")
util.AddNetworkString("aCM.Loaded")
util.AddNetworkString("aCM.Assessment")
util.AddNetworkString("aCM.UpdatePlayer")
util.AddNetworkString("aCM.CanRespawn")
util.AddNetworkString("aCM.IsDead")
util.AddNetworkString("aCM.PlayerRevived")
util.AddNetworkString("aCM.FixNode")
util.AddNetworkString("aCM.UpdateDoctor")
util.AddNetworkString("aCM.DownedPlayers")

aCM.BleedingPlayers = {}
aCM.DoctorCache = {} -- Stores the list of patients, indexed by the doctor player.
aCM.PatientCache = {} -- Stores the list of doctors, indexed by the patient player.
aCM.DownedPlayers = {}

aCM.HitGroupDictionary = {
	[HITGROUP_GENERIC] = "Body Overall",
	[HITGROUP_HEAD] = "Head",
	[HITGROUP_CHEST] = "Ribs",
	[HITGROUP_STOMACH] = "Torso",
	[HITGROUP_LEFTARM] = "Left Arm",
	[HITGROUP_RIGHTARM] = "Right Arm",
	[HITGROUP_LEFTLEG] = "Left Leg",
	[HITGROUP_RIGHTLEG] = "Right Leg",
	[HITGROUP_GEAR] = "Belt",
}

aCM.OnDamaged = {
	[HITGROUP_HEAD] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_HEAD)
	end,
	[HITGROUP_CHEST] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_CHEST)
		local didBoneBreak = aCM.RollBrokenBone(ply, HITGROUP_CHEST)
	end,
	[HITGROUP_STOMACH] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_STOMACH)
	end,

	[HITGROUP_LEFTARM] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_LEFTARM)

		local didBoneBreak = aCM.RollBrokenBone(ply, HITGROUP_LEFTARM)
	end,
	[HITGROUP_RIGHTARM] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_RIGHTARM)

		local didBoneBreak = aCM.RollBrokenBone(ply, HITGROUP_RIGHTARM)
	end,
	[HITGROUP_LEFTLEG] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_LEFTLEG)

		if aCM.Config.LegDamage == false then return end
		local didBoneBreak = aCM.RollBrokenBone(ply, HITGROUP_LEFTLEG)
	end,
	[HITGROUP_RIGHTLEG] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_RIGHTLEG)

		if aCM.Config.LegDamage == false then return end
		local didBoneBreak = aCM.RollBrokenBone(ply, HITGROUP_RIGHTLEG)
	end,
}

aCM.OnBoneBroken = {
	[HITGROUP_GENERIC] = function(ply)
		aCM.CreateBleed(ply, HITGROUP_HEAD)
        print("aCM: Warning! Found strange hitgroups on model "..ply:GetModel().."; Bones may not break on this playermodel!")
	end,
    [HITGROUP_CHEST] = function(ply)
        if aCM.Config.BrokenRibsPreventSprint then
            aCM.AdjustSpeeds(ply, true)
        end
    end,
    [HITGROUP_LEFTLEG] = function(ply)
        aCM.AdjustSpeeds(ply, true)
    end,
    [HITGROUP_RIGHTLEG] = function(ply)
        aCM.AdjustSpeeds(ply, true)
    end,
}

-- Logic for fixing bones
aCM.OnBoneFixed = {
    [HITGROUP_CHEST] = function(ply)
        aCM.AdjustSpeeds(ply, false)
    end,
    [HITGROUP_LEFTLEG] = function(ply)
        aCM.AdjustSpeeds(ply, false)
    end,
    [HITGROUP_RIGHTLEG] = function(ply)
        aCM.AdjustSpeeds(ply, false)
    end,
}

function aCM.AdjustSpeeds(ply, subtract)
    if subtract == true then
	    if (ply:GetWalkSpeed()-aCM.Config.DamagedLegPenalty) > aCM.Config.MinimumWalkSpeed then
	    	ply:SetWalkSpeed(ply:GetWalkSpeed()-aCM.Config.DamagedLegPenalty)
	    else
	    	ply:SetWalkSpeed(aCM.Config.MinimumWalkSpeed)
	    end

	    ply:SetRunSpeed(ply:GetWalkSpeed())
	elseif subtract == false then
		if (ply:GetWalkSpeed()+aCM.Config.DamagedLegPenalty) > ply.aCM.DefaultWalkSpeed then
	    	ply:SetWalkSpeed(ply.aCM.DefaultWalkSpeed)
	    else
	    	ply:SetWalkSpeed(ply:GetWalkSpeed()+aCM.Config.DamagedLegPenalty)
	    end

	    if ply:GetWalkSpeed() >= ply.aCM.DefaultWalkSpeed then
	    	ply:SetRunSpeed(ply.aCM.DefaultRunSpeed)
	    else
	    	ply:SetRunSpeed(ply:GetWalkSpeed())
	    end
	end
end

function aCM.UpdatePlayer(ply)
	net.Start("aCM.UpdatePlayer")
		net.WriteTable(ply.aCM)
	net.Send(ply)
end

function aCM.UpdateDoctor(ply)
	if aCM.DoctorCache[ply] == nil or !aCM.DoctorCache[ply]:IsValid() or aCM.DoctorCache[ply].aCM == nil then return end

	net.Start("aCM.UpdateDoctor")
		net.WriteTable(aCM.DoctorCache[ply].aCM)
		net.WriteEntity(aCM.DoctorCache[ply])
	net.Send(ply)
end

function aCM.CreateBleed(ply, location)
	ply.aCM.bleeds[location] = ply.aCM.bleeds[location] + 1

	local bleeds = 0
	for _,l in pairs(ply.aCM.bleeds) do
		if l != 0 then
			if aCM.Config.BandageFixesWholePart == true then
				bleeds = bleeds + 1
			else
				bleeds = bleeds + l
			end

		end
	end
	ply.aCM.BleedCount = bleeds

	aCM.BleedingPlayers[ply] = bleeds

	aCM.UpdatePlayer(ply)
end

function aCM.FixAllBleeds(ply, location)
	ply.aCM.bleeds[location] = 0

	local bleeds = 0
	for _,l in pairs(ply.aCM.bleeds) do
		if l != 0 then
			if aCM.Config.BandageFixesWholePart == true then
				bleeds = bleeds + 1
			else
				bleeds = bleeds + l
			end

		end
	end
	ply.aCM.BleedCount = bleeds

	if bleeds == 0 then
		aCM.BleedingPlayers[ply] = nil
	else
		aCM.BleedingPlayers[ply] = bleeds
	end

	aCM.UpdatePlayer(ply)
	aCM.UpdateDoctor(aCM.PatientCache[ply])
end

function aCM.FixBleed(ply, location)
	if ply.aCM.bleeds[location] - 1 >= 0 then
		ply.aCM.bleeds[location] = ply.aCM.bleeds[location] - 1
	else
		ply.aCM.bleeds[location] = 0
	end

	local bleeds = 0
	for _,l in pairs(ply.aCM.bleeds) do
		if l != 0 then
			if aCM.Config.BandageFixesWholePart == true then
				bleeds = bleeds + 1
			else
				bleeds = bleeds + l
			end

		end
	end
	ply.aCM.BleedCount = bleeds

	if bleeds == 0 then
		aCM.BleedingPlayers[ply] = nil
	else
		aCM.BleedingPlayers[ply] = bleeds
	end

	aCM.UpdatePlayer(ply)
	aCM.UpdateDoctor(aCM.PatientCache[ply])
end

function aCM.FixBone(ply, bone)
	if aCM.Config.BrokenBones == false then return end

	if aCM.OnBoneFixed[bone] != nil then
		aCM.OnBoneFixed[bone](ply)
	end
	ply.aCM.brokenBones[bone] = false

	local brokenBones = 0
	for _,broken in pairs(ply.aCM.brokenBones) do
		if broken == true then
			brokenBones = brokenBones + 1
		end
	end
	ply.aCM.BrokenBoneCount = brokenBones

	aCM.UpdatePlayer(ply)
	aCM.UpdateDoctor(aCM.PatientCache[ply])
end

function aCM.BreakBone(ply, bone)
	if aCM.Config.BrokenBones == false then return end

	if ply.aCM.brokenBones[bone] == true then return true end

	ply.aCM.brokenBones[bone] = true
	if aCM.OnBoneBroken[bone] != nil then
		aCM.OnBoneBroken[bone](ply)
	end

	local brokenBones = 0
	for _,broken in pairs(ply.aCM.brokenBones) do
		if broken == true then
			brokenBones = brokenBones + 1
		end
	end
	ply.aCM.BrokenBoneCount = brokenBones

	ply:ChatPrint("You broke your "..aCM.HitGroupDictionary[bone])

	aCM.UpdatePlayer(ply)
end

function aCM.RollBrokenBone(ply, part)
	if aCM.Config.BrokenBones == false then return false end

	math.randomseed(CurTime())

	if math.random(1, 100) <= aCM.Config.BrokenBoneChance then
		aCM.BreakBone(ply, part)
    	return true
	else
	    return false
	end
end

function aCM.RagdollPlayer(ply)
	if ply:InVehicle() then ply:ExitVehicle() end
	if ply.aCM.RagdollData != nil then return end

	ply.aCM.RagdollData = {
		pos = ply:GetPos(),
		ang = ply:GetAngles(),
		health = ply:Health(),
		armor = ply:Armor(),
		ammo = {},
		weps = {},
	}

	for _,wep in pairs(ply:GetWeapons()) do
		table.insert(ply.aCM.RagdollData.weps, wep:GetClass())
	end

	for _,ammoID in pairs(ply:GetAmmo()) do
		ply.aCM.RagdollData.ammo[ammoID] = ply:GetAmmoCount(ammoID)
	end

	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll.aCMPlayer = ply
	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
    ragdoll:SetModel(ply:GetModel())
    ragdoll:Spawn()
    ragdoll:Activate()

    ragdoll:SetNWBool("aCM.Ragdoll", true)
    ragdoll:SetNWEntity("aCM.Player", ply)

    ragdoll:CallOnRemove("aCM.COM", function(self, rdPly)
    	if rdPly == nil or !IsValid(rdPly) then return end

    	aCM.StopRagdollPlayer(rdPly)
    end, ply)

    ply:SetParent(ragdoll)
    local velocity = ply:GetVelocity()

    local i = 1
    while true do
        if ragdoll:GetPhysicsObjectNum(i) then
            ragdoll:GetPhysicsObjectNum(i):SetVelocity( velocity )
            i = i + 1
        else
            break
        end
    end

    ply:Spectate( OBS_MODE_CHASE )
    ply:SpectateEntity( ragdoll )
    ply:StripWeapons()
    ply.aCM.RagdollEntity = ragdoll

    ply:SetNWEntity("aCM.RagdollEntity", ragdoll)

	aCM.DownedPlayers[ply] = true
	net.Start("aCM.DownedPlayers")
		net.WriteTable(aCM.DownedPlayers)
	net.Broadcast()

    aCM.UpdatePlayer(ply)
end

function aCM.StopRagdollPlayer(ply, noSpawn)
	if ply == nil or !IsValid(ply) then return end
	if ply.aCM == nil then return end
    if ply.aCM.RagdollData == nil then return end

    ply:Spectate(OBS_MODE_NONE)
    ply:UnSpectate()
    ply:SetParent()
    ply.aCM.JustStoppedRagdoll = true -- Prevent stack overflow in PlayerSpawn hook
    ply:Spawn()
    ply.aCM.JustStoppedRagdoll = nil

    local respawnPos = ply.aCM.RagdollData.pos
    if ply.aCM.RagdollEntity and IsValid(ply.aCM.RagdollEntity) then
        respawnPos = ply.aCM.RagdollEntity:GetPos() + Vector(0, 0, 12)
        ply.aCM.RagdollEntity:Remove()
    end

    -- Ensure there's space at the respawn position
    local trace = util.TraceHull({
        start = respawnPos,
        endpos = respawnPos,
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
        filter = {ply, ply.aCM.RagdollEntity} -- Ignore the player and their ragdoll
    })

    if trace.Hit then
        -- Adjust position upwards until there's space
        local safeHeight = 0
        local maxAttempts = 10 -- Try moving up 10 times
        for i = 1, maxAttempts do
            local checkPos = respawnPos + Vector(0, 0, i * 12) -- Move up by 12 units per attempt
            trace = util.TraceHull({
                start = checkPos,
                endpos = checkPos,
                mins = ply:OBBMins(),
                maxs = ply:OBBMaxs(),
                filter = {ply, ply.aCM.RagdollEntity}
            })

            if not trace.Hit then
                respawnPos = checkPos
                break
            end
        end
    end

    ply:SetPos(respawnPos)
    ply:SetAngles(ply.aCM.RagdollData.ang)

    ply:StripWeapons()
    ply:RemoveAllAmmo()

    for _, wep in pairs(ply.aCM.RagdollData.weps) do
        ply:Give(wep)
    end

    for id, amount in pairs(ply.aCM.RagdollData.ammo) do
        ply:SetAmmo(amount, id)
    end

    ply:SetHealth(ply.aCM.RagdollData.health)
    ply:SetArmor(ply.aCM.RagdollData.armor)

    ply.aCM.RagdollData = nil
    ply:SetNWEntity("aCM.RagdollEntity", nil)

    net.Start("aCM.IsDead")
    	net.WriteBool(false)
    net.Send(ply)

    for bone,broken in pairs(ply.aCM.brokenBones) do
    	if broken != true then return end

    	if bone == HITGROUP_CHEST or bone == HITGROUP_LEFTLEG or bone == HITGROUP_RIGHTLEG then
    		aCM.AdjustSpeeds(ply, true)
    	end
    end

	aCM.DownedPlayers[ply] = false
	
	net.Start("aCM.DownedPlayers")
		net.WriteTable(aCM.DownedPlayers)
	net.Broadcast()

    aCM.UpdatePlayer(ply)
end

function aCM.RevivePlayer(ply)
	if ply.aCM == nil then return end
	if ply.aCM.RagdollData == nil then return end

	aCM.StopRagdollPlayer(ply)
	ply:SetHealth(aCM.Config.RespawnHealth)

	net.Start("aCM.PlayerRevived")
		net.WriteEntity(ply)
	net.Broadcast()
end

function aCM.PlayerAssessRagdoll(caller, ragdoll)
	local target = ragdoll.aCMPlayer

	aCM.SetDoctor(caller, target)

	net.Start("aCM.Assessment")
		net.WriteTable(target.aCM)
		net.WriteEntity(target)
	net.Send(caller)
end

function aCM.GetNearestBone(ply, ragdoll)
    local trace = ply:GetEyeTrace()
    if trace.Entity ~= ragdoll then return end

    local closestBone, closestDist = nil, math.huge
    for i = 0, ragdoll:GetBoneCount() - 1 do
        local bonePos = ragdoll:GetBonePosition(i)
        local dist = bonePos:Distance(trace.HitPos)
        if dist < closestDist then
            closestDist = dist
            closestBone = i
        end
    end

    return closestBone
end

function aCM.DragThink()
	for _, ply in ipairs(player.GetAll()) do
        if not ply:KeyDown(IN_USE) or not ply.DraggingRagdoll or not ply.DraggingBone then
            ply.DraggingRagdoll = nil
            ply.DraggingBone = nil
            continue
        end

        if ply:GetActiveWeapon():GetClass() == "acm_medkit" then return end -- Don't drag players with the medkit out, as 'e' with the medkit analyzes a player.

        local ragdoll = ply.DraggingRagdoll
        local bone = ply.DraggingBone
        local bonePhys = ragdoll:GetPhysicsObjectNum(bone)
        
        if not IsValid(bonePhys) then continue end

        -- Get the position of the player and the bone
        local playerPos = ply:GetPos() + Vector(0, 0, 50) -- Slight offset for chest height
        local bonePos = bonePhys:GetPos()

        -- Calculate direction and force
        local direction = (playerPos - bonePos):GetNormalized()
        local distance = playerPos:Distance(ragdoll:GetPos())

        if distance >= 150 then
        	ply.DraggingRagdoll = nil
            ply.DraggingBone = nil
        end

        local force = distance * 250 -- Scaled force with a maximum cap

        -- Apply the force to the ragdoll's bone
        if distance > 50 then
        	bonePhys:SetVelocity(direction * force * FrameTime())
        end
    end
end

function aCM.FindTarget(from)
	local ent = from:GetEyeTrace().Entity
	if ent == nil or !IsValid(ent) then return end

	if type(ent) == "Player" then
		return ent
	else
		if ent:GetNWBool("aCM.Ragdoll") != true then return end
		local ply = ent:GetNWEntity("aCM.Player")

		return ply, ent
	end
end

function aCM.BleedThink()
	for ply,amount in pairs(aCM.BleedingPlayers) do
		if ply == nil or !IsValid(ply) then 
			aCM.BleedingPlayers[ply] = nil
			return 
		end

		if !ply:Alive() then return end

		local pos = ply:GetPos()

		if ply.aCM.RagdollEntity != nil and IsValid(ply.aCM.RagdollEntity) then
			pos = ply.aCM.RagdollEntity:GetPos()
		end

		if aCM.Config.BloodVisuals == true then
			-- This one places blood on the ground
			util.Decal("Blood", pos+Vector(0,0,100), pos-Vector(0,0,100), {ply, ply.aCM.RagdollEntity})

			-- This one is responsible for the blood on the player / player ragdoll
			if ply.aCM.bloodDecals < amount then
				if ply.aCM.RagdollEntity == nil or !IsValid(ply.aCM.RagdollEntity) then
					util.Decal("Blood", pos+(ply:EyeAngles():Forward() * 100)+Vector(0,0,50), pos-(ply:EyeAngles():Forward() * 100)+Vector(0,0,50))
				else
					util.Decal("Blood", pos+Vector(0,0,100), pos-Vector(0,0,100))
				end
				ply.aCM.bloodDecals = ply.aCM.bloodDecals + 1
			end
		end
		if ply.aCM.RagdollData == nil then
			if ply:Health() - (amount/10) <= 0 then
				aCM.DoDeath(ply)
			else
				ply:SetHealth(ply:Health()-(amount/10))
			end
		end
	end
end

function aCM.ClearPlayerTable(patient)
	if aCM.PatientCache[patient] != nil then
		-- Player has a doctor, let's clear them
		local doctor = aCM.PatientCache[patient]
		aCM.DoctorCache[doctor] = nil
		aCM.PatientCache[patient] = nil
	end
end

function aCM.SetDoctor(doctor, patient)
	aCM.DoctorCache[doctor] = patient
	aCM.PatientCache[patient] = doctor

	patient.aCM.Doctor = doctor
	doctor.aCM.Patient = patient
end

function aCM.DoDeath(ply)
	ply:SetHealth(0.1)
		
	if ply.aCM.RagdollData == nil then
		aCM.RagdollPlayer(ply)
	end

	aCM.ClearPlayerTable(ply)

	if timer.Exists("aCM.DeathTimer."..ply:SteamID()) then
		timer.Stop("aCM.DeathTimer."..ply:SteamID())
		timer.Remove("aCM.DeathTimer."..ply:SteamID())
	end

	if timer.Exists("aCM.RespawnTimer."..ply:SteamID()) then
		timer.Stop("aCM.RespawnTimer."..ply:SteamID())
		timer.Remove("aCM.RespawnTimer."..ply:SteamID())
	end

	local timeToLive = aCM.Config.TimeUntilDeath

	if aCM.BleedingPlayers[ply] != nil then
		local negator = aCM.Config.DeathTimerBleedPenalty * aCM.BleedingPlayers[ply]

		if timeToLive - negator >= aCM.Config.DeathTimerMinimumTime then
			timeToLive = timeToLive - negator
		else
			timeToLive = aCM.Config.DeathTimerMinimumTime
		end
	end

	ply.aCM.TimeOfRagdoll = CurTime()
	ply.aCM.TimeUntilDead = CurTime() + timeToLive
	ply.aCM.DeathTimerDelay = timeToLive
	ply.aCM.CanRespawn = false

	timer.Create("aCM.DeathTimer."..ply:SteamID(), timeToLive, 1, function()
		if ply == nil or !IsValid(ply) then return end
		if ply.aCM.RagdollData == nil then return end

		aCM.StopRagdollPlayer(ply)
		ply:Kill()
	end)

	timer.Create("aCM.RespawnTimer."..ply:SteamID(), aCM.Config.TimeUntilForfeitAllowed, 1, function()
		if ply == nil or !IsValid(ply) then return end
		if ply.aCM.RagdollData == nil then return end

		ply.aCM.CanRespawn = true

		net.Start("aCM.CanRespawn")
		net.Send(ply)
	end)

	net.Start("aCM.IsDead")
		net.WriteBool(true)
		net.WriteInt(ply.aCM.TimeUntilDead, 32)
	net.Send(ply)

	net.Start("aCM.PlayerRevived")
		net.WriteEntity(ply)
	net.Broadcast()
end

hook.Add("EntityTakeDamage", "aCM.EntityTakeDamage", function(target, dmgInfo)
	if target == nil or !IsValid(target) then return end
	if !target:IsPlayer() then return end
	
	if aCM.Config.DamageBlacklist[dmgInfo:GetDamageType()] != nil then
		return false
	end

	if dmgInfo:GetWeapon() != nil and dmgInfo:GetWeapon():IsValid() then
        if aCM.Config.WeaponBlacklist[dmgInfo:GetWeapon():GetClass()] == true then
            return
        end
	end

	local ply = target -- For convenience, since we know at this point the target is a player.

	local dmgPos = ply:LastHitGroup()
	if dmgPos != nil and aCM.OnDamaged[dmgPos] != nil then
		aCM.OnDamaged[dmgPos](ply)
	end

	if ply:Health()-dmgInfo:GetDamage() < 0.1 then
		if aCM.Config.InstaDeathHeadshots and dmgPos == HITGROUP_HEAD then
			return false
		else
			if ply.aCM.RagdollData == nil then
				aCM.DoDeath(ply)
			end

			return true
		end
	end
end)

hook.Add("PlayerSpawn", "aCM.PlayerSpawn", function(ply)
	if ply == nil or !IsValid(ply) then return end

	if ply.aCM != nil and ply.aCM.JustStoppedRagdoll == true then 
		return 
	else
		-- Player has likely been force-respawned.
		aCM.RevivePlayer(ply)
	end

	ply.aCM = {
		brokenBones = {},
		BleedCount = 0,
		BrokenBoneCount = 0,
		bleeds = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
			[6] = 0,
			[7] = 0,
		},
		bloodDecals = 0,
	}
	local ragdollData = ply.aCM.RagdollData
	ply.aCM.DefaultRunSpeed = ply:GetRunSpeed()
	ply.aCM.DefaultWalkSpeed = ply:GetWalkSpeed()
	ply.aCM.RagdollData = ragdollData
	aCM.BleedingPlayers[ply] = nil
	aCM.StopRagdollPlayer(ply)
	ply.aCM.CanRespawn = false

	aCM.UpdatePlayer(ply)

	aCM.ClearPlayerTable(patient)

	net.Start("aCM.IsDead")
		net.WriteBool(false)
	net.Send(ply)

	net.Start("aCM.PlayerRevived")
		net.WriteEntity(ply)
	net.Broadcast()
end)

hook.Add("PlayerUse", "aCM.StartDraggingRagdoll", function(ply, ent)
    if not IsValid(ent) or not ent:IsRagdoll() then return end

    if ply.DraggingRagdoll then return end

    -- Save the ragdoll and player interaction state
    ply.DraggingRagdoll = ent

    -- Detect which bone the player is aiming at
    local bone = aCM.GetNearestBone(ply, ent)
    if not bone then return end

    ply.DraggingBone = bone
end)

hook.Add("Think", "aCM.Think", function()
    aCM.DragThink()
end)

hook.Add("CanPlayerSuicide", "aCM.CanPlayerSuicide", function(ply)
	if ply.aCM.RagdollData != nil then return false end
end)

hook.Add("KeyRelease", "aCM.StopDraggingRagdoll", function(ply, key)
    if key == IN_USE then
        ply.DraggingRagdoll = nil
        ply.DraggingBone = nil
    end

    if ply.aCM.CanRespawn == true and ply.aCM.RagdollData != nil then
    	aCM.StopRagdollPlayer(ply)
    	ply:Kill()
    end
end)

hook.Add("Initialize", "aCM.Initialize", function()
	game.AddAmmoType({
		name = "ACM_BANDAGE",
		dmgtype = DMG_GENERIC, 
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		maxcarry = 30,
	})

	game.AddAmmoType({
		name = "ACM_SPLINT",
		dmgtype = DMG_GENERIC, 
		tracer = TRACER_NONE,
		plydmg = 0,
		npcdmg = 0,
		maxcarry = 10,
	})
end)

timer.Create("aCM.BleedTimer", 5, 0, aCM.BleedThink)

net.Receive("aCM.Assessment", function(len, ply)
	local ragdoll = net.ReadEntity()

	if aCM.Config.MedicRolesEnabled and aCM.Config.StrictMedicRules then
		if aCM.Config.DarkRPEnabled then
			if !table.HasValue(aCM.Config.MedicRoles, ply:Team()) then
				return
			end
		else
			local customCheck = aCM.Config.MedicRoleCustomCheck(ply)
			if customCheck != true then return end
		end
	end

	aCM.PlayerAssessRagdoll(ply, ragdoll)
end)

net.Receive("aCM.FixNode", function(len, ply)
	local patient = net.ReadEntity()
	local minigame = net.ReadTable()

	if aCM.Config.MedicRolesEnabled and aCM.Config.StrictMedicRules then
		if aCM.Config.DarkRPEnabled then
			if !table.HasValue(aCM.Config.MedicRoles, ply:Team()) then
				return
			end
		else
			local customCheck = aCM.Config.MedicRoleCustomCheck(ply)
			if customCheck != true then return end
		end
	end
	
	if minigame.type == "bleed" then
		if !ply:GetWeapon("acm_bandage"):IsValid() then return end

		if ply:GetWeapon("acm_bandage"):Clip1() - 1 >= 0 then
			if aCM.Config.BandageFixesWholePart == true then
				aCM.FixAllBleeds(patient, minigame.hitgroup)
			else
				aCM.FixBleed(patient, minigame.hitgroup)
			end

			ply:GetWeapon("acm_bandage"):SetClip1(ply:GetWeapon("acm_bandage"):Clip1() - 1)
			ply:GetWeapon("acm_bandage"):DoAnimation("anim_fire")
			ply:EmitSound("acm/bandage.mp3")
		end
	elseif minigame.type == "bone" then
		if !ply:GetWeapon("acm_splint"):IsValid() then return end

		if ply:GetWeapon("acm_splint"):Clip1() - 1 >= 0 then
			aCM.FixBone(patient, minigame.hitgroup)
			ply:GetWeapon("acm_splint"):SetClip1(ply:GetWeapon("acm_splint"):Clip1() - 1)
			ply:GetWeapon("acm_splint"):DoAnimation("anim_fire")
			ply:EmitSound("acm/snap.mp3")
		end
	end
end)

net.Receive("aCM.Loaded", function(len, ply)
	if ply == nil or !IsValid(ply) then return end

	ply.aCM = {
		brokenBones = {},
		BrokenBoneCount = 0,
		BleedCount = 0,
		bleeds = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
			[6] = 0,
			[7] = 0,
		},
		bloodDecals = 0,
	}
	ply.aCM.DefaultRunSpeed = ply:GetRunSpeed()
	ply.aCM.DefaultWalkSpeed = ply:GetWalkSpeed()
	ply.aCM.RagdollData = nil
	aCM.BleedingPlayers[ply] = nil
	ply.aCM.CanRespawn = false

	aCM.UpdatePlayer(ply)
end)