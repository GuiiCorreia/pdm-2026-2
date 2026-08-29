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

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- COUNT, MIN, AVG, MAX, STDDEV sao funcoes de agregacao: comem a
-- coluna inteira e devolvem UM numero. Como nao tem GROUP BY, o
-- "grupo" e a tabela toda — sai uma linha so.
--
-- A unica estranha e a mediana, porque o SQL nao tem MEDIAN():
--
--   APPROX_QUANTILES(preco, 100)[OFFSET(50)]
--    |                       |      |
--    |                       |      +-- pega o item 50 dessa lista
--    |                       +--------- corte a distribuicao em 100 partes
--    +--------------------------------- devolve um ARRAY com 101 valores
--
--   Corta em 100 pedacos = percentis. O array vai do minimo (posicao 0)
--   ao maximo (posicao 100). A posicao 50 e a mediana. A posicao 90
--   seria o percentil 90 — e a mesma funcao serve para os dois.
--   OFFSET(50) e "item de indice 50", contando do zero.
--   O "APPROX" e proposital: em bilhoes de linhas, ordenar tudo para
--   achar o meio exato e caro. Ele estima, com erro conhecido e baixo.
--
-- E o WHERE preco IS NOT NULL: agregacao ja ignora NULL sozinha, mas
-- deixar explicito serve para VOCE lembrar de que existem NULLs ali.
--
-- Pergunta para a turma antes de seguir:
--   MIN e MAX voces conseguem conferir no olho. Mediana e desvio
--   padrao, nao. Se essa query estivesse errada, como voces
--   descobririam?
-- =====================================================================

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

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Esta query tem um truque que vale para a vida inteira: ela mede o
-- "com" e o "sem" NA MESMA PASSADA, sem apagar nada.
--
--   COUNTIF(preco > 50000000)
--     conta so as linhas onde a condicao e verdadeira. E acucar para
--     SUM(IF(condicao, 1, 0)) — o mesmo resultado, menos digitacao.
--
--   STDDEV(preco)                              <- desvio COM os outliers
--   STDDEV(IF(preco <= 50000000, preco, NULL)) <- desvio SEM os outliers
--
--     O IF por dentro e a chave. Ele nao remove a LINHA, ele troca o
--     VALOR por NULL. E toda funcao de agregacao ignora NULL.
--     Resultado: a mesma coluna, duas leituras, lado a lado.
--
--   ROUND(100 * COUNTIF(...) / COUNT(*), 1)
--     percentual com uma casa. Repare que COUNTIF e COUNT(*) sao os
--     dois agregacoes — da pra fazer conta entre elas normalmente.
--
-- POR QUE NAO FAZER COM UM WHERE?
--   Com WHERE preco <= 50000000 voce so consegue o desvio "sem".
--   Para ter os dois, precisaria de duas queries, e ai voce compara
--   dois numeros que sairam de execucoes diferentes. Com o IF por
--   dentro, os dois numeros vem da mesma leitura da tabela.
--
--   "WHERE decide quais LINHAS entram na conta.
--    IF por dentro do agregado decide quais VALORES entram."
--
-- Pergunta para a turma antes de seguir:
--   se em vez de NULL a gente colocasse 0 no IF, o que aconteceria
--   com o desvio_sem_eles?
--   (resposta: viria errado e para baixo — as 29 linhas continuariam
--    na conta, agora valendo zero, puxando a media para o chao.
--    NULL e "nao existe". Zero e um valor)
-- =====================================================================

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
-- SUJEIRA 2 — A fazenda do tamanho de metade de Goiânia
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
-- Isso e 390 km2 — mais da METADE do municipio de Goiania (~729 km2).
-- Um imovel a venda ocupando metade da cidade onde ele esta anunciado.
--
-- Causa: mistura de unidade. Alguem preencheu em m2, outro em
-- hectares, outro em alqueires, e o campo aceitou os tres.
--
-- LICAO:
--   "Nenhum modelo vai te avisar que o numero e impossivel.
--    Quem sabe que uma fazenda nao ocupa metade de Goiania
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
-- Medicao: em 25,9% dos anuncios (259 de 1000) aparece "R$" dentro
-- da descricao, quase sempre com o preco do anuncio junto.
--
-- GUARDE ESSE 25,9%. Ele volta no ultimo script da aula, e la
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
  AND cidade = 'Goiânia'                 -- 999 de 1000 ja sao; tira o ruido
;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Sintaxe, nenhuma novidade: e um SELECT com WHERE virando tabela.
-- O que tem para ler aqui nao e SQL, e DECISAO. Cada linha do WHERE
-- e uma escolha sua sobre o que e "dado valido", e cada uma joga
-- linha fora para sempre.
--
--   preco IS NOT NULL
--     sem alvo nao da para treinar. Nao e limpeza, e requisito.
--
--   preco BETWEEN 50000 AND 50000000
--     BETWEEN inclui as duas pontas. O teto de 50 milhoes e o corte
--     das 29 linhas que a gente acabou de medir la em cima. O piso
--     de 50 mil corta o caminho oposto: quem digitou o valor em
--     milhares e virou "R$ 850".
--
--   area_util BETWEEN 20 AND 10000
--     a fazenda do tamanho de metade de Goiania sai por aqui.
--
--   cidade = 'Goiânia'
--     999 de 1000 ja eram. Este filtro nao existe para limpar, e sim
--     para GARANTIR que o modelo fale de um mercado so.
--
-- E a coluna nova:
--   ROUND(preco / area_util, 2) AS preco_por_m2
--     coluna derivada — nao veio do JSON, foi calculada. Repare que
--     ela so e segura DEPOIS do filtro: area_util = 0 daria divisao
--     por zero, e area_util = 390.000.000 daria um preco por metro
--     de centavos. O WHERE protege o SELECT.
--
--   "A ordem importa: primeiro voce decide o que e valido,
--    depois voce calcula em cima disso."
--
-- Pergunta para a turma antes de seguir:
--   os quatro filtros sao regras de negocio disfarcadas de SQL.
--   Quem, numa empresa de verdade, deveria assinar embaixo do
--   "50 milhoes" — voces ou a area de negocio?
-- =====================================================================

-- REPARE NO ACENTO: 'Goiânia', nao 'Goiania'.
-- Se voce digitar sem acento, o filtro nao casa com nada e a tabela
-- sai VAZIA — sem erro, sem aviso, sem uma linha vermelha na tela.
-- Voce so descobre tres queries depois, quando o CREATE MODEL falhar.
--
--   "Um filtro errado nao da erro. Ele da silencio."
--
-- E por isso que a proxima query, a de conferencia, nao e opcional.

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
