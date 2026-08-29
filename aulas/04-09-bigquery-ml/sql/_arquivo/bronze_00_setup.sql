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
--     SEU_DATASET   -> o dataset que voce criou no BigQuery (pdm_2026_2)
--
-- No editor, isso e um "substituir em todos os arquivos".
-- Se esquecer, o BigQuery reclama de tabela nao encontrada e voce
-- perde cinco minutos procurando o motivo errado.
--
-- Ambiente ainda nao montado? Veja docs/01-monte-seu-ambiente-gcp.md
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Onde o arquivo esta
-- ---------------------------------------------------------------------
-- Voce nao precisa subir nada. O dado da disciplina ja esta publicado
-- num bucket publico, em us-east1:
--
--     gs://pdm-2026-2-dados/imoveis/aula-pdm.csv
--
-- Por que GCS e nao upload direto no BigQuery?
-- Porque e assim que funciona de verdade: o dado chega em um bucket,
-- e o BigQuery le de la. E o mesmo caminho que voce ja percorreu.
--
-- ATENCAO: o SEU dataset precisa estar em us-east1 tambem. Bucket e
-- dataset em regioes diferentes = o BigQuery se recusa a ler.


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
  uris = ['gs://pdm-2026-2-dados/imoveis/aula-pdm.csv'],
  skip_leading_rows = 1,
  quote = '"',
  allow_quoted_newlines = TRUE,
  ignore_unknown_values = TRUE
);

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Compare com um CREATE TABLE comum. A diferenca esta em UMA palavra
-- e no que vem depois dela:
--
--   CREATE ... EXTERNAL TABLE nome (colunas)  OPTIONS (onde e como ler)
--                  |
--                  +-- "a tabela nao guarda dado, ela aponta pro arquivo"
--
-- Em tabela normal voce diz o que a tabela E. Aqui voce diz onde o
-- arquivo esta e como interpretar ele. Nada e copiado: o CSV continua
-- no bucket, e cada consulta vai ler ele de novo, la.
--
-- O bloco de colunas: voce esta DECLARANDO o schema, nao descobrindo.
-- O BigQuery ate consegue adivinhar sozinho, mas aqui a gente escreve
-- na mao de proposito — declarar `listing STRING` e o que impede o
-- BigQuery de tentar ser esperto com o JSON. Ele fica como texto, e a
-- gente abre ele no proximo arquivo, no nosso tempo.
--
-- E cada OPTION resolve um problema concreto deste arquivo:
--
--   format = 'CSV'            e um CSV. (Poderia ser PARQUET, JSON...)
--   uris = ['gs://...']       o caminho no bucket. E LISTA, entre
--                             colchetes: da pra apontar para varios
--                             arquivos, e aceita curinga
--                             ('gs://.../2024-*.csv' = a pasta toda
--                             virando uma tabela so).
--   skip_leading_rows = 1     a primeira linha e o cabecalho, e nao
--                             um anuncio chamado "id_anuncio".
--   quote = '"'               o que delimita um campo de texto.
--   allow_quoted_newlines = TRUE
--                             ESTA E A IMPORTANTE. O JSON da coluna
--                             listing tem quebras de linha DENTRO
--                             dele. Sem esta opcao, o leitor de CSV
--                             acha que a linha acabou no meio do JSON
--                             e o arquivo inteiro sai picado.
--   ignore_unknown_values = TRUE
--                             se alguma linha vier com coluna a mais,
--                             ignora aquilo em vez de falhar tudo.
--
-- Pergunta para a turma antes de seguir:
--   se alguem trocar o arquivo la no bucket, o que acontece com esta
--   tabela?
--   (resposta: muda sozinha, na proxima consulta. Isso e comodo e e
--    perigoso — a sua tabela depende de um arquivo que outra pessoa
--    pode mexer. E um dos motivos pelos quais a Silver, la na frente,
--    e uma tabela DE VERDADE e nao mais um ponteiro)
-- =====================================================================


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
-- [ ] A External Table foi criada sem erro
-- [ ] O PASSO 3 retornou 1000
-- [ ] O PASSO 4 mostrou a parede de texto
--
-- Deu erro de localizacao? O seu dataset nao esta em us-east1.
-- A regiao do dataset nao pode ser alterada depois: apague o dataset
-- e crie de novo em us-east1.
