# Ultras FC — Fase 1

Um jogo de Roblox onde **ser adepto é o jogo** e o futebol é o pano de fundo.

Esta é a fatia mais pequena que ainda prova a ideia: duas bancadas, escolher
equipa, cantar ao compasso para encher a barra de ambiente, e um jogo de NPCs
cujo resultado é inclinado por essa barra.

Sem liga, sem economia, sem presidente. Isso vem depois — e só se isto for
divertido.

## Pôr a correr

**1. Instalar o Rojo** (uma vez, no computador)

O Rojo liga esta pasta ao Roblox Studio: escreves ficheiros aqui, aparecem lá.

- Ferramenta: <https://rojo.space> (ou `cargo install rojo` / `aftman add rojo-rbx/rojo`)
- Plugin do Studio: no Rojo, `rojo plugin install`, ou pela loja de plugins

**2. Arrancar o servidor do Rojo**

```bash
cd ultras-fc
rojo serve
```

**3. Ligar no Studio**

Abre um place novo (Baseplate serve), separador **Rojo** → **Connect**.
Os scripts aparecem sozinhos em `ServerScriptService`, `ReplicatedStorage` e
`StarterPlayer`.

**4. Play**

Carrega em Play. Escolhes equipa, aparece o círculo dourado a pulsar — carrega
em **espaço** no momento da batida.

Para testar a sério, usa **Test → Players → 2 Players**: o bónus de minoria e a
disputa entre bancadas só se sentem com mais do que uma pessoa.

## Onde mexer

Quase tudo o que "sente mal" está em `src/shared/Config.luau`:

| Sintoma | Valor |
| --- | --- |
| A barra sobe rápido demais | `Atmosphere.gainPerHit` |
| A barra cai rápido demais | `Atmosphere.decayPerSecond` |
| É difícil acertar no compasso | `Beat.window` |
| Poucos golos | `Match.baseGoalChance` |
| Cantar não parece fazer diferença | `Match.atmosphereSwing` |
| As partes são longas | `Match.halfLength` |

## Os ficheiros

```
src/shared/Config.luau      Números de afinação
src/shared/Remotes.luau     Os RemoteEvents, num sítio só
src/server/Teams.luau       Quem apoia quem, e o bónus de minoria
src/server/Atmosphere.luau  A barra de ambiente
src/server/MatchLoop.luau   Fases, relógio, lances e golos
src/server/Main.server.luau Arranque e ligação dos módulos
src/client/Chant.client.luau  HUD, compasso e input
```

## Som

Falta só o som, e é o que mais se nota. Abre `src/client/Chant.client.luau` e
preenche a tabela `SOUNDS` no topo com ids de áudio do Roblox:

```lua
local SOUNDS = {
	drum = "rbxassetid://123456789",
	perfect = "",
	hit = "",
	miss = "",
	goal = "",
}
```

Vazios, o jogo funciona na mesma — só em silêncio. **Começa pelo `drum`:** é ele
que marca o compasso. Sem som, o ritmo tem de se ler no círculo, o que é bem
mais difícil do que ouvi-lo.

## Ainda por fazer

- **Um estádio a sério.** O que existe são peças soltas para haver um sítio.
  Quando construíres o teu à mão, põe `Config.Stadium.build` a `false` para o
  código não to apagar.
- **Cânticos com letra**, tifos, tochas, corteo — a Fase 2.
- **Testar a dois.** O bónus de minoria e a disputa entre bancadas só se sentem
  com mais do que uma pessoa: **Test → Players → 2 Players**.
