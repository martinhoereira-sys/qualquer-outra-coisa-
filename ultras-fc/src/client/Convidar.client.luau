--!strict
--[[
	INVITE YOUR FRIENDS. When my curva has more figures than real people, a
	small message comes up with Roblox's own invite button:

	    YOUR CURVA NEEDS VOICES — INVITE YOUR FRIENDS

	It blocks nothing, gives no prize, goes away by itself, and comes back at
	most once every few minutes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local T = Config.Text.rota
local U = Config.UI
local player = Players.LocalPlayer

local EVERY = 300 -- seconds between two messages
local STAYS = 14

local gui = Instance.new("ScreenGui")
gui.Name = "UltrasConvidar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("Frame")
toast.Name = "Convite"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 150)
toast.Size = UDim2.fromOffset(560, 46)
toast.BackgroundColor3 = U.panel
toast.BackgroundTransparency = 0.1
toast.BorderSizePixel = 0
toast.Visible = false
toast.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 10)
round.Parent = toast
local fit = Instance.new("UISizeConstraint")
fit.MaxSize = Vector2.new(560, 46)
fit.Parent = toast

local words = Instance.new("TextLabel")
words.BackgroundTransparency = 1
words.Position = UDim2.fromOffset(14, 6)
words.Size = UDim2.new(1, -150, 1, -12)
words.Font = Enum.Font.GothamBold
words.TextScaled = true
words.TextXAlignment = Enum.TextXAlignment.Left
words.TextColor3 = U.text
words.Text = T.invite
words.Parent = toast

local invite = Instance.new("TextButton")
invite.Name = "Convidar"
invite.AnchorPoint = Vector2.new(1, 0.5)
invite.Position = UDim2.new(1, -8, 0.5, 0)
invite.Size = UDim2.fromOffset(120, 32)
invite.BackgroundColor3 = U.good
invite.BorderSizePixel = 0
invite.Font = Enum.Font.GothamBlack
invite.TextSize = 15
invite.TextColor3 = U.text
invite.Text = T.inviteButton
invite.Parent = toast
local inviteRound = round:Clone()
inviteRound.Parent = invite

invite.Activated:Connect(function()
	toast.Visible = false
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)

-- More figures than real people in my curva?
local function needsVoices(): boolean
	local mine = player:GetAttribute("Team")
	if type(mine) ~= "string" or not Config.Teams[mine] then
		return false
	end
	local people = 0
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("Team") == mine then
			people += 1
		end
	end
	return Config.Bonecos.bancada > people
end

task.spawn(function()
	task.wait(45)
	while true do
		if needsVoices() then
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				toast.Visible = true
				task.wait(STAYS)
				toast.Visible = false
				task.wait(EVERY)
				continue
			end
		end
		task.wait(20)
	end
end)
