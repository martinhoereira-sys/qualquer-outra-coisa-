--!strict
--[[
	Today's derby: which two clubs play, and repainting the world for them.

	The game has two places (home and away) and four clubs. Each match day is
	one derby; its two clubs take the two places (Config.applyDerby). Code that
	reads Config.Teams always sees today's clubs.

	But much of the world was BUILT with the colours and names of the clubs of
	the moment: academies, buses, sede signs, stadium plates, the stand bots.
	So, once everything is built (with Derby 1), `Derby.track` remembers every
	part, label and colour that belongs to each place; when the derby changes,
	`Derby.repaint` recolours and rewrites exactly those.

	The server decides (Derby.set) and publishes it in the workspace attribute
	"Derby"; each screen follows it (Derby.follow).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Derby = {}

local SLOTS = { "home", "away" }

--[[
	What the world was built with, for each place: the colour, and the names
	that may be written on things (including the old names still saved in the
	map). Longer texts first, so "ULTRAS AGN" is found before "AGN".
]]
local BUILT = {
	home = {
		color = Color3.fromRGB(196, 58, 48),
		texts = {
			{ "ÁGUIAS DO NORTE", "upper" },
			{ "AGUIAS DO NORTE", "upper" },
			{ "Águias do Norte", "name" },
			{ "Aguias do Norte", "name" },
			{ "ULTRAS ÁGUIA", "claque" },
			{ "ULTRAS AGN", "claque" },
			{ "AGN", "short" },
		},
	},
	away = {
		color = Color3.fromRGB(0, 133, 80),
		texts = {
			{ "LEOES DO SUL", "upper" },
			{ "Leoes do Sul", "name" },
			{ "BRIGADA DO LEÃO", "claque" },
			{ "BRIGADA LES", "claque" },
			{ "LEÕES", "upper" },
			{ "Leões", "name" },
			{ "LES", "short" },
			{ "LEO", "short" },
		},
	},
}

type ColourEntry = { inst: Instance, prop: string, slot: string }
type TextEntry = { inst: Instance, template: string }

local colours: { ColourEntry } = {}
local texts: { TextEntry } = {}
local seen: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local listeners: { (number) -> () } = {}

local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
end

local function isWordChar(byte: number?): boolean
	if not byte then
		return false
	end
	-- Letters, digits and any byte of an accented letter (>= 128).
	return (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte >= 128
end

-- Replaces whole-word occurrences of `from` (plain text) by `to`.
local function swap(text: string, from: string, to: string): (string, boolean)
	local out = {}
	local i = 1
	local changed = false
	while true do
		local a, b = string.find(text, from, i, true)
		if not a or not b then
			break
		end
		if not isWordChar(string.byte(text, a - 1)) and not isWordChar(string.byte(text, b + 1)) then
			table.insert(out, string.sub(text, i, a - 1))
			table.insert(out, to)
			changed = true
		else
			table.insert(out, string.sub(text, i, b))
		end
		i = b + 1
	end
	table.insert(out, string.sub(text, i))
	return table.concat(out), changed
end

-- "{home.short}" style tokens (never shown: always filled before display).
local function token(slot: string, field: string): string
	return "\1" .. slot .. "." .. field .. "\2"
end

local function templateOf(text: string): string?
	local changed = false
	for _, slot in SLOTS do
		for _, pair in (BUILT :: any)[slot].texts do
			local did
			text, did = swap(text, pair[1], token(slot, pair[2]))
			changed = changed or did
		end
	end
	return if changed then text else nil
end

local function fill(template: string): string
	return (string.gsub(template, "\1(%a+)%.(%a+)\2", function(slot: string, field: string)
		local team = Config.Teams[slot]
		if field == "upper" then
			return team.nameUpper
		elseif field == "name" then
			return team.name
		elseif field == "claque" then
			return team.claque
		end
		return team.short
	end))
end

local function slotOfColour(c: Color3): string?
	for _, slot in SLOTS do
		if near(c, (BUILT :: any)[slot].color) then
			return slot
		end
	end
	return nil
end

local function look(inst: Instance)
	if seen[inst] then
		return
	end
	seen[inst] = true
	-- An emblem is always one club's own (whoever draws it redraws it); the admin bar names all four clubs.
	if inst.Name == "Emblema" or inst:FindFirstAncestor("Emblema") or inst:FindFirstAncestor("UltrasAdmin") then
		return
	end
	if inst:IsA("BasePart") then
		local slot = slotOfColour(inst.Color)
		if slot then
			table.insert(colours, { inst = inst, prop = "Color", slot = slot })
		end
	elseif inst:IsA("GuiObject") then
		local slot = slotOfColour(inst.BackgroundColor3)
		if slot then
			table.insert(colours, { inst = inst, prop = "BackgroundColor3", slot = slot })
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			local textSlot = slotOfColour(inst.TextColor3)
			if textSlot then
				table.insert(colours, { inst = inst, prop = "TextColor3", slot = textSlot })
			end
			local template = templateOf(inst.Text)
			if template then
				table.insert(texts, { inst = inst, template = template })
			end
		end
	elseif inst:IsA("UIStroke") then
		local slot = slotOfColour(inst.Color)
		if slot then
			table.insert(colours, { inst = inst, prop = "Color", slot = slot })
		end
	elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		local slot = slotOfColour(inst.Color)
		if slot then
			table.insert(colours, { inst = inst, prop = "Color", slot = slot })
		end
	end
end

--[[
	Remembers everything under `root` built with the clubs of Derby 1. Call it
	while Derby 1 is applied (things are recognised by its colours and names).
]]
function Derby.track(root: Instance)
	look(root)
	for _, inst in root:GetDescendants() do
		look(inst)
	end
end

-- Recolours and rewrites everything remembered, for today's clubs.
function Derby.repaint()
	for _, entry in colours do
		if entry.inst.Parent then
			(entry.inst :: any)[entry.prop] = Config.Teams[entry.slot].color
		end
	end
	for _, entry in texts do
		if entry.inst.Parent then
			(entry.inst :: any).Text = fill(entry.template)
		end
	end
end

function Derby.current(): number
	return Config.Derby
end

-- The clubs of today's derby, in place order.
function Derby.clubs(): (any, any)
	return Config.Teams.home, Config.Teams.away
end

-- Called after the derby changed (and the world was repainted).
function Derby.onChanged(fn: (number) -> ())
	table.insert(listeners, fn)
end

local function changed(n: number)
	Derby.repaint()
	for _, fn in listeners do
		task.spawn(fn, n)
	end
end

--[[
	SERVER: today's derby is `n`. Fills the two places, repaints the world and
	tells every screen.
]]
function Derby.set(n: number): boolean
	assert(RunService:IsServer(), "Derby.set is for the server")
	if not Config.Derbies[n] then
		return false
	end
	if n == Config.Derby and workspace:GetAttribute("Derby") == n then
		return true
	end
	Config.applyDerby(n)
	workspace:SetAttribute("Derby", n)
	changed(n)
	return true
end

-- Repaints and rebuilds for the current derby (e.g. right after the first
-- build, to replace old names still saved in the map).
function Derby.refresh()
	changed(Config.Derby)
end

-- SERVER: the other derby (one derby per match day).
function Derby.next(): number
	local n = Config.Derby % #Config.Derbies + 1
	Derby.set(n)
	return n
end

--[[
	CLIENT: follow the server's derby. Call once, after the interface exists
	(so its labels are remembered with Derby 1 still applied).
]]
function Derby.follow(roots: { Instance })
	for _, root in roots do
		Derby.track(root)
		root.DescendantAdded:Connect(function(inst)
			-- Built later. With Derby 1 applied it is recognised like the rest;
			-- otherwise it already has today's clubs and there is nothing to remember.
			if Config.Derby == 1 then
				look(inst)
			else
				seen[inst] = true
			end
		end)
	end
	local function sync()
		local n = workspace:GetAttribute("Derby")
		if type(n) == "number" and n ~= Config.Derby and Config.applyDerby(n) then
			changed(n)
		end
	end
	workspace:GetAttributeChangedSignal("Derby"):Connect(sync)
	sync()
end

return Derby
