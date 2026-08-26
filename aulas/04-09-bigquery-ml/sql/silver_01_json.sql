-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SILVER (parte 1): transformar JSON em tabela
-- =====================================================================
--
-- Onde estamos: em 21/08 voces criaram Bronze, Silver e Gold.
-- Hoje a gente vai fazer a Silver de novo, mas com um dado que
-- resiste: um JSON aninhado. E depois vamos treinar em cima dela.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — Pegar UM campo de dentro do JSON
-- ---------------------------------------------------------------------
-- JSON_VALUE(coluna, '$.caminho') -> extrai um valor escalar.
-- O '$' e a raiz do documento. O ponto desce um nivel.

SELECT
  id_anuncio,
  JSON_VALUE(listing, '$.address.city')          AS cidade,
  JSON_VALUE(listing, '$.address.neighborhood')  AS bairro
FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`
LIMIT 10;

-- PARE E PENSE:
--   "Quantas linhas de Python isso seria?"
-- (json.loads, try/except pra chave faltando, dict.get aninhado,
--  um loop, um DataFrame... aqui foram duas linhas de SQL.)


-- ---------------------------------------------------------------------
-- PASSO 2 — Quando o campo e uma LISTA
-- ---------------------------------------------------------------------
-- Varios campos vem como lista de um elemento so:
--     "bedrooms": [3]     "usableAreas": [120]
--
-- Duas formas de pegar o primeiro item:
--   a) indice direto no caminho: '$.bedrooms[0]'
--   b) JSON_QUERY_ARRAY + UNNEST (necessario quando a lista tem varios)

SELECT
  id_anuncio,
  JSON_VALUE(listing, '$.usableAreas[0]') AS area,
  JSON_VALUE(listing, '$.bedrooms[0]')    AS quartos,
  JSON_VALUE(listing, '$.bathrooms[0]')   AS banheiros,
  JSON_VALUE(listing, '$.parkingSpaces[0]') AS vagas
FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`
LIMIT 10;

-- REPARE: tudo volta como STRING. JSON nao tem tipo forte.
-- Vamos ter que converter. Isso e o PASSO 4.


-- ---------------------------------------------------------------------
-- PASSO 3 — Quando a lista tem OBJETOS dentro (o caso do preco)
-- ---------------------------------------------------------------------
-- O preco nao esta solto. Ele esta em pricingInfos, que e uma lista
-- de objetos, e um anuncio pode ter mais de um (venda E aluguel):
--
--   "pricingInfos": [
--       {"businessType":"SALE",   "price":"850000", "yearlyIptu":"1200"},
--       {"businessType":"RENTAL", "price":"3500",   "monthlyCondoFee":"600"}
--   ]
--
-- Entao nao da pra pegar '$.pricingInfos[0].price' e sair correndo:
-- o primeiro item nem sempre e a venda.
--
-- Solucao: abrir a lista com UNNEST e filtrar pelo businessType.

SELECT
  id_anuncio,
  (SELECT JSON_VALUE(p, '$.price')
   FROM UNNEST(JSON_QUERY_ARRAY(listing, '$.pricingInfos')) AS p
   WHERE JSON_VALUE(p, '$.businessType') = 'SALE'
   LIMIT 1) AS preco_venda
FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`
LIMIT 10;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Tem uma query DENTRO do SELECT. Leia ela primeiro, de dentro pra fora:
--
--   1) JSON_QUERY_ARRAY(listing, '$.pricingInfos')
--      Pega o pedaco do JSON que e uma lista e devolve um ARRAY.
--      Repare na familia de funcoes:
--        JSON_VALUE       -> devolve UM valor escalar, ja como texto
--        JSON_QUERY_ARRAY -> devolve uma LISTA de pedacos de JSON
--      Aqui a gente quer a lista inteira, entao e a segunda.
--
--   2) FROM UNNEST( ... ) AS p
--      UNNEST transforma ARRAY em LINHAS. Uma linha por elemento.
--      O "AS p" da um apelido a cada elemento — e p continua sendo
--      um JSON, entao da pra fazer JSON_VALUE(p, ...) nele.
--      (E o equivalente do explode() do pandas, dentro do FROM.)
--
--   3) WHERE JSON_VALUE(p, '$.businessType') = 'SALE'
--      Agora que virou linha, filtrar e SQL normal.
--      E exatamente isto que resolve o problema: em vez de apostar
--      que a venda e o item [0], a gente PROCURA a venda.
--
--   4) SELECT JSON_VALUE(p, '$.price')
--      Da linha que sobrou, pega o preco.
--
--   5) LIMIT 1
--      Nao e enfeite. Os parenteses em volta de tudo isso fazem uma
--      SUBQUERY ESCALAR: uma query usada como se fosse uma coluna.
--      Ela e OBRIGADA a devolver no maximo uma linha. Sem o LIMIT 1,
--      um anuncio com duas vendas cadastradas derruba a query com
--      "Scalar subquery produced more than one element".
--
-- Repare tambem: dentro da subquery a gente usa `listing`, que vem da
-- query DE FORA. Isso tem nome — subquery correlacionada. Ela roda
-- uma vez para cada linha da tabela de fora.
--
-- Pergunta para a turma antes de seguir:
--   o que acontece com essa query se UM anuncio, entre mil, tiver
--   dois pricingInfos do tipo SALE?
--   (resposta: com LIMIT 1, nada. Sem ele, a query inteira falha por
--    causa de uma linha — e falha em producao, nao no seu teste com
--    LIMIT 10, porque essa linha provavelmente nem estava nas dez)
-- =====================================================================

-- ESTE E O CONCEITO MAIS IMPORTANTE DO BLOCO.
-- Dado real e aninhado e irregular. O SQL do BigQuery abre isso
-- sem voce sair do SQL.


-- ---------------------------------------------------------------------
-- PASSO 4 — Montar a Silver inteira
-- ---------------------------------------------------------------------
-- Agora juntamos tudo, convertendo os tipos.
-- SAFE_CAST devolve NULL em vez de quebrar quando o valor e invalido.
-- Em dado sujo, SAFE_CAST e obrigatorio.

CREATE OR REPLACE TABLE `SEU_PROJETO.SEU_DATASET.imoveis_silver` AS
SELECT
  id_anuncio,

  -- preco de venda (o nosso alvo)
  SAFE_CAST(
    (SELECT JSON_VALUE(p, '$.price')
     FROM UNNEST(JSON_QUERY_ARRAY(listing, '$.pricingInfos')) AS p
     WHERE JSON_VALUE(p, '$.businessType') = 'SALE'
     LIMIT 1) AS FLOAT64
  ) AS preco,

  SAFE_CAST(
    (SELECT JSON_VALUE(p, '$.monthlyCondoFee')
     FROM UNNEST(JSON_QUERY_ARRAY(listing, '$.pricingInfos')) AS p
     WHERE JSON_VALUE(p, '$.businessType') = 'SALE'
     LIMIT 1) AS FLOAT64
  ) AS condominio,

  SAFE_CAST(
    (SELECT JSON_VALUE(p, '$.yearlyIptu')
     FROM UNNEST(JSON_QUERY_ARRAY(listing, '$.pricingInfos')) AS p
     WHERE JSON_VALUE(p, '$.businessType') = 'SALE'
     LIMIT 1) AS FLOAT64
  ) AS iptu_anual,

  -- caracteristicas fisicas
  SAFE_CAST(JSON_VALUE(listing, '$.usableAreas[0]')    AS FLOAT64) AS area_util,
  SAFE_CAST(JSON_VALUE(listing, '$.totalAreas[0]')     AS FLOAT64) AS area_total,
  SAFE_CAST(JSON_VALUE(listing, '$.bedrooms[0]')       AS INT64)   AS quartos,
  SAFE_CAST(JSON_VALUE(listing, '$.bathrooms[0]')      AS INT64)   AS banheiros,
  SAFE_CAST(JSON_VALUE(listing, '$.suites[0]')         AS INT64)   AS suites,
  SAFE_CAST(JSON_VALUE(listing, '$.parkingSpaces[0]')  AS INT64)   AS vagas,

  -- localizacao
  JSON_VALUE(listing, '$.address.city')         AS cidade,
  JSON_VALUE(listing, '$.address.neighborhood') AS bairro,
  SAFE_CAST(JSON_VALUE(listing, '$.address.point.lat') AS FLOAT64) AS latitude,
  SAFE_CAST(JSON_VALUE(listing, '$.address.point.lon') AS FLOAT64) AS longitude,

  -- categorias
  JSON_VALUE(listing, '$.unitTypes[0]')  AS tipo_imovel,
  JSON_VALUE(listing, '$.usageTypes[0]') AS uso,
  JSON_VALUE(listing, '$.listingType')   AS estado_do_imovel,

  -- quem anuncia
  JSON_VALUE(listing, '$.account.name') AS imobiliaria,

  -- texto livre (vamos usar no bloco de NLP e na armadilha)
  JSON_VALUE(listing, '$.title')       AS titulo,
  JSON_VALUE(listing, '$.description') AS descricao,

  -- quantidade de comodidades (piscina, portaria 24h, etc)
  ARRAY_LENGTH(JSON_QUERY_ARRAY(listing, '$.amenities')) AS qtd_comodidades,

  -- datas
  SAFE_CAST(SUBSTR(JSON_VALUE(listing, '$.createdAt'), 1, 10) AS DATE) AS data_publicacao

FROM `SEU_PROJETO.SEU_DATASET.imoveis_bronze`;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Ele parece grande, mas nao tem nada novo. E os PASSOS 1, 2 e 3
-- empilhados, com o tipo certo em volta de cada um. Tres formatos:
--
--   a) o caso simples          JSON_VALUE(listing, '$.address.city')
--      texto que ja e texto, entra direto. Sem CAST.
--
--   b) o caso da lista curta   SAFE_CAST(JSON_VALUE(listing,
--                                '$.bedrooms[0]') AS INT64)
--      pega o item [0] e converte. Lembre do PASSO 2: JSON nao tem
--      tipo, tudo sai como texto. Quem decide o tipo e voce, aqui.
--
--   c) o caso do preco         SAFE_CAST( (subquery do PASSO 3) AS FLOAT64 )
--      a subquery inteira que a gente leu ali em cima, embrulhada
--      num CAST. Aparece tres vezes: preco, condominio, iptu.
--
-- Duas funcoes novas, so:
--   ARRAY_LENGTH(JSON_QUERY_ARRAY(listing, '$.amenities'))
--     nao interessa QUAIS comodidades tem, interessa QUANTAS.
--     Uma lista de tamanho variavel virou um numero — e numero
--     e o que um modelo sabe usar.
--   SUBSTR(JSON_VALUE(listing, '$.createdAt'), 1, 10)
--     a data vem como "2024-03-15T14:22:01Z". Os 10 primeiros
--     caracteres sao "2024-03-15", que o CAST AS DATE aceita.
--
-- E o CREATE OR REPLACE TABLE ... AS SELECT:
--   pega o resultado do SELECT e MATERIALIZA como tabela nova.
--   "OR REPLACE" = se ja existir, sobrescreve sem reclamar. E por
--   isso que voce pode rodar este arquivo dez vezes seguidas.
--
-- Pergunta para a turma antes de seguir:
--   por que praticamente todo CAST aqui e SAFE_CAST?
--   (resposta: sao 1.000 anuncios preenchidos por gente diferente.
--    Basta UM com area_util = "120 m2" para um CAST comum derrubar
--    a criacao da tabela inteira. SAFE_CAST troca "quebrar tudo"
--    por "essa celula vira NULL" — e NULL a gente trata depois)
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 5 — Ver o resultado
-- ---------------------------------------------------------------------
SELECT * FROM `SEU_PROJETO.SEU_DATASET.imoveis_silver` LIMIT 20;

-- FECHAMENTO DO BLOCO:
--   "Aquela parede de 14 mil caracteres virou uma tabela com 25 colunas.
--    Isso e a camada Silver. Foi um comando."
--
--   "So que ela ainda esta MENTINDO pra gente. E o proximo bloco."


-- ---------------------------------------------------------------------
-- DESAFIOS (para quem terminou antes)
-- ---------------------------------------------------------------------
-- 1) Traga tambem 'account.tier' (o plano da imobiliaria).
-- 2) Quantos anuncios tem piscina? Dica: UNNEST em '$.amenities'
--    e procure por 'POOL'.
-- 3) Existe algum anuncio com mais de um pricingInfos? Quantos?
--    Dica: ARRAY_LENGTH(JSON_QUERY_ARRAY(listing, '$.pricingInfos'))
