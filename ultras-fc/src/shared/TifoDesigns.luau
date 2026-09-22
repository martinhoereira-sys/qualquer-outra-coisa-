--!strict
--[[
	Os desenhos dos tifos, como linhas de letras: E cor da equipa, B branco,
	P preto. Partilhado porque o servidor precisa deles para as cartolinas e o
	ecra do lider para mostrar o que vai sair.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local T = Config.Tifo

local TifoDesigns = {}

--[[
	Letras de 4x6 para as iniciais. Tres letras mais dois espacos dao as 14
	colunas da grelha certas. So estao as que as siglas usam; uma letra que
	falte fica em branco em vez de partir o tifo.
]]
local GLYPHS: { [string]: { string } } = {
	A = { ".BB.", "B..B", "B..B", "BBBB", "B..B", "B..B" },
	E = { "BBBB", "B...", "BBB.", "B...", "B...", "BBBB" },
	G = { ".BBB", "B...", "B...", "B.BB", "B..B", ".BBB" },
	L = { "B...", "B...", "B...", "B...", "B...", "BBBB" },
	N = { "B..B", "BB.B", "BBBB", "B.BB", "B..B", "B..B" },
	S = { ".BBB", "B...", ".BB.", "...B", "...B", "BBB." },
}

local function initials(short: string): { string }
	local rows = {}
	for r = 1, T.rows do
		rows[r] = string.split(string.rep("E", T.columns), "")
	end

	local top = math.floor((T.rows - 6) / 2)
	for i = 1, math.min(#short, 3) do
		local glyph = GLYPHS[string.upper(string.sub(short, i, i))]
		if glyph then
			local left = (i - 1) * 5
			for gr, line in glyph do
				for gc = 1, 4 do
					if string.sub(line, gc, gc) == "B" then
						rows[top + gr][left + gc] = "B"
					end
				end
			end
		end
	end

	local out = {}
	for r, chars in rows do
		out[r] = table.concat(chars)
	end
	return out
end

function TifoDesigns.byId(id: string): any
	for _, design in T.designs do
		if design.id == id then
			return design
		end
	end
	return nil
end

-- As linhas do desenho para esta equipa, de cima para baixo.
function TifoDesigns.rows(design: any, teamId: string): { string }
	if design.initials then
		return initials(Config.Teams[teamId].short)
	end
	return design.rows
end

-- A cor de uma letra do desenho.
function TifoDesigns.colour(code: string, teamId: string): Color3
	if code == "B" then
		return Color3.fromRGB(242, 242, 238)
	elseif code == "P" then
		return Color3.fromRGB(28, 30, 36)
	end
	return Config.Teams[teamId].color
end

return TifoDesigns
