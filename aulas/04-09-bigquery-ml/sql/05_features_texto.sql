-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 5: NLP QUE FUNCIONA — arrancar features do texto
-- =====================================================================
--
-- O modelo do script 3 chegou em R2 0,30. Melhorou 5x em relacao ao
-- de 28/08, mas ainda erra R$ 2,58 milhoes em media.
--
-- A pergunta do professor Savio:
--
--     "Sera que o texto do anuncio nao explica parte do preco?
--      Um lugar requintado, com piscina, mobiliado — isso justifica
--      valor. Da pra tirar isso do titulo?"
--
-- Da. E este script mede se vale a pena. NAO acredite na hipotese
-- porque ela e razoavel: MECA.
--
-- COMO USAR: troque SEU_PROJETO. Requer anuncios_gold (script 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Testar a hipotese ANTES de treinar qualquer coisa
-- ---------------------------------------------------------------------
-- Regra de ouro da engenharia de features: uma feature custa tempo,
-- risco e complexidade. Antes de criar, pergunte se ela separa o
-- dado. Duas linhas de SQL respondem.

SELECT
  COUNTIF(REGEXP_CONTAINS(LOWER(titulo), r'piscina'))                    AS anuncios_com_piscina,
  ROUND(AVG(IF(REGEXP_CONTAINS(LOWER(titulo), r'piscina'), preco, NULL)))     AS preco_medio_com,
  ROUND(AVG(IF(NOT REGEXP_CONTAINS(LOWER(titulo), r'piscina'), preco, NULL))) AS preco_medio_sem
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- RESULTADO MEDIDO:  31  |  10.035.666  |  10.788.561
--
-- [PARE AQUI. Deixe a turma ler o numero.]
--
-- Imovel COM piscina no titulo e, em media, MAIS BARATO que imovel
-- sem. A hipotese mais obvia do mundo — "piscina valoriza" — sai
-- NEGATIVA no teste bruto.
--
--   "A intuicao do especialista e uma HIPOTESE, nao um fato.
--    Ela entra no pipeline depois de passar no teste, nao antes."
--
-- Mas segure a conclusao: o teste bruto compara piscina contra TUDO —
-- galpao, fazenda, lote, apartamento. Esta comparando coisas que nao
-- se comparam. Guarde: e exatamente isso que o PASSO 2 conserta.


-- ---------------------------------------------------------------------
-- PASSO 2 — A feature que a silver perdeu: QUE COISA e essa?
-- ---------------------------------------------------------------------
-- Lembra do que morreu no caminho raw -> silver? A coluna tipo_imovel.
-- Um lote e um apartamento estao na mesma tabela, com o mesmo schema,
-- e o modelo nao tem como saber que sao mercados diferentes.
--
-- O titulo sabe. Sempre soube.

SELECT
  REGEXP_CONTAINS(LOWER(titulo), r'apartamento|apto|studio|kitnet|flat') AS eh_apartamento,
  REGEXP_CONTAINS(LOWER(titulo), r'casa|sobrado|mans[aã]o')              AS eh_casa,
  REGEXP_CONTAINS(LOWER(titulo), r'lote|terreno|[aá]rea |fazenda|ch[aá]cara|s[ií]tio|rural') AS eh_terreno,
  COUNT(*)                                                   AS anuncios,
  ROUND(APPROX_QUANTILES(preco, 100)[OFFSET(50)])            AS mediana_preco,
  ROUND(APPROX_QUANTILES(preco / area_util, 100)[OFFSET(50)]) AS mediana_reais_por_m2
FROM `SEU_PROJETO.anuncios.anuncios_gold`
GROUP BY 1, 2, 3
ORDER BY anuncios DESC;

-- RESULTADO MEDIDO (as quatro linhas que importam):
--
--   casa        352 anuncios   mediana R$  8.990.000   R$ 16.049/m2
--   nenhum      312 anuncios   mediana R$  9.000.000   R$ 14.388/m2
--   apartamento 101 anuncios   mediana R$  8.015.000   R$ 18.000/m2
--   terreno      91 anuncios   mediana R$ 10.780.000   R$  4.001/m2
--
-- ESTE e o numero da aula:
--
--   Pelo PRECO, terreno e o mais caro dos quatro (R$ 10,7 mi).
--   Pelo PRECO POR M2, terreno custa R$ 4.001 e apartamento
--   R$ 18.000 — QUATRO VEZES MAIS.
--
--   "Terreno e caro porque e grande, nao porque o metro vale muito.
--    O modelo so tinha a area para trabalhar: para ele, area grande
--    virava preco alto, viesse de um lote de chacara ou de uma
--    cobertura no Bueno. Faltava dizer QUE COISA e aquilo."
--
-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
--   Os tres REGEXP_CONTAINS viram TRUE/FALSE e entram no GROUP BY:
--   cada combinacao de flags e um grupo. Por isso aparecem linhas
--   com dois TRUE (um titulo pode dizer "casa em lote de 700m2").
--
--   APPROX_QUANTILES(x, 100)[OFFSET(50)] = mediana. Por que mediana
--   e nao AVG? Script 1: media mente quando existe cauda longa.
--
--   preco / area_util dentro do quantil: normaliza o tamanho e faz a
--   comparacao entre grupos ser justa. Comparar preco cru entre um
--   lote de 5.000 m2 e um apto de 60 m2 nao diz nada.
--
--   PERGUNTA: por que 312 anuncios ficam em "nenhum"?
--   (Resposta: titulos como "Imovel para venda possui 5637 metros
--    quadrados com 3 quartos" — o texto nao nomeia o tipo. Cobertura
--    de regex nunca e 100%, e esta bem assim: 65% classificado ja
--    muda o modelo.)
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 3 — A tabela com as features de texto
-- ---------------------------------------------------------------------
-- Seis colunas novas. Tres de TIPO (que coisa e) e tres de
-- QUALIDADE (o que ela tem). Nenhuma delas usa o preco.

CREATE OR REPLACE TABLE `SEU_PROJETO.anuncios.gold_texto` AS
SELECT
  *,
  -- QUALIDADE: a hipotese do Savio
  REGEXP_CONTAINS(LOWER(titulo), r'piscina')                               AS tem_piscina,
  REGEXP_CONTAINS(LOWER(titulo), r'alto padr[aã]o|luxo|requintad|exclusiv') AS eh_alto_padrao,
  REGEXP_CONTAINS(LOWER(titulo), r'mobiliad|armári|armari|planejad')       AS tem_mobilia,

  -- TIPO: a coluna que a silver perdeu, reconstruida do texto
  REGEXP_CONTAINS(LOWER(titulo), r'lote|terreno|[aá]rea |fazenda|ch[aá]cara|s[ií]tio|rural') AS eh_terreno,
  REGEXP_CONTAINS(LOWER(titulo), r'apartamento|apto|studio|kitnet|flat')   AS eh_apartamento,
  REGEXP_CONTAINS(LOWER(titulo), r'casa|sobrado|mans[aã]o')                AS eh_casa
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- Conferindo a cobertura de cada uma:
SELECT
  COUNT(*)                  AS total,
  COUNTIF(tem_piscina)      AS piscina,
  COUNTIF(eh_alto_padrao)   AS alto_padrao,
  COUNTIF(tem_mobilia)      AS mobilia,
  COUNTIF(eh_terreno)       AS terreno,
  COUNTIF(eh_apartamento)   AS apartamento,
  COUNTIF(eh_casa)          AS casa
FROM `SEU_PROJETO.anuncios.gold_texto`;

-- RESULTADO MEDIDO: 887 | 31 | 80 | 51 | 120 | 104 | 382
--
-- Repare na assimetria: casa aparece em 382 titulos, piscina em 31.
-- Uma feature que existe em 3,5% das linhas dificilmente move a
-- metrica geral — e o script 6 vai mostrar por que isso importa.


-- ---------------------------------------------------------------------
-- PASSO 4 — Retreinar: mesmo algoritmo, seis colunas a mais
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_preco_v3`
OPTIONS (
  model_type            = 'LINEAR_REG',   -- IGUAL ao script 3
  input_label_cols      = ['preco'],      -- IGUAL ao script 3
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  preco,
  area_util, quartos, banheiros, suites, garagem, condominio, iptu,
  bairro, eh_comercial,
  -- <<< a unica diferenca para o modelo_preco: estas seis
  tem_piscina, eh_alto_padrao, tem_mobilia,
  eh_terreno, eh_apartamento, eh_casa
FROM `SEU_PROJETO.anuncios.gold_texto`;


-- ---------------------------------------------------------------------
-- PASSO 5 — O placar dos tres modelos
-- ---------------------------------------------------------------------
SELECT 'v0_dado_como_estava' AS modelo, mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_imoveis`)
UNION ALL
SELECT 'v1_gold_limpa', mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco`)
UNION ALL
SELECT 'v3_gold_mais_texto', mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_v3`)
ORDER BY r2_score;

-- RESULTADO MEDIDO (pdm-2026-gui):
--
--   v0_dado_como_estava   MAE 13.835.427   R2  -0,350
--   v1_gold_limpa         MAE  2.581.138   R2  +0,298
--   v3_gold_mais_texto    MAE  2.469.775   R2  +0,471
--
--   Limpeza (v0 -> v1):  o erro caiu 5,4x
--   Texto   (v1 -> v3):  o R2 subiu 58% (0,298 -> 0,471)
--
--   "Nenhum dos dois saltos veio de trocar de algoritmo. Os tres
--    modelos sao LINEAR_REG. O primeiro salto foi jogar lixo fora.
--    O segundo foi contar ao modelo QUE COISA ele esta avaliando.
--    Isso e engenharia de dados, nao machine learning."


-- ---------------------------------------------------------------------
-- PASSO 6 — Quem pesou (e a volta da piscina)
-- ---------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_preco_v3`)
ORDER BY attribution DESC;

-- RESULTADO MEDIDO (topo da lista):
--
--   bairro          1.168.812
--   eh_comercial    1.157.458
--   tem_mobilia     1.131.424
--   tem_piscina     1.128.073      <<< a mesma piscina do PASSO 1
--   eh_casa         1.127.408
--   eh_alto_padrao  1.124.132
--   eh_terreno      1.119.474
--   eh_apartamento  1.118.170
--   garagem           475.197
--   area_util         334.058
--
-- As SEIS features de texto ficaram acima de area_util. E a piscina,
-- que no teste bruto parecia inutil (ate negativa), virou uma das
-- colunas que mais pesam.
--
--   "No PASSO 1 a piscina competia contra fazenda e galpao. Aqui ela
--    entra JUNTO com o tipo e o bairro: o modelo ja sabe que e um
--    apartamento no Bueno, e ai a piscina finalmente responde a
--    pergunta certa — 'entre dois apartamentos parecidos, a piscina
--    muda o preco?'.
--    Feature nao se avalia sozinha. Se avalia dentro do modelo."


-- ---------------------------------------------------------------------
-- FECHAMENTO
-- ---------------------------------------------------------------------
--   Tudo que acabamos de fazer saiu de UMA coluna de texto que ja
--   estava na tabela desde a primeira aula. Sem GPU, sem embedding,
--   sem LLM: REGEXP_CONTAINS e uma pergunta de negocio.
--
--   E as seis features tem uma propriedade que o script 6 vai
--   destruir: TODAS existem ANTES da venda. Piscina, tipo, mobilia
--   sao atributos do imovel — nao dependem de alguem ja saber o
--   preco. Segure essa frase.


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Sua vez de levantar hipotese: "vista", "nascente", "esquina",
--    "reformado", "novo", "condominio fechado". Rode o teste do
--    PASSO 1 em cada uma, escolha as que separam o dado, adicione ao
--    modelo e MECA. Ganhou R2? Perdeu?
-- 2) O PASSO 2 deixou 312 anuncios sem tipo nenhum. Leia 20 desses
--    titulos e proponha regras novas. Quanto a cobertura sobe?
-- 3) eh_casa e eh_apartamento podem ser TRUE ao mesmo tempo (2 casos).
--    Isso e um problema? Como voce faria uma coluna UNICA de tipo com
--    CASE WHEN, e em que ordem testaria as regras?
-- 4) Treine um v3 SO com as tres features de TIPO e outro SO com as
--    tres de QUALIDADE. Qual grupo explica mais? O que isso diz sobre
--    onde investir o proximo esforco de feature engineering?
-- 5) Repita o PASSO 1 da piscina, mas so entre apartamentos
--    (WHERE eh_apartamento). A piscina valoriza agora? Este e o
--    controle de variavel que faltava no teste bruto.
