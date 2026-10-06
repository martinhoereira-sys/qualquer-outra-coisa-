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
	-- Quem marcou: o seu festejo (joelho, mbappe), uma vez.
	local own = me:GetAttribute("FestejoGolo")
	if type(own) == "string" then
		return own
	end
	if character:GetAttribute("Festejo") == true then
		return "festejo"
	end
	-- Golo da minha equipa: festeja toda a gente dela (quem joga por ela e a
	-- sua claque), nao so quem marcou, enquanto dura a festa do golo.
	local party = workspace:GetAttribute("Celebration")
	if type(party) == "string" then
		local mine = if me:GetAttribute("Team") == "jogador" then me:GetAttribute("PitchTeam") else me:GetAttribute("Team")
		if mine == party then
			return "festejo"
		end
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
	if me:GetAttribute("Emote") == "aplaudir" and not walking then
		return "palmas"
	end
	-- Jumping goes on while one moves, in any direction.
	if me:GetAttribute("Emote") == "saltar" then
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

--[[
	THE BEAT my claque is on now: how many beats have gone by (a number that
	keeps growing) and how many a second. Of the chant that is on, if it says
	its bpm (Config.Chants); if not, of the claque's drum (the one the stand
	jumps to).
]]
local function beatNow(): (number?, number?)
	local teamId = me:GetAttribute("Team")
	local stadium = workspace:FindFirstChild("Stadium")
	if not stadium or type(teamId) ~= "string" then
		return nil, nil
	end
	local value = stadium:GetAttribute("Musica_" .. teamId)
	if type(value) == "string" then
		local clubId, index, started = string.match(value, "^(%w+):(%d+):([%d%.]+)$")
		local song = if clubId then Config.chantsOf(clubId)[tonumber(index) :: number] else nil
		local startedAt = tonumber(started)
		if song and startedAt and type(song.bpm) == "number" and song.bpm > 0 then
			return (workspace:GetServerTimeNow() - startedAt) * song.bpm / 60, song.bpm / 60
		end
	end
	local crowd = stadium:FindFirstChild("Crowd")
	local stamp = crowd and crowd:GetAttribute("Stamp")
	local beat = crowd and crowd:GetAttribute("Beat_" .. teamId)
	local rate = crowd and crowd:GetAttribute("Rate_" .. teamId)
	if type(stamp) == "number" and type(beat) == "number" and type(rate) == "number" and rate > 0 then
		return beat + rate * (workspace:GetServerTimeNow() - stamp), rate
	end
	return nil, nil
end

-- The animations that go to the beat, and how many beats one turn of each takes.
local ON_BEAT: { [string]: string } = { salto = "beatsPerJump", palmas = "beatsPerClap" }

local ONCE: { [string]: boolean } = { joelho = true, mbappe = true }

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
		-- The jump goes to the beat of the chant that is on (one jump every
		-- Config.Chants.beatsPerJump beats); with no chant, at its own speed.
		local track = playing
		local per = if name then (Config.Chants :: any)[ON_BEAT[name] or ""] else nil
		if name and track and type(per) == "number" and track.Length > 0 then
			local beat, rate = beatNow()
			if beat and rate then
				-- One turn every `per` beats, and landing on the beat: the speed
				-- follows the tempo, and the place in the turn is put right if it drifts.
				track:AdjustSpeed(track.Length * rate / per)
				local want = (beat / per % 1) * track.Length
				local off = math.abs(track.TimePosition - want)
				if math.min(off, track.Length - off) > 0.12 then
					track.TimePosition = want
				end
			else
				track:AdjustSpeed(Animacoes.speed(name))
			end
		end
		return
	end
	stop()
	if name then
		local track = Animacoes.track(animator, name)
		if track then
			-- Os festejos de quem marcou tocam uma vez; o resto em ciclo.
			track.Looped = not ONCE[name]
			track.Priority = Enum.AnimationPriority.Action
			Animacoes.play(track, name, 0.25)
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
				Animacoes.play(track, "tambor", 0.05)
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
