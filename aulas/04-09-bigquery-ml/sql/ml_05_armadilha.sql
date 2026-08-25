-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- A ARMADILHA — o modelo bom demais
-- =====================================================================
--
-- Este e o ultimo bloco da aula, e o mais importante dela.
--
-- O seu modelo do ml_03 errou bastante. Vamos melhorar ele.
-- Tem uma coluna que a gente nem usou ainda: a descricao do anuncio.
-- Texto e informacao. Vamos aproveitar.
--
-- RODE OS QUATRO PASSOS NA ORDEM, ate o fim, ANTES de concluir
-- qualquer coisa. Este arquivo nao e o que parece no PASSO 2.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — "Vamos extrair informacao do texto"
-- ---------------------------------------------------------------------
-- Qualquer pipeline de NLP comeca assim: puxar entidades do texto livre.
-- Numeros com R$ na frente sao a entidade mais obvia que existe.

CREATE OR REPLACE TABLE `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto` AS
SELECT
  *,
  SAFE_CAST(
    REPLACE(
      REPLACE(
        REGEXP_EXTRACT(descricao, r'R\$\s*([0-9][0-9\.]*(?:,[0-9]{2})?)'),
      '.', ''),
    ',', '.') AS FLOAT64
  ) AS valor_citado_no_texto
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`;

-- Quantos anuncios tem um valor escrito na descricao?
SELECT
  COUNTIF(valor_citado_no_texto IS NOT NULL) AS com_valor_no_texto,
  COUNT(*)                                   AS total,
  ROUND(100 * COUNTIF(valor_citado_no_texto IS NOT NULL) / COUNT(*), 1) AS pct
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`;

-- Esperado: por volta de 23%. E o mesmo numero que apareceu no
-- silver_02_etl.sql, quando a gente olhou a SUJEIRA 3.
--
-- Otimo: temos uma feature nova. Segue para o PASSO 2.


-- ---------------------------------------------------------------------
-- PASSO 2 — Treinar com a feature nova
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco_v2`
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
  vagas,
  qtd_comodidades,
  bairro,
  tipo_imovel,
  uso,
  valor_citado_no_texto   -- <<< a unica coisa que mudou
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`;


-- ---------------------------------------------------------------------
-- PASSO 3 — Comparar v1 e v2
-- ---------------------------------------------------------------------
SELECT 'v1 (so caracteristicas)' AS modelo, r2_score, mean_absolute_error
FROM ML.EVALUATE(MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`)
UNION ALL
SELECT 'v2 (+ valor do texto)', r2_score, mean_absolute_error
FROM ML.EVALUATE(MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco_v2`);

-- Olhe a diferenca entre os dois R2 antes de seguir.
--
-- Duas perguntas, nessa ordem:
--   1) "Beleza. Publicamos esse modelo?"
--   2) "De onde saiu esse numero que a gente extraiu?"
--
-- Responda as duas de cabeca. Depois rode o PASSO 4.


-- ---------------------------------------------------------------------
-- PASSO 4 — De onde veio a informacao
-- ---------------------------------------------------------------------
SELECT
  id_anuncio,
  ROUND(preco)                 AS preco_da_coluna,
  ROUND(valor_citado_no_texto) AS valor_extraido_do_texto,
  SUBSTR(descricao, 1, 120)    AS trecho
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`
WHERE valor_citado_no_texto IS NOT NULL
ORDER BY ABS(valor_citado_no_texto - preco) ASC
LIMIT 15;

-- As duas colunas de numero sao IGUAIS.
--
--   "A gente nao criou uma feature. A gente copiou a resposta
--    de dentro do texto e colou na entrada do modelo.
--    O modelo nao ficou melhor. Ele ficou com a prova na mao."
--
-- O nome disso:
--   VAZAMENTO DE ALVO (data leakage)


-- ---------------------------------------------------------------------
-- PASSO 5 — A prova de que o modelo nao serve
-- ---------------------------------------------------------------------
-- Uma metrica global esconde o crime. Basta separar em dois grupos.

SELECT
  IF(valor_citado_no_texto IS NOT NULL,
     'anuncio com preco escrito no texto',
     'anuncio SEM preco no texto')                AS grupo,
  COUNT(*)                                        AS anuncios,
  ROUND(AVG(ABS(predicted_preco - preco)))        AS erro_medio_em_reais
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco_v2`,
  (SELECT * FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`)
)
GROUP BY grupo
ORDER BY anuncios DESC;

-- O QUE VAI APARECER:
--   nos ~23% com o preco no texto  -> erro proximo de ZERO
--   nos ~77% restantes             -> erro enorme
--
--   "Esse modelo nao avalia imovel. Ele le anuncio.
--    Quando o anuncio nao diz o preco, ele nao sabe nada.
--    E e exatamente nesses casos que a gente ia querer usar ele."
--
-- E o ponto que fecha o argumento:
--   "Em producao, todo imovel novo chega SEM preco.
--    Se ele tivesse preco, voce nao precisaria do modelo."


-- ---------------------------------------------------------------------
-- PASSO 6 — Confirmar com a explicabilidade
-- ---------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco_v2`
)
ORDER BY attribution DESC;

-- valor_citado_no_texto vai estar no topo, dominando todo o resto.
-- area_util, bairro, quartos viram detalhe.
--
--   "Deu pra descobrir tudo isso com UMA query.
--    A explicabilidade nao e enfeite. E teste de sanidade."


-- ---------------------------------------------------------------------
-- O CHECKLIST — leve este daqui para o Trabalho 1
-- ---------------------------------------------------------------------
-- Antes de acreditar em qualquer metrica boa, tres perguntas:
--
--   1. Essa coluna vai EXISTIR no momento em que eu for prever?
--      (o preco no texto nao existe num imovel que ainda nao tem preco)
--
--   2. Essa coluna foi preenchida DEPOIS de acontecer o que eu quero prever?
--      (data de pagamento para prever inadimplencia; data de alta para
--       prever internacao; status do pedido para prever cancelamento)
--
--   3. O resultado ficou bom demais?
--      Metrica quase perfeita em problema do mundo real e quase sempre
--      vazamento — nao genialidade.
--
--   "Treinar modelo no BigQuery e uma linha de SQL.
--    O trabalho de verdade e tudo que veio ANTES do CREATE MODEL:
--    abrir o JSON, achar a fazenda do tamanho da Alemanha,
--    e desconfiar do modelo que acertou demais.
--    Isso nenhuma ferramenta faz por voce."


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Use o texto do jeito CERTO: remova os valores em R$ da descricao
--    com REGEXP_REPLACE e treine com ML.NGRAMS sobre o texto limpo:
--       ML.NGRAMS(SPLIT(LOWER(descricao_limpa), ' '), [1, 2])
--    Palavras como "alto padrao", "piscina" e "vista" ajudam de verdade?
-- 2) O desafio 2 do arquivo de regressao pedia para usar preco_por_m2
--    como feature. Aquilo era o mesmo crime deste arquivo. Explique
--    por que, em duas frases.
-- 3) Procure um vazamento no dataset do trabalho do seu grupo.
--    Se voce nao achou nenhum, provavelmente ainda nao procurou direito.
