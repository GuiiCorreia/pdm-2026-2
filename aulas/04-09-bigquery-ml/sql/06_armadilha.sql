-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 6: VAZAMENTO DE ALVO — quando a metrica melhora pelo
--            motivo errado
-- =====================================================================
--
-- No script 5 as flags do titulo levaram o R2 de 0,30 para 0,47:
-- extrair informacao de texto funcionou. A extensao natural seria ir
-- mais fundo no mesmo texto — tem mais coisa escrita ali.
--
-- Este script segue esse caminho ate o fim e mostra por que, sem
-- criterio, ele produz um modelo com metrica boa e uso nenhum.
--
-- Rode os passos na ordem e leia o resultado de cada um antes de
-- passar para o seguinte.
--
-- COMO USAR: troque SEU_PROJETO. Requer anuncios_gold e modelo_preco.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Minerar o titulo
-- ---------------------------------------------------------------------
-- Alguns anunciantes escrevem o valor no proprio titulo. Extraia:

SELECT
  titulo,
  ROUND(preco) AS preco,
  REGEXP_EXTRACT(titulo, r'R\$\s*([\d\.]+(?:,\d+)?)') AS valor_no_titulo
FROM `SEU_PROJETO.anuncios.anuncios_gold`
WHERE REGEXP_CONTAINS(titulo, r'R\$')
LIMIT 15;

-- RESULTADO ESPERADO: 40 anuncios da Gold tem "R$" no titulo
-- (36 com valor parseavel — tem ate um "R$ .00" no meio).
-- Ex.: "GALPÃO À VENDA| 3044M² ÁREA CONSTRUÍDA| R$12.500.000,00"
--      e o preco da coluna e... 12500000. Exatamente.
--
-- =====================================================================
-- COMO LER — REGEXP_EXTRACT e o parse de numero sujo
-- =====================================================================
--   REGEXP_CONTAINS -> TRUE/FALSE (script 2)
--   REGEXP_EXTRACT  -> devolve O TRECHO que casou com o grupo (...)
--
-- So que o trecho e STRING, e o dado real escreve numero de DOIS
-- jeitos no mesmo dataset:
--     "R$ 8200000.00"      ponto decimal (formato americano)
--     "R$12.500.000,00"    ponto de milhar + virgula (formato BR)
-- Um REPLACE ingenuo quebraria um dos dois. Dai o CASE abaixo.
-- Texto e traicoeiro — ISSO tambem e NLP.
-- =====================================================================

CREATE OR REPLACE TABLE `SEU_PROJETO.anuncios.gold_com_titulo` AS
SELECT
  *,
  CASE
    -- tem virgula -> formato BR: tira pontos de milhar, virgula vira decimal
    WHEN REGEXP_EXTRACT(titulo, r'R\$\s*([\d\.]+(?:,\d+)?)') LIKE '%,%'
      THEN SAFE_CAST(REPLACE(REPLACE(
             REGEXP_EXTRACT(titulo, r'R\$\s*([\d\.]+(?:,\d+)?)'),
             '.', ''), ',', '.') AS FLOAT64)
    -- sem virgula -> formato americano: o ponto e decimal mesmo
    ELSE SAFE_CAST(
           REGEXP_EXTRACT(titulo, r'R\$\s*([\d\.]+(?:,\d+)?)') AS FLOAT64)
  END AS preco_no_titulo
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- Conferindo a mineracao:
SELECT
  COUNT(*)                                        AS total,
  COUNTIF(preco_no_titulo IS NOT NULL)            AS com_preco_no_titulo,
  COUNTIF(ABS(preco_no_titulo - preco) < preco * 0.02) AS valor_bate_com_preco
FROM `SEU_PROJETO.anuncios.gold_com_titulo`;

-- RESULTADO ESPERADO (medido):  887  |  36  |  33
--
-- Dos 36 titulos com valor parseavel, 33 batem com o preco real.
-- Guarde esse numero: ele explica o que acontece no passo 4.
-- (Entre os que nao batem: "R$13 Milhões" — a regex le "13". O texto
--  ate quando entrega, entrega mentindo. Guarde para o final.)


-- ---------------------------------------------------------------------
-- PASSO 2 — Retreinar com a feature nova
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_preco_v2`
OPTIONS (
  model_type            = 'LINEAR_REG',
  input_label_cols      = ['preco'],
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  preco,
  area_util,
  quartos,
  banheiros,
  suites,
  garagem,
  condominio,
  iptu,
  bairro,
  eh_comercial,
  preco_no_titulo    -- <<< a UNICA diferenca para o modelo_preco
FROM `SEU_PROJETO.anuncios.gold_com_titulo`;


-- ---------------------------------------------------------------------
-- PASSO 3 — Comparar os dois modelos
-- ---------------------------------------------------------------------
SELECT 'v1_sem_titulo' AS modelo, mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco`)
UNION ALL
SELECT 'v2_com_titulo', mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_v2`);

-- RESULTADO MEDIDO (pdm-2026-gui, 28/08):
--   v1_sem_titulo   MAE 2.581.138   R2 0,298
--   v2_com_titulo   MAE 2.595.485   R2 0,286
--
-- [SURPRESA DE CONDUCAO: o agregado NAO melhora — ate piora um fio.
--  A feature so existe em 4% das linhas; diluida no bolo, ela some
--  do ML.EVALUATE. NAO desanime nem encerre aqui: isso torna a demo
--  MELHOR. Um vazamento pode passar batido em TODA metrica agregada.
--  A prova mora no PASSO 4, nao aqui.]

SELECT *
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_preco_v2`)
ORDER BY attribution DESC;

-- MEDIDO: preco_no_titulo aparece com atribuicao MINUSCULA (~771,
-- contra 3,6 mi de eh_comercial). Com 96% de NULL, o peso medio
-- dilui — o explain global tambem NAO denuncia nada. A feature
-- parece inofensiva em toda visao agregada do modelo.
--
-- [Perguntar:]
--   "Empatou no EVALUATE e o explain diz que a coluna nao pesa.
--    Entao ela e inofensiva — pode deixar no modelo?"
--
-- Responda antes de rodar o passo 4.


-- ---------------------------------------------------------------------
-- PASSO 4 — Decompondo o erro em dois grupos
-- ---------------------------------------------------------------------
-- Agrupe o erro do v2 por "o titulo entregava o preco?":

SELECT
  preco_no_titulo IS NOT NULL            AS titulo_entregava_o_preco,
  COUNT(*)                               AS anuncios,
  ROUND(AVG(ABS(predicted_preco - preco))) AS erro_medio_absoluto
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.anuncios.modelo_preco_v2`,
  (SELECT * FROM `SEU_PROJETO.anuncios.gold_com_titulo`)
)
GROUP BY 1;

-- RESULTADO MEDIDO:
--   titulo_entregava = TRUE   ->  MAE 1.608.815   (36 anuncios)
--   titulo_entregava = FALSE  ->  MAE 2.646.722   (851 anuncios)
--
-- O v2 nao aprendeu a AVALIAR imovel nenhum. Ele aprendeu a LER o
-- preco quando o preco esta escrito — 1 milhao de reais a menos de
-- erro so nesse subgrupo — e continua errando igual quando nao
-- esta. O ML.EVALUATE nao viu NADA disso: o ganho inteiro mora nos
-- 4% de linhas onde a resposta estava colada na pergunta.
--
-- Isso tem nome: VAZAMENTO DE ALVO (target leakage).
--
--   "Em producao, todo imovel novo chega SEM preco — no titulo ou
--    em qualquer lugar. Se tivesse preco, voce nao precisaria do
--    modelo. O v2 e otimo em prever o passado."
--
-- E o detalhe cruel dos 3 que nao batiam: "R$13 Milhões" virou 13.
-- A feature vazada, alem de vazada, MENTE de vez em quando — o
-- anuncio de R$ 13,9 mi ganhou um "preco" de R$ 13,00. O modelo
-- engole os dois com a mesma confianca.


-- ---------------------------------------------------------------------
-- FECHAMENTO DA AULA
-- ---------------------------------------------------------------------
-- O checklist que vai para o Trabalho 1 (e para a vida):
--
--   1. Essa feature EXISTIRIA no momento da predicao?
--   2. Ela foi preenchida DEPOIS do que eu quero prever?
--   3. Meu alvo foi derivado de alguma coluna? Ela ficou FORA?
--
--   Regra da casa: metrica boa demais nao se comemora, se investiga.
--   Modelo com metrica perfeita sera tratado como vazamento ate
--   prova em contrario.
--
--   "Treinar modelo no BigQuery e uma linha de SQL. O trabalho de
--    verdade e tudo que veio antes do CREATE MODEL: desconfiar da
--    silver, achar a fazenda de meio Goiania, e desconfiar do
--    modelo que acertou demais. Isso nenhuma ferramenta faz por
--    voces."


-- ---------------------------------------------------------------------
-- DESAFIOS (para depois da aula)
-- ---------------------------------------------------------------------
-- 1) O script 4 avisou que titulo nao podia ser feature do
--    modelo_comercial. Quebre a regra: treine um classificador com
--    titulo como feature e veja a acuracia. Por que ela e perfeita
--    e por que o modelo e inutil?
-- 2) area_util esta no titulo tambem ("3044M2..."). Extrair a area
--    do titulo e vazamento? (dica: nao — area existe ANTES do
--    anuncio. A pergunta certa e: ja nao temos essa coluna?)
-- 3) Qual informacao do titulo seria feature LEGITIMA para o modelo
--    de preco? (ex.: menciona "piscina"? "condominio fechado"?
--    "reformado"?) Crie uma com REGEXP_CONTAINS e meca o efeito.
