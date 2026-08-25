-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- BRONZE: o dado cru, do jeito que ele chega
-- =====================================================================
--
-- Este e o primeiro script. Ele monta a camada Bronze: o BigQuery
-- passa a enxergar o CSV que esta no seu bucket.
--
-- ANTES DE EXECUTAR, substitua nos SEIS arquivos desta pasta:
--     SEU_PROJETO   -> o id do seu projeto no GCP
--     SEU_DATASET   -> o dataset que voce criou no BigQuery
--     SEU_BUCKET    -> o seu bucket no Cloud Storage
--
-- No editor, isso e um "substituir em todos os arquivos".
-- Se esquecer, o BigQuery reclama de tabela nao encontrada e voce
-- perde cinco minutos procurando o motivo errado.
--
-- Ambiente ainda nao montado? Veja docs/01-monte-seu-ambiente-gcp.md
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Subir o arquivo para o Cloud Storage
-- ---------------------------------------------------------------------
-- Pelo console: Cloud Storage > seu bucket > Upload > aula-pdm.csv
-- Destino sugerido: gs://SEU_BUCKET/imoveis/aula-pdm.csv
--
-- Por que GCS e nao upload direto no BigQuery?
-- Porque e assim que funciona de verdade: o dado chega em um bucket,
-- e o BigQuery le de la. E o mesmo caminho que voce ja percorreu.


-- ---------------------------------------------------------------------
-- PASSO 2 — External Table: ler o CSV SEM copiar nada
-- ---------------------------------------------------------------------
-- A External Table nao move o dado. Ela e um ponteiro para o arquivo
-- no bucket. Nenhum byte e duplicado.
--
-- Repare no schema: sao 4 colunas, e a ultima e um JSON inteiro
-- espremido dentro de uma STRING de ~14 KB.

CREATE OR REPLACE EXTERNAL TABLE `SEU_PROJETO.SEU_DATASET.imoveis_bronze`
(
  id_anuncio        STRING,
  data_atualizacao  STRING,
  data_insercao     STRING,
  listing           STRING   -- <<< o JSON inteiro mora aqui dentro
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://SEU_BUCKET/imoveis/aula-pdm.csv'],
  skip_leading_rows = 1,
  quote = '"',
  allow_quoted_newlines = TRUE,
  ignore_unknown_values = TRUE
);


-- ---------------------------------------------------------------------
-- PASSO 3 — Sanidade: o arquivo entrou?
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_de_anuncios
FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`;
-- Esperado: 1000


-- ---------------------------------------------------------------------
-- PASSO 4 — Olhar UM anuncio cru
-- ---------------------------------------------------------------------
-- Antes de rodar, responda para voce mesmo:
--     "Como eu treinaria um modelo com ISSO?"
--
-- Se voce nao souber responder, otimo. E esse o ponto.

SELECT
  id_anuncio,
  LENGTH(listing) AS tamanho_do_json_em_caracteres,
  listing
FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`
LIMIT 1;

-- O que voce vai ver: uma parede de texto de ~14 mil caracteres,
-- com chaves, colchetes, acentos, emoji e HTML no meio.
-- Nada disso e coluna. Nada disso e numero. Nada disso treina modelo.
--
--   "Isso aqui e o que chega. O que a gente precisa e uma tabela.
--    A distancia entre as duas coisas e o trabalho de verdade."


-- ---------------------------------------------------------------------
-- ANTES DE SEGUIR PARA O silver_01_json.sql
-- ---------------------------------------------------------------------
-- [ ] O bucket existe e o aula-pdm.csv foi enviado para imoveis/
-- [ ] A External Table foi criada sem erro
-- [ ] O PASSO 3 retornou 1000
-- [ ] O PASSO 4 mostrou a parede de texto
--
-- Deu erro de localizacao? Bucket e dataset precisam estar na MESMA
-- regiao, e a regiao do dataset nao pode ser alterada depois.
-- Nesse caso, apague o dataset e crie de novo na regiao do bucket.
