aCM = aCM or {}

aCM.DeadScreenFrame = nil
aCM.CanRespawn = false
aCM.HTML = nil

local matBlurScreen = Material( "pp/blurscreen" )
function aCM.BlurPanel(panel, amount, opacity, color)
	local x, y = panel:LocalToScreen( 0, 0 )
	surface.SetMaterial( matBlurScreen )
	surface.SetDrawColor( 0, 0, 0, 255 )
	for i = 0.33, 1, 0.33 do
		matBlurScreen:SetFloat( "$blur", amount * i ) -- Increase number 5 for more blur
		matBlurScreen:Recompute()
		if ( render ) then render.UpdateScreenEffectTexture() end
		surface.DrawTexturedRect( x * -1, y * -1, ScrW(), ScrH() )
	end

	if opacity == nil then
		opacity = 50
	end

	if color == nil then
		color = Color(0,0,0)
	end

	surface.SetDrawColor( ColorAlpha(color, opacity) )
	surface.DrawRect( x * -1, y * -1, ScrW(), ScrH() )
end

function aCM.DeadScreen()
	if aCM.DeadScreenFrame != nil then aCM.DeadScreenFrame:Remove() end

	aCM.DeadScreenFrame = vgui.Create("DFrame")
	local frame = aCM.DeadScreenFrame
	frame:SetSize(ScrW(), ScrH())
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetBackgroundBlur(true)
	function frame:Paint(w,h) 
		aCM.BlurPanel(self, 10, 0, Color(0,0,0))
		draw.RoundedBox(0, 0, 0, w, h, Color(0,0,0,200))
	end

	frame.html = vgui.Create("DHTML", frame)
	local html = frame.html
	html:SetSize(frame:GetSize())
	html.onDeadScreen = false

	local deadHTML = [[
		<h1>YOU ARE UNCONSCIOUS</h1>
		<p id="info">WAIT FOR A MEDIC</p>
		<div id="deathTimer">
			<p id="deathTimerLeft">(YOU CAN RESPAWN IN </p><p id="deathTimerNumbers">UNKNOWN</p><p id="deathTimerRight"> SECONDS)</p>
		</div>
	]]

	local respawnHTML = [[
		<h1>PRESS ANY KEY TO GIVE UP</h1>
		<p id="info">OR CONTINUE WAITING FOR A MEDIC.</p>
		<div id="deathTimer">
			<p id="deathTimerLeft">(YOU WILL DIE IN </p><p id="deathTimerNumbers">UNKNOWN</p><p id="deathTimerRight"> SECONDS)</p>
		</div>
	]]

	local css = [[<style>
		body {
			color: #fff;
			font-family: Arial;
			text-align: center;
			font-size: 1vw;
			overflow: hidden;
		}

		h1 {
			width:fit-content;
			font-weight: 1000;
			font-size: 4vw;
			border-bottom: 0.5vh solid #fff;
			text-align:center;
			margin: auto;

			margin-top: 45vh;
		}

		#info {
			text-align:center;
			font-weight: 600;
			font-size: 2vw;
			margin-top: 2vh;
			margin-bottom: 0vh;
		}

		#deathTimer {
			font-weight: 200;
			width: 100vw;
			height:fit-content;
			display: flex;
			flex-direction: row;
			justify-content: center;
			position: absolute;
			bottom: 0;
		}

		#deathTimerLeft {
			margin-right: 0.35vw;
		}
		#deathTimerRight {
			margin-left: 0.35vw;
		}

	</style>]]

	local documentReady = false
	function html:OnDocumentReady()
		documentReady = true
	end

	local timeUntilRespawn = aCM.TimeOfDeath+aCM.Config.TimeUntilForfeitAllowed

	function frame:Think()
		if frame == nil or !IsValid(frame) or !ispanel(frame) then return end
		if LocalPlayer().aCM.RagdollData == nil then frame:Remove() end

		if aCM.CanRespawn == false then
			if html.onDeadScreen == false then
				html:SetHTML(deadHTML..css)

				html.onDeadScreen = true
			end

			if documentReady == true and aCM.TimeOfDeath != nil then
				html:RunJavascript([[
					var timer = document.getElementById("deathTimerNumbers");
					timer.innerText = " ]]..math.Round(timeUntilRespawn-CurTime())..[[ ";
				]])
			end
		else
			if html.onDeadScreen == true then
				html:SetHTML(respawnHTML..css)
				
				html.onDeadScreen = false
			end

			if documentReady == true and aCM.TimeUntilDead != nil then
				html:RunJavascript([[
					var timer = document.getElementById("deathTimerNumbers");
					timer.innerText = ]]..math.Round(aCM.TimeUntilDead-CurTime())..[[;
				]])
			end
		end

		frame:MoveToFront() -- Keep behind everything
	end

	function frame:OnRemove()
		if aCM.CanRespawn == true then
			aCM.CanRespawn = false
		end
	end
end

function aCM.FindTarget()
	local ent = LocalPlayer():GetEyeTrace().Entity
	if ent == nil or !IsValid(ent) then return end

	if type(ent) == "Player" then
		return ent
	else
		if ent:GetNWBool("aCM.Ragdoll") != true then return end
		local ply = ent:GetNWEntity("aCM.Player")

		return ply, ent
	end
end

function aCM.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

function aCM.SetDownedHTML()
	if aCM.HTML == nil or !ispanel(aCM.HTML) then return end

	aCM.HTML:SetHTML([[
		<img src="https://i.imgur.com/TkffGp0.gif" id="heart"/>
		<div id="wrapper">
			<h1>THIS PLAYER HAS BEEN DOWNED!</h1>
			<p id="info">(+USE THEM WITH THE MEDKIT TO VIEW THEIR AILMENTS</p>
			<p id="info">OR +USE THEM WITHOUT HOLDING THE MEDKIT TO DRAG THEM)</p>
		</div>
	]]..aCM.HTML.aCMCSS)
end

function aCM.SetPatientHTML()
	if aCM.HTML == nil or !ispanel(aCM.HTML) then return end
	if aCM.Patient == nil or !IsValid(aCM.Patient) then return end
	if aCM.Patient.aCM == nil then return end

	local ply = aCM.Patient

	aCM.HTML:SetHTML([[
		<img src="https://i.imgur.com/TkffGp0.gif" id="heart"/>
		<div id="wrapper">
			<h1 id="tod">ESTIMATED TOD: ]]..[[</h1>
			<div id="vital-div">
				<img src="https://i.imgur.com/CfToSfM.png" id="vital-img" /><p class="vital-p" id="bleeds">0</p>
			</div>
			<div id="vital-div">
				<img src="https://i.imgur.com/jNYIFVh.png" id="vital-img" /><p class="vital-p" id="breaks">0</p>
			</div>
		</div>
	]]..aCM.HTML.aCMCSS) --..aCM.FormatTime(ply.aCM.TimeUntilDead-SysTime())
end

function aCM.DrawBone(x, y, color)
	draw.RoundedBox(x, x-25, y-10, 10, 10, color)
	draw.RoundedBox(x, x-25, y, 10, 10, color)
	draw.RoundedBox(x, x+15, y-10, 10, 10, color)
	draw.RoundedBox(x, x+15, y, 10, 10, color)

	draw.RoundedBox(0, x-20, y-5, 40, 10, color)
end

-- `type` can either be "bone" or "bleed"
function aCM.RenderNode(type, boneID, hitgroup, amount)
	if !LocalPlayer():Alive() then return end
	local localPos = aCM.Patient.aCM.RagdollEntity:GetBonePosition(boneID):ToScreen()
	local color = nil
	
	-- This will be the 'Hitbox' for the bone. If localPos is within these values, the bone is in the center of the screen.
	local hitbox = {
		["min_x"] = ScrW()/2 - 20,
		["max_x"] = ScrW()/2 + 20,
		["min_y"] = ScrH()/2 - 20,
		["max_y"] = ScrH()/2 + 20,
	}

	if type == "bone" then
		color = Color(255,255,255,50)
	else
		color = Color(255,0,0,50)
	end

	if (localPos.x >= hitbox.min_x and localPos.y >= hitbox.min_y) and (localPos.x <= hitbox.max_x and localPos.y <= hitbox.max_y) then
		if LocalPlayer():GetActiveWeapon():GetClass() == "acm_bandage" or LocalPlayer():GetActiveWeapon():GetClass() == "acm_splint" then
			if type == "bone" then
				if LocalPlayer():GetWeapon("acm_splint"):Clip1() > 0 then
					color = Color(255,255,255,255)
				end
			else
				if LocalPlayer():GetWeapon("acm_bandage"):Clip1() > 0 then
					color = Color(255,0,0,255)
				end
			end
		end

		if LocalPlayer():KeyPressed(IN_USE) then
			if LocalPlayer():GetActiveWeapon():GetClass() == "acm_bandage" or LocalPlayer():GetActiveWeapon():GetClass() == "acm_splint" then
				-- Player selected this node. Let's start a minigame!
				if aCM.CurrentMinigame == nil then
					math.randomseed(SysTime()+CurTime())
					aCM.CurrentMinigame = {
						['type'] = type,
						['boneID'] = boneID,
						['hitgroup'] = hitgroup,
						['amount'] = amount,
						['progress'] = 0,
						['difficulty'] = math.Rand(1, 10)
					}
				end
			end
		end
	end

	-- Draw the indicator that a bone has been broken
	if type == "bone" then
		aCM.DrawBone(localPos.x, localPos.y, color)
		if IsValid(LocalPlayer():GetWeapon("acm_splint")) and LocalPlayer():GetWeapon("acm_splint"):Clip1() <= 0 then
			draw.DrawText("No Splints Remaining!", "DermaDefault", localPos.x, localPos.y+10, Color(255,255,255), TEXT_ALIGN_CENTER)
		end
	else
		draw.RoundedBox(20, localPos.x-10, localPos.y-10, 20, 20, color)
		if amount >= 2 then
			draw.DrawText("x"..tostring(amount), "DermaLarge", localPos.x, localPos.y, color, TEXT_ALIGN_LEFT)
		end

		if IsValid(LocalPlayer():GetWeapon("acm_bandage")) and LocalPlayer():GetWeapon("acm_bandage"):Clip1() <= 0 then
			draw.DrawText("No Bandages Remaining!", "DermaDefault", localPos.x, localPos.y-10, Color(255,255,255), TEXT_ALIGN_CENTER)
		end
	end
end

-- Show the overlay for all of the bleeds
function aCM.RenderBleeds()
	if !IsValid(LocalPlayer()) or !LocalPlayer():Alive() then return end
	if !IsValid(LocalPlayer():GetActiveWeapon()) then return end
	
	if LocalPlayer():GetActiveWeapon():GetClass() != "acm_bandage" and LocalPlayer():GetActiveWeapon():GetClass() != "acm_medkit" then return end

	for bone, amount in pairs(aCM.Patient.aCM.bleedBonePositions) do
		local boneID = aCM.Patient.aCM.RagdollEntity:LookupBone(aCM.HitGroupBoneTranslation[bone])
		aCM.RenderNode("bleed", boneID, bone, amount)
	end
end

-- Show the overlay for all of the broken bones
function aCM.RenderBones()
	if LocalPlayer():GetActiveWeapon():GetClass() != "acm_splint" and LocalPlayer():GetActiveWeapon():GetClass() != "acm_medkit" then return end

	for bone,broken in pairs(aCM.Patient.aCM.brokenBones) do
		if !broken then continue end

		local boneID = aCM.Patient.aCM.RagdollEntity:LookupBone(aCM.HitGroupBoneTranslation[bone])
		
		aCM.RenderNode("bone", boneID, bone)
	end
end

-- Below will be the minigame section
function aCM.RenderMinigame()
	if aCM.CurrentMinigame == nil then return end

	if aCM.CurrentMinigame.type == "bone" then
		if !LocalPlayer():GetWeapon("acm_splint"):IsValid() then return end
		if LocalPlayer():GetActiveWeapon():GetClass() != "acm_splint" then 
			aCM.CurrentMinigame = nil
			return
		end

		if LocalPlayer():GetWeapon("acm_splint"):Clip1() > 0 then
			aCM.RenderBoneMinigame()
		else
			aCM.CurrentMinigame = nil
		end
	elseif aCM.CurrentMinigame.type == "bleed" then
		if !LocalPlayer():GetWeapon("acm_bandage"):IsValid() then return end
		if LocalPlayer():GetActiveWeapon():GetClass() != "acm_bandage" then 
			aCM.CurrentMinigame = nil
			return
		end

		if LocalPlayer():GetWeapon("acm_bandage"):Clip1() > 0 then
			aCM.RenderBleedMinigame()
		else
			aCM.CurrentMinigame = nil
		end
	end
end

function aCM.RenderBoneMinigame()
	local minigame = aCM.CurrentMinigame

	minigame.progress = (minigame.progress+(FrameTime()*minigame.difficulty))%200
	local width = math.Remap(math.sin(minigame.progress), -1, 1, 0, 1)*200

	-- Progress bar
	draw.RoundedBox(3, ScrW()/2 - 100, ScrH()/2 - 5, 200, 10, Color(25,25,25, 150))

	draw.RoundedBoxEx(0, ScrW()/2+100-20, ScrH()/2 - 5, 20, 10, Color(0,255,0), true, false, true, false)
	draw.RoundedBoxEx(0, ScrW()/2-100, ScrH()/2 - 5, 20, 10, Color(0,255,0), false, true, false, true)

	draw.RoundedBox(3, ScrW()/2 - width/2, ScrH()/2 - 5, width, 10, Color(255,255,255))

	if LocalPlayer():KeyPressed(IN_ATTACK) then
		if width > 160 then
			-- We've beat the game!
			net.Start("aCM.FixNode")
				net.WriteEntity(aCM.Patient)
				net.WriteTable(aCM.CurrentMinigame)
			net.SendToServer()

			aCM.CurrentMinigame = nil
		else
			-- They failed, let's punish them for it
		end
	end
end

function aCM.RenderBleedMinigame()
	local minigame = aCM.CurrentMinigame

	minigame.progress = math.Clamp(minigame.progress-FrameTime()*(minigame.difficulty*50), 0, 200)
	local width = minigame.progress

	-- Progress bar
	draw.RoundedBox(3, ScrW()/2 - 100, ScrH()/2 - 5, 200, 10, Color(25,25,25, 150))

	draw.RoundedBoxEx(0, ScrW()/2+100-20, ScrH()/2 - 5, 20, 10, Color(0,255,0), true, false, true, false)
	draw.RoundedBoxEx(0, ScrW()/2-100, ScrH()/2 - 5, 20, 10, Color(0,255,0), false, true, false, true)

	draw.RoundedBox(3, ScrW()/2 - width/2, ScrH()/2 - 5, width, 10, Color(255,0,0))

	if LocalPlayer():KeyPressed(IN_ATTACK) then
		minigame.progress = minigame.progress + 20

		if minigame.progress >= 180 then
			-- We've beat the game!
			net.Start("aCM.FixNode")
				net.WriteEntity(aCM.Patient)
				net.WriteTable(aCM.CurrentMinigame)
			net.SendToServer()

			aCM.CurrentMinigame = nil
		end
	end
end

function aCM.RenderDownIcons()
	local shouldContinue = true
	local ply = LocalPlayer()

	if aCM.Config.MedicRolesEnabled == true then
		if aCM.Config.DarkRPEnabled == true then
			if !table.HasValue(aCM.Config.MedicRoles, ply:Team()) then
				shouldContinue = false
			end
		else
			local customCheck = aCM.Config.MedicRoleCustomCheck(LocalPlayer())
			if customCheck != true then shouldContinue = false end
		end
	end

	if shouldContinue != true then 
		for ply, panel in pairs(aCM.DownedPlayers) do
			if IsValid(panel) then 
				panel:Remove() 
			end
		end

		return 
	end

	for ply, panel in pairs(aCM.DownedPlayers) do
		if type(panel) != "Panel" or !IsValid(panel) then 
			pcall(function()
				panel:Remove() -- Attempt removal but don't chuck errors
			end)

			continue 
		end

		if !ply:IsValid() then
			if panel != nil and IsValid(panel) then panel:Remove() end
			aCM.DownedPlayers[ply] = nil

			continue 
		end

		if !IsValid(ply:GetNWEntity("aCM.RagdollEntity")) then 
			continue 
		end

		local loc = ply:GetNWEntity("aCM.RagdollEntity"):GetPos():ToScreen()
		local dist = ply:GetNWEntity("aCM.RagdollEntity"):GetPos():Distance(LocalPlayer():GetPos())
		dist = math.Clamp(1/dist*10000, 16, 48)

		local size = math.Clamp(dist*CurTime()%dist, 16, 48)

		panel:SetPos(loc.x - size/2, loc.y-size/2)
		panel:SetSize(size, size)
	end
end

hook.Add("HUDPaint", "aCM.HUDPaint", function()
	-- Let's draw the icon for downed players.
	aCM.RenderDownIcons()

	-- Here, we'll handle showing the overlay for broken bones/bleeds
	if aCM.Patient == nil or !IsValid(aCM.Patient) then return end
	if aCM.Patient.aCM.RagdollEntity == nil or !IsValid(aCM.Patient.aCM.RagdollEntity) then return end

    aCM.RenderBleeds(ply, ragdoll)
	aCM.RenderBones(ply, ragdoll)

	if aCM.CurrentMinigame != nil then
		aCM.RenderMinigame()
	end
end)