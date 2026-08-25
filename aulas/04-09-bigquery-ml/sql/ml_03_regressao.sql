-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- MODELO 1: REGRESSAO — quanto vale este imovel?
-- =====================================================================
--
-- Este e o momento em que "SQL" e "machine learning" viram a mesma coisa.
--
-- Voce ja sabe criar tabela. Vai criar um modelo com o MESMO verbo:
--
--     CREATE TABLE   ->   CREATE MODEL
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Treinar
-- ---------------------------------------------------------------------
-- Leia esta query com calma, linha por linha, antes de rodar.
-- Nao tem import, nao tem train_test_split, nao tem fit().
-- Tem CREATE, tem OPTIONS, tem SELECT.

CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`
OPTIONS (
  model_type              = 'LINEAR_REG',   -- regressao linear
  input_label_cols        = ['preco'],      -- <<< o que queremos prever
  data_split_method       = 'AUTO_SPLIT',   -- BQ separa treino/validacao sozinho
  enable_global_explain   = TRUE            -- liga a explicabilidade (PASSO 4)
) AS
SELECT
  preco,            -- label
  area_util,        -- features abaixo
  quartos,
  banheiros,
  suites,
  vagas,
  qtd_comodidades,
  bairro,           -- STRING: o BQ faz one-hot sozinho
  tipo_imovel,
  uso
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`;

-- TRES COISAS PARA DESTACAR:
--
-- 1) input_label_cols diz QUAL coluna e a resposta.
--    Todo o resto do SELECT vira feature. Nao existe lista de features.
--
-- 2) bairro e tipo_imovel sao TEXTO e entraram direto.
--    Em Python voce faria OneHotEncoder, get_dummies, ColumnTransformer.
--    Aqui: voce colocou a coluna no SELECT.
--
-- 3) data_split_method = AUTO_SPLIT.
--    O BigQuery separou treino e validacao. Voce nao viu, nao escreveu,
--    e nao tem como esquecer de fazer.
--
-- PERGUNTA (importante):
--   "Por que a descricao NAO esta nessa lista?"
--   Anote o seu palpite. A resposta esta no ml_05_armadilha.sql.
--
-- CUSTO: ~700 linhas, 10 colunas. Cabe folgado no free tier de 1 TB.


-- ---------------------------------------------------------------------
-- PASSO 2 — Avaliar
-- ---------------------------------------------------------------------
SELECT *
FROM ML.EVALUATE(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`
);

-- O QUE VEM: mean_absolute_error, mean_squared_error,
--            median_absolute_error, r2_score, explained_variance
--
-- COMO LER (olhe so estes dois, o resto e ruido agora):
--
--   mean_absolute_error  -> em REAIS, quanto o modelo erra em media.
--                           Se der 2.000.000, ele erra R$ 2 milhoes
--                           num imovel cuja mediana e R$ 9 milhoes.
--
--   r2_score             -> 0 a 1. Quanto da variacao do preco o modelo
--                           conseguiu explicar. 0 = chutou a media.
--
--   "R2 nao e nota de prova. E quanto do mundo o modelo enxergou."
--
-- NAO EXISTE UM NUMERO CERTO AQUI. Dado de imovel e dificil:
-- R2 entre 0,4 e 0,7 e um resultado honesto, e rende uma discussao
-- muito melhor do que 0,99. Anote o que deu no SEU modelo.


-- ---------------------------------------------------------------------
-- PASSO 3 — Prever
-- ---------------------------------------------------------------------
-- ML.PREDICT recebe uma tabela e devolve a MESMA tabela com uma coluna
-- nova na frente: predicted_<label>.

SELECT
  bairro,
  tipo_imovel,
  area_util,
  quartos,
  ROUND(preco)                     AS preco_real,
  ROUND(predicted_preco)           AS preco_previsto,
  ROUND(predicted_preco - preco)   AS erro
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`,
  (SELECT * FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`)
)
ORDER BY ABS(predicted_preco - preco) DESC
LIMIT 20;

-- Ordenado pelos MAIORES erros de proposito.
--
-- PERGUNTA:
--   "Olhe os 20 piores. Tem alguma coisa em comum entre eles?"
--
-- Quase sempre tem: sao os imoveis mais caros, ou de um bairro com
-- poucos anuncios, ou de um tipo raro (FARM, PENTHOUSE).
-- Isso ja e analise de erro — e e mais util que o R2.


-- ---------------------------------------------------------------------
-- PASSO 4 — Perguntar ao modelo o que ele achou importante
-- ---------------------------------------------------------------------
-- So funciona porque ligamos enable_global_explain = TRUE no PASSO 1.

SELECT *
FROM ML.GLOBAL_EXPLAIN(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`
)
ORDER BY attribution DESC;

-- Isto responde: quais colunas mais pesaram na previsao.
--
--   "O modelo nao e uma caixa preta por natureza.
--    Ele e uma caixa preta quando voce nao pergunta."
--
-- Se area_util aparecer no topo: otimo, o modelo aprendeu o obvio certo.
-- Se bairro aparecer no topo: melhor ainda, e a tese do mercado imobiliario.


-- ---------------------------------------------------------------------
-- PASSO 5 — Prever um imovel que nao existe
-- ---------------------------------------------------------------------
-- Mostra que o modelo virou uma FUNCAO consultavel por qualquer um
-- que tenha acesso ao dataset. Nao precisa de API, nem de deploy.

SELECT
  ROUND(predicted_preco) AS preco_estimado
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_preco`,
  (SELECT
     180.0    AS area_util,
     3        AS quartos,
     2        AS banheiros,
     1        AS suites,
     2        AS vagas,
     8        AS qtd_comodidades,
     'Setor Bueno'  AS bairro,
     'APARTMENT'    AS tipo_imovel,
     'RESIDENTIAL'  AS uso
  )
);

--   "Isso aqui e um modelo em producao. Ele mora no data warehouse,
--    do lado do dado. Quem sabe SQL sabe consultar."
--
-- Guarde esta query: e ela que o agente de WhatsApp vai chamar
-- na aula de 27/11. Nao muda nada, so muda quem faz a pergunta.
--
-- E quando o modelo precisa SAIR do warehouse e virar uma API de
-- verdade? Ai entram Vertex AI e Cloud Run, na aula de 02/10.


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Treine um segundo modelo trocando LINEAR_REG por BOOSTED_TREE_REGRESSOR
--    (mude tambem OPTIONS: max_iterations). Compare o ML.EVALUATE dos dois.
--    O melhor R2 ganhou? Ou o menor erro em reais?
-- 2) Adicione preco_por_m2 como feature. O R2 vai para perto de 1.
--    Por que isso e um problema, e nao uma vitoria?
--    (dica: preco_por_m2 = preco / area_util)
-- 3) Treine so com imoveis RESIDENTIAL. Ficou melhor? Se sim, o que isso
--    diz sobre juntar residencial e comercial no mesmo modelo?
