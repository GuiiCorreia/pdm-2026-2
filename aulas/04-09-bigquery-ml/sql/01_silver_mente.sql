-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 1: A SILVER MENTE
-- =====================================================================
--
-- Voce construiu essa tabela com o Savio: raw -> bronze -> silver.
-- 23 colunas tipadas, zero JSON. A vontade agora e treinar o modelo.
--
-- Antes disso: tres queries olhando o dado.
--
-- A tese deste script (e da aula):
--
--     SILVER NAO QUER DIZER LIMPO. QUER DIZER ESTRUTURADO.
--     Tipar a coluna nao conserta o valor que esta dentro dela.
--
-- COMO USAR: troque SEU_PROJETO pelo id do seu projeto GCP.
-- O dataset criado nos notebooks do Savio chama `anuncios`.
-- =====================================================================


-- ---------------------------------------------------------------------
-- MENTIRA 1 — O preco (estatistica descritiva basica)
-- ---------------------------------------------------------------------
-- Comece pelo mais simples que existe. E ja aparece o problema.

SELECT
  COUNT(*)                                        AS anuncios,
  ROUND(MIN(preco))                               AS menor_preco,
  ROUND(APPROX_QUANTILES(preco, 100)[OFFSET(50)]) AS mediana,
  ROUND(AVG(preco))                               AS media,
  ROUND(MAX(preco))                               AS maior_preco,
  ROUND(STDDEV(preco))                            AS desvio_padrao
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE preco IS NOT NULL;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- COUNT, MIN, AVG, MAX, STDDEV sao funcoes de agregacao: comem a
-- coluna inteira e devolvem UM numero. Sem GROUP BY, o "grupo" e a
-- tabela toda — sai uma linha so.
--
-- A unica estranha e a mediana, porque o SQL nao tem MEDIAN():
--
--   APPROX_QUANTILES(preco, 100)[OFFSET(50)]
--    |                       |      |
--    |                       |      +-- pega o item 50 dessa lista
--    |                       +--------- corta a distribuicao em 100 partes
--    +--------------------------------- devolve um ARRAY com 101 valores
--
--   O array vai do minimo (posicao 0) ao maximo (posicao 100).
--   A posicao 50 e a mediana; a 90 seria o percentil 90 — a mesma
--   funcao serve para os dois. O "APPROX" e proposital: em bilhoes
--   de linhas, ordenar tudo para achar o meio exato e caro. Ele
--   estima, com erro conhecido e baixo.
-- =====================================================================

-- RESULTADO ESPERADO (medido na tb_anuncios_silver de 1.000 anuncios):
--   menor_preco  R$        29.000
--   mediana      R$     9.083.228
--   media        R$    20.638.086   <<< mais que o DOBRO da mediana
--   maior_preco  R$ 1.419.000.000   <<< um imovel de 1,4 BILHAO
--   desvio       R$    72.087.491
--
-- PERGUNTA:
--   "Por que a media e mais que o dobro da mediana?"
--
-- Resposta: alguem la em cima esta puxando tudo.
-- Quando media >> mediana, existe outlier. Sempre.


-- Achar os culpados:
SELECT
  bairro,
  titulo,
  area_util,
  quartos,
  ROUND(preco) AS preco
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE preco > 50000000
ORDER BY preco DESC
LIMIT 10;

-- O QUE VAI APARECER: imoveis comuns com preco de pais pequeno.
-- O anunciante digitou o valor em milhares (ou centavos), e o sistema
-- aceitou. Passou pelo raw, passou pelo bronze, passou pelo SAFE_CAST
-- da silver — porque 1419000000 E um FLOAT64 perfeitamente valido.
--
--   "O pipeline validou o TIPO. Ninguem validou o VALOR."


-- Quantos sao? E quanto eles pesam?
SELECT
  COUNTIF(preco > 50000000)                            AS anuncios_suspeitos,
  COUNT(*)                                             AS total,
  ROUND(100 * COUNTIF(preco > 50000000) / COUNT(*), 1) AS pct,
  ROUND(STDDEV(preco))                                 AS desvio_com_eles,
  ROUND(STDDEV(IF(preco <= 50000000, preco, NULL)))    AS desvio_sem_eles
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE preco IS NOT NULL;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Esta query tem um truque que vale para a vida inteira: ela mede o
-- "com" e o "sem" NA MESMA PASSADA, sem apagar nada.
--
--   COUNTIF(condicao)
--     conta so as linhas onde a condicao e verdadeira. E acucar para
--     SUM(IF(condicao, 1, 0)).
--
--   STDDEV(preco)                              <- desvio COM os outliers
--   STDDEV(IF(preco <= 50000000, preco, NULL)) <- desvio SEM os outliers
--
--     O IF por dentro e a chave: ele nao remove a LINHA, ele troca o
--     VALOR por NULL — e toda agregacao ignora NULL. A mesma coluna,
--     duas leituras, lado a lado.
--
--   "WHERE decide quais LINHAS entram na conta.
--    IF por dentro do agregado decide quais VALORES entram."
--
-- Pergunta para a turma:
--   se em vez de NULL o IF devolvesse 0, o que acontecia com o
--   desvio_sem_eles? (resposta: viria errado — as 29 linhas
--   continuariam na conta, valendo zero. NULL e "nao existe".
--   Zero e um valor.)
-- =====================================================================

-- RESULTADO ESPERADO:
--   29 anuncios de 1.000  =  2,9%
--   desvio COM eles:  R$ 72.087.491
--   desvio SEM eles:  R$  6.927.941   <<< caiu 90,4%
--
-- GUARDE ESTE NUMERO: 2,9% das linhas controlam 90% da variacao.
--
--   "Se voce nao olhar essas 29 linhas, o seu modelo vai passar o
--    treino inteiro tentando explicar um imovel de R$ 1,4 bilhao
--    que nao existe."


-- ---------------------------------------------------------------------
-- MENTIRA 2 — A fazenda do tamanho de meio Goiania
-- ---------------------------------------------------------------------
SELECT
  bairro,
  titulo,
  area_util,
  area_total,
  ROUND(preco) AS preco
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE area_util > 100000
ORDER BY area_util DESC
LIMIT 10;

-- O maior valor e 459.800.000 m2.
-- Isso e 459,8 km2 — cerca de 63% do municipio de Goiania (~729 km2).
-- Um imovel a venda ocupando dois tercos da cidade onde ele esta
-- anunciado.
--
-- Causa: mistura de unidade. Alguem preencheu em m2, outro em
-- hectares, outro em alqueires, e o campo aceitou os tres.
--
-- LICAO:
--   "Nenhum modelo vai te avisar que o numero e impossivel.
--    Quem sabe que uma fazenda nao ocupa 63% de Goiania
--    e voce, nao ele."

SELECT
  COUNTIF(area_util > 10000) AS acima_de_10mil_m2,
  COUNTIF(area_util <= 1)    AS area_zero_ou_um,
  COUNT(*)                   AS total
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`;
-- Esperado: 83 acima de 10.000 m2, 1 com area <= 1 m2.
-- Os dois extremos mentem: a fazenda impossivel e o imovel de 1 m2.


-- ---------------------------------------------------------------------
-- MENTIRA 3 — Colunas que parecem features e nao sao
-- ---------------------------------------------------------------------
-- Parte A: as colunas mortas.

SELECT
  COUNT(DISTINCT tipo_contrato) AS tipos_contrato,
  COUNT(DISTINCT status)        AS status_distintos,
  COUNT(DISTINCT cidade)        AS cidades
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`;

-- RESULTADO ESPERADO:  1 | 1 | 2
--
--   tipo_contrato: 'REAL_ESTATE' nas 1.000 linhas.
--   status:        'ACTIVE'      nas 1.000 linhas.
--   cidade:        999 Goiania + 1 Senador Canedo.
--
-- Coluna com um valor so nao ensina NADA a um modelo: nao ha o que
-- comparar. Ela existe, esta tipada, esta "estruturada" — e e inutil.
--
--   "Feature morta nao da erro. Ela da peso zero e ocupa espaco.
--    O problema e voce CONTAR com ela."

-- Parte B: as coordenadas que caem no lugar errado.

SELECT
  id_anuncio,
  bairro,
  latitude,
  longitude
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE latitude < -40 OR latitude IS NULL
ORDER BY latitude NULLS LAST   -- sem o NULLS LAST, os 377 NULLs escondem as trocadas
LIMIT 10;

-- Goiania fica em latitude ~ -16,7 e longitude ~ -49,2.
--
-- RESULTADO ESPERADO: 2 anuncios (ids 2848670234 e 2815113524) com
--   latitude  = -49.196...   <<< isso e a LONGITUDE
--   longitude = -16.706...   <<< isso e a LATITUDE
--
-- Alguem inverteu os campos no cadastro. Plotado num mapa, o imovel
-- cai no meio do oceano Indico. O SAFE_CAST aprovou: -49.19 e um
-- FLOAT64 valido. So nao e uma latitude de Goiania.
--
-- E tem coisa pior que o par trocado: 377 anuncios (37,7%) nem TEM
-- coordenada. Guarde isso — vai decidir se lat/long vira feature.


-- ---------------------------------------------------------------------
-- FECHAMENTO DO BLOCO
-- ---------------------------------------------------------------------
-- Tres queries, tres mentiras, na tabela que o pipeline inteiro
-- aprovou:
--
--   1. Preco:  29 linhas (2,9%) seguram 90% do desvio padrao.
--   2. Area:   uma "fazenda" de 63% de Goiania, 83 areas impossiveis.
--   3. Schema: 3 colunas mortas + coordenadas trocadas e faltando.
--
--   "SILVER NAO QUER DIZER LIMPO. QUER DIZER ESTRUTURADO.
--    O proximo script constroi a tabela em que da para confiar."


-- ---------------------------------------------------------------------
-- DESAFIOS (para depois da aula)
-- ---------------------------------------------------------------------
-- 1) MIN e MAX voce confere no olho. Mediana e desvio, nao. Escreva
--    uma query que VALIDE a mediana de outro jeito (dica: COUNTIF
--    acima e abaixo do valor devem dar ~metade cada).
-- 2) area_total tambem mente? Compare area_util e area_total: em
--    quantos anuncios area_util > area_total? Isso e possivel?
-- 3) Ha anuncios DUPLICADOS na silver (mesmo titulo, mesmo preco).
--    Quantos? Use GROUP BY titulo, preco HAVING COUNT(*) > 1.
--    Por que duplicata e um problema para o treino de um modelo?
