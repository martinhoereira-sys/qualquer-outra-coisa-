--!strict
--[[
	A tela do tifo a ondular, neste ecra.

	O servidor estende a tela parada (tiras chamadas "Tela", em
	Workspace.Stadium); aqui cada tira mexe-se um pouco para a frente e para
	tras e dobra-se, com um atraso de tira para tira, para a onda correr a
	tela de lado a lado como papel ao vento. So aspecto: nao se envia nada.
]]

local RunService = game:GetService("RunService")

type Wave = { part: BasePart, base: CFrame, phase: number }

local waves: { [BasePart]: Wave } = {}

local function watch(d: Instance)
	if d:IsA("BasePart") and d.Name == "Tela" and not waves[d] then
		local strip = d:GetAttribute("Strip")
		waves[d] = {
			part = d,
			base = d.CFrame,
			phase = (if type(strip) == "number" then strip else 0) * 0.55,
		}
		d.AncestryChanged:Connect(function()
			if not d:IsDescendantOf(workspace) then
				waves[d] = nil
			end
		end)
	end
end

local stadium = workspace:WaitForChild("Stadium")
for _, d in stadium:GetDescendants() do
	watch(d)
end
stadium.DescendantAdded:Connect(watch)

RunService.RenderStepped:Connect(function()
	if next(waves) == nil then
		return
	end
	local t = os.clock()
	for _, w in waves do
		local p = w.phase
		-- Para a frente e para tras (ao longo da normal), um pouco para cima,
		-- e a dobrar-se de cima para baixo.
		local push = math.sin(t * 2.1 + p) * 0.45 + math.sin(t * 3.7 + p * 1.7) * 0.15
		local lift = math.sin(t * 1.6 + p * 0.8) * 0.2
		local bend = math.sin(t * 2.4 + p) * 0.07
		w.part.CFrame = w.base * CFrame.new(0, lift, -push) * CFrame.Angles(bend, 0, 0)
	end
end)
