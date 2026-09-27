--!strict
--[[
	As animacoes feitas (Config.Animations), no proprio personagem.

	Cada ecra so anima o seu corpo; o Roblox mostra-o a toda a gente. Aqui
	decide-se o que se esta a fazer (tocha na mao, a saltar, a festejar, no
	corteo...) e toca-se a animacao com esse nome. Sem animacao feita para
	isso, nao se toca nada e fica a pose do jogo (Poses.client) ou a normal.

	A ordem conta: festejar ganha a tudo; o material na mao ganha ao salto;
	o capo e a marcha sao o fundo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Animacoes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animacoes"))
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StadiumPlan"))

local me = Players.LocalPlayer

-- O material na mao (atributo "Hold") e o nome da animacao.
local HOLD: { [string]: string } = {
	tocha = "tocha",
	fumo = "fumo",
	vela = "velaromana",
	mastro = "bandeira",
	bandeirinha = "bandeirinha",
}

local function myBanner(): BasePart?
	local teamId = me:GetAttribute("Team")
	local stadium = workspace:FindFirstChild("Stadium")
	local march = stadium and stadium:FindFirstChild("March")
	local banner = march and type(teamId) == "string" and march:FindFirstChild("Banner_" .. teamId)
	return if banner and banner:IsA("BasePart") then banner else nil
end

-- O que se esta a fazer agora, pela ordem de importancia.
local function wanted(character: Model, root: BasePart): string?
	if character:GetAttribute("Festejo") == true then
		return "festejo"
	end
	local hold = me:GetAttribute("Hold")
	if type(hold) == "string" and HOLD[hold] then
		return HOLD[hold]
	end
	local walking = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 2
	local banner = myBanner()
	if banner and me:GetAttribute("Leader") == true and banner:GetAttribute("Led") == true
		and (banner.Position - root.Position).Magnitude < 14 then
		return "faixa"
	end
	if me:GetAttribute("Emote") == "saltar" and not walking then
		return "salto"
	end
	local teamId = me:GetAttribute("Team")
	if me:GetAttribute("Leader") == true and not walking and type(teamId) == "string" and Config.Teams[teamId]
		and Plan.inClaque(teamId, root.Position) then
		return "capo"
	end
	if banner and walking and banner:GetAttribute("Stage") == "marcha"
		and (banner.Position - root.Position).Magnitude <= Config.March.radius then
		return "marcha"
	end
	return nil
end

local playing: AnimationTrack? = nil
local playingName: string? = nil

local function stop()
	if playing then
		playing:Stop(0.25)
	end
	playing = nil
	playingName = nil
end

local nextCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheck then
		return
	end
	nextCheck = now + 0.1
	local character = me.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not animator or not root then
		stop()
		return
	end
	local name = wanted(character, root)
	-- So conta se ha animacao feita para isto.
	if name and not Animacoes.has(name) then
		name = nil
	end
	if name == playingName then
		return
	end
	stop()
	if name then
		local track = Animacoes.track(animator, name)
		if track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.25)
			playing = track
			playingName = name
		end
	end
end)

-- O tambor: cada pancada toca a animacao "tambor" uma vez.
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchTool(tool: Instance)
	if tool:IsA("Tool") and tool:GetAttribute("Kind") == "tambor" and not watched[tool] then
		watched[tool] = true
		tool.Activated:Connect(function()
			local character = me.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local track = animator and Animacoes.track(animator, "tambor")
			if track then
				track.Looped = false
				track.Priority = Enum.AnimationPriority.Action2
				track:Play(0.05)
			end
		end)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
	character.ChildAdded:Connect(watchTool)
end
if me.Character then
	watchCharacter(me.Character)
end
me.CharacterAdded:Connect(function(character)
	stop()
	watchCharacter(character)
end)
