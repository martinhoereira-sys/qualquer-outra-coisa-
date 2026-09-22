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

## Ainda por fazer

- **O estádio.** Não há relvado nem bancadas — isso constrói-se à mão no Studio.
  O código não depende da geometria, por isso podes montar o espaço a teu gosto.
- **Spawn na bancada certa.** Escolher equipa ainda não te leva para o teu lado.
- **Som.** Cânticos e tambores. É metade do efeito e está por pôr.
- **Testar.** Este código nunca correu — foi escrito fora do Studio. Conta com
  erros na primeira vez que carregares em Play.
