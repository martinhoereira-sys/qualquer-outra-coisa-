# Ultras FC — estado do jogo (6 de Outubro de 2026)

Texto para dar contexto a outro Claude. Descreve o que o jogo é, o que já funciona, o que falta e para onde vai.

## O que é

Ultras FC é um jogo de Roblox sobre ser ultra de um clube, não sobre jogar à bola. A pessoa escolhe um clube, que fica seu, e vive o dia de jogo: sede, cortejo pelas ruas, bancada, pirotecnia, cânticos. Também pode jogar em campo ou apitar, mas o centro é a claque.

É feito por duas pessoas (Team Create). O código está em Luau, sincronizado com o Studio por Rojo, e toda a lógica que conta é verificada no servidor. O texto do jogo é em inglês; os nomes de clubes, claques e lemas ficam na língua de cada clube.

## O mundo

- **Dez clubes inventados, em cinco derbies de cidade**: Luz SC e Alvalade SC (Lisboa), Nervión CF e Triana Balompié (Sevilla), Testaccio e Flaminio (Roma), Athinaikos e Pireus FC (Athina), Galata SK e Kadiköy SK (Istanbul). Não copiam nomes, emblemas nem cânticos de clubes reais.
- Cada clube tem emblema feito de formas, equipamento principal e alternativo, fato de ultra todo preto (capuz, máscara e cachecol na cor do clube), claque com nome, lema e faixas.
- **Uma cidade** com ruas, lojas, dealers de pirotecnia, Multibanco, bicicletas e autocarros, **um estádio grande** ao centro, e **um recinto por clube** com sede e campo de treino.

## Como se joga

- **Relógio real**: das 09:00 à 01:00 há um jogo oficial de 20 em 20 minutos (15 de jogo, 5 de intervalo). De madrugada só há amigáveis nos campos de treino.
- **Antes do jogo**: os ultras juntam-se na sede e marcham em cortejo até ao estádio; os jogadores aquecem no campo de treino do clube e vão no autocarro da equipa.
- **No estádio**: a claque tem uma barra de ambiente que sobe com o apoio — tochas, fumos, estrobos, velas romanas, bandeira de mastro, tambor, tifo em pano, saltos e palmas ao compasso.
- **O líder da claque (capo)** escolhe os cânticos, dá material e manda ordens (formar, marchar, saltar, acender...). Nunca obriga ninguém: as pessoas recebem um aviso e decidem.
- **Em campo**: equipas de quatro mais guarda-redes, com faltas, cartões, foras de jogo e reposições. O árbitro pode ser uma pessoa; é do jogo, não de um clube.

## Papéis e clubes de cada pessoa

- Na primeira vez pergunta-se o que a pessoa quer ser (ULTRA, PLAYER ou REFEREE) e depois o clube.
- Cada pessoa pode ter até três clubes: um como ultra, e um primeiro e um segundo como jogador. Acrescentam-se no perfil com um botão.
- O clube da claque só muda na sede do outro clube, em pessoa. O rival de um dos meus clubes nunca pode ser outro dos meus clubes.
- Quem muda de clube da claque para o rival fica **traidor** durante alguns jogos: faixa por cima da cabeça e remate mais fraco.
- Ninguém apita um jogo em que entre um dos seus clubes.

## Gemellaggio (8 de Outubro de 2026 — escrito, AINDA NÃO TESTADO em Play)

Duas claques de cidades diferentes que são amigas são "gemellate" (nunca se diz "irmãs").

- **Pares**: Luz ↔ Galata, Alvalade ↔ Athinaikos, Nervión ↔ Pireus, Flaminio ↔ Kadiköy, Testaccio ↔ Triana. Nenhum par é de rivais de cidade.
- **No Config só há duas coisas por clube**: a cidade (o outro clube da cidade é o rival) e `gemellati`. Os **inimigos são calculados** (`Config.enemiesOf`): o meu rival e o rival dos meus gemellati. Não há lista de inimigos escrita.
- **Convidado**: no menu dos papéis, ao lado de ULTRA, há "GUEST OF <gemellati>". Vou para a curva deles nos jogos deles, com o MEU fato e o MEU material, conto para a barra deles e sigo o capo deles (um convidado nunca é capo). Continuo do meu clube (atributo `Convidado`). Se o meu clube está no jogo (também quando os dois gemellati se defrontam), cada um fica na sua curva. Os jogos dos gemellati aparecem destacados no meu horário.
- **Cachecol e bandeira de gemellaggio** (as únicas coisas que misturam dois clubes; um só modelo que lê os dois clubes do Config): só aparecem no inventário (1) como convidado na curva deles, (2) quando o meu clube joga contra o RIVAL dos meus gemellati. Decide o servidor (`Gear.sync`, atributo `Gemellaggio`).
- **Cortejos que se cruzam** (`March`, `Config.Gemellaggio`): nunca há luta. Gemellati: param, ficam frente a frente e cantam juntos uns segundos. Inimigos: param frente a frente, uma linha de stewards no meio, tochas acesas, meio minuto, e seguem. Os outros: nada. Uma vez por cortejo, só enquanto as duas faixas estão em marcha e a menos de `meetDistance`.
- **Perfil** (MY CLUB): linhas RIVAL / GEMELLATI / ENEMIES. No cartão do clube: rival e gemellati.
- **Mapa** (8 de Outubro): os gemellati estão lado a lado e as portas das duas sedes dão para a rua entre elas (`site.door`): Alvalade 9_1 + Athinaikos 8_1, Nervión 2_2 + Pireus 3_2, Triana 8_7 + Testaccio 9_7, Kadiköy 4_1 + Flaminio 5_1 (ponta oeste). Falta o Galata, que ainda está em 4_4: tem de ficar ao lado da Luz (1_8), mas em 1_7 o campo não cabe ao lado da loja de conveniência, que não se tira. Só se removem casas genéricas "Predio".

## Áudios

- **Cânticos do Alvalade** (`Config.Chants.clubs.alvalade`): "Nunca vais acabar" 121342319651900 (31 s, 2×), "Onde tu fores jogar eu vou lá estar" 123151187163093 (84 s, 1×), "O nosso grande amor" 119491230940361 (24 s, 2×).
- **Som de golo** (`Config.Chants.goalSounds`): é do clube, não uma lista global. Só o Alvalade tem (119617651245949, 13 s): toca uma vez, para o estádio todo, só quando o Alvalade marca. Clube sem som de golo: não toca nada.

## Competições

- **Liga**: duas voltas, 36 jornadas; fecha sábado à noite com campeão e cerimónia do troféu.
- **Taça**: dois grupos, meias-finais e final ao sábado. **Supertaça** ao domingo às 21:00.
- Às :00 e :20 joga-se liga, às :40 taça. Cada servidor joga o jogo em falta que junta mais gente.
- Classificações, resultados e títulos ficam guardados e são iguais em todos os servidores.

## Progresso

- Três caminhos de nível (adepto, jogador, árbitro). O nível de jogador nunca melhora o jogo de ninguém, só a aparência.
- Dinheiro do jogo (escudos): salário no fim de cada jogo, golos da equipa, recompensa diária.
- O perfil de cada pessoa (clubes, níveis, dinheiro) fica gravado e volta quando ela entra de novo.

## O que é provisório

- **Os bonecos de adeptos nas bancadas** existem só para mostrar o jogo enquanto há pouca gente. Vão ser todos retirados mais tarde.
- Só o Alvalade tem cânticos próprios; os outros clubes usam sons de tambores.
- As duas sedes mais antigas (Luz e Alvalade) foram feitas à mão e ainda não são iguais às novas.

## O que falta fazer a seguir

1. Sedes: telhado na cor do clube, entrada em todas, as duas antigas iguais às novas, bicicletas e NPCs (capo e loja) em todas.
2. Campos de treino maiores, bons para amigáveis.
3. A bancada da claque só enche, e o fumo só começa, quando o cortejo chega.
4. Ver em telemóvel os ecrãs novos, e testar com contas a sério o percurso de traidor.

## Para onde vai

- Sem bonecos de adeptos: bancadas só com pessoas.
- O estádio grande fechado quando não há jogo: sem adeptos nem jogadores lá dentro.
- A academia de cada clube como um sítio a sério, ao lado da sede: física da bola igual à do jogo oficial, luzes, bem organizada, com espaço para tudo.
