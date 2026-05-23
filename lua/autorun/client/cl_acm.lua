aCM = aCM or {}

include("apolloscombatmedic/config.lua")

language.Add("ACM_BANDAGE_ammo", "Bandages")
language.Add("ACM_SPLINT_ammo", "Splints")

aCM.Assessing = false
aCM.TimeOfAssessment = nil
aCM.Patient = nil
aCM.TimeOfDeath = 0
aCM.TimeUntilDeath = 0
aCM.CurrentMinigame = nil
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

aCM.HitGroupBoneTranslation = {
	[HITGROUP_GENERIC] = "ValveBiped.Bip01_Pelvis",
	[HITGROUP_HEAD] = "ValveBiped.Bip01_Head1",
	[HITGROUP_CHEST] = "ValveBiped.Bip01_Spine2",
	[HITGROUP_STOMACH] = "ValveBiped.Bip01_Spine",
	[HITGROUP_LEFTARM] = "ValveBiped.Bip01_L_Forearm",
	[HITGROUP_RIGHTARM] = "ValveBiped.Bip01_R_Forearm",
	[HITGROUP_LEFTLEG] = "ValveBiped.Bip01_L_Calf",
	[HITGROUP_RIGHTLEG] = "ValveBiped.Bip01_R_Calf",
	[HITGROUP_GEAR] = "ValveBiped.Bip01_Pelvis",
}

function aCM.StartAssessment(ply)
	if ply == nil or !IsValid(ply) or (!ply:IsPlayer() and !ply:IsBot()) then return end
	aCM.Assessing = true

	LocalPlayer():ChatPrint("Assessing "..ply:Nick().."...")

	aCM.TimeOfAssessment = CurTime()

	if timer.Exists("aCM.AssessPlayer") then 
		timer.Stop("aCM.AssessPlayer") 
		timer.Remove("aCM.AssessPlayer") 
	end

	timer.Create("aCM.AssessPlayer", aCM.Config.AssessmentTime, 1, function()
		aCM.Assessing = false
		
		if ply == nil or !IsValid(ply) then return end
		local ragdoll = ply:GetNWEntity("aCM.RagdollEntity", nil)
		if ragdoll == nil or !IsValid(ragdoll) then return end

		net.Start("aCM.Assessment")
			net.WriteEntity(ragdoll)
		net.SendToServer()
		ragdoll.wasAssessed = true
	end)
end

function aCM.ProcessBleeds(target)
	target.aCM.totalBleeds = 0
	target.aCM.bleedBonePositions = {}

	local bleeds = 0
	for loc,amount in pairs(target.aCM.bleeds) do
		if aCM.Config.BandageFixesWholePart == true then
			if amount != 0 then
				bleeds = bleeds + 1
				target.aCM.bleedBonePositions[loc] = target.aCM.bleedBonePositions[loc] or 0
				target.aCM.bleedBonePositions[loc] = target.aCM.bleedBonePositions[loc] + 1
			end
		else
			if amount != 0 then
				bleeds = bleeds + amount
				target.aCM.bleedBonePositions[loc] = target.aCM.bleedBonePositions[loc] or 0
				target.aCM.bleedBonePositions[loc] = target.aCM.bleedBonePositions[loc] + amount
			end
		end
	end
	target.aCM.totalBleeds = bleeds

	return bleeds
end

function aCM.ProcessBones(target)
	local brokenBonesString = ""
	local bones = 0
	for loc,broken in pairs(target.aCM.brokenBones) do
		if !broken then continue end

		brokenBonesString = brokenBonesString..(bones != 0 and ", " or "")..aCM.HitGroupDictionary[loc]
		bones = bones + 1
	end
	target.aCM.totalBrokenBones = bones

	return brokenBonesString, bones
end

gameevent.Listen( "player_activate" )
hook.Add("player_activate", "aCM.PlayerActivate", function(data) 
	net.Start("aCM.Loaded")
	net.SendToServer()

	if BRANCH != "x86-64" then
		LocalPlayer():ChatPrint("aCM :: You are not on the x86-64 branch of Garry's Mod. UI will probably be broken.")
	end
end)

hook.Add("Think", "aCM.Think", function()
	if !LocalPlayer():Alive() then return end

	local ent = LocalPlayer():GetEyeTrace().Entity
	if ent == nil or !IsValid(ent) then return end
	if ent:GetNWBool("aCM.Ragdoll") != true then return end

	-- Assess Player

	if LocalPlayer():KeyPressed(IN_USE) and LocalPlayer():GetActiveWeapon():GetClass() == "acm_medkit" then
		if aCM.Config.MedicRolesEnabled and aCM.Config.StrictMedicRules then
            if aCM.Config.DarkRPEnabled then
                if !table.HasValue(aCM.Config.MedicRoles, LocalPlayer():Team()) then
                    return
                end
            else
                local customCheck = aCM.Config.MedicRoleCustomCheck(LocalPlayer())
                if customCheck != true then return end
            end
        end

		if aCM.Assessing == false then
			if ent.wasAssessed != true then
				aCM.StartAssessment(ent:GetNWEntity("aCM.Player"))
			else
				net.Start("aCM.Assessment")
					net.WriteEntity(ent)
				net.SendToServer()
			end
		end
	end
end)

net.Receive("aCM.UpdatePlayer", function()
	LocalPlayer().aCM = nil
	
	LocalPlayer().aCM = net.ReadTable()
end)

net.Receive("aCM.UpdateDoctor", function()
	local tbl = net.ReadTable()
	local patient = net.ReadEntity()

	patient.aCM = tbl

	local bleeds = aCM.ProcessBleeds(patient)
	local brokenBonesString, bones = aCM.ProcessBones(patient)
end)

net.Receive("aCM.Assessment", function()
	local aCMTable = net.ReadTable()
	local target = net.ReadEntity()

	if target == aCM.Patient then return end

	target.aCM = aCMTable

	local bleeds = aCM.ProcessBleeds(target)
	local brokenBonesString, bones = aCM.ProcessBones(target)

	aCM.Patient = target
	aCM.SetPatientHTML()

	LocalPlayer():ChatPrint("Assessment Complete:")
	LocalPlayer():ChatPrint("	Bleeds: "..bleeds)
	LocalPlayer():ChatPrint("	Broken Bones: "..brokenBonesString)
	LocalPlayer():ChatPrint("	Seconds until death: "..math.Round(target.aCM.TimeUntilDead-CurTime()))
end)

net.Receive("aCM.IsDead", function()
	local state = net.ReadBool()
	aCM.TimeUntilDead = net.ReadInt(32)

	if state == true then
		aCM.TimeOfDeath = CurTime()
		aCM.DeadScreen()
	else
		if aCM.DeadScreenFrame != nil then
			aCM.DeadScreenFrame:Remove()
			aCM.DeadScreenFrame = nil
		end
	end
end)

net.Receive("aCM.CanRespawn", function()
	aCM.CanRespawn = true
end)

net.Receive("aCM.PlayerRevived", function()
	local ply = net.ReadEntity()

	if aCM.Patient == ply then
		aCM.Patient = nil
		aCM.CurrentMinigame = nil
		aCM.SetDownedHTML()

		if aCM.DownedPlayers[ply] != nil and aCM.DownedPlayers[ply]:IsValid() then
			aCM.DownedPlayers[ply]:Remove()
		end
	end
end)

net.Receive("aCM.DownedPlayers", function()
	local downedPlayers = net.ReadTable()

	for ply, panel in pairs(aCM.DownedPlayers) do
		if type(panel) == "Panel" and IsValid(panel) then
			panel:Remove()
		end
	end

	for ply, down in pairs(downedPlayers) do
		if down != false then
			local img = vgui.Create("DImage")
			aCM.DownedPlayers[ply] = img
			aCM.DownedPlayers[ply]:SetImage("icon16/heart.png")
			aCM.DownedPlayers[ply]:SetSize(32,32)
		end
	end
end)