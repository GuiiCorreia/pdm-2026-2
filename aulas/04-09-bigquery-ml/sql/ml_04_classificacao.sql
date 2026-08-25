-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- MODELO 2: CLASSIFICACAO — este anuncio e residencial ou comercial?
-- =====================================================================
--
-- Muda o model_type e muda a forma de avaliar. Mais nada muda.
--
-- A unica diferenca entre os dois modelos de hoje e UMA palavra
-- dentro do OPTIONS. Compare este arquivo com o ml_03 e confira.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 0 — Olhar o alvo ANTES de treinar
-- ---------------------------------------------------------------------
-- Regra que vale para sempre: em classificacao, conte as classes primeiro.

SELECT
  uso,
  COUNT(*) AS anuncios,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`
WHERE uso IS NOT NULL
GROUP BY uso
ORDER BY anuncios DESC;

-- ESPERADO (aproximado, na base completa): RESIDENTIAL ~79% / COMMERCIAL ~21%
--
-- PERGUNTA — responda ANTES de treinar:
--   "Se eu criar um modelo que responde RESIDENTIAL para tudo,
--    sem olhar nada, qual vai ser a acuracia dele?"
--
-- Resposta: 79%.
--
-- GUARDE ESTE NUMERO:
--   Acuracia base (chutar a classe maioritaria) = 79%
--
-- Esse numero e a linha de corte. Um modelo com 80% de acuracia
-- nao aprendeu quase nada. Guarde para o PASSO 2.


-- ---------------------------------------------------------------------
-- PASSO 1 — Treinar
-- ---------------------------------------------------------------------
-- Compare visualmente com o CREATE MODEL do arquivo anterior.
-- Mudou: LINEAR_REG -> LOGISTIC_REG, e o input_label_cols.

CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.modelo_uso`
OPTIONS (
  model_type            = 'LOGISTIC_REG',   -- <<< a unica mudanca estrutural
  input_label_cols      = ['uso'],
  data_split_method     = 'AUTO_SPLIT',
  auto_class_weights    = TRUE,             -- compensa o desbalanceamento 79/21
  enable_global_explain = TRUE
) AS
SELECT
  uso,              -- label (STRING: o BQ entende como classe)
  area_util,
  quartos,
  banheiros,
  suites,
  vagas,
  qtd_comodidades,
  preco,
  preco_por_m2,
  bairro,
  tipo_imovel
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`
WHERE uso IS NOT NULL;

-- SOBRE auto_class_weights = TRUE:
--   Sem isso, o modelo aprende que "chutar RESIDENTIAL" ja acerta 79%
--   e nunca se esforca para achar os comerciais.
--   Com isso, errar um COMMERCIAL passa a custar mais caro no treino.
--
--   "Classe desbalanceada nao e detalhe estatistico.
--    E o modelo descobrindo que da pra colar na prova."


-- ---------------------------------------------------------------------
-- PASSO 2 — Avaliar
-- ---------------------------------------------------------------------
SELECT *
FROM ML.EVALUATE(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_uso`
);

-- Agora as metricas sao OUTRAS: precision, recall, accuracy,
-- f1_score, log_loss, roc_auc.
--
-- COMO LER (olhe estas tres, so):
--
--   accuracy   -> % de acertos. COMPARE COM OS 79% DO PASSO 0.
--   recall     -> dos comerciais que existiam, quantos ele achou?
--   precision  -> dos que ele CHAMOU de comercial, quantos eram mesmo?
--
--   "Precision e recall respondem perguntas diferentes.
--    Escolher qual importa nao e decisao do modelo. E sua."
--
-- Exemplo concreto:
--   Filtro de spam    -> precision importa mais (nao jogue email bom fora)
--   Exame de cancer   -> recall importa mais (nao deixe doente passar)


-- ---------------------------------------------------------------------
-- PASSO 3 — A matriz de confusao
-- ---------------------------------------------------------------------
-- Aqui o modelo para de ser um numero e vira uma tabela que voce le.

SELECT *
FROM ML.CONFUSION_MATRIX(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_uso`
);

-- LEITURA:
--   linha  = o que o imovel E de verdade
--   coluna = o que o modelo DISSE que era
--   diagonal = acertos. Fora da diagonal = erros, e cada lado e um erro
--   de tipo diferente.
--
-- PERGUNTA:
--   "Qual dos dois erros seria pior num site de imoveis de verdade?"
--   (mostrar galpao para quem quer apartamento? ou o contrario?)
--   Nao tem resposta certa. Tem decisao de produto. E esse e o ponto.


-- ---------------------------------------------------------------------
-- PASSO 4 — Prever
-- ---------------------------------------------------------------------
SELECT
  bairro,
  tipo_imovel,
  area_util,
  uso                        AS uso_real,
  predicted_uso              AS uso_previsto,
  ROUND(
    (SELECT MAX(p.prob)
     FROM UNNEST(predicted_uso_probs) AS p), 3
  )                          AS confianca
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_uso`,
  (SELECT * FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold` WHERE uso IS NOT NULL)
)
WHERE uso <> predicted_uso
ORDER BY confianca DESC
LIMIT 20;

-- REPARE NO predicted_uso_probs:
--   classificacao no BQML nao devolve so o rotulo. Devolve a
--   probabilidade de CADA classe, num ARRAY de STRUCT.
--   O UNNEST de novo — o mesmo que usamos no JSON no comeco da aula.
--
-- E REPARE NO FILTRO: uso <> predicted_uso ordenado por confianca DESC.
-- Estamos olhando os erros que o modelo cometeu com MAIS certeza.
--
--   "Um modelo errando com 51% de certeza e um modelo em duvida.
--    Um modelo errando com 98% de certeza e um modelo que aprendeu
--    a coisa errada. Sao problemas diferentes."


-- ---------------------------------------------------------------------
-- PASSO 5 — O que pesou
-- ---------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_uso`
)
ORDER BY attribution DESC;

-- Provavel: tipo_imovel domina (SHED_DEPOSIT_WAREHOUSE, OFFICE...).
--
-- Se isso acontecer, pare um segundo:
--   tipo_imovel praticamente ENTREGA a resposta.
--   O modelo nao aprendeu a reconhecer um imovel comercial —
--   ele aprendeu a ler uma etiqueta que ja dizia isso.
--
-- Guarde essa sensacao. Ela e o assunto do proximo arquivo.


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Treine de novo SEM tipo_imovel. A acuracia cai quanto?
--    Esse segundo modelo e pior ou e mais honesto?
-- 2) Rode com auto_class_weights = FALSE e compare a matriz de confusao.
--    Onde exatamente o modelo passou a errar?
-- 3) Troque LOGISTIC_REG por BOOSTED_TREE_CLASSIFIER. Valeu o custo
--    de treino a mais?
