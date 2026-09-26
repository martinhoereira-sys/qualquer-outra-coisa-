--!strict
--[[
	Os panos parados no mapa (faixas na vedacao, etc.) a mexer, neste ecra.

	O servidor deixa-os com uma forma natural (Pano.fix). Aqui cada tira
	baloica com atraso da do lado. So os que estao perto da camara: um pano
	do outro lado do mapa nao se ve mexer e so gastava o telemovel.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pano = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pano"))

-- A partir daqui os panos ficam parados.
local NEAR = 220

type Entry = { cloth: Pano.Cloth, base: CFrame, amp: number }

local entries: { [Model]: Entry } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local base = instance:GetAttribute("Base")
	local amp = instance:GetAttribute("Amp")
	if typeof(base) ~= "CFrame" or type(amp) ~= "number" then
		return
	end
	local cloth = Pano.wrap(instance)
	if cloth then
		entries[instance] = { cloth = cloth, base = base, amp = amp }
	end
end

for _, model in CollectionService:GetTagged(Pano.TAG) do
	add(model)
end
CollectionService:GetInstanceAddedSignal(Pano.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(Pano.TAG):Connect(function(instance)
	entries[instance :: Model] = nil
end)

local parts: { BasePart } = {}
local frames: { CFrame } = {}

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera or next(entries) == nil then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	table.clear(parts)
	table.clear(frames)
	for model, entry in entries do
		if not model.Parent then
			entries[model] = nil
		elseif (entry.base.Position - eye).Magnitude < NEAR then
			Pano.pose(entry.cloth, entry.base, t, entry.amp, parts, frames)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
