--!strict
--[[
	Os sons, pelo nome.

	Toda a gente chama `Sounds.play("golo")`, nunca um numero: os numeros vivem
	so em Config.Sounds, e trocar um som e mudar uma linha la.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local function make(name: string): Sound?
	local spec = Config.Sounds[name]
	if not spec then
		warn("[Sounds] nao ha som com o nome " .. name .. " em Config.Sounds")
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. tostring(spec.id)
	sound.Volume = spec.volume
	sound.Looped = spec.looped == true
	-- So o comeco do ficheiro (ex.: uma pancada de um som com varias).
	if spec.cut then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(0, spec.cut)
	end
	return sound
end

--[[
	Toca uma vez. Com `at`, ouve-se daquele sitio e mais baixo ao longe (o
	pontape, o tambor); sem ele, ouve-se igual em todo o lado (o apito, o golo).
	`scale` multiplica o volume do Config.
]]
function Sounds.play(name: string, at: Vector3?, scale: number?)
	local sound = make(name)
	if not sound then
		return
	end
	sound.Volume *= scale or 1

	local holder: Instance = SoundService
	if at then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 400
		holder = attachment
	end
	sound.Parent = holder

	sound.Ended:Once(function()
		if holder ~= SoundService then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end)
	sound:Play()
end

--[[
	Um som continuo (a multidao, o corteo). Devolve-o parado: quem o pede e que
	lhe mexe no volume e o liga e desliga.
]]
function Sounds.loop(name: string): Sound?
	local sound = make(name)
	if sound then
		sound.Looped = true
		sound.Parent = SoundService
	end
	return sound
end

-- O volume de base de um som, tal como esta no Config.
function Sounds.volume(name: string): number
	local spec = Config.Sounds[name]
	return spec and spec.volume or 0
end

return Sounds
