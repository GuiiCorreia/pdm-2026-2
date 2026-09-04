-- =====================================================================
-- AULA 04/09 — SCRIPT 7: O cardapio do BigQuery ML
-- =====================================================================
-- Ate aqui as melhorias vieram do DADO:
--   limpou (v0 -> v1) e criou feature de texto (v1 -> v3).
--
-- Falta a terceira alavanca: trocar o ALGORITMO.
-- No BigQuery ML isso e UMA PALAVRA no OPTIONS. Nao muda uma linha
-- do SELECT, nao muda a tabela, nao instala nada.
--
-- E na parte B, uma coisa diferente: treinar um modelo SEM label
-- nenhum, so para ver que grupos existem no mercado.
--
-- Troque SEU_PROJETO pelo ID do seu projeto em todas as queries.
-- ---------------------------------------------------------------------


-- =====================================================================
-- PARTE A — Arvore no lugar da reta
-- =====================================================================

-- ---------------------------------------------------------------------
-- PASSO 1 — Trocar UMA palavra
-- ---------------------------------------------------------------------
-- Compare com o CREATE MODEL do script 05. E o MESMO SELECT, a MESMA
-- tabela gold_texto, as MESMAS colunas. So mudou:
--
--     model_type = 'LINEAR_REG'              (script 05)
--     model_type = 'BOOSTED_TREE_REGRESSOR'  (aqui)
--
-- Demora ~1 minuto. Rode e espere.

CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_preco_arvore`
OPTIONS (
  model_type            = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols      = ['preco'],
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  preco,
  bairro,
  area_util,
  quartos,
  banheiros,
  suites,
  garagem,
  condominio,
  iptu,
  eh_comercial,
  tem_piscina,
  eh_alto_padrao,
  tem_mobilia,
  eh_terreno,
  eh_apartamento,
  eh_casa
FROM `SEU_PROJETO.anuncios.gold_texto`;

-- COMO LER ESTE COMANDO
-- ---------------------------------------------------------------------
--  BOOSTED_TREE_REGRESSOR = arvore de decisao com boosting (XGBoost
--  por dentro). Diferenca pratica pra regressao linear:
--
--    LINEAR_REG   ->  "preco = a*area + b*quartos + c*bairro + ..."
--                     Uma formula so, valida pro dataset inteiro.
--                     Cada +1 m2 vale sempre a mesma coisa.
--
--    BOOSTED_TREE ->  "SE area > 400 E bairro = Bueno ENTAO ...
--                      SENAO SE eh_terreno ENTAO ..."
--                     Milhares de regras encadeadas. Cada +1 m2 vale
--                     UMA COISA no terreno e OUTRA no apartamento.
--
--  E por isso que a arvore ganha aqui: o nosso mercado NAO e uma reta.
--  Um metro quadrado de chacara e um metro quadrado de cobertura no
--  Bueno sao a mesma coluna com significados opostos.
--
--  enable_global_explain = TRUE  -> libera o ML.GLOBAL_EXPLAIN la no
--  PASSO 3. Se voce esquecer isso no CREATE MODEL, tem que retreinar.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 2 — O placar final dos quatro modelos
-- ---------------------------------------------------------------------

SELECT 'v0_dado_como_estava'  AS modelo,
       mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_imoveis`)
UNION ALL
SELECT 'v1_gold_limpa',
       mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco`)
UNION ALL
SELECT 'v3_gold_mais_texto',
       mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_v3`)
UNION ALL
SELECT 'v4_arvore_mesmo_dado',
       mean_absolute_error, r2_score
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_arvore`)
ORDER BY r2_score;

-- RESULTADO MEDIDO
-- ---------------------------------------------------------------------
--   modelo                    MAE            R2
--   v0_dado_como_estava   13.835.427       -0,350
--   v1_gold_limpa          2.581.138       +0,298
--   v3_gold_mais_texto     2.469.775       +0,471
--   v4_arvore_mesmo_dado   1.823.401       +0,556
--
--   A conta das tres alavancas, do inicio ao fim:
--     limpar o dado   (v0 -> v1)  o erro caiu 5,4x
--     criar feature   (v1 -> v3)  o R2 subiu de 0,298 pra 0,471
--     trocar modelo   (v3 -> v4)  o erro caiu mais 26%
--
--   Comeco: erra R$ 13,8 milhoes e e PIOR que chutar a media.
--   Fim:    erra R$ 1,8 milhao e explica 56% da variacao do preco.
--
-- Para pensar: qual das tres alavancas deu o maior ganho?
--  A aposta natural e a troca de modelo, porque e a que parece "de
--  ML". Foi a limpeza, de longe — e ela e a que ninguem quer fazer.
--  Sem a gold, a arvore treinaria no dado de R$ 1,4 bilhao e iria
--  mal do mesmo jeito. Algoritmo bom nao salva dado ruim.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 3 — A mesma pergunta, duas respostas diferentes
-- ---------------------------------------------------------------------
-- Agora pergunte pros DOIS modelos quais colunas eles usaram.
-- Rode as duas queries e compare lado a lado.

-- 3a) O linear (v3):
SELECT feature, ROUND(attribution, 0) AS atribuicao
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_preco_v3`)
ORDER BY attribution DESC;

-- 3b) A arvore (v4):
SELECT feature, ROUND(attribution, 0) AS atribuicao
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_preco_arvore`)
ORDER BY attribution DESC;

-- RESULTADO MEDIDO (top 5 de cada)
-- ---------------------------------------------------------------------
--   LINEAR v3                      ARVORE v4
--   bairro          1.168.812      area_util      1.880.364
--   eh_comercial    1.157.458      garagem          826.542
--   tem_mobilia     1.131.424      quartos          438.815
--   tem_piscina     1.128.073      suites           434.656
--   eh_casa         1.127.408      bairro           411.132
--   ...                            ...
--   area_util         334.058      tem_piscina            0
--
--   Leia isso com calma, porque e contraintuitivo:
--
--   No LINEAR, as flags de texto estao no topo e a area_util no fim.
--   Na ARVORE, a area_util domina e a piscina vale ZERO.
--
--   As duas leituras estao certas. Elas nao respondem "o que decide o
--   preco de um imovel no mundo real" — respondem "o que ESTE modelo
--   usou pra chegar no numero dele".
--
--   O linear so consegue somar. Pra ele, uma flag booleana e um degrau
--   grande e barato: ligou a flag, soma R$ 1,1 milhao. A arvore
--   consegue QUEBRAR a area_util em faixas, entao ela ja separa
--   terreno de apartamento olhando so o tamanho — e a flag de texto
--   fica redundante.
--
--   "Importancia de feature nao e verdade sobre o mundo.
--    E confissao de um modelo especifico."
--
--   No relatorio do trabalho de voces: sempre diga de QUAL modelo veio
--   o ranking de importancia. Sem isso a frase nao significa nada.
-- ---------------------------------------------------------------------


-- =====================================================================
-- PARTE B — Treinar sem resposta: KMEANS
-- =====================================================================
-- Tudo ate aqui foi APRENDIZADO SUPERVISIONADO:
-- existia uma coluna certa (preco, eh_comercial) e o modelo tentava
-- acertar ela.
--
-- Agora um caso sem gabarito. A pergunta muda de:
--     "quanto vale este imovel?"
-- para:
--     "que tipos de imovel existem nessa base, afinal?"
--
-- Ninguem etiquetou isso. Nao ha input_label_cols. O modelo tem que
-- descobrir os grupos sozinho.


-- ---------------------------------------------------------------------
-- PASSO 4 — Segmentar o mercado
-- ---------------------------------------------------------------------

CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.segmentos_imoveis`
OPTIONS (
  model_type           = 'KMEANS',
  num_clusters         = 4,
  standardize_features = TRUE
) AS
SELECT
  preco,
  area_util,
  quartos,
  banheiros,
  garagem
FROM `SEU_PROJETO.anuncios.gold_texto`;

-- COMO LER ESTE COMANDO
-- ---------------------------------------------------------------------
--  Repare no que NAO tem aqui: input_label_cols. Nao existe resposta
--  certa. O KMEANS so joga os 887 imoveis num espaco de 5 dimensoes
--  (preco, area, quartos, banheiros, garagem) e procura 4 nuvens.
--
--  num_clusters = 4        -> quantos grupos voce quer. Voce escolhe.
--                             Nao existe numero "certo": 4 e um chute
--                             informado que da pra explicar pra um
--                             humano. (Da pra deixar o BQML escolher
--                             omitindo essa opcao — ele testa varios.)
--
--  standardize_features    -> OBRIGATORIO na pratica aqui. Preco esta
--    = TRUE                   na casa dos milhoes e quartos na casa
--                             das unidades. Sem padronizar, a distancia
--                             entre dois imoveis vira praticamente
--                             "diferenca de preco" e as outras quatro
--                             colunas somem. Padronizar poe todas na
--                             mesma escala antes de medir distancia.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 5 — Ler os grupos que ele achou
-- ---------------------------------------------------------------------
-- O KMEANS devolve "CENTROID_ID 1, 2, 3, 4". Ele NAO da nome.
-- Dar nome e trabalho seu. Perfile e batize.

SELECT
  CENTROID_ID                                          AS segmento,
  COUNT(*)                                             AS imoveis,
  CAST(APPROX_QUANTILES(preco, 100)[OFFSET(50)] AS INT64)     AS preco_mediano,
  CAST(APPROX_QUANTILES(area_util, 100)[OFFSET(50)] AS INT64) AS area_mediana,
  ROUND(AVG(quartos), 1)                               AS quartos_medio,
  ROUND(AVG(garagem), 1)                               AS vagas_media,
  ROUND(100 * AVG(CAST(eh_comercial AS INT64)), 1)     AS pct_comercial
FROM ML.PREDICT(
       MODEL `SEU_PROJETO.anuncios.segmentos_imoveis`,
       TABLE `SEU_PROJETO.anuncios.gold_texto`)
GROUP BY segmento
ORDER BY preco_mediano;

-- RESULTADO MEDIDO
-- ---------------------------------------------------------------------
--  seg  imoveis  preco_mediano  area_med  quartos  vagas  %comercial
--   1      610      8.300.000       527      4,4     4,7      3,0%
--   4      188     10.500.000     1.798      0,0    12,2     61,7%
--   2       11     12.000.000     2.337     13,3    26,9     90,9%
--   3       78     16.500.000       760      5,1     6,2      2,6%
--
--  Agora batize cada um lendo a linha:
--
--   seg 1  (610) -> residencial padrao. 4 quartos, 527 m2, 3% comercial.
--                   E o miolo do mercado.
--   seg 4  (188) -> ZERO quarto, 12 vagas, 1.798 m2, 62% comercial.
--                   Isso e galpao, sala e terreno comercial.
--   seg 2  ( 11) -> 13 quartos, 27 vagas, 91% comercial.
--                   Predio inteiro / hotel / pousada. So 11 imoveis.
--   seg 3  ( 78) -> mediana R$ 16,5 mi com 760 m2 e 2,6% comercial.
--                   Alto padrao residencial: o preco por m2 e o dobro
--                   do seg 1.
--
--  Repare no que aconteceu: o KMEANS RECONSTRUIU o tipo_imovel que a
--  silver perdeu. Ninguem contou pra ele o que e galpao. Ele olhou
--  "zero quarto e doze vagas" e separou.
--
--  E o seg 2, com 11 imoveis, e o alerta permanente do KMEANS: ele
--  SEMPRE devolve os 4 grupos que voce pediu, mesmo quando um deles
--  e so um punhado de outliers. Cluster pequeno demais nao e
--  descoberta, e sobra. Olhe o COUNT antes de escrever a conclusao.
--
-- Para pensar: que nome voce daria ao segmento 4 antes de ler a
--  interpretacao acima? A resposta provavel e "terreno" — e o ponto
--  e esse: o modelo achou o tipo de imovel sem ninguem etiquetar
--  nada.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 6 — Para onde o cardapio continua
-- ---------------------------------------------------------------------
-- Voce usou hoje 4 dos tipos de modelo do BQML. O menu completo, tudo
-- com o mesmo CREATE MODEL / ML.EVALUATE / ML.PREDICT:
--
--   REGRESSAO         LINEAR_REG, BOOSTED_TREE_REGRESSOR,
--                     RANDOM_FOREST_REGRESSOR, DNN_REGRESSOR,
--                     AUTOML_REGRESSOR
--   CLASSIFICACAO     LOGISTIC_REG, BOOSTED_TREE_CLASSIFIER,
--                     RANDOM_FOREST_CLASSIFIER, DNN_CLASSIFIER
--   SEM LABEL         KMEANS, PCA, AUTOENCODER
--   SERIE TEMPORAL    ARIMA_PLUS            (preco medio do m2 por mes)
--   RECOMENDACAO      MATRIX_FACTORIZATION  (usuario x imovel visto)
--   TEXTO / LLM       ML.GENERATE_EMBEDDING + VECTOR_SEARCH,
--                     ML.GENERATE_TEXT      (chama Gemini de dentro
--                                            do SQL, via conexao remota)
--   TRAZER DE FORA    TENSORFLOW, ONNX, REMOTE  (modelo treinado fora,
--                                            servido dentro do BQ)
--
-- Trocar de familia = trocar a string do model_type. Trocar de
-- REGRESSAO pra CLASSIFICACAO exige tambem trocar o label e as
-- metricas que voce olha (script 04).
--
-- Nao existe "o melhor modelo". Existe o que voce MEDIU melhor no seu
-- dado. E medir custa uma query.


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Rode o CREATE MODEL do PASSO 1 trocando BOOSTED_TREE_REGRESSOR
--    por RANDOM_FOREST_REGRESSOR e por DNN_REGRESSOR. Monte um placar
--    de 6 modelos. Qual ganha? A diferenca justifica o tempo de treino?
--
-- 2) A arvore do PASSO 1 usou gold_texto. Treine a MESMA arvore sobre
--    a anuncios_gold (sem as flags de texto). Quanto das melhorias
--    veio do algoritmo e quanto veio da feature? Essa e a pergunta que
--    separa relatorio bom de relatorio ruim.
--
-- 3) Refaca o KMEANS com num_clusters = 3, 5, 6 e 8. A partir de quantos
--    grupos as descricoes comecam a ficar impossiveis de nomear? Use
--    ML.EVALUATE no modelo KMEANS pra ver o davies_bouldin_index
--    (menor = grupos mais separados) e cruze com a sua leitura humana.
--
-- 4) Junte as duas partes: crie a coluna segmento com ML.PREDICT do
--    KMEANS, grave numa tabela e use ELA como feature de entrada da
--    arvore de preco. Melhorou? (Cuidado: o KMEANS foi treinado COM o
--    preco dentro. Isso e vazamento? Refaca o KMEANS sem a coluna
--    preco antes de responder.)
--
-- 5) O segmento 2 tem 11 imoveis. Investigue-os com um SELECT e decida:
--    sao um nicho real do mercado de Goiania ou lixo que sobrou da
--    limpeza do script 02? Se for lixo, volte no script 02 e proponha
--    o filtro que faltou.
