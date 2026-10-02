--!strict
--[[
	Numeros de afinacao do jogo.

	Mexe AQUI primeiro. Quase tudo o que "sente mal" a jogar — a barra sobe
	depressa demais, os golos sao poucos, o compasso e apertado — resolve-se
	nestes valores, sem tocar na logica.
]]

local Config = {}

--[[
	THE CLUBS. Four clubs, two derbies. Everything about a club lives here:
	change a colour, a name or a motto in one line.

	Names, mottos and claque names stay in the club's own language (Portuguese),
	while the game interface is in English.

	`color` is the club's identity colour: scoreboard, bars, smoke, flags.
	`kits` describes what the players wear, built from parts (no textures):
	  pattern  "plain" | "hoops" (horizontal) | "stripes" (vertical) | "sash" (one diagonal band) | "halves" (two vertical halves)
	  shirt    the base colour of the shirt
	  second   the colour of the hoops / stripes / sash
	  trim     collar and cuffs (optional)
	  shorts, socks, sockTop (optional)
	  thin     thin hoops (optional)
	Every club has two kits: `home` (the main one) and `away` (the alternate).
	Which one is worn is decided by itself before each match (Config.pickKits).

	`emblem` is drawn from shapes and text (shared/Emblem):
	  colours  the colours used, by a short key
	  shapes   the drawing: { centreX, centreY, width, height, rotation, round, colour key }
]]
local WHITE = Color3.fromRGB(245, 245, 245)
local BLACK = Color3.fromRGB(24, 24, 28)
local NAVY = Color3.fromRGB(20, 34, 84)

Config.Clubs = {
	luz = {
		club = "luz",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = -697, z = 529, existing = true, block = "1_8" }, -- the sede made by hand, where it is
		name = "Luz SC",
		fullName = "Sport Clube da Luz",
		nameUpper = "LUZ SC",
		short = "LUZ",
		founded = 1904,
		foundedOn = "28 February 1904",
		bairro = "Luz",
		city = "Lisboa",
		country = "pt",
		motto = "SEMPRE MAIS ALTO",
		claque = "SEM NOME",
		faixas = { "TOPO SUL", "SEM NOME", "SEMPRE MAIS ALTO" }, -- on the fence, left to right
		color = Color3.fromRGB(196, 58, 48),
		second = WHITE,
		mask = Color3.fromRGB(196, 58, 48), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: plain red, white collar; white shorts, red socks.
			home = { pattern = "plain", shirt = Color3.fromRGB(196, 58, 48), second = WHITE, trim = WHITE, shorts = WHITE, socks = Color3.fromRGB(196, 58, 48) },
			-- Alternate: plain black, red collar; black shorts, black socks.
			away = { pattern = "plain", shirt = BLACK, second = Color3.fromRGB(196, 58, 48), trim = Color3.fromRGB(196, 58, 48), shorts = BLACK, socks = BLACK, sockTop = Color3.fromRGB(196, 58, 48) },
		},
		-- The emblem: an eagle perched on top of a shield (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(196, 58, 48), w = WHITE, y = Color3.fromRGB(245, 205, 40), k = BLACK },
			shapes = {
				{ 0.5, 0.545, 0.6, 0.31, 0, 0, "m" },
				{ 0.5, 0.68, 0.6, 0.6, 0, 0.5, "m" },
				{ 0.5, 0.56, 0.6, 0.08, 0, 0, "w" },
				{ 0.332, 0.259, 0.26, 0.085, -22, 0.471, "y" },
				{ 0.378, 0.345, 0.21, 0.075, -34, 0.467, "y" },
				{ 0.668, 0.259, 0.26, 0.085, 22, 0.471, "y" },
				{ 0.622, 0.345, 0.21, 0.075, 34, 0.467, "y" },
				{ 0.5, 0.275, 0.16, 0.27, 0, 0.5, "y" },
				{ 0.5, 0.11, 0.13, 0.13, 0, 0.5, "y" },
				{ 0.57, 0.119, 0.055, 0.055, 45, 0, "w" },
				{ 0.52, 0.095, 0.025, 0.025, 0, 0.5, "k" },
				{ 0.46, 0.415, 0.04, 0.05, 0, 0.25, "y" },
				{ 0.54, 0.415, 0.04, 0.05, 0, 0.25, "y" },
			},
		},
	},
	alvalade = {
		club = "alvalade",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = 701, z = -590, existing = true, block = "9_2" }, -- the sede made by hand, where it is
		name = "Alvalade SC",
		fullName = "Sporting Clube de Alvalade",
		nameUpper = "ALVALADE SC",
		short = "ALV",
		founded = 1906,
		foundedOn = "1 July 1906",
		bairro = "Alvalade",
		city = "Lisboa",
		country = "pt",
		motto = "RUGIR ATÉ AO FIM",
		claque = "JUVENTUDE",
		faixas = { "CURVA SUL", "JUVENTUDE", "RUGIR ATÉ AO FIM" }, -- on the fence, left to right
		color = Color3.fromRGB(0, 133, 80),
		second = WHITE,
		accent = Color3.fromRGB(245, 205, 40), -- the second colour of the details
		hoops = true, -- the big flag has horizontal hoops
		mask = Color3.fromRGB(0, 133, 80), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: green and white hoops; black shorts, green socks.
			home = { pattern = "hoops", shirt = Color3.fromRGB(0, 133, 80), second = WHITE, trim = Color3.fromRGB(0, 133, 80), shorts = BLACK, socks = Color3.fromRGB(0, 133, 80), sockTop = WHITE },
			-- Alternate: navy with thin green hoops; navy shorts, navy socks.
			away = { pattern = "hoops", thin = true, shirt = Color3.fromRGB(22, 40, 90), second = Color3.fromRGB(0, 133, 80), trim = Color3.fromRGB(0, 133, 80), shorts = Color3.fromRGB(22, 40, 90), socks = Color3.fromRGB(22, 40, 90), sockTop = Color3.fromRGB(0, 133, 80) },
		},
		-- The emblem: a lion standing on its hind legs, on a disc with a yellow ring (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(0, 133, 80), w = WHITE, y = Color3.fromRGB(245, 205, 40) },
			shapes = {
				{ 0.5, 0.5, 0.94, 0.94, 0, 0.5, "y" },
				{ 0.5, 0.5, 0.85, 0.85, 0, 0.5, "m" },
				{ 0.349, 0.533, 0.046, 0.198, -35, 0.5, "w" },
				{ 0.302, 0.401, 0.046, 0.106, 30, 0.5, "w" },
				{ 0.337, 0.335, 0.091, 0.091, 0, 0.5, "y" },
				{ 0.352, 0.683, 0.068, 0.182, 30, 0.5, "w" },
				{ 0.306, 0.768, 0.106, 0.046, 0, 0.5, "w" },
				{ 0.474, 0.691, 0.068, 0.182, -10, 0.5, "w" },
				{ 0.511, 0.776, 0.106, 0.046, 0, 0.5, "w" },
				{ 0.479, 0.513, 0.167, 0.327, 25, 0.5, "w" },
				{ 0.64, 0.385, 0.175, 0.057, -30, 0.467, "w" },
				{ 0.638, 0.506, 0.167, 0.057, 10, 0.467, "w" },
				{ 0.557, 0.343, 0.228, 0.228, 0, 0, "y" },
				{ 0.557, 0.343, 0.228, 0.228, 45, 0, "y" },
				{ 0.587, 0.328, 0.114, 0.114, 0, 0.5, "w" },
				{ 0.648, 0.343, 0.061, 0.046, 0, 0.417, "w" },
				{ 0.549, 0.274, 0.038, 0.038, 0, 0.5, "w" },
			},
		},
	},
	nervion = {
		club = "nervion",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = -555, z = -525, block = "2_2" },
		name = "Nervión CF",
		fullName = "Nervión Club de Fútbol",
		nameUpper = "NERVIÓN CF",
		short = "NER",
		founded = 1890,
		foundedOn = "25 January 1890",
		bairro = "Nervión",
		city = "Sevilla",
		country = "es",
		motto = "NERVIÓN ES NUESTRO",
		claque = "FONDO NORTE",
		faixas = { "FONDO NORTE", "FONDO NORTE", "NERVIÓN ES NUESTRO" }, -- on the fence, left to right
		color = Color3.fromRGB(206, 32, 46),
		second = WHITE,
		accent = WHITE, -- the second colour of the details
		mask = WHITE, -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: white with a red diagonal sash; white shorts, white socks.
			home = { pattern = "sash", shirt = WHITE, second = Color3.fromRGB(206, 32, 46), trim = Color3.fromRGB(206, 32, 46), shorts = WHITE, socks = WHITE, sockTop = Color3.fromRGB(206, 32, 46) },
			-- Alternate: black with a red diagonal sash; black shorts, black socks.
			away = { pattern = "sash", shirt = BLACK, second = Color3.fromRGB(206, 32, 46), trim = Color3.fromRGB(206, 32, 46), shorts = BLACK, socks = BLACK, sockTop = Color3.fromRGB(206, 32, 46) },
		},
		-- The emblem: a ball with three figures round it, on a tall block (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = WHITE, r = Color3.fromRGB(206, 32, 46) },
			shapes = {
				{ 0.5, 0.5, 0.67, 0.93, 0, 0.187, "r" },
				{ 0.5, 0.5, 0.61, 0.87, 0, 0.156, "m" },
				{ 0.5, 0.53, 0.27, 0.27, 0, 0.5, "r" },
				{ 0.5, 0.53, 0.11, 0.11, 0, 0.5, "m" },
				{ 0.5, 0.19, 0.1, 0.1, 0, 0.5, "r" },
				{ 0.5, 0.31, 0.09, 0.13, 0, 0.444, "r" },
				{ 0.27, 0.61, 0.1, 0.1, 0, 0.5, "r" },
				{ 0.27, 0.73, 0.09, 0.13, 0, 0.444, "r" },
				{ 0.73, 0.61, 0.1, 0.1, 0, 0.5, "r" },
				{ 0.73, 0.73, 0.09, 0.13, 0, 0.444, "r" },
			},
		},
	},
	triana = {
		club = "triana",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = 562, z = 374, block = "8_7" },
		name = "Triana Balompié",
		fullName = "Triana Balompié",
		nameUpper = "TRIANA BALOMPIÉ",
		short = "TRI",
		founded = 1907,
		foundedOn = "12 September 1907",
		bairro = "Triana",
		city = "Sevilla",
		country = "es",
		motto = "TRIANA NO SE RINDE",
		claque = "GOL SUR",
		faixas = { "GOL SUR", "GOL SUR", "TRIANA NO SE RINDE" }, -- on the fence, left to right
		color = Color3.fromRGB(26, 150, 62),
		second = WHITE,
		mask = Color3.fromRGB(26, 150, 62), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: green and white vertical stripes; white shorts, green socks.
			home = { pattern = "stripes", shirt = Color3.fromRGB(26, 150, 62), second = WHITE, trim = Color3.fromRGB(26, 150, 62), shorts = WHITE, socks = Color3.fromRGB(26, 150, 62) },
			-- Alternate: plain dark blue, green details; dark blue shorts and socks.
			away = { pattern = "plain", shirt = Color3.fromRGB(20, 34, 84), second = Color3.fromRGB(26, 150, 62), trim = Color3.fromRGB(26, 150, 62), shorts = Color3.fromRGB(20, 34, 84), socks = Color3.fromRGB(20, 34, 84), sockTop = Color3.fromRGB(26, 150, 62) },
		},
		-- The emblem: the bridge of Triana, on a diamond (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(26, 150, 62), w = WHITE, k = BLACK },
			shapes = {
				{ 0.5, 0.5, 0.7, 0.7, 45, 0.05, "k" },
				{ 0.5, 0.5, 0.66, 0.66, 45, 0.045, "m" },
				{ 0.36, 0.58, 0.23, 0.23, 0, 0.5, "w" },
				{ 0.36, 0.58, 0.15, 0.15, 0, 0.5, "m" },
				{ 0.64, 0.58, 0.23, 0.23, 0, 0.5, "w" },
				{ 0.64, 0.58, 0.15, 0.15, 0, 0.5, "m" },
				{ 0.36, 0.645, 0.23, 0.11, 0, 0, "m" },
				{ 0.64, 0.645, 0.23, 0.11, 0, 0, "m" },
				{ 0.5, 0.43, 0.62, 0.06, 0, 0, "w" },
				{ 0.242, 0.53, 0.045, 0.14, 0, 0, "w" },
				{ 0.5, 0.53, 0.05, 0.14, 0, 0, "w" },
				{ 0.757, 0.53, 0.045, 0.14, 0, 0, "w" },
				{ 0.5, 0.34, 0.09, 0.09, 0, 0.5, "w" },
				{ 0.5, 0.34, 0.05, 0.05, 0, 0.5, "m" },
				{ 0.38, 0.35, 0.07, 0.07, 0, 0.5, "w" },
				{ 0.38, 0.35, 0.03, 0.03, 0, 0.5, "m" },
				{ 0.62, 0.35, 0.07, 0.07, 0, 0.5, "w" },
				{ 0.62, 0.35, 0.03, 0.03, 0, 0.5, "m" },
				{ 0.5, 0.645, 0.44, 0.03, 0, 0.5, "w" },
				{ 0.5, 0.715, 0.28, 0.03, 0, 0.5, "w" },
			},
		},
	},
	testaccio = {
		club = "testaccio",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = -712, z = -234, block = "1_4" },
		name = "Testaccio",
		fullName = "Testaccio Calcio",
		nameUpper = "TESTACCIO",
		short = "TES",
		founded = 1927,
		foundedOn = "7 June 1927",
		bairro = "Testaccio",
		city = "Roma",
		country = "it",
		motto = "QUI NON SI MOLLA MAI",
		claque = "CURVA SUD",
		faixas = { "CURVA SUD", "CURVA SUD", "QUI NON SI MOLLA MAI" }, -- on the fence, left to right
		color = Color3.fromRGB(134, 30, 48),
		second = Color3.fromRGB(240, 172, 40),
		accent = Color3.fromRGB(240, 172, 40), -- the second colour of the details
		mask = Color3.fromRGB(134, 30, 48), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: bordeaux with gold sleeves; bordeaux shorts and socks.
			home = { pattern = "plain", shirt = Color3.fromRGB(134, 30, 48), second = Color3.fromRGB(240, 172, 40), sleeves = Color3.fromRGB(240, 172, 40), trim = Color3.fromRGB(240, 172, 40), shorts = Color3.fromRGB(134, 30, 48), socks = Color3.fromRGB(134, 30, 48), sockTop = Color3.fromRGB(240, 172, 40) },
			-- Alternate: plain dark grey, gold details; dark grey shorts and socks.
			away = { pattern = "plain", shirt = Color3.fromRGB(62, 64, 70), second = Color3.fromRGB(240, 172, 40), trim = Color3.fromRGB(240, 172, 40), shorts = Color3.fromRGB(62, 64, 70), socks = Color3.fromRGB(62, 64, 70), sockTop = Color3.fromRGB(240, 172, 40) },
		},
		-- The emblem: a she-wolf with two children, on a shield (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(134, 30, 48), y = Color3.fromRGB(240, 172, 40) },
			shapes = {
				{ 0.5, 0.33, 0.7, 0.5, 0, 0, "m" },
				{ 0.5, 0.58, 0.7, 0.7, 0, 0.5, "m" },
				{ 0.782, 0.408, 0.18, 0.05, 28, 0.5, "y" },
				{ 0.315, 0.56, 0.05, 0.18, 0, 0.4, "y" },
				{ 0.405, 0.545, 0.05, 0.15, 0, 0.4, "y" },
				{ 0.625, 0.545, 0.05, 0.15, 0, 0.4, "y" },
				{ 0.715, 0.56, 0.05, 0.18, 0, 0.4, "y" },
				{ 0.5, 0.42, 0.5, 0.16, 0, 0.469, "y" },
				{ 0.29, 0.31, 0.17, 0.17, 0, 0.5, "y" },
				{ 0.22, 0.328, 0.16, 0.075, 0, 0.4, "y" },
				{ 0.289, 0.22, 0.075, 0.075, 45, 0, "y" },
				{ 0.25, 0.29, 0.03, 0.03, 0, 0.5, "m" },
				{ 0.45, 0.66, 0.09, 0.09, 0, 0.5, "y" },
				{ 0.45, 0.755, 0.07, 0.1, 0, 0.429, "y" },
				{ 0.57, 0.66, 0.09, 0.09, 0, 0.5, "y" },
				{ 0.57, 0.755, 0.07, 0.1, 0, 0.429, "y" },
			},
		},
	},
	flaminio = {
		club = "flaminio",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = 706, z = -25, block = "9_5" },
		name = "Flaminio",
		fullName = "Flaminio Calcio",
		nameUpper = "FLAMINIO",
		short = "FLA",
		founded = 1900,
		foundedOn = "9 January 1900",
		bairro = "Flaminio",
		city = "Roma",
		country = "it",
		motto = "UN'AQUILA SOPRA TUTTI",
		claque = "CURVA NORD",
		faixas = { "CURVA NORD", "CURVA NORD", "UN'AQUILA SOPRA TUTTI" }, -- on the fence, left to right
		color = Color3.fromRGB(130, 195, 235),
		second = WHITE,
		mask = Color3.fromRGB(130, 195, 235), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: plain light blue, white collar; white shorts, white socks.
			home = { pattern = "plain", shirt = Color3.fromRGB(130, 195, 235), second = WHITE, trim = WHITE, shorts = WHITE, socks = WHITE, sockTop = Color3.fromRGB(130, 195, 235) },
			-- Alternate: plain navy, light blue details; navy shorts and socks.
			away = { pattern = "plain", shirt = Color3.fromRGB(22, 40, 90), second = Color3.fromRGB(130, 195, 235), trim = Color3.fromRGB(130, 195, 235), shorts = Color3.fromRGB(22, 40, 90), socks = Color3.fromRGB(22, 40, 90), sockTop = Color3.fromRGB(130, 195, 235) },
		},
		-- The emblem: an eagle with open wings, on a shield (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(130, 195, 235), n = Color3.fromRGB(20, 34, 84), y = Color3.fromRGB(240, 172, 40), w = WHITE },
			shapes = {
				{ 0.5, 0.33, 0.7, 0.5, 0, 0, "m" },
				{ 0.5, 0.58, 0.7, 0.7, 0, 0.5, "m" },
				{ 0.323, 0.393, 0.41, 0.11, 25, 0.5, "n" },
				{ 0.677, 0.393, 0.41, 0.11, -25, 0.5, "n" },
				{ 0.352, 0.534, 0.32, 0.09, 10, 0.5, "n" },
				{ 0.648, 0.534, 0.32, 0.09, -10, 0.5, "n" },
				{ 0.396, 0.655, 0.23, 0.08, -8, 0.5, "n" },
				{ 0.604, 0.655, 0.23, 0.08, 8, 0.5, "n" },
				{ 0.5, 0.555, 0.14, 0.39, 0, 0.5, "n" },
				{ 0.5, 0.79, 0.13, 0.13, 45, 0, "n" },
				{ 0.5, 0.33, 0.15, 0.15, 0, 0.5, "n" },
				{ 0.58, 0.34, 0.06, 0.06, 45, 0, "y" },
				{ 0.52, 0.315, 0.025, 0.025, 0, 0.5, "w" },
			},
		},
	},
	athinaikos = {
		club = "athinaikos",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = -264, z = -525, block = "4_2" },
		name = "Athinaikos",
		fullName = "Athinaikos",
		nameUpper = "ATHINAIKOS",
		short = "ATH",
		founded = 1908,
		foundedOn = "3 February 1908",
		bairro = "Ampelokipi",
		city = "Athina",
		country = "gr",
		motto = "PANTA PROTOI",
		claque = "PORTA 13",
		faixas = { "PORTA 13", "PORTA 13", "PANTA PROTOI" }, -- on the fence, left to right
		color = Color3.fromRGB(0, 120, 62),
		second = WHITE,
		mask = Color3.fromRGB(0, 120, 62), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: plain green with white; white shorts, green socks.
			home = { pattern = "plain", shirt = Color3.fromRGB(0, 120, 62), second = WHITE, trim = WHITE, shorts = WHITE, socks = Color3.fromRGB(0, 120, 62), sockTop = WHITE },
			-- Alternate: plain white, green details; green shorts, white socks.
			away = { pattern = "plain", shirt = WHITE, second = Color3.fromRGB(0, 120, 62), trim = Color3.fromRGB(0, 120, 62), shorts = Color3.fromRGB(0, 120, 62), socks = WHITE, sockTop = Color3.fromRGB(0, 120, 62) },
		},
		-- The emblem: a clover of three leaves, on a disc (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(0, 120, 62), w = WHITE },
			shapes = {
				{ 0.5, 0.5, 0.94, 0.94, 0, 0.5, "m" },
				{ 0.5, 0.5, 0.85, 0.85, 0, 0.5, "w" },
				{ 0.473, 0.687, 0.05, 0.3, 12, 0.4, "m" },
				{ 0.5, 0.33, 0.27, 0.27, 0, 0.5, "m" },
				{ 0.35, 0.55, 0.27, 0.27, 0, 0.5, "m" },
				{ 0.65, 0.55, 0.27, 0.27, 0, 0.5, "m" },
				{ 0.5, 0.48, 0.16, 0.16, 0, 0.5, "m" },
			},
		},
	},
	pireus = {
		club = "pireus",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = 413, z = 656, block = "7_9" },
		name = "Pireus FC",
		fullName = "Pireus FC",
		nameUpper = "PIREUS FC",
		short = "PIR",
		founded = 1925,
		foundedOn = "10 March 1925",
		bairro = "Pireu",
		city = "Athina",
		country = "gr",
		motto = "O THRYLOS ZEI",
		claque = "PORTA 7",
		faixas = { "PORTA 7", "PORTA 7", "O THRYLOS ZEI" }, -- on the fence, left to right
		color = Color3.fromRGB(214, 30, 40),
		second = WHITE,
		mask = Color3.fromRGB(214, 30, 40), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: red and white vertical stripes; red shorts, red socks.
			home = { pattern = "stripes", shirt = Color3.fromRGB(214, 30, 40), second = WHITE, trim = Color3.fromRGB(214, 30, 40), shorts = Color3.fromRGB(214, 30, 40), socks = Color3.fromRGB(214, 30, 40), sockTop = WHITE },
			-- Alternate: plain black, red details; black shorts and socks.
			away = { pattern = "plain", shirt = BLACK, second = Color3.fromRGB(214, 30, 40), trim = Color3.fromRGB(214, 30, 40), shorts = BLACK, socks = BLACK, sockTop = Color3.fromRGB(214, 30, 40) },
		},
		-- The emblem: a young man crowned with laurel, in profile, on a disc (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(214, 30, 40), w = WHITE, y = Color3.fromRGB(240, 172, 40) },
			shapes = {
				{ 0.5, 0.5, 0.94, 0.94, 0, 0.5, "w" },
				{ 0.5, 0.5, 0.86, 0.86, 0, 0.5, "m" },
				{ 0.47, 0.705, 0.18, 0.25, -8, 0.167, "w" },
				{ 0.49, 0.46, 0.36, 0.36, 0, 0.5, "w" },
				{ 0.675, 0.472, 0.09, 0.065, 0, 0.385, "w" },
				{ 0.615, 0.603, 0.13, 0.085, 0, 0.412, "w" },
				{ 0.31, 0.46, 0.15, 0.06, -90, 0.5, "y" },
				{ 0.34, 0.355, 0.15, 0.06, -55, 0.5, "y" },
				{ 0.43, 0.29, 0.15, 0.06, -20, 0.5, "y" },
				{ 0.535, 0.285, 0.15, 0.06, 15, 0.5, "y" },
				{ 0.63, 0.345, 0.15, 0.06, 50, 0.5, "y" },
				{ 0.58, 0.44, 0.04, 0.04, 0, 0.5, "m" },
			},
		},
	},
	galata = {
		club = "galata",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = -264, z = -234, block = "4_4" },
		name = "Galata SK",
		fullName = "Galata SK",
		nameUpper = "GALATA SK",
		short = "GAL",
		founded = 1905,
		foundedOn = "20 October 1905",
		bairro = "Galata",
		city = "Istanbul",
		country = "tr",
		motto = "ASLANLAR ÖLMEZ",
		claque = "ASLAN",
		faixas = { "ASLAN", "ASLAN", "ASLANLAR ÖLMEZ" }, -- on the fence, left to right
		color = Color3.fromRGB(190, 30, 44),
		second = Color3.fromRGB(250, 190, 30),
		accent = Color3.fromRGB(250, 190, 30), -- the second colour of the details
		mask = Color3.fromRGB(190, 30, 44), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: red and yellow vertical halves; red shorts, red socks.
			home = { pattern = "halves", shirt = Color3.fromRGB(190, 30, 44), second = Color3.fromRGB(250, 190, 30), trim = Color3.fromRGB(190, 30, 44), shorts = Color3.fromRGB(190, 30, 44), socks = Color3.fromRGB(190, 30, 44), sockTop = Color3.fromRGB(250, 190, 30) },
			-- Alternate: plain white, red and yellow collar; white shorts and socks.
			away = { pattern = "plain", shirt = WHITE, second = Color3.fromRGB(190, 30, 44), trim = Color3.fromRGB(190, 30, 44), shorts = WHITE, socks = WHITE, sockTop = Color3.fromRGB(250, 190, 30) },
		},
		-- The emblem: the head of a roaring lion, from the front, on a disc (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(190, 30, 44), y = Color3.fromRGB(250, 190, 30), w = WHITE, k = BLACK },
			shapes = {
				{ 0.5, 0.5, 0.94, 0.94, 0, 0.5, "y" },
				{ 0.5, 0.5, 0.85, 0.85, 0, 0.5, "m" },
				{ 0.5, 0.5, 0.56, 0.56, 0, 0, "y" },
				{ 0.5, 0.5, 0.56, 0.56, 45, 0, "y" },
				{ 0.34, 0.32, 0.11, 0.11, 0, 0.5, "w" },
				{ 0.66, 0.32, 0.11, 0.11, 0, 0.5, "w" },
				{ 0.5, 0.5, 0.4, 0.4, 0, 0.5, "w" },
				{ 0.425, 0.45, 0.055, 0.055, 0, 0.5, "k" },
				{ 0.575, 0.45, 0.055, 0.055, 0, 0.5, "k" },
				{ 0.5, 0.527, 0.09, 0.055, 0, 0.364, "k" },
				{ 0.5, 0.63, 0.21, 0.12, 0, 0.417, "k" },
				{ 0.438, 0.593, 0.035, 0.045, 0, 0.286, "w" },
				{ 0.562, 0.593, 0.035, 0.045, 0, 0.286, "w" },
			},
		},
	},
	kadikoy = {
		club = "kadikoy",
		-- Where the club's ground is in the city (its sede and training pitch: server/SedeBuilder).
		site = { x = 562, z = -682, block = "8_1" },
		name = "Kadiköy SK",
		fullName = "Kadiköy SK",
		nameUpper = "KADIKÖY SK",
		short = "KAD",
		founded = 1907,
		foundedOn = "3 May 1907",
		bairro = "Kadiköy",
		city = "Istanbul",
		country = "tr",
		motto = "DENIZIN ÖTESI BIZIM",
		claque = "GENÇ TRIBÜN",
		faixas = { "GENÇ TRIBÜN", "GENÇ TRIBÜN", "DENIZIN ÖTESI BIZIM" }, -- on the fence, left to right
		color = Color3.fromRGB(22, 40, 90),
		second = Color3.fromRGB(250, 214, 50),
		accent = Color3.fromRGB(250, 214, 50), -- the second colour of the details
		mask = Color3.fromRGB(250, 214, 50), -- the ultras' face mask
		keeperColor = Color3.fromRGB(240, 200, 40), -- replaced before each match (Config.pickKeepers)
		kits = {
			-- Main: navy and yellow vertical stripes; white shorts, navy socks.
			home = { pattern = "stripes", shirt = Color3.fromRGB(22, 40, 90), second = Color3.fromRGB(250, 214, 50), trim = Color3.fromRGB(22, 40, 90), shorts = WHITE, socks = Color3.fromRGB(22, 40, 90), sockTop = Color3.fromRGB(250, 214, 50) },
			-- Alternate: plain yellow, navy details; navy shorts, yellow socks.
			away = { pattern = "plain", shirt = Color3.fromRGB(250, 214, 50), second = Color3.fromRGB(22, 40, 90), trim = Color3.fromRGB(22, 40, 90), shorts = Color3.fromRGB(22, 40, 90), socks = Color3.fromRGB(250, 214, 50), sockTop = Color3.fromRGB(22, 40, 90) },
		},
		-- The emblem: a lighthouse with an anchor, on a disc (see shared/Emblem for how the shapes are written).
		emblem = {
			colours = { m = Color3.fromRGB(22, 40, 90), y = Color3.fromRGB(250, 214, 50), w = WHITE },
			shapes = {
				{ 0.5, 0.5, 0.94, 0.94, 0, 0.5, "y" },
				{ 0.5, 0.5, 0.85, 0.85, 0, 0.5, "m" },
				{ 0.547, 0.251, 0.22, 0.035, -14, 0.429, "y" },
				{ 0.37, 0.755, 0.22, 0.05, 0, 0.2, "w" },
				{ 0.37, 0.55, 0.14, 0.38, 0, 0.071, "w" },
				{ 0.37, 0.49, 0.14, 0.06, 0, 0, "y" },
				{ 0.37, 0.62, 0.14, 0.06, 0, 0, "y" },
				{ 0.37, 0.31, 0.12, 0.1, 0, 0.1, "y" },
				{ 0.384, 0.226, 0.1, 0.1, 45, 0, "w" },
				{ 0.69, 0.39, 0.1, 0.1, 0, 0.5, "w" },
				{ 0.69, 0.39, 0.045, 0.045, 0, 0.5, "m" },
				{ 0.69, 0.58, 0.03, 0.3, 0, 0.333, "w" },
				{ 0.69, 0.495, 0.16, 0.03, 0, 0.5, "w" },
				{ 0.669, 0.654, 0.15, 0.035, 35, 0.429, "w" },
				{ 0.711, 0.654, 0.15, 0.035, -35, 0.429, "w" },
			},
		},
	},
}

-- Display order (menus, lists). Everything that lists the clubs counts this table.
-- Two by two they are the derbies of the five cities: the first round of the calendar.
Config.ClubOrder = { "luz", "alvalade", "nervion", "triana", "testaccio", "flaminio", "athinaikos", "pireus", "galata", "kadikoy" }

--[[
	THE COUNTRIES. Each club has one (`country`). The flag is drawn small beside
	the club's name, from shapes like the emblems (Emblem.flag), in a box three
	wide and two tall.
]]
Config.Countries = {
	pt = {
		name = "Portugal",
		colours = { r = Color3.fromRGB(218, 41, 28), g = Color3.fromRGB(0, 102, 0), y = Color3.fromRGB(255, 220, 0) },
		shapes = {
			{ 0.5, 0.5, 1, 1, 0, 0, "r" },
			{ 0.2, 0.5, 0.4, 1, 0, 0, "g" },
			{ 0.4, 0.5, 0.227, 0.34, 0, 0.5, "y" },
			{ 0.4, 0.5, 0.133, 0.2, 0, 0.5, "r" },
		},
	},
	es = {
		name = "España",
		colours = { r = Color3.fromRGB(198, 11, 30), y = Color3.fromRGB(255, 196, 0) },
		shapes = {
			{ 0.5, 0.5, 1, 1, 0, 0, "r" },
			{ 0.5, 0.5, 1, 0.5, 0, 0, "y" },
		},
	},
	it = {
		name = "Italia",
		colours = { g = Color3.fromRGB(0, 146, 70), w = WHITE, r = Color3.fromRGB(206, 43, 55) },
		shapes = {
			{ 0.5, 0.5, 1, 1, 0, 0, "w" },
			{ 0.167, 0.5, 0.333, 1, 0, 0, "g" },
			{ 0.833, 0.5, 0.333, 1, 0, 0, "r" },
		},
	},
	gr = {
		name = "Ellada",
		colours = { b = Color3.fromRGB(13, 94, 175), w = WHITE },
		shapes = {
			{ 0.5, 0.5, 1, 1, 0, 0, "b" },
			{ 0.5, 0.3, 1, 0.2, 0, 0, "w" },
			{ 0.5, 0.7, 1, 0.2, 0, 0, "w" },
			{ 0.2, 0.3, 0.4, 0.6, 0, 0, "b" },
			{ 0.2, 0.3, 0.08, 0.6, 0, 0, "w" },
			{ 0.2, 0.3, 0.4, 0.12, 0, 0, "w" },
		},
	},
	tr = {
		name = "Türkiye",
		colours = { r = Color3.fromRGB(227, 10, 23), w = WHITE },
		shapes = {
			{ 0.5, 0.5, 1, 1, 0, 0, "r" },
			{ 0.393, 0.5, 0.333, 0.5, 0, 0.5, "w" },
			{ 0.44, 0.5, 0.267, 0.4, 0, 0.5, "r" },
			{ 0.607, 0.5, 0.107, 0.16, 0, 0, "w" },
			{ 0.607, 0.5, 0.107, 0.16, 45, 0, "w" },
		},
	},
}

--[[
	THE MATCHES. Any club can play any other: every club against every other,
	once at home and once away, and then it starts again. The list is made
	from Config.ClubOrder (the usual round-robin wheel), so a new club in
	Config.Clubs gets its matches by itself. The first match is the first two
	clubs of the list.

	Config.Derbies is the list in the order it is played (the name is from when
	there were only the two derbies).
]]
Config.Derbies = {} :: { { id: number, name: string, home: string, away: string, round: number } }
do
	-- The wheel: 1st v 2nd, 3rd v 4th, ... in the first round; then everyone but the first turns one place.
	local wheel: { string } = {}
	local order = table.clone(Config.ClubOrder)
	if #order % 2 == 1 then
		table.insert(order, "") -- an odd number of clubs: one rests each round
	end
	local n = #order
	for i = 1, n, 2 do
		table.insert(wheel, order[i])
	end
	for i = n - (n % 2), 2, -2 do
		table.insert(wheel, order[i])
	end
	local rounds = n - 1
	for leg = 1, 2 do
		local seats = table.clone(wheel)
		for round = 1, rounds do
			for i = 1, n / 2 do
				local a, b = seats[i], seats[n + 1 - i]
				if a ~= "" and b ~= "" then
					-- Alternate who is at home from round to round, and swap in the second leg.
					local swap = (round % 2 == 0) ~= (leg == 2)
					local home, away = if swap then b else a, if swap then a else b
					local id = #Config.Derbies + 1
					Config.Derbies[id] = {
						id = id,
						name = Config.Clubs[home].short .. " v " .. Config.Clubs[away].short,
						home = home,
						away = away,
						round = (leg - 1) * rounds + round,
					}
				end
			end
			table.insert(seats, 2, table.remove(seats) :: string)
		end
	end
end

--[[
	THE COLOUR CLASH RULE. Before each match the two main kits are compared. If
	their shirts look alike, the HOME team keeps its main kit and the AWAY team
	wears its alternate. (If that one clashed too, the home team would change
	instead.) The goalkeepers get the first colour of Config.KeeperColours that
	is on none of the shirts of the match. Nobody chooses anything.
]]
Config.KeeperColours = {
	Color3.fromRGB(240, 200, 40), -- yellow
	Color3.fromRGB(240, 130, 30), -- orange
	Color3.fromRGB(128, 132, 140), -- grey
	Color3.fromRGB(140, 70, 200), -- purple
	Color3.fromRGB(60, 190, 220), -- light blue
	Color3.fromRGB(240, 110, 170), -- pink
	Color3.fromRGB(150, 220, 60), -- lime
	Color3.fromRGB(250, 250, 250), -- white
	Color3.fromRGB(20, 20, 24), -- black
}

local function alike(a: Color3, b: Color3): boolean
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) < 0.3
end

-- The colours that fill a shirt: one on plain ones, two on hoops and stripes.
local function shirtColours(kit: any): { Color3 }
	local list = { kit.shirt }
	if (kit.pattern == "hoops" or kit.pattern == "stripes" or kit.pattern == "halves") and not kit.thin and kit.second then
		table.insert(list, kit.second)
	end
	return list
end

function Config.kitsClash(a: any, b: any): boolean
	for _, x in shirtColours(a) do
		for _, y in shirtColours(b) do
			if alike(x, y) then
				return true
			end
		end
	end
	return false
end

-- Which kit each club wears in a match: ("home" | "away") for the home club and for the away club.
function Config.pickKits(homeClub: any, awayClub: any): (string, string)
	for _, try in { { "home", "home" }, { "home", "away" }, { "away", "home" }, { "away", "away" } } do
		if not Config.kitsClash(homeClub.kits[try[1]], awayClub.kits[try[2]]) then
			return try[1], try[2]
		end
	end
	return "home", "away"
end

-- The two goalkeepers' colours, for the two kits of a match.
function Config.pickKeepers(homeKit: any, awayKit: any): (Color3, Color3)
	local taken: { Color3 } = {}
	for _, kit in { homeKit, awayKit } do
		table.insert(taken, kit.shirt)
		if kit.second then
			table.insert(taken, kit.second)
		end
	end
	local picked: { Color3 } = {}
	for _ = 1, 2 do
		for _, colour in Config.KeeperColours do
			local free = true
			for _, other in taken do
				if alike(colour, other) then
					free = false
					break
				end
			end
			if free then
				table.insert(picked, colour)
				table.insert(taken, colour)
				break
			end
		end
	end
	return picked[1] or Config.KeeperColours[1], picked[2] or Config.KeeperColours[2]
end

--[[
	THE TWO PLACES OF THE MATCH. The whole game talks about "home" and "away":
	which stand, which sede, which academy. These tables are filled with the
	club that takes each place in today's derby (Config.applyDerby), so the rest
	of the code keeps reading Config.Teams[...] and always sees today's clubs.

	`side` is the stand along the X axis: -1 west, 1 east. Each claque is on
	the side of its sede, so the two corteos arrive without crossing.
]]
Config.Teams = {
	home = {
		id = "home",
		side = -1, -- west end
		sedeName = "sede vermelha", -- the name of the sede model in the map (see City)
	},
	away = {
		id = "away",
		side = 1, -- east end
		sedeName = "sede azul",
	},
} :: { [string]: any }

Config.Derby = 1

-- Fills the two places with the clubs of derby `n`. Returns false if there is no such derby.
function Config.applyDerby(n: number): boolean
	local derby = Config.Derbies[n]
	if not derby then
		return false
	end
	Config.Derby = n
	for _, slot in { "home", "away" } do
		local team = Config.Teams[slot]
		local club = (Config.Clubs :: any)[(derby :: any)[slot]]
		-- Clear the previous club's fields, keep the place's own.
		for key in team do
			if key ~= "id" and key ~= "side" and key ~= "sedeName" then
				team[key] = nil
			end
		end
		for key, value in club do
			team[key] = value
		end
	end
	-- What each one wears in this match (the colour clash rule).
	local home, away = Config.Teams.home, Config.Teams.away
	home.kitName, away.kitName = Config.pickKits(home, away)
	home.kit, away.kit = home.kits[home.kitName], away.kits[away.kitName]
	home.keeperColor, away.keeperColor = Config.pickKeepers(home.kit, away.kit)
	return true
end
Config.applyDerby(1)

-- Ordem fixa, para a UI nao andar a saltar.
Config.TeamOrder = { "home", "away" }

--[[
	A claque.

	A bancada enche-se de gente. Nao e decoracao: e a massa que faz o ambiente, e
	o ambiente e que faz o remate entrar. Uma bancada vazia nao apoia ninguem por
	mais botoes que se carregue.

	Saltam em sincronia. E isso que se ve de uma claque a serio de longe — nao
	pessoas paradas, um bloco inteiro a mexer ao mesmo tempo.
]]
--[[
	OS BONECOS. Uma linha para cada: quantos ha. 0 tira-os de vez.
	  bancada  -> em cada curva de claque, no estadio
	  cortejo  -> atras de cada faixa, no corteo
]]
--[[
	THE LEAGUE. Points for a win and a draw; the season is a week (Monday to
	Sunday) and the table starts again each Monday (server/League).
]]
Config.League = {
	win = 3,
	draw = 1,
	store = "UltrasFC_Liga_v1", -- the DataStore of the table and the titles
	refreshSeconds = 60, -- how often a server reads the table the other servers wrote
}

--[[
	PYRO, KEPT READABLE. Flares and smoke must not wash the picture out: with
	them lit you still see faces, the grass and the colours of the shirts.
	One place to tune it (1 = as strong as it was drawn):
	  light      brightness of each flare's light
	  range      how far that light reaches
	  glow       how bright the flame itself is
	  halo       size of the round glow at the tip
	  particles  share of the particles (smoke, flame, sparks)
	  smokeSize, smokeOpacity, smokeLife  the smoke: size, how solid, how long
	  maxLights  lights lit at the same time, at most (the rest burn without one)
	  maxSmokes  smoke clouds at the same time, at most
]]
Config.Pyro = {
	light = 0.55,
	range = 0.8,
	glow = 0.85,
	halo = 0.8,
	particles = 0.8,
	smokeSize = 0.75, -- how big the puffs of smoke get
	smokeOpacity = 0.7, -- how solid the smoke is
	smokeLife = 0.75, -- how long it hangs in the air
	maxLights = 12,
	maxSmokes = 10,
}

Config.Bonecos = {
	bancada = 40,
	cortejo = 36,
}

Config.Crowd = {
	perStand = Config.Bonecos.bancada,
	bounceHeight = 1.6,
	baseRate = 1.6, -- saltos por segundo em repouso
	drumRate = 3.4, -- ao ritmo do tambor
	flagEvery = 0, -- de quantos em quantos bonecos leva bandeira (0 = nenhum: as bandeiras ficam para as pessoas)
	partyHeight = 1.8, -- no golo, quantas vezes mais alto do que o salto normal
	sitDrop = 1.1, -- quanto descem os que se sentam, calados
	botsPerPlayer = 2, -- bonecos que saem da bancada por cada pessoa na claque
}

--[[
	O tambor. E ele que manda na bancada: bate-se, a claque salta mais forte e o
	ambiente sobe. Para de se bater e cai.
]]
Config.Drum = {
	hitGain = 7, -- quanto sobe o ambiente por pancada
	intensityPerHit = 0.34, -- quanto acelera a claque
	intensityDecay = 0.5, -- por segundo
	minInterval = 0.22, -- entre pancadas que contam
}

-- A barra de ambiente de cada bancada, de 0 a max.
Config.Atmosphere = {
	max = 100,
	decayPerSecond = 3.2, -- quanto desce sozinha por segundo
	crowdFloor = 0.3, -- o ambiente nunca cai abaixo disto com a bancada cheia
	minorityCap = 2.0, -- teto do bonus de quem esta em minoria
}

--[[
	O dia de jogo, em ciclo, sem nunca parar:

		sede -> corteo -> espera -> entrada -> 1a parte -> intervalo
		-> 2a parte -> fim -> sede

	Em segundos reais. Ao intervalo ninguem troca de campo: cada equipa ataca
	sempre a baliza a frente da sua claque.
]]
Config.Match = {
	clubhouseLength = 180, -- na sede: material, lider, e esperar pelos outros
	corteoLength = 210, -- a caminhada ate ao estadio: ~1200 studs a 7 studs/s, mais a espera e a formatura
	waitLength = 60, -- no maximo, a espera de que as bancadas estejam nos seus lugares
	entranceLength = 40, -- do tunel ao apito: saida, fila e cada um ao seu lugar
	halfLength = 450, -- cada parte: 7 min e meio
	halfTimeLength = 30,
	fullTimeLength = 120, -- no relvado ou na bancada, antes de voltar a sede
	celebrationLength = 15, -- do golo ao pontape de saida
	switchCooldown = 60, -- depois de escolher um papel, segundos ate poder trocar outra vez
}

--[[
	As horas do dia. Um dia inteiro (24 horas de jogo) dura `dayMinutes`
	minutos reais, e o servidor arranca a `startHour`. De noite acendem-se os
	candeeiros e os holofotes; so um candeeiro em cada `lampLightEvery`
	ilumina a serio, os outros so brilham.
]]
Config.DayNight = {
	dayMinutes = 30,
	startHour = 15,
	lampLightEvery = 3,
	windowsLit = 0.2, -- das faixas de janelas, quantas se acendem a noite
}

--[[
	Quem pode saltar de fase, pelo numero da conta Roblox. E o servidor que
	confirma: o botao so aparece a estes, mas quem decide e a lista.
]]
Config.Admins = {
	10733750829,
}

--[[
	The words on the screen. The interface is in English; proper names (clubs,
	mottos, claques, bairros) stay in each club's own language and live in
	Config.Clubs. To change a word on the screen, change it here.
]]
Config.Text = {
	league = {
		open = "TABLE",
		title = "LEAGUE TABLE",
		daysLeft = "%d DAYS LEFT",
		lastDay = "LAST DAY",
		over = "SEASON OVER",
		played = "P",
		won = "W",
		drawn = "D",
		lost = "L",
		goals = "GOALS",
		points = "PTS",
	},
	clubhouse = {
		join = "Join",
		ultrasOf = "Ultras of ",
		take = "Take",
		theUltrasDrum = "The ultras' drum",
		leaveInCorteo = "Leave in corteo",
		capoOnly = "Capo only",
		clubhouse = "CLUBHOUSE  ·  ",
		capo = "capo: ",
		noCapo = "no capo",
		signUp = "SIGN UP",
		shop = "SHOP",
		capo2 = "CAPO",
		joinTheUltras = "Join the ultras",
		welcomeToTheUltrasOf = "Welcome to the ultras of ",
		onYourBar1Flare = "On your bar: 1 flare, 2 smoke, 3 scarf (and 4 drum, if you are the capo). Click to light.",
		gEmotesCtrlLockThe = "G emotes  ·  Ctrl lock the camera  ·  B appeal to the referee  ·  space jump",
		beforeTheMatchWeLeave = "Before the match we leave from here in corteo to the stadium, behind the banner and the capo.",
		atTheStadiumTheUltras = "At the stadium the ultras stand in the end behind the goal: jump, sing, light up, and push the team on.",
		seeTheShop = "See the shop",
		flaresSmokeScarvesFlags = "Flares, smoke, scarves, flags",
		theUltrasShop = "The ultras' shop",
		theUltrasGiveYouA = "The ultras give you a ration for every match: 2 flares, 1 smoke and 1 strobe, already on your bar.",
		moreThanThatAndRoman = "More than that, and roman candles, you buy from the dealers in the street, with coins.",
		youEarnCoinsByGoing = "You earn coins by going to matches with the ultras, marching in the corteo, and with every goal your team scores.",
		beTheCapo = "Be the capo",
		capoOfTheUltras = "Capo of the ultras",
		firstJoinTheUltrasAt = "First join the ultras, at the sign-up desk.",
		youAreAlreadyTheCapo = "You are already the capo",
		beatTheDrum4In = "Beat the drum (4) in rhythm: the stand jumps more and the atmosphere rises.",
		comingSoonHereDesignThe = "Coming soon here: design the tifo and set meeting times for the corteo.",
		youAreTheCapoOf = "You are the capo of the ultras",
		youHaveTheDrum4 = "You have the drum (4): beat it in rhythm to get the stand jumping.",
		withEnoughPeopleAtThe = "With enough people at the clubhouse, start the corteo at the door: the banner goes ahead of you, wherever you walk.",
		theUltrasAlreadyHaveA = "The ultras already have a capo",
		someone = "Someone",
		isTheCapoWhenThey = " is the capo. When they leave, the place is free.",
		takeABike = "Take a bike",
		toRideAroundTheCity = "To ride around the city",
		referees = "REFEREES",
		takeTheWhistle = "Take the whistle",
		refereeTheMatch = "Referee the match",
	},
	lider = {
		capo = "CAPO",
		theCapoCalledFormUp = "The capo called FORM UP at the clubhouse door",
		theCapoCalledJump = "The capo called JUMP",
		theCapoCalledLightUp = "The capo called LIGHT UP the flares",
		theCapoCalledUniformOn = "The capo called UNIFORM on",
		theCapoCalledCrouchEverybody = "The capo called CROUCH — everybody down!",
		theCapoCalledSwayYour = "The capo called SWAY YOUR ARMS",
		giantFlagLightYourFlare = "GIANT FLAG! Light your flare under the cloth",
		youHaveNoFlaresOr = "You have no flares or smoke: buy from a dealer.",
		thatPersonIsNotIn = "That person is not in the ultras.",
		theCapoPickedYouTo = "The capo picked you to wave the pole flag! It is on your bar.",
		nowWavesThePoleFlag = " now waves the pole flag.",
		youHaveGivenAllYou = "You have given all you can this match. Level up to give more.",
		aFlare = "a flare",
		aSmoke = "a smoke",
		theBigFlag = "the big flag",
		theBanner = "the banner",
		theCapoGaveYou = "The capo gave you ",
		youGave = "You gave ",
		to = " to ",
		theCapoPutOn = "The capo put on: ",
		playing = "Playing: ",
		musicStopped = "Music stopped.",
		youHaveCalledLightUp = "You have called LIGHT UP ",
		timesThisMatchLevelUp = " times this match. Level up to call it more.",
		theFlaresAreStillBurning = "The flares are still burning. Wait a little.",
		flaresUp = "Flares up! You can call LIGHT UP ",
		moreTime = " more time this match.",
		moreTimes = " more times this match.",
		waitAFewSecondsBefore = "Wait a few seconds before repeating the order.",
		youOnlyFormUpBefore = "You only form up before the corteo, at the clubhouse door.",
		theUltrasHaveAlreadyFormed = "The ultras have already formed up (or already left).",
		theUltrasAreFormingUp = "The ultras are forming up.",
		theCorteoHasAlreadyLeft = "The corteo has already left (or it is not time yet).",
		theCorteoIsAboutTo = "The corteo is about to leave: follow the banner!",
		theCorteoLeavesAfterThe = "The corteo leaves after the formation.",
		theUltrasJump = "The ultras jump.",
		theUltrasCrouch = "The ultras crouch.",
		theUltrasSwayTheirArms = "The ultras sway their arms.",
		theUltrasPutTheUniform = "The ultras put the uniform on.",
		theGiantFlagIsNot = "The giant flag is not ready yet.",
		theGiantFlagIsComing = "The giant flag is coming down!",
		notNow = "Not now.",
	},
	bandeirao = {
		theGiantFlagOnlyComes = "The giant flag only comes down while the match is on.",
		youHaveAlreadyUsedThe = "You have already used the giant flag this half.",
	},
	progress = {
		loudUltras = "Loud ultras: +",
		supporter = "Supporter: +",
		xpWages = " XP, wages ",
		player = "Player: +",
		referee = "Referee: +",
		refereeCaughtNoWagesThis = "Referee: caught, no wages this match",
		oneMoreFlarePerMatch = "one more flare per match",
		oneMoreSmokePerMatch = "one more smoke per match",
		oneMoreRomanCandlePer = "one more roman candle per match",
		carryTheCorteoBanner = "carry the corteo banner",
		bigFlare = "big flare",
		romanCandleWith = "roman candle with ",
		shots = " shots",
		goldAndSilverColours = "gold and silver colours",
		chooseYourNumber = "choose your number",
		chooseYourPosition = "choose your position",
		bootColour = "boot colour",
		captainSArmband = "captain's armband",
		newCelebration = "new celebration",
		nameOnTheBack = "name on the back",
		goldenBoots = "golden boots",
		higherWagesEveryLevel = "higher wages every level",
		level = "Level ",
		everythingUnlocked = "Everything unlocked",
	},
	main = {
		youGotOutOf = "YOU GOT %d OUT OF %d",
		rightCallsEarnXp = "Only the right calls earn XP.",
		youLostTheWhistle = "You lost the whistle",
		noRefereeingFor = "Too many wrong calls. You cannot referee for %d matches.",
		outOf = "Out of: ",
		theUltrasGiveOneRation = "The ultras give one ration per match, and you have used it.",
		buyMoreFromADealer = "Buy more from a dealer in the street, with the game's coins.",
		theClubBusIsHere = "The club bus is here",
		itIsAtTheAcademy = "It is at the academy door, doors open.",
		itLeavesForTheStadium = "It leaves for the stadium in ",
		seconds = " seconds.",
		youAreAtTheStadium = "You are at the stadium",
		dressingRoomYouWalkOut = "Dressing room. You walk out shortly.",
		whistleFoulBy = "WHISTLE  ·  foul by ",
	},
	whistle = {
		insideTheBox = "inside the box",
		rightOnTheEdgeOf = "right on the edge of the box",
		inMidfield = "in midfield",
		tackleBy = "Tackle by ",
		on = " on ",
		fromBehind = "  ·  from behind",
		fromTheFront = "  ·  from the front",
		cardFor = "Card for ",
		penalty = "penalty",
		freeKick = "free kick",
		nothing = "Nothing",
		yellow = "Yellow",
		red = "Red",
		whereWasTheFoulBy = "Where was the foul by ",
		freeKickOutsideTheBox = "Free kick outside the box",
		penalty2 = "Penalty",
		penaltyCall = "PENALTY",
		freeKickCall = "FREE KICK",
		red2 = "RED  ",
		t2ndYellow = "2nd YELLOW  ",
		sentOff = "  ·  SENT OFF",
		yellow2 = "YELLOW  ",
	},
	bank = {
		atm = "ATM",
		sendMoney = "Send money",
		youHaveToBeNext = "You have to be next to an ATM.",
		waitAFewSecondsBefore = "Wait a few seconds before sending again.",
		youCanSendFrom1 = "You can send from 1$ to ",
		atATime = "$ at a time.",
		thatPersonIsNoLonger = "That person is no longer in the game.",
		youSent = "You sent ",
		to = "$ to ",
		youDoNotHaveEnough = "You do not have enough (or your profile has not loaded yet).",
	},
	shops = {
		robTheTill = "Rob the till",
		till = "Till",
		tillRobbed = "Till robbed",
		youTook = "You took ",
		coins = " coins.",
		thisTillStaysEmptyFor = "This till stays empty for a few minutes. There are more shops in the city.",
	},
	transit = {
		board = "Board",
		bus = "Bus ",
	},
	bikes = {
		takeABike = "Take a bike",
		bike = "Bike",
	},
	kit = {
		referee = "REFEREE",
	},
	gear = {
		flare = "Flare",
		smoke = "Smoke",
		candle = "Roman candle",
		strobe = "Strobe",
		scarf = "Scarf",
		smallFlag = "Small flag",
		bigFlag = "Big flag",
		poleFlag = "Pole flag",
		drum = "Drum",
	},
	hud = {
		chooseYourClub = "Choose your club",
		warnJoin = "You are joining %s.",
		warnKept = "This club is kept. It is your ultras, your shirt and your curva.",
		warnChange = "To change later you must go to the other club's clubhouse, in person.",
		warnSure = "Are you sure?",
		warnYes = "I AM %s",
		follow = "FOLLOW THIS CLUB",
		unfollow = "STOP FOLLOWING",
		followNote = "your second club: its matches, no ultras, no curva, no gear",
		substitute = "PLAY AS A SUBSTITUTE",
		substituteNote = "in its shirt, for this match only",
		change = "CHANGE TO THIS CLUB",
		changeNote = "you leave your club for good",
		confirmChange = "Do you really want to leave %s and join %s?",
		yesChange = "YES, CHANGE",
		noStay = "NO, STAY",
		thenSupporterOrPlayer = "then your role: supporter or player  ·  or referee the match",
		todaysDerby = "NOW PLAYING",
		nextMatchDay = "UP NEXT",
		upNextNote = "this match is up next  ·  choose your role now, you go in when it starts",
		signedUp = "signed up for %s  ·  up next  ·  free to watch this match as a neutral",
		refereeRole = "REFEREE",
		refereeNote = "you decide the match",
		supporter = "SUPPORTER",
		supporterNote = "with the ultras: flares, smoke, corteo",
		playerRole = "PLAYER",
		playerNote = "on the pitch, 4 per team",
		goalkeeper = "GOALKEEPER",
		keeperNote = "in goal",
		back = "◀ BACK",
		level = "LEVEL %d",
		chooseYourRole = "Choose your role",
		leaveTheClubhouseMarchIn = "Leave the clubhouse, march in the corteo, and walk into the stadium",
		ultrasFlaresSmokeCorteo = "ultras  ·  flares, smoke, corteo",
		playFor = "Play for ",
		player4Goalkeeper = "player  ·  4 + goalkeeper",
		gk = "GK",
		inGoal = "in goal",
		refereeTheMatch = "Referee the match",
		refereeYouDecideAndYou = "referee  ·  you decide, and you can give in",
		youRefereeThisMatch = "you referee this match",
		inGoal2 = "  ·  in goal",
		youPlayFor = "you play for ",
		no = "  ·  no. ",
		capo = "  ·  capo",
		ultrasOf = "ultras of ",
		followOneOfTheLight = "follow one of the light beams to an ultras clubhouse",
		home = "HOME",
		switchWait = "SWITCH %ds",
		switch = "SWITCH",
		gEmotes = "G  EMOTES",
		fGetOff = "F  GET OFF",
		throwIn = "THROW-IN",
		corner = "CORNER",
		goalKick = "GOAL KICK",
		foulFreeKick = "FOUL  ·  FREE KICK",
		penalty = "PENALTY",
		takenBy = "taken by ",
		t14GearOnThe = "1-4 gear on the bar    ·    click to light    ·    B  appeal to the referee    ·    T  tifo    ·    space  jump",
		flares = "flares",
		smokes = "smokes",
		candles = "candles",
		strobes = "strobes",
		bigFlag = "big flag",
		unlimitedGear = "unlimited gear",
		noPyroBuyFromA = "no pyro: buy from a dealer in the street",
		drum = "drum",
		streetGearPaidInEscudos = "street gear · paid in escudos",
		colour = "COLOUR",
		unlimited = "unlimited",
		youHave = "you have ",
		tm = "TM",
		fromSupporterLevel = ": from supporter level ",
		colourChosen = "colour chosen: ",
		youAreShortBy = "you are short by ",
		bought = "bought: ",
		save = "  (save ",
		theStandWants = "the stand wants  —  ",
		eWhistle = "E   WHISTLE",
		doYouBlow = "   ·   do you blow?",
		bAppealForAFoul = "   ·   B  appeal for a foul",
		willTheRefereeBlow = "   ·   will the referee blow?",
		referee = "referee: ",
		noReferee = "no referee",
		refereeCaught = "REFEREE CAUGHT",
		appeal = "APPEAL",
		atTheClubhouse = "AT THE CLUBHOUSE",
		gearTheCapoAndYour = "gear, the capo and your ultras",
		corteo = "CORTEO",
		corteoNote = "the capo leads, the ultras follow the banner",
		waitingForTheStands = "WAITING FOR THE STANDS",
		teamsComeOut = "TEAMS COME OUT",
		t1stHalf = "1st HALF",
		halfTime = "HALF-TIME",
		t2ndHalf = "2nd HALF",
		fullTime = "FULL TIME",
		nextANewDayAt = "next, a new day at the clubhouse",
		dDInTheStand = "%d/%d in the stand",
		goal = "GOAL",
		lightTheFlares = "LIGHT THE FLARES",
		winFor = "win for ",
		draw = "draw",
		skipPhase = "]  SKIP PHASE",
		ultrasName = "ULTRAS NAME",
		noneLeftThisMatch = "none left this match",
		rightMomentCountsDouble = "RIGHT MOMENT  ·  counts double",
		wrongMomentCountsHalf = "wrong moment  ·  counts half",
		atTheRightMoment = "  ·  at the right moment",
		atTheWrongMoment = "  ·  at the wrong moment",
		cardUp = "card up",
		yourColourTToLift = "your colour  ·  T to lift",
		tLiftYourCard = "T  LIFT YOUR CARD",
		goal2 = "GOAL!",
		scoredInTraining = " scored in training",
		inTraining = "in training",
	},
	perfil = {
		supporter = "SUPPORTER",
		marchInTheCorteoNear = "March in the corteo near the banner",
		beInTheStandDuring = "Be in the stand during the match",
		aFlareOrSmokeAfter = "A flare or smoke after a goal",
		beThereAtKickOff = "Be there at kick-off",
		player = "PLAYER",
		minutesPlayed = "Minutes played",
		goalsAndAssists = "Goals and assists",
		winningTheBall = "Winning the ball",
		savesGoalkeeper = "Saves (goalkeeper)",
		referee = "REFEREE",
		refereeTheWholeMatch = "Referee the whole match",
		makeTheFairCall = "Make the fair call",
		donTGetCaughtBeing = "Don't get caught being bent",
		profile = "⭐ PROFILE",
		yourProfile = "YOUR PROFILE",
		levels = "⭐ LEVELS",
		money = "💰 MONEY",
		kit = "👕 KIT",
		level = "LEVEL",
		howToEarnXp = "HOW TO EARN XP",
		youHave = "YOU HAVE",
		escudosTheGameSMoney = "Escudos: the game's money",
		howToEarnEscudos = "HOW TO EARN ESCUDOS",
		wagesAtFullTime = "Wages at full time",
		goesUpWithEachRole = "goes up with each role's level",
		dailyReward = "Daily reward",
		comeBackEveryDayIn = "come back every day in a row",
		robTheTills = "Rob the tills",
		inTheCitySShops = "in the city's shops",
		yourTeamSGoals = "Your team's goals",
		allTheUltrasEarn = "all the ultras earn",
		whereToSpend = "WHERE TO SPEND",
		bStreetDealersBFlares = "🔥 <b>Street dealers</b>: flares, smoke, strobe, roman candle and colours.\n📍 Look for the DEALER sign above them. A bike gets you there fast (there are bikes at the clubhouse door).\n🏧 <b>ATM</b>: send escudos to a friend.",
		dailyReward2 = "DAILY REWARD",
		looksOnlyYourLevelNever = "⚽ Looks only: your level never makes you play better. Unlocked with your PLAYER level.",
		number = "🔢 NUMBER",
		wear = "WEAR",
		position = "📍 POSITION",
		attack = "ATTACK",
		midfield = "MIDFIELD",
		defence = "DEFENCE",
		boots = "👟 BOOTS",
		b1WagesAtThe = "<b>1. Wages at the end of every match</b> (they go up with your level). Today you get:\n",
		supporter2 = "   📣 supporter ",
		to = "$ to ",
		moreIfYouMarchIn = "$ (more if you march in the corteo)\n",
		player2 = "   ⚽ player ",
		perGoalReferee = "$ per goal)   🟨 referee ",
		b2DailyRewardB = "<b>2. Daily reward</b>: come back every day.\n",
		b3RobTheTills = "<b>3. Rob the tills</b> in the city's shops: 15$ to 35$.\n",
		b4YourTeamS = "<b>4. Your team's goals</b>: +",
		forAllTheUltras = "$ for all the ultras.",
		maxLevel = "MAX LEVEL!",
		xpToLevel = " XP to level ",
		upTo = "up to ",
		todayDayB = "Today: day <b>",
		bOf = "</b> of ",
		inARowNNtomorrow = " in a row.\n\nTomorrow, if you come back: <b>+",
		bNmissADayAnd = "$</b>\nMiss a day and it goes back to day 1.\nDay 7 pays ",
		youWearNumber = "You wear number ",
		ifNobodyOnYourTeam = " (if nobody on your team has it).",
		pickOneAndPressWear = "Pick one and press WEAR.",
		playerLevel = "🔒 Player level ",
		youGetASpotIn = "You get a spot in that part of the pitch, if one is free.",
		goldenBootsLevel = "✨ Golden boots (level ",
		theColourOfYourBoots = "The colour of your boots.",
		dailyReward3 = "🎁 DAILY REWARD",
		comeBackEveryDayEach = "Come back every day: each day in a row pays more! Miss a day and it goes back to day 1.",
		day = "DAY ",
		claim = "CLAIM",
		claimed = "CLAIMED",
		today = "TODAY",
		claim2 = "CLAIM  +",
		comeBackTomorrow = "COME BACK TOMORROW  ·  ",
		seeTheCalendar = "📅 SEE THE CALENDAR",
		fullTime = "🏁 FULL TIME",
		supporter3 = "📣 SUPPORTER",
		player3 = "⚽ PLAYER",
		referee2 = "🟨 REFEREE",
		levelUp = "⭐ LEVEL UP!",
		level2 = "  ·  LEVEL ",
		day2 = "Day ",
		inARow = " in a row  ·  +",
	},
	liderHud = {
		pressEToJoinIn = "Press E to join in  ·  ignore it if you don't want to",
		joinInE = "JOIN IN  (E)",
		youReIn = "You're in!",
		orders = "📣 ORDERS",
		capoYourOrders = "CAPO · your orders",
		nobodyIsForcedTheUltras = "Nobody is forced: the ultras get a notice and decide.",
		back = "◀ back",
		stop = "■ STOP",
		flare = "🔥 Flare",
		smoke = "💨 Smoke",
		flag = "🚩 Flag",
		banner = "🎌 Banner",
		poleFlagOnly1 = "🏴 Pole flag (only 1)",
		youCanGive = "You can give ",
		thisMatchPickThePerson = " this match. Pick the person, then what.",
		meCapo = "Me (capo)",
		nobodyElseInTheUltras = "Nobody else in the ultras yet.",
		pickThePersonFirst = "Pick the person first.",
		formUp = "FORM UP",
		march = "MARCH",
		jump = "JUMP",
		crouch = "CROUCH",
		arms = "ARMS",
		lightUp = "LIGHT UP",
		giantFlag = "GIANT FLAG",
		music = "MUSIC ▸",
		giveGear = "GIVE GEAR ▸",
		uniform = "UNIFORM",
		of = " of ",
		onTheWayToYour = "On the way to your place in the formation (move to cancel).",
	},
	football = {
		stamina = "stamina",
		curveHeight = "curve · height",
		leftClickShootRightClick = "left click  shoot    ·    right click  shoot with curve    ·    Shift  sprint    ·    Ctrl  lock camera",
		dive = "DIVE",
		shoot = "SHOOT",
		sprint = "SPRINT",
		ballInHandD = "BALL IN HAND  ·  %d",
		kickOff = "kick-off  ·  ",
		kickOff2 = "kick-off",
		whistle = "WHISTLE",
		theGoalkeeperHasTheBall = "The goalkeeper has the ball: get out of the box!",
	},
	banco = {
		atm = "🏧  ATM",
		balance = "BALANCE",
		sendTo = "SEND TO",
		nobodyElseInTheGame = "Nobody else in the game right now.",
		amount = "AMOUNT",
		pickThePersonFromThe = "Pick the person from the list.",
		send = "SEND",
		sendTo2 = "Send to ",
		pickWhoToSendTo = "Pick who to send to.",
		typeHowMuchYouWant = "Type how much you want to send.",
		sending = "Sending...",
		sentYou = " sent you ",
	},
	corteo = {
		runInside = "RUN INSIDE!",
	},
	admin = {
		open = "ADMIN",
		title = "ADMIN BAR",
		team = "MY TEAM",
		kit = "WEAR KIT",
		farda = "WEAR UNIFORM",
		kitType = "KIT",
		derby = "MATCH",
		off = "OFF",
		home = "MAIN",
		alt = "ALTERNATE",
		auto = "AUTO",
	},
}

--[[
	Os sons. O codigo chama-os pelo nome, nunca pelo numero: para trocar um som,
	muda-se o numero aqui e mais nada.

	`volume` e o volume de base. A multidao de fundo sobe e desce com o ambiente
	entre `volume` e `volumeMax`, e fica sempre abaixo dos outros para nao os
	abafar.

	Todos da biblioteca de sons que o Roblox deixa usar em qualquer jogo
	(ProSoundEffects e APM). Audio privado de outra conta nao toca e nao da
	erro: fica mudo.
]]
export type SoundSpec = { id: number, volume: number, volumeMax: number?, looped: boolean?, cut: number? }

Config.Sounds = {
	multidao = { id = 9119562234, volume = 0.15, volumeMax = 0.4, looped = true },
	golo = { id = 9120975204, volume = 0.9 },
	lamento = { id = 9120974911, volume = 0.6 },
	tambor = { id = 9113343286, volume = 0.8, cut = 0.55 }, -- o ficheiro tem varias pancadas: toca-se so a primeira
	apito_inicio = { id = 9118113825, volume = 0.8 },
	apito_falta = { id = 9117261163, volume = 0.8 },
	apito_fim = { id = 9117259635, volume = 0.9 },
	pontape = { id = 9119326824, volume = 0.6 },
	corteo = { id = 9112779476, volume = 0.45, looped = true },
	festa_fim = { id = 1839963987, volume = 0.6 },
} :: { [string]: SoundSpec }

--[[
	O estadio. E propositadamente simples: partes soltas, sem modelos nem texturas.
	Serve para haver um sitio, e para se perceber de que lado se esta. Quando
	quiseres um estadio a serio, constroi-o a mao no Studio e poe
	Config.Stadium.build a false para este nao te apagar o trabalho.
]]
Config.Stadium = {
	build = true,

	--[[
		O campo, em studs. Cerca de 70 x 45 m: menos do que um relvado oficial,
		mas o suficiente para jogadores a serio (5 studs de altura, 16 por segundo
		a correr) terem espaco. Tudo o resto — bancadas, muralha, cidade, corteo —
		mede-se a partir daqui, menos o bloco da claque, que tem medida propria.
	]]
	pitchLength = 210, -- ao longo do eixo X
	pitchWidth = 136, -- ao longo do eixo Z

	--[[
		Medidas de um recinto a serio, convertidas para studs (1 m ~ 3 studs).

		Degrau de 0,8 m de profundidade e inclinacao de 34 graus, que e o maximo
		que se usa numa bancada; da 1,6 studs de subida, e por baixo dos 2 studs
		que o Roblox deixa subir a andar. Doze filas chegam: isto e um estadio
		pequeno de proposito, e um pequeno cheio vale mais do que um grande vazio.
	]]
	rows = 12,
	rowDepth = 2.4,
	rowHeight = 1.6,
	standGap = 8, -- da linha lateral a primeira fila

	--[[
		Blocos. E a divisao que faz uma bancada parecer arrumada em vez de uma
		rampa unica.

		Nos topos, o bloco do meio e da claque, mesmo atras da baliza, e uma
		claque quer-se junta: nenhuma escada o corta ao meio, so tem as duas dos
		lados, e sao essas as suas entradas. Tem largura fixa — nao cresce com o
		campo — porque e sobre ele que assenta a grelha do tifo, e uma claque
		espalhada deixa de o ser. Os outros blocos dividem o resto. `blocksEnd`
		tem de ser impar, para haver bloco do meio.
	]]
	blocksLong = 5, -- nas bancadas laterais, do publico
	blocksEnd = 3, -- nas bancadas de topo, das claques
	claqueBlockWidth = 28, -- o bloco do meio dos topos
	gangwayWidth = 5, -- tambem a largura do tunel de cada vomitorio

	--[[
		Os vomitorios. Entra-se pelas costas da bancada ao nivel da rua, sobe-se
		uma rampa por baixo dos degraus e sai-se a meio da bancada, nesta fila.
		A meio e de proposito: sair ca em baixo obrigava a subir a bancada toda,
		sair la em cima obrigava a desce-la.
	]]
	vomitoryRow = 6,

	-- A muralha a volta do recinto. Cada claque entra pela porta do seu topo;
	-- o publico pelas das laterais.
	wallHeight = 10,
	claqueGateWidth = 24,
	publicGateWidth = 16,

	--[[
		O estadio novo (2026-09): uma taca branca continua, com as bancadas a
		darem a volta pelos cantos em curva. As claques ficam em duas curvas
		opostas, na diagonal; a bancada principal tem dois andares, com os
		camarotes e a tribuna presidencial entre eles.
	]]
	endGap = 20, -- da linha de golo a primeira fila dos topos (a baliza precisa de espaco atras)
	cornerRadius = 20, -- raio da frente das curvas (a primeira fila)
	curveSegments = 7, -- pedacos de cada fila de uma curva (mais = mais redondo, mais pecas)
	boxDepth = 8, -- os camarotes, atras do primeiro andar da principal
	boxHeight = 7,
	upperRows = 8, -- o segundo andar da principal
	upperRowHeight = 1.9,
}


--[[
	Tochas.

	E a imagem da coisa toda: uma bancada as escuras e um ponto de luz vermelha a
	arder no meio dela. Por isso sao poucas e duram pouco — se cada um pudesse ter
	sempre uma acesa, deixava de ser um momento e passava a ser o fundo do ecra.
]]
--[[
	O futebol. Cinco contra cinco, jogado por pessoas; os lugares que ficam
	vazios levam um boneco, e o boneco sai quando chega alguem.

	A bola e fisica normal do Roblox, nao simulacao: e para ser previsivel e
	agradavel de chutar, nao realista. Quase tudo o que "sente mal" a jogar
	resolve-se aqui.
]]
Config.Football = {
	-- A formacao: quatro no campo e um na baliza, como no futsal. `x` e a
	-- fracao de meio campo a partir do centro, para tras; `z` e a fracao da
	-- largura do relvado. A ordem e a de quem entra: uma pessoa fica com o
	-- primeiro lugar livre de campo, de frente para tras. A baliza so a quem
	-- a escolhe.
	formation = {
		{ number = 9, x = 0.12, z = 0 },
		{ number = 7, x = 0.42, z = 0.27 },
		{ number = 11, x = 0.42, z = -0.27 },
		{ number = 4, x = 0.68, z = 0 },
		{ number = 1, x = 0.95, z = 0, keeper = true },
	},

	--[[
		O guarda-redes. Dentro da sua area agarra a bola que lhe passa perto,
		sozinho; fora dela e um jogador como os outros. Com a bola nas maos
		ninguem lha tira, e tem uns segundos para a por em jogo.

		O boneco fica na linha, a acompanhar a bola, e defende so uma parte dos
		remates fortes — quer-se golos.
	]]
	keeperReach = 5, -- a esta distancia agarra sozinho, na sua area
	keeperHeight = 8, -- e ate esta altura: apanha a bola no ar
	keeperDiveReach = 11, -- a atirar-se chega mais longe
	keeperDiveSpeed = 42, -- studs/s do mergulho
	keeperDiveTime = 1, -- quanto dura o voo; falhou, fica no chao (fallTime)
	keeperDiveCooldown = 1.5,
	keeperHoldTime = 5, -- segundos com a bola nas maos; depois perde-a
	botKeeperSave = 0.45, -- remates fortes que o boneco agarra
	botKeeperDelay = 1.2, -- o boneco com a bola nas maos espera isto antes de a por em jogo
	fastShot = 38, -- acima desta velocidade e um remate a serio, nao uma bola a rolar

	-- Correr
	walkSpeed = 18,
	sprintSpeed = 27,
	botSpeed = 19, -- os bonecos a posicionar-se
	botSprintSpeed = 24.5, -- a ir a bola; abaixo do sprint de uma pessoa, para se lhes poder fugir
	botDribbleSpeed = 24, -- com bola, um pouco mais do que quem aperta: foge-se por tras, nao pela frente
	staminaMax = 100,
	staminaDrain = 24, -- por segundo, a correr em sprint
	staminaRegen = 13, -- por segundo, sem sprint
	staminaRecover = 30, -- esgotado, so volta ao sprint a partir daqui

	-- A bola
	ballSize = 2,
	claimRange = 3.6, -- a que distancia dos pes se fica com ela
	claimHeight = 3.8, -- acima disto passa por cima: nao ha cabecear
	dribbleDistance = 2.6, -- a que distancia a frente dos pes vai com a posse
	kickLockout = 0.4, -- quem chutou nao a volta a apanhar logo
	kickFlight = 0.15, -- ninguem lhe toca logo a saida do pe
	rollFriction = 5.5, -- travao no chao: studs/s perdidos por segundo, sempre
	rollDrag = 0.25, -- mais isto vezes a velocidade (a bola rapida perde mais)
	airDrag = 0.08, -- no ar, so a resistencia do ar

	--[[
		Chutar: um botao para tudo. Segurar carrega a forca, largar chuta; um
		toque curto e um passe, carregado a fundo e um remate. Enquanto se
		segura, mexer o rato da o efeito (para os lados) e a altura (para cima,
		chapeu; para baixo, rasteira).
	]]
	chargeTime = 0.9, -- segundos ate a forca maxima
	kickSpeedMin = 36, -- um toque
	kickSpeedMax = 125, -- tudo
	aimPixels = 120, -- quanto se mexe o rato para chegar ao maximo de efeito ou altura
	liftNeutral = 0.08, -- fracao da velocidade que vai para cima, com o rato parado
	liftMax = 0.8, -- rato todo para cima: chapeu, que passa por cima de quem esta a frente
	curveAccel = 70, -- studs/s2 de desvio para o lado, com o efeito todo
	curveTime = 1.2, -- quanto tempo o efeito dura no ar

	-- Chutos fracos para a frente de um colega vao na direcao dele, com a
	-- forca que se escolheu. Sem isto, passar so pela direcao do boneco era
	-- quase impossivel.
	passAssistPower = 0.4, -- ate esta forca ha ajuda
	passCone = 25, -- graus; um colega dentro deste cone recebe-a
	passRange = 70,

	-- Os passes dos bonecos
	passSpeedMin = 38,
	passSpeedMax = 90,

	-- Roubar
	tackleRange = 2.8, -- encostar
	tackleImmunity = 1.5, -- quem ganhou a bola nao a perde logo a seguir
	claimImmunity = 0.5, -- o mesmo, mais curto, a quem apanha uma bola solta
	fallTime = 1, -- quem a perdeu fica no chao

	-- Recomecos
	kickoffFreeze = 2, -- toda a gente parada antes do apito
	restartPriority = 1.5, -- segundos em que so a equipa certa pode tocar
	goalPause = 2.5, -- a bola na rede antes do pontape de saida

	-- A baliza
	goalHalfWidth = 10.5, -- maiores do que eram (8 x 8): 21 de largo
	goalHeight = 9.6,
	goalDepth = 8, -- funda: a rede fica bem atras da linha, como as de verdade

	-- Os bonecos
	botThink = 0.25, -- de quanto em quanto tempo quem tem a bola decide
	botShootRange = 40,
	botPressure = 9, -- um adversario a esta distancia aperta
}

--[[
	O corteo. Sai no aquecimento e tem de chegar antes do apito — por isso o
	aquecimento e mais longo do que seria preciso: e o tempo da caminhada.
]]
Config.March = {
	readyNeeded = 3, -- quantos tem de estar na sede para o lider poder sair (ou todos, se forem menos)
	autoStartAfter = 20, -- sem lider a dar a ordem, a faixa forma e sai sozinha, com folga para chegar
	formSeconds = 8, -- a formatura: filas direitas, quietos, antes de sair
	formLook = 70, -- forming up, they look at the point this far ahead on the route: down the street, to the stadium
	formAhead = 20, -- ao formar, a faixa avanca isto pela rua: as filas ficam atras dela, fora da sede
	runDistance = 55, -- a esta distancia da porta acaba a marcha e corre-se para dentro
	runSpeed = 20, -- a corrida para dentro
	runBoost = 24, -- quem vai no corteo pode correr assim uns segundos (so se quiser)
	bots = Config.Bonecos.cortejo, -- bonecos que marcham atras de cada faixa (Config.Bonecos)
	columns = 10, -- quantos lado a lado, da largura da faixa: a rua cheia de parede a parede
	leaderSpeed = 8, -- o lider a guiar anda a este passo, para o grupo o acompanhar
	leadDistance = 8, -- a faixa vai estes studs a frente do lider
	takeRadius = 20, -- o lider a esta distancia da faixa passa a guia-la
	arriveRadius = 30, -- a esta distancia da porta da claque, o corteo chegou
	speed = 7, -- passo da faixa, em studs por segundo: o de quem vai a pe, devagar, nunca a correr
	spacing = 2.4, -- studs between two people side by side in the block
	-- The banner that opens the corteo: three players wide, half a player tall,
	-- straight, held at chest height by the two at its ends; it barely moves.
	banner = { width = 12, height = 2.4, chest = 3.6, sway = 0.08 },
	radius = 45, -- a que distancia da faixa ainda se conta como ir no corteo
	atmosphereBonus = 55, -- ambiente de partida para uma claque que fez o caminho
}

--[[
	A entrada em campo. Sai o arbitro, as duas equipas atras dele em fila, e
	param lado a lado a frente do circulo central, virados para a bancada
	principal. E o momento mais alto do dia: as duas claques no maximo.
]]
Config.Entrance = {
	lineAt = 14, -- segundos depois de abrir o tunel em que a fila fica presa
	lineSeconds = 20, -- quanto tempo fica parada
	lineZ = 22, -- a que distancia do centro, para o lado da bancada principal
	spacing = 2.6, -- entre dois jogadores lado a lado
	stagger = 0.9, -- segundos entre um jogador e o seguinte a sair do balneario
	flares = 4, -- bonecos de cada claque que acendem tocha na fila (so no ecra)
}

--[[
	O LIDER (o capo): de costas para o campo, virado para a claque, a dirigir.

	So ele ve os botoes das ordens. REGRA: o lider NUNCA obriga ninguem. Os
	bonecos obedecem sempre; as pessoas recebem um aviso e decidem ("carrega
	E para entrar"); quem ignora, fica como esta.

	O material que da e limitado por jogo, e cresce com o nivel de adepto
	dele: `give.base` no nivel 1 ate `give.max` no nivel maximo.
]]
Config.Lider = {
	give = { base = 3, max = 15 },
	giveKinds = { "tocha", "fumo", "bandeira", "faixa", "mastro" }, -- o que pode dar (o mastro nao gasta: e so um, muda de mao)
	cooldown = 6, -- segundos entre duas ordens iguais
	-- ACENDER: quantas vezes por jogo (do nivel 1 ao maximo) e o intervalo minimo.
	lights = { base = 2, max = 8 },
	lightCooldown = 30,
	inviteSeconds = 8, -- quanto tempo o aviso fica no ecra de cada um
	jumpSeconds = 12, -- SALTAR: quanto tempo se salta
	lightSeconds = 22, -- ACENDER: quanto tempo os bonecos ficam de tocha acesa
	lightBots = 14, -- quantos bonecos da bancada acendem
	musicSeconds = 120, -- MUSICA: quanto tempo toca o cantico
	-- Os canticos: so audio que o Roblox deixa usar em qualquer jogo (APM,
	-- Pro Sound Effects). Para trocar, muda-se o numero aqui.
	canticos = {
		{ name = "Tambores da curva", id = 84302571478690 },
		{ name = "Marcha dos tambores", id = 1836342097 },
		{ name = "Tambor sozinho", id = 140393706670152 },
		{ name = "A bancada a cantar", id = 9112766203 },
		{ name = "Festa com buzinas", id = 9112779173 },
		-- `club`: only that club's leader sees it.
		{ name = "Sporting o meu Lugar", id = 117260593732846, club = "alvalade" },
	},
	farda = Color3.fromRGB(20, 20, 24), -- o casaco da farda (o cachecol e da cor da claque)
	--[[
		O BANDEIRAO: o pano gigante enrolado no cimo da curva que desce por cima
		da claque inteira. Uma vez por parte. Tempos em segundos; `headroom` e a
		altura do pano por cima do degrau (tem de passar por cima das cabecas).
		`columns` x `rows` sao os bocados de pano (o emblema e pintado neles).
	]]
	bandeirao = { unroll = 4, hold = 25, rollup = 3, headroom = 8.5, columns = 28, rows = 16, t0 = 0.04, t1 = 0.96 },
}

--[[
	O material da claque.

	Tudo o que aqui esta empurra o ambiente para cima enquanto dura, e e por isso
	que quase tudo dura pouco: se pudesse estar sempre ligado, deixava de ser um
	momento e passava a ser o fundo do ecra. O tambor e a excepcao — esse nao da
	nada sozinho, so se acertar no compasso.
]]
--[[
	As regras: reposicoes, faltas, cartoes e fora de jogo.

	A regra que manda em todas: RAPIDEZ. Sao muitas formas de parar o jogo, e se
	cada uma demorar o jogo morre. Prefere-se um jogo rapido e um bocado tosco a
	um jogo correto e parado — a bola tem de estar viva pelo menos dois tercos do
	tempo.

	Distancias em studs (1 m ~ 3 studs). As zonas proibidas so valem para os
	bonecos: as pessoas ficam onde quiserem, e se alguem se puser em cima da
	bola o tempo da reposicao trata disso.
]]
Config.Rules = {
	outDelay = 0.5, -- a bola fora ve-se sair antes de ser reposta
	restartTime = 3, -- quanto se espera por quem repoe; depois a bola fica viva ali
	humanRestartTime = 6, -- uma pessoa a bater tem mais tempo: apontar e dosear demora
	freeKickTime = 15, -- um livre (ou penalti) marcado por uma pessoa; o relogio do jogo para ate ser batido
	restartEdge = 0.5, -- acabado o tempo, a equipa que repunha ainda tem este avanco
	botTakerDelay = 0.6, -- um boneco na bola bate ao fim disto

	throwInGap = 9, -- lancamento: adversarios a 3 m
	cornerGap = 15, -- canto: a 5 m
	freeKickGap = 15, -- livre: a 5 m
	penaltyTime = 4, -- o penalti espera mais: apontar leva tempo

	--[[
		As faltas. A maior parte do contacto e so contacto: decide-se no momento
		do roubo, e por tras e mais provavel do que de frente, mas mesmo por
		tras a maioria nao e falta. Nao ha relogio: e sorte a cada entrada, e
		por isso em 30 segundos tanto pode nao haver nenhuma como haver duas ou
		tres. Em media da perto de duas por minuto; o Output diz a cada minuto
		quantas houve. `foulGap` so impede duas faltas no mesmo lance.
		O arbitro automatico marca o que aqui sai; uma pessoa com o apito pode
		marcar outra coisa.
	]]
	foulBehind = 0.2, -- roubos por tras que sao falta
	foulFront = 0.05, -- roubos de frente que sao falta
	foulGap = 3, -- segundos depois de uma falta em que nenhuma entrada o e: so o mesmo lance
	behindDot = -0.2, -- abaixo disto (olhar de quem leva a bola vs. de onde vem quem rouba) e por tras
	boxLineMargin = 3, -- a esta distancia da linha da area, fica em duvida: penalti ou livre

	-- Cartoes que o arbitro automatico mostra, por falta
	yellowBehind = 0.2,
	redBehind = 0.03,
	yellowFront = 0.05,
}

--[[
	O arbitro.

	E o motor do drama, e por isso corromper-se tem de ser ARRISCADO e nunca
	comprado. Um arbitro que se comprasse com Robux fazia quem paga ganhar
	sempre — toda a gente percebia em dois dias e o jogo morria. Assim vira jogo
	do gato e do rato, e esse dura.

	Cada decisao a favor de quem mais pressionou enche a barra de suspeicao.
	Cheia, e apanhado: a ultima decisao e revertida e fica suspenso.
]]
Config.Referee = {
	whistleWindow = 2, -- segundos para apitar uma entrada; sem apito, o jogo seguiu
	cardSeconds = 10, -- com a bola parada, para escolher o cartao; sem escolha, nao ha cartao
	suspicionPerCall = 26, -- quanto sobe ao ceder a quem pressiona
	suspicionDecay = 1.4, -- por segundo, quando se porta bem
	caughtAt = 100,
	banMatches = 2,
	wrongLimit = 4, -- this many wrong calls in one match and the whistle is taken away
	pressureWindow = 20, -- segundos que um pedido da bancada continua a contar
}

--[[
	Maquinas fracas.

	A maior parte de quem joga isto esta no telemovel. Estes tetos sao o que
	impede o jogo de pesar mais do que um telemovel aguenta.
]]
Config.Performance = {
	--[[
		A pirotecnia NAO tem limite no jogo a serio: a bancada inteira pode
		arder. O modo baixo so existe para testar no Studio num computador fraco,
		e so conta dentro do Studio — mesmo esquecido ligado, o jogo publicado
		nunca fica limitado.

		  studioBaixo = true   -> no Studio: poucas luzes, metade das particulas
		  studioBaixo = false  -> no Studio fica tudo como no jogo (maximo)
	]]
	studioBaixo = true,
	baixo = {
		maxLights = 6, -- tochas e fumos com luz propria ao mesmo tempo
		maxSmokes = 8, -- bombas de fumo a fundo ao mesmo tempo
		particles = 0.5, -- metade das particulas
	},

	--[[
		O maximo de pecas de cada parte. Passar daqui e engano num ciclo, nao
		crescimento normal: a construcao para e escreve no Output. Estao um pouco
		acima do que cada parte cria hoje.
	]]
	maxParts = {
		Estadio = 1400,
		Cidade = 800,
		Adeptos = 1500, -- bonecos com cabelo, cachecol, oculos (Ultra): ~12 pecas cada
		Jogadores = 400, -- vivos ao mesmo tempo; os bonecos saem e entram
		Tifo = 300, -- cartolinas no ar, as duas claques
		Jogo = 20, -- a bola e as paredes que so ela sente
		default = 200,
	},
}

--[[
	AS ANIMACOES. O codigo chama sempre pelo nome, nunca pelo numero.

	Vazia (""), fica a pose que o jogo ja faz (ou a normal do Roblox). Com o
	numero de uma animacao tua, e essa que toca. Para por uma: muda so o texto
	entre aspas, por exemplo  tocha = "12345678",

	  tocha        com a tocha acesa na mao
	  fumo         com a bomba de fumo acesa na mao
	  velaromana   com a vela romana acesa na mao
	  salto        a saltar (emote e ordem SALTAR do lider)
	  bandeira     com a bandeira grande (a do mastro) na mao; mexe tambem o
	               mastro e o pano (as juntas Bandeira_*)
	  bandeirinha  com a bandeirinha na mao; mexe o pau e o pano (Bandeirinha_*)
	  tambor       cada pancada no tambor
	  marcha       a andar no corteo, perto da faixa
	  faixa        quem vai a segurar a faixa do corteo
	  capo         o lider parado na curva da claque, virado para ela
	  festejo      golo da equipa: festeja toda a gente dela (jogadores e claque)
	  joelho       quem marcou, nivel 12 de jogador: desliza de joelhos (uma vez)
	  mbappe       quem marcou, nivel 20 de jogador: o festejo do Mbappe (uma vez)
	  faixapano    o pano da faixa do corteo (rig proprio, juntas Faixa_*)
	  bandeirao    o bandeirao a descer (rig proprio, juntas Bandeirao_*)
]]
Config.Animations = {
	tocha = "101977181059854",
	fumo = "113905861032838",
	velaromana = "134149231915828",
	salto = "",
	bandeira = "", -- agitada pelo jogo, com as duas maos (a animacao 107165199750926 fica guardada aqui)
	bandeirinha = "122243468746097",
	tambor = "",
	marcha = "",
	faixa = "",
	capo = "",
	festejo = "74546471177853",
	-- Os festejos de quem marca (niveis de jogador, Config.Progress.perks.celebrationAt).
	joelho = "139953858994182", -- deslizar de joelhos (nivel 12)
	mbappe = "", -- o do Mbappe (nivel 20); desligado: o 135442560312009 foi publicado pelo amigo e este jogo nao o pode usar
	faixapano = "",
	bandeirao = "",
}

--[[
	A velocidade de cada animacao: 1 e a normal, 0.5 metade, 1.5 mais depressa.
	`todas` vale para as que nao tem numero proprio aqui.
]]
Config.AnimationSpeed = {
	todas = 0.7,
	bandeirinha = 0.5, -- mais lenta do que as outras
	bandeira = 0.5,
}

--[[
	As animacoes: os bracos com a tocha no ar, o cachecol esticado, e o menu
	de animacoes de adepto. Sao feitas em codigo, junta a junta, em todos os
	ecras (Poses.client) — assim toda a gente ve as de toda a gente, sem
	depender de animacoes carregadas de fora. So para avatares R15.

	`raisedArm` e o angulo do braco com a tocha acesa: 0 caido, 180 todo no
	ar. O Gear usa o mesmo para a tocha ficar de pe na mao.
]]
Config.Poses = {
	raisedArm = 150,
}

-- O menu de animacoes, pela ordem em que aparecem. Mexer-se para-as.
Config.Emotes = {
	{ id = "aplaudir", label = "Applaud" },
	{ id = "maos", label = "Hands up" },
	{ id = "saltar", label = "Jump" },
	{ id = "balancar", label = "Sway" },
	{ id = "agachado", label = "Crouch" },
}

--[[
	O material de claque. Esta sempre na barra de baixo de quem e de claque,
	desde que escolhe o lado; quem nao e de claque nao tem nada. Acender gasta
	um do stock, e o objecto fica na mao a espera do proximo.

	A sede da, a cada dia de jogo, `perMatch` de cada (a racao da claque); o
	resto compra-se aos dealers na rua, com o dinheiro do jogo (Config.Money).
	`GearStock.unlimited` = true poe tudo sem limite, para testes.
]]
Config.GearStock = {
	unlimited = false,
}

--[[
	O dinheiro do jogo: Escudos (mostram-se como 25$). Ganha-se a jogar (o
	salario no fim de cada jogo, a recompensa diaria, roubar caixas) e gasta-se
	nos dealers da rua. Nao se compra com Robux.
]]
Config.Money = {
	start = 50, -- quem entra pela primeira vez
	perMatch = 20, -- cada pessoa de claque no apito inicial
	perCorteo = 30, -- a mais, por ter feito o corteo inteiro (proporcional)
	perGoal = 5, -- cada golo da propria equipa
}

--[[
	Niveis e salarios. Tres caminhos que nao se misturam: adepto, jogador e
	arbitro. Todo o XP e dinheiro e contado no servidor (Progress, Profile).

	Para passar do nivel n ao n+1 precisa-se de xpBase + xpStep * (n - 1) XP;
	do 1 ao 30 sao ~13 000 XP, uns 40 a 50 jogos.

	REGRA: o nivel de jogador nunca o torna melhor a jogar. So da coisas que
	se veem ou escolhas (numero, posicao, bracadeira).
]]
Config.Progress = {
	maxLevel = 30,
	xpBase = 100,
	xpStep = 25,

	-- Estar "ativo": ter-se mexido pelo menos isto nos ultimos `activeWindow`
	-- segundos, ou ter feito alguma coisa (tambor, tocha, chuto...). Parado nao
	-- ganha XP de bancada nem de minutos.
	activeWindow = 90,
	activeDistance = 6,

	adepto = {
		corteoTick = 10, -- de quantos em quantos segundos se conta o corteo
		corteoNear = 12, -- a esta distancia da faixa...
		corteoNearXP = 4,
		corteoFar = 25, -- ...ou a esta
		corteoFarXP = 2,
		corteoCap = 60,
		standTick = 30, -- na bancada durante o jogo
		standXP = 2,
		standCap = 60,
		kickoffXP = 20, -- na bancada no apito inicial
		pyroXP = 15, -- tocha ou fumo no momento certo
		pyroCap = 3,
		pyroMoment = 20, -- segundos depois de um golo da equipa
		loudAt = 0.6, -- ambiente medio da claque no jogo
		loudXP = 40,
		louderAt = 0.8,
		louderXP = 70,
	},
	jogador = {
		minuteXP = 10,
		goalXP = 50,
		assistXP = 30,
		assistWindow = 8,
		stealXP = 8,
		stealCap = 10,
		saveXP = 15,
		saveCap = 10,
		winXP = 40,
		drawXP = 20,
	},
	arbitro = {
		fullMatchXP = 150, -- proporcional aos minutos, com pelo menos metade
		rightCallXP = 15, -- decisao igual a do arbitro automatico
		cleanXP = 100, -- acabar sem ser apanhado
	},

	-- O salario, no fim de cada jogo, a quem participou.
	salary = {
		adepto = { base = 20, perLevel = 1, minXP = 30 }, -- mais o corteo (Money.perCorteo)
		jogador = { base = 30, perLevel = 2, perGoal = 10, minMinutes = 3 },
		arbitro = { base = 40, perLevel = 3 }, -- com pelo menos metade do jogo apitado
	},

	-- O que cada nivel da. Adepto: material e direitos na claque.
	perks = {
		tochaAt = { 5, 15, 25 }, -- mais uma tocha por jogo em cada um
		fumoAt = { 10, 20 },
		velaAt = { 30 },
		bannerAt = 8, -- pode segurar a faixa do corteo
		bigFlareAt = 12, -- tocha grande
		longCandleAt = 18, -- vela romana com 15 tiros
		longCandleShots = 15,
		exclusiveColoursAt = 25, -- dourado e prateado na loja
		-- Jogador: so coisas que se veem ou escolhas.
		numberAt = 3,
		positionAt = 5,
		bootsAt = 7,
		captainAt = 10,
		celebrationAt = { 12, 20 },
		nameAt = 15,
		goldBootsAt = 30,
	},

	-- A recompensa diaria: dia 1 a 7 seguidos (depois volta ao 1).
	daily = { 20, 30, 40, 50, 60, 80, 120 },
}

-- As cores das botas (nivel de jogador 7).
Config.BootColours = {
	{ name = "Black", color = Color3.fromRGB(24, 24, 26) },
	{ name = "White", color = Color3.fromRGB(240, 240, 240) },
	{ name = "Red", color = Color3.fromRGB(210, 40, 40) },
	{ name = "Blue", color = Color3.fromRGB(40, 100, 220) },
	{ name = "Green", color = Color3.fromRGB(40, 170, 80) },
	{ name = "Orange", color = Color3.fromRGB(255, 130, 30) },
	{ name = "Pink", color = Color3.fromRGB(255, 100, 180) },
}

--[[
	A academia: o campo de treino onde quem joga aparece antes do jogo, a norte
	do estadio. Dali o autocarro da equipa leva-os ao estadio no corteo.
	(O edificio vive no mapa, em Workspace.Academia: AcademyBuilder.)
]]
Config.Academy = {
	centre = Vector3.new(40, 0, 510), -- o meio do relvado de treino
	pitchLength = 110, -- ao longo de X
	pitchWidth = 64, -- ao longo de Z
	groundY = 0.3, -- o passeio do quarteirao
	goalHalfWidth = 8,
	goalHeight = 8.4,
	goalDepth = 6,
	kickSpeed = 70, -- a bola de treino, com a barra toda
	keeperSpeed = 13, -- o guarda-redes de treino, a acompanhar a bola
	boardingTime = 45, -- segundos com o autocarro da equipa de portas abertas
}

--[[
	Uma academia por clube (as medidas de cima valem para as duas). `turn`
	vira-a ao contrario, para a entrada dar para a rua do lado do estadio.
]]
Config.Academies = {
	home = { centre = Vector3.new(40, 0, 510), turn = false }, -- a norte do estadio
	away = { centre = Vector3.new(-40, 0, -681.5), turn = true }, -- a sul (o edificio fica antes da loja e do cafe)
}

--[[
	Os autocarros. Andam sozinhos pelos percursos do mapa
	(Workspace.Transportes.Rotas, que se mexem no Studio) e param nas
	paragens que ficam ao lado deles. Conduz-se pela direita.
]]
Config.Transit = {
	cruise = 26, -- studs/s em recta
	turnSpeed = 9, -- nas curvas
	accel = 6, -- studs/s2 a arrancar
	brake = 10, -- a travar
	dwell = 9, -- segundos parado numa paragem, de portas abertas
	laneOffset = 6.5, -- do meio da rua ao meio da faixa
	cornerRadius = 15, -- o raio das curvas nos cruzamentos (autocarros de 50)
	stopReach = 16, -- uma paragem a esta distancia da faixa serve o percurso
}

-- As bicicletas das sedes: a velocidade de quem pedala (a pe e 16).
Config.Bikes = {
	speed = 34,
}

-- Quantos dealers ha na rua, se o mapa nao tiver pecas "Dealer" a dizer onde.
Config.Dealers = {
	count = 6,
}

-- O que os dealers vendem, e quanto custa cada um.
Config.Shop = {
	{ kind = "tocha", label = "Flare", price = 10, about = "Live flame and smoke. Burns for 25 seconds." },
	{ kind = "fumo", label = "Smoke bomb", price = 15, about = "A thick cloud seen from the other end." },
	{ kind = "estrobo", label = "Strobe", price = 12, about = "Flashing white, it dazzles the stand." },
	{ kind = "vela", label = "Roman candle", price = 25, about = "Ten fireballs, one per click." },
	{ kind = "bandeira", label = "Big flag", price = 40, about = "Two poles, over the fence. Yours for the whole match; whoever waves it stays in place." },
}

-- Quantas de uma vez: o pack de 5 sai mais barato (paga-se 4).
Config.ShopPacks = {
	{ amount = 1, pay = 1 },
	{ amount = 5, pay = 4 },
}

--[[
	As cores a escolher no dealer. "Team" e a cor da claque; as outras
	ficam a valer para esse material ate se escolher outra.
]]
Config.PyroColours = {
	{ name = "Team", color = nil :: Color3? },
	{ name = "Red", color = Color3.fromRGB(226, 36, 36) :: Color3? },
	{ name = "Orange", color = Color3.fromRGB(255, 122, 20) :: Color3? },
	{ name = "Yellow", color = Color3.fromRGB(255, 214, 40) :: Color3? },
	{ name = "Green", color = Color3.fromRGB(40, 196, 80) :: Color3? },
	{ name = "Blue", color = Color3.fromRGB(40, 110, 240) :: Color3? },
	{ name = "Purple", color = Color3.fromRGB(150, 60, 220) :: Color3? },
	{ name = "Pink", color = Color3.fromRGB(255, 90, 170) :: Color3? },
	{ name = "White", color = Color3.fromRGB(245, 245, 245) :: Color3? },
	-- So a partir do nivel 25 de adepto (Config.Progress.perks.exclusiveColoursAt).
	{ name = "Gold", color = Color3.fromRGB(255, 196, 60) :: Color3?, exclusive = true },
	{ name = "Silver", color = Color3.fromRGB(200, 208, 220) :: Color3?, exclusive = true },
}

Config.Gear = {
	tocha = {
		perMatch = 2,
		duration = 25, -- a arder na mao; os ultimos `fade` segundos a morrer
		fade = 5,
		cooldown = 2, -- depois de apagar, ate se poder acender a seguinte
		gainPerSecond = 2.4,
	},
	fumo = {
		perMatch = 1,
		duration = 30, -- dura mais e ve-se melhor de longe, mas aquece menos
		fade = 8,
		jet = 3, -- segundos de jacto forte antes de abrir em nuvem
		cooldown = 3,
		gainPerSecond = 1.5,
	},
	vela = {
		perMatch = 1, -- a sede da uma; mais, so aos dealers
		duration = 40, -- acesa ate gastar os tiros (um por clique) ou ate isto
		cooldown = 3,
		gainPerSecond = 3,
	},
	estrobo = {
		perMatch = 1,
		duration = 15, -- pisca-pisca branco
		cooldown = 2,
		gainPerSecond = 1.8,
	},
	bandeirinha = {
		perMatch = 1, -- de toda a gente; nao se gasta
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 0.4, -- a agitar
	},
	mastro = {
		perMatch = 1, -- so ha uma por claque: quem o lider escolher
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 2.2, -- a agitar
	},
	bandeira = {
		perMatch = 0, -- a de duas hastes: so do dealer ou dada pelo lider; nao se gasta
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 1.2, -- a agitar
	},
	cachecol = {
		perMatch = 1, -- nao se gasta: levanta-se e baixa-se
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 0.3, -- enquanto roda no ar
	},
	tambor = {
		perMatch = 1, -- so um, e fica para o jogo todo
		duration = math.huge,
		cooldown = 0,
		gainPerSecond = 0, -- nao aquece sozinho: tem de se bater ao ritmo
		chantMultiplier = 2.2, -- e ai vale por dois
	},
}

--[[
	Os tifos: um mosaico de cartolinas por cima do bloco da claque.

	O lider escolhe o desenho e dispara; cada um no bloco recebe a cartolina da
	cor do seu lugar e levanta-a. O lugar de quem nao levanta fica um buraco no
	desenho — ve-se de longe quem nao esteve.

	Vale pelo MOMENTO. Um tifo e para o apito inicial ou para o golo, nao para
	meio da segunda parte: nessas janelas da o dobro, fora delas da metade.
	E isso que torna disparar uma decisao do lider e nao um botao a toa.
]]
Config.Tifo = {
	perMatch = 4, -- por claque, e renova-se no aquecimento
	countdown = 3, -- segundos de aviso antes de subir
	duration = 12, -- quanto tempo fica no ar
	gainPerSecond = 3, -- ambiente por segundo enquanto esta no ar
	momentWindow = 20, -- segundos depois do apito inicial ou de um golo nosso
	momentMultiplier = 2, -- na janela certa
	offMomentMultiplier = 0.5, -- fora dela
	crowdShare = 0.5, -- a parte do efeito que a bancada ja da sozinha; o resto e de quem levanta

	-- A grelha, sobre o bloco do meio da bancada: colunas ao longo dela, filas
	-- a partir desta, para cima.
	columns = 14,
	rows = 8,
	firstRow = 2,
	liftHeight = 6.6, -- a que altura acima do degrau fica a cartolina

	--[[
		Os desenhos. Cada linha e uma fila de cartolinas vista do relvado, de cima
		para baixo e da esquerda para a direita:

			E  cor da equipa
			B  branco
			P  preto

		Com `initials`, o desenho e gerado a partir da sigla da equipa. Com
		`message`, sai uma frase por cima (%TEAM% vira o nome da claque).
	]]
	designs = {
		{
			id = "riscas",
			name = "Stripes",
			rows = {
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
				"EEBBEEBBEEBBEE",
			},
		},
		{
			id = "iniciais",
			name = "Initials",
			initials = true,
		},
		{
			id = "estrela",
			name = "Star",
			rows = {
				"EEEEEEBBEEEEEE",
				"EEEEEBBBBEEEEE",
				"BBBBBBBBBBBBBB",
				"EBBBBBBBBBBBBE",
				"EEBBBBBBBBBBEE",
				"EEEBBBBBBBBEEE",
				"EEBBBBEEBBBBEE",
				"EBBBEEEEEEBBBE",
			},
		},
		{
			id = "emblema",
			name = "Emblem", -- a aguia (AGN) ou o leao (LES)
			emblem = true,
		},
		-- Frases: a cor da equipa, e a frase por cima em letras gigantes.
		{
			id = "frase_aqui",
			name = "Aqui mandamos nos",
			message = "AQUI MANDAMOS NÓS",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_pesadelo",
			name = "O vosso pesadelo chegou",
			message = "O VOSSO PESADELO CHEGOU",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_sempre",
			name = "Sempre contigo",
			message = "SEMPRE CONTIGO",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_fim",
			name = "Ate ao fim",
			message = "ATÉ AO FIM",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_equipa",
			name = "Ultras name",
			message = "%TEAM%",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
		{
			id = "frase_ultras",
			name = "Ultras",
			message = "ULTRAS",
			rows = {
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
				"EEEEEEEEEEEEEE",
			},
		},
	},
}

--[[
	THE FUTURE: switches only, all off. Nothing is built behind them yet; they
	are here so that nothing in the code gets in their way.
]]
Config.Futuro = {
	presidente = false,
	atributos = false,
	transferencias = false,
	treinadores = false,
	segundoEstadio = false,
	roupaDeClaque = false,
	var = false,
	taca = false,
}

return Config
