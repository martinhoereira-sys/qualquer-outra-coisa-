--!strict
--[[
	O que cada um veste, conforme o papel.

	Mudar de papel muda a roupa: nao faz sentido ser arbitro com a farda da
	claque, nem ultra com o equipamento da equipa. Sempre que o papel muda
	(atributo "Team": a claque, "jogador" ou "arbitro"):

	1. tira-se o que era do papel anterior (a farda da claque, o equipamento
	   de jogo, o do arbitro);
	2. volta o avatar da propria pessoa (guardado quando entrou);
	3. veste-se o do papel novo: o jogador o equipamento da equipa (Squad), o
	   arbitro camisola amarela e calcoes pretos com ARBITRO nas costas; o ultra
	   fica com a sua roupa e o cachecol da claque (Gear).
]]

local Players = game:GetService("Players")
local Lider = require(script.Parent:WaitForChild("Lider"))
local Squad = require(script.Parent:WaitForChild("Squad"))

local Kit = {}

local SHIRT = Color3.fromRGB(245, 205, 40) -- o amarelo do arbitro
local SHORTS = Color3.fromRGB(22, 22, 26)

-- O avatar de cada um como entrou no jogo.
local original: { [Player]: HumanoidDescription } = {}
-- Para nao vestir duas vezes ao mesmo tempo (ApplyDescription demora).
local busy: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Tira a roupa (camisolas, calcas, roupa por camadas), como o equipamento de jogo.
local function strip(model: Model)
	for _, child in model:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:FindFirstChildOfClass("WrapLayer") then
				child:Destroy()
			end
		end
	end
end

local function refereeKit(player: Player)
	local character = player.Character
	if not character then
		return
	end
	strip(character)
	local colours = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	local bc = colours :: BodyColors
	bc.TorsoColor3 = SHIRT
	bc.LeftArmColor3 = SHIRT
	bc.RightArmColor3 = SHIRT
	bc.LeftLegColor3 = SHORTS
	bc.RightLegColor3 = SHORTS
	bc.Parent = character
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") and not torso:FindFirstChild("KitArbitro") then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "KitArbitro"
		gui.Face = Enum.NormalId.Back
		gui.CanvasSize = Vector2.new(200, 200)
		gui.LightInfluence = 0.6
		gui.Parent = torso
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, 0.22)
		t.Position = UDim2.fromScale(0.05, 0.1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = SHORTS
		t.Text = "ÁRBITRO"
		t.Parent = gui
	end
end

-- Tira o que e de outros papeis (sem mexer no avatar).
local function clear(player: Player)
	Lider.undress(player)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d.Name == "KitArbitro" or d.Name == "NomeCostas" or d.Name == "NumberFront" or d.Name == "NumberBack" or d.Name == "Bracadeira" then
			d:Destroy()
		end
	end
end

-- Veste quem mudou de papel.
function Kit.apply(player: Player)
	local stamp = os.clock()
	busy[player] = stamp
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	clear(player)
	local description = original[player]
	if description then
		pcall(function()
			humanoid:ApplyDescription(description)
		end)
	end
	-- Mudou outra vez enquanto se vestia: o mais recente e que conta.
	if busy[player] ~= stamp then
		return
	end
	local role = player:GetAttribute("Team")
	if role == "arbitro" then
		refereeKit(player)
	elseif role == "jogador" then
		local f = Squad.byPlayer(player)
		if f then
			Squad.redress(f)
		end
	end
end

function Kit.start()
	local function watch(player: Player)
		-- O avatar da pessoa, tal como entrou (antes de qualquer equipamento).
		player.CharacterAppearanceLoaded:Connect(function(character)
			if original[player] then
				-- Renasceu: o papel volta a vestir-se (o jogador ja o faz o Squad).
				if player:GetAttribute("Team") == "arbitro" then
					task.wait(0.3)
					refereeKit(player)
				end
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local ok, description = pcall(function()
					return humanoid:GetAppliedDescription()
				end)
				if ok and description then
					original[player] = description
				end
			end
		end)
		local last = player:GetAttribute("Team")
		player:GetAttributeChangedSignal("Team"):Connect(function()
			local now = player:GetAttribute("Team")
			if now ~= last then
				last = now
				task.spawn(Kit.apply, player)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		original[player] = nil
		busy[player] = nil
	end)
end

return Kit
