-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SILVER (parte 2): o dado esta mentindo
-- =====================================================================
--
-- Este e o bloco que separa quem faz ML de quem faz ML QUE FUNCIONA.
--
-- A tabela esta pronta. A vontade agora e treinar o modelo.
-- Antes disso: tres minutos olhando o dado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- SUJEIRA 1 — Estatistica descritiva basica
-- ---------------------------------------------------------------------
-- Comece pelo mais simples que existe. E ja aparece o problema.

SELECT
  COUNT(*)                          AS anuncios,
  ROUND(MIN(preco))                 AS menor_preco,
  ROUND(APPROX_QUANTILES(preco, 100)[OFFSET(50)]) AS mediana,
  ROUND(AVG(preco))                 AS media,
  ROUND(MAX(preco))                 AS maior_preco,
  ROUND(STDDEV(preco))              AS desvio_padrao
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE preco IS NOT NULL;

-- RESULTADO ESPERADO (medido no dataset de 1.000 anuncios):
--   mediana      R$   9.200.000
--   media        R$  20.809.770   <<< mais que o DOBRO da mediana
--   maior_preco  R$ 1.419.000.000
--   desvio       R$  72.055.740
--
-- PERGUNTA:
--   "Por que a media e o dobro da mediana?"
--
-- Resposta: alguem la em cima esta puxando tudo.
-- Quando media >> mediana, existe outlier. Sempre.


-- ---------------------------------------------------------------------
-- SUJEIRA 1 (continuacao) — Achar os culpados
-- ---------------------------------------------------------------------
SELECT
  bairro,
  tipo_imovel,
  area_util,
  quartos,
  ROUND(preco) AS preco
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE preco > 50000000
ORDER BY preco DESC
LIMIT 10;

-- O QUE VAI APARECER:
--   um APARTAMENTO de 74 m2 em Vila Rosa por R$ 499.000.000
--
-- Olhe para essa linha antes de seguir. Voce acredita nesse preco?
--
-- O que aconteceu: o anunciante digitou o valor em milhares.
-- R$ 499.000 virou R$ 499.000.000. O sistema aceitou.
-- Nenhum banco de dados vai te avisar disso. Nenhum modelo tambem.


-- ---------------------------------------------------------------------
-- SUJEIRA 1 (o numero que importa)
-- ---------------------------------------------------------------------
-- Quantos sao? E quanto eles pesam?

SELECT
  COUNTIF(preco > 50000000)                     AS anuncios_suspeitos,
  COUNT(*)                                      AS total,
  ROUND(100 * COUNTIF(preco > 50000000) / COUNT(*), 1) AS pct,
  ROUND(STDDEV(preco))                          AS desvio_com_eles,
  ROUND(STDDEV(IF(preco <= 50000000, preco, NULL))) AS desvio_sem_eles
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE preco IS NOT NULL;

-- RESULTADO:
--   29 anuncios de 1000  =  2,9%
--   desvio COM eles:  R$ 72.055.740
--   desvio SEM eles:  R$  6.823.132   <<< caiu 90,5%
--
-- GUARDE ESTE NUMERO:
--   2,9% das linhas controlam 90% da variacao.
--
--   "Se voce nao olhar essas 29 linhas, o seu modelo vai passar o
--    treino inteiro tentando explicar um apartamento de
--    R$ 499 milhoes que nao existe."


-- ---------------------------------------------------------------------
-- SUJEIRA 2 — A fazenda maior que a Alemanha
-- ---------------------------------------------------------------------
SELECT
  bairro,
  tipo_imovel,
  area_util,
  ROUND(preco) AS preco
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE area_util > 100000
ORDER BY area_util DESC
LIMIT 10;

-- O maior valor e 390.000.000 m2.
-- Isso e 390 mil km2 — maior que a Alemanha (357 mil km2).
--
-- Causa: mistura de unidade. Alguem preencheu em m2, outro em
-- hectares, outro em alqueires, e o campo aceitou os tres.
--
-- LICAO:
--   "Nenhum modelo vai te avisar que o numero e impossivel.
--    Quem sabe que uma fazenda nao tem o tamanho da Alemanha
--    e voce, nao ele."

SELECT
  COUNTIF(area_util > 10000) AS acima_de_10mil_m2,
  COUNTIF(area_util <= 1)    AS area_zero_ou_um,
  COUNT(*)                   AS total
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`;
-- Esperado: 83 acima de 10.000 m2


-- ---------------------------------------------------------------------
-- SUJEIRA 3 — O preco esta escrito na descricao
-- ---------------------------------------------------------------------
-- Esta e a mais perigosa das tres, porque nao parece problema.

SELECT
  id_anuncio,
  ROUND(preco) AS preco,
  SUBSTR(descricao, 1, 180) AS trecho_da_descricao
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE REGEXP_CONTAINS(descricao, r'R\$')
LIMIT 10;

-- Voces vao ver descricoes tipo:
--   "Casa a Venda - House Garden | Valor: A partir de R$ 961.510,78"
--
-- E o preco na coluna e exatamente 961510.78.
--
-- Medicao: em 22,8% dos anuncios o preco esta literalmente
-- escrito dentro do texto.
--
-- GUARDE ESSE 22,8%. Ele volta no ultimo script da aula, e la
-- ele deixa de ser curiosidade e vira o problema mais caro do dia.
--
-- Por enquanto, so a pergunta:
--   a descricao e uma boa feature para prever preco?


-- ---------------------------------------------------------------------
-- A LIMPEZA — construir a camada Gold
-- ---------------------------------------------------------------------
-- Agora sim. Regras explicitas, cada uma justificada.

CREATE OR REPLACE TABLE `SEU_PROJETO.SEU_DATASET.imoveis_gold` AS
SELECT
  id_anuncio,
  preco,
  area_util,
  quartos,
  banheiros,
  suites,
  vagas,
  condominio,
  iptu_anual,
  bairro,
  tipo_imovel,
  uso,
  imobiliaria,
  qtd_comodidades,
  descricao,
  ROUND(preco / area_util, 2) AS preco_por_m2
FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver`
WHERE
      preco IS NOT NULL
  AND preco BETWEEN 50000 AND 50000000   -- corta erro de escala (2,9%)
  AND area_util BETWEEN 20 AND 10000     -- corta unidade trocada
  AND cidade = 'Goiania'                 -- 999 de 1000 ja sao; tira o ruido
;

-- Conferencia: quanto sobrou e como ficou a distribuicao?
SELECT
  COUNT(*) AS anuncios,
  ROUND(APPROX_QUANTILES(preco, 100)[OFFSET(50)]) AS mediana,
  ROUND(AVG(preco))    AS media,
  ROUND(STDDEV(preco)) AS desvio,
  ROUND(APPROX_QUANTILES(preco_por_m2, 100)[OFFSET(50)]) AS mediana_m2
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`;

-- Agora media e mediana devem estar proximas. Era esse o objetivo.
--
-- FECHAMENTO DO BLOCO — e a tese da aula inteira:
--   "Isso que a gente acabou de fazer tem nome: ETL.
--    Nao e a parte chata antes do ML.
--    E a parte que decide se o ML vai servir pra alguma coisa."


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Em vez de cortar em R$ 50 milhoes na mao, corte pelo percentil 99
--    usando APPROX_QUANTILES. Qual dos dois voce defenderia num
--    relatorio, e por que?
-- 2) Quantos anuncios sobraram por bairro? Algum bairro sumiu inteiro
--    depois da limpeza? Isso e um problema?
-- 3) O corte em area_util > 20 elimina kitnets reais. Como voce trataria
--    fazendas e apartamentos sem jogar nenhum dos dois fora?
