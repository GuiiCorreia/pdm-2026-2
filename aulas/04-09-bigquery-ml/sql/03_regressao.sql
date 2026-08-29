-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 3: REGRESSAO — quanto vale este imovel?
-- =====================================================================
--
-- Este e o momento em que "SQL" e "machine learning" viram a mesma
-- coisa. Voce ja sabe criar tabela. Vai criar um modelo com o MESMO
-- verbo:
--
--     CREATE TABLE   ->   CREATE MODEL
--
-- COMO USAR: troque SEU_PROJETO. Requer a anuncios_gold (script 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Treinar
-- ---------------------------------------------------------------------
-- Leia com calma, linha por linha, antes de rodar.
-- Nao tem import, nao tem train_test_split, nao tem fit().
-- Tem CREATE, tem OPTIONS, tem SELECT.

CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_preco`
OPTIONS (
  model_type            = 'LINEAR_REG',   -- regressao linear
  input_label_cols      = ['preco'],      -- <<< o que queremos prever
  data_split_method     = 'AUTO_SPLIT',   -- BQ separa treino/validacao sozinho
  enable_global_explain = TRUE            -- liga a explicabilidade (PASSO 4)
) AS
SELECT
  preco,            -- label
  area_util,        -- daqui para baixo: features
  quartos,
  banheiros,
  suites,
  garagem,
  condominio,
  iptu,
  bairro,           -- STRING: o BQ faz one-hot sozinho
  eh_comercial      -- BOOL derivada do titulo, no script 2
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- TRES partes, sempre nesta ordem:
--
--   CREATE OR REPLACE MODEL `projeto.dataset.nome`   <- 1) o nome
--   OPTIONS ( ... )                                  <- 2) as regras
--   AS SELECT ...                                    <- 3) o dado
--
--   1) O MODELO E UM OBJETO DO DATASET. Mora no mesmo lugar que a
--      tabela, aparece no painel esquerdo do console junto com ela.
--      Nao e arquivo, nao e .pkl, nao esta na sua maquina.
--      "OR REPLACE": rodar de novo retreina por cima, sem historico.
--      Quer comparar dois? Use dois nomes (e o script 5 faz isso).
--
--   2) OPTIONS e a lista de decisoes:
--        model_type='LINEAR_REG'     qual algoritmo
--        input_label_cols=['preco']  qual coluna e a RESPOSTA
--        data_split_method           quem separa treino/validacao
--        enable_global_explain=TRUE  guarda o peso de cada coluna.
--                                    E a unica opcao que voce NAO
--                                    consegue ligar depois do treino.
--
--   3) O SELECT e a materia-prima. A regra:
--        a coluna citada em input_label_cols  ->  label
--        TODAS as outras que aparecerem       ->  features
--      NAO EXISTE lista de features. Colocar coluna no SELECT E
--      adicionar feature. Toda a engenharia de features acontece
--      editando este SELECT.
--
--      Por isso ele NAO e SELECT *. Olhe o que ficou de fora:
--        id_anuncio    (identificador nao e atributo)
--        preco_por_m2  (contem o proprio preco — desafio 2)
--        latitude/longitude (37,7% dos anuncios nem tem coordenada;
--                       o BQ imputaria um valor medio para 1/3 da
--                       base, inventando um "centro da cidade" falso)
--        titulo        (por que? anote seu palpite. Script 5.)
--
-- SOBRE OS NULLs QUE FICARAM (condominio, iptu, quartos...):
--   o BigQuery ML imputa sozinho — numerico vira a media da coluna,
--   categorico vira categoria propria. Voce nao viu acontecer.
--   E comodo e e perigoso: comodo porque nao trava; perigoso porque
--   177 condominios "na media" e uma ficcao estatistica. Saber que
--   a imputacao existe e o que separa usar de ser usado.
--
-- Pergunta para a turma:
--   onde esta o train_test_split neste comando?
--   (resposta: data_split_method. Voce nao escreve o split, escolhe
--    a POLITICA — e ela fica gravada no modelo, nao num notebook
--    que alguem esqueceu de rodar)
-- =====================================================================

-- CUSTO: ~887 linhas, 10 colunas. Nada perto do free tier de 1 TiB.
-- O treino leva ~1-2 min — use esse tempo para reler o OPTIONS.


-- ---------------------------------------------------------------------
-- PASSO 2 — Avaliar
-- ---------------------------------------------------------------------
SELECT *
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco`);

-- O QUE VEM: mean_absolute_error, mean_squared_error,
--            median_absolute_error, r2_score, explained_variance
--
-- COMO LER (olhe estes dois, o resto e ruido agora):
--
--   mean_absolute_error -> em REAIS: quanto o modelo erra em media.
--                          Compare com a mediana de R$ 8,9 mi.
--   r2_score            -> 0 a 1: quanto da variacao do preco o
--                          modelo explicou. 0 = chutou a media.
--
-- EXPECTATIVA HONESTA, dita ANTES de rodar:
--   este dado e DIFICIL. A correlacao preco x area_util na Gold e
--   0,38 (fraca). E preco x quartos e NEGATIVA (-0,11) — porque
--   galpao comercial tem 0 quartos e preco alto, e o dataset mistura
--   os dois mercados.
--
--   O modelo VAI errar bastante. A pergunta do dia nao e "como zerar
--   o erro" — e "o que o erro me conta sobre o dado".
--
-- RESULTADO MEDIDO (pdm-2026-gui, 28/08 — o AUTO_SPLIT e
-- deterministico no mesmo dado; os alunos devem ver o MESMO numero):
--   mean_absolute_error   2.581.138    (v0 de 28/08: 13.835.427)
--   r2_score              0,298        (v0 de 28/08: -0,35)
--
--   MESMO algoritmo, MESMO verbo, 5,4x menos erro — e um R2 que saiu
--   do negativo. A diferenca inteira foi o DADO (gold do script 2).
--   R2 0,30 e resultado honesto num dado dificil, e rende discussao
--   melhor que 0,99.
--
--   "R2 nao e nota de prova. E quanto do mundo o modelo enxergou."


-- ---------------------------------------------------------------------
-- PASSO 3 — Prever (e olhar os ERROS, nao os acertos)
-- ---------------------------------------------------------------------
SELECT
  bairro,
  eh_comercial,
  area_util,
  quartos,
  ROUND(preco)                   AS preco_real,
  ROUND(predicted_preco)         AS preco_previsto,
  ROUND(predicted_preco - preco) AS erro
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.anuncios.modelo_preco`,
  (SELECT * FROM `SEU_PROJETO.anuncios.anuncios_gold`)
)
ORDER BY ABS(predicted_preco - preco) DESC
LIMIT 20;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- ML.PREDICT aparece no FROM, no lugar de uma tabela — porque e isso
-- que ela devolve: a tabela do segundo argumento, com uma coluna nova
-- na frente, predicted_<label> (o nome e automatico).
--
--   Como sobrou tudo que entrou, da para escrever
--   predicted_preco - preco na mesma linha: previsao e verdade
--   lado a lado.
--
--   O segundo argumento e uma query entre parenteses — pode ser
--   QUALQUER coisa: a tabela toda (aqui), um bairro so, ou um imovel
--   inventado na mao (PASSO 5).
--
--   ORDER BY ABS(...) DESC: sem o ABS, o topo mostraria so quem o
--   modelo subestimou. Erro para cima e para baixo pesa igual.
--
-- Pergunta para a turma:
--   essas linhas estavam no TREINO do modelo. Isso invalida a
--   analise? (para julgar QUALIDADE, sim — para isso ha o
--   ML.EVALUATE, que usa a fatia de validacao. Para procurar PADRAO
--   no erro, nao: errar feio em quem ele ja viu e informacao boa.)
-- =====================================================================

-- PERGUNTA: "Olhem os 20 piores. O que eles tem em comum?"
-- Quase sempre: os mais caros, bairros com poucos anuncios, ou
-- eh_comercial = TRUE. Isso ja e analise de erro — vale mais que o R2.


-- ---------------------------------------------------------------------
-- PASSO 4 — Perguntar ao modelo o que ele achou importante
-- ---------------------------------------------------------------------
-- So funciona porque enable_global_explain = TRUE no PASSO 1.

SELECT *
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_preco`)
ORDER BY attribution DESC;

--   "O modelo nao e caixa preta por natureza.
--    Ele e caixa preta quando voce nao pergunta."
--
-- RESULTADO MEDIDO (attribution):
--   eh_comercial  3,62 mi  >  bairro  3,39 mi  >  area_util  668 mil
--
-- O modelo aprendeu o obvio certo: QUAL mercado e ONDE pesam mais
-- que o tamanho. E repare: eh_comercial, a coluna mais importante,
-- foi feature que NOS derivamos do titulo no script 2 — engenharia
-- de feature de uma linha virou o maior peso do modelo.


-- ---------------------------------------------------------------------
-- PASSO 5 — Prever um imovel que nao existe
-- ---------------------------------------------------------------------
-- O modelo virou uma FUNCAO consultavel por quem tem acesso ao
-- dataset. Sem API, sem deploy.

SELECT
  ROUND(predicted_preco) AS preco_estimado
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.anuncios.modelo_preco`,
  (SELECT
     180            AS area_util,  -- INT64, igual ao tipo da silver (180.0 daria erro de coercao)
     3              AS quartos,
     2              AS banheiros,
     1              AS suites,
     2              AS garagem,
     800.0          AS condominio,
     2400.0         AS iptu,
     'Setor Bueno'  AS bairro,
     FALSE          AS eh_comercial
  )
);

-- RESULTADO MEDIDO: preco_estimado 8.385.718 (R$ 8,4 mi por um
-- apartamento de 180 m2 no Bueno — caro? E o dataset que e assim:
-- a mediana da Gold e R$ 8,9 mi. O modelo responde no mundo em que
-- foi treinado).
--
--   "Isso aqui e um modelo em producao. Mora no data warehouse,
--    do lado do dado. Quem sabe SQL sabe consultar."
--
-- Guarde esta query: e ela que o agente de WhatsApp vai chamar na
-- aula de 27/11. Nao muda nada — muda quem faz a pergunta.
-- E quando o modelo precisa SAIR do warehouse e virar API de
-- verdade? Vertex AI e Cloud Run, aula de 02/10.


-- ---------------------------------------------------------------------
-- DESAFIOS (para depois da aula)
-- ---------------------------------------------------------------------
-- 1) Troque LINEAR_REG por BOOSTED_TREE_REGRESSOR e compare o
--    ML.EVALUATE dos dois modelos (use outro nome!). O melhor R2
--    ganhou, ou o menor erro em reais?
-- 2) Adicione preco_por_m2 como feature. O R2 vai para perto de 1.
--    Por que isso e um problema, e nao uma vitoria?
--    (dica: preco_por_m2 = preco / area_util)
-- 3) Treine so com eh_comercial = FALSE. Melhorou? O que isso diz
--    sobre juntar mercado residencial e comercial no mesmo modelo?
-- 4) Os 37,7% sem coordenada: crie a feature BOOL tem_coordenada e
--    adicione ao modelo. O erro muda? O que significaria se mudar?
