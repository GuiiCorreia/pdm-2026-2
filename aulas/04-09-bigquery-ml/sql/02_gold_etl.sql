-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 2: CONSTRUIR A GOLD
-- =====================================================================
--
-- A auditoria do script 1 mostrou o que a silver esconde. Este script
-- constroi a tabela em que da para confiar: a camada GOLD — dado
-- pronto para CONSUMO, neste caso, consumo por um modelo.
--
-- Tres tipos de decisao aparecem aqui, e e importante separa-los:
--
--   CORTAR    linha invalida sai (preco impossivel, area impossivel)
--   CONSERTAR valor errado e corrigivel (coordenadas trocadas)
--   DERIVAR   coluna nova nasce de coluna velha (eh_comercial, preco_m2)
--
-- COMO USAR: troque SEU_PROJETO. Requer o script 1 ja executado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- ANTES DE CRIAR: a coluna que a silver PERDEU
-- ---------------------------------------------------------------------
-- O dado bruto la do raw tinha 'uso' (RESIDENTIAL/COMMERCIAL) e
-- 'tipo_imovel' (APARTMENT, HOME, FARM...). A silver nao tem mais.
-- Sobrou UMA coluna de texto: o titulo. E o titulo sabe:

SELECT
  titulo,
  ROUND(preco) AS preco
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE REGEXP_CONTAINS(
        LOWER(titulo),
        r'comercial|galp[aã]o|pr[eé]dio|loja|escrit[oó]rio|barrac[aã]o|industrial')
LIMIT 10;

-- =====================================================================
-- COMO LER ESTE COMANDO — e por que isso e NLP
-- =====================================================================
--   REGEXP_CONTAINS(texto, r'padrao')  -> TRUE/FALSE
--
--   LOWER(titulo)  poe tudo em minusculo antes de comparar —
--                  "GALPÃO", "Galpão" e "galpão" viram a mesma coisa.
--
--   O padrao e uma lista de palavras separadas por | (OU):
--   basta UMA aparecer para dar TRUE.
--
--   galp[aã]o  casa "galpao" E "galpão" — colchetes sao alternativa
--   de UM caractere. Dado real tem gente que digita sem acento.
--
-- Isso e processamento de linguagem natural no nivel mais basico
-- que existe: extrair informacao de texto livre. Nao precisa de GPU
-- para comecar — precisa de uma pergunta e uma expressao regular.
-- (Embedding e LLM sao a versao sofisticada disso; ficam no cardapio.)
-- =====================================================================

-- Quantos sao?
SELECT
  COUNTIF(REGEXP_CONTAINS(LOWER(titulo),
    r'comercial|galp[aã]o|pr[eé]dio|loja|escrit[oó]rio|barrac[aã]o|industrial'))
    AS comerciais,
  COUNT(*) AS total
FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`;
-- Esperado: 179 de 1.000 = 17,9% na silver inteira.


-- ---------------------------------------------------------------------
-- A GOLD — cada linha do WHERE e uma decisao assinada
-- ---------------------------------------------------------------------

CREATE OR REPLACE TABLE `SEU_PROJETO.anuncios.anuncios_gold` AS
SELECT
  id_anuncio,
  preco,
  area_util,
  quartos,
  banheiros,
  suites,
  garagem,
  condominio,
  iptu,
  bairro,

  -- CONSERTAR: nas 2 linhas trocadas, latitude < -40 denuncia a
  -- inversao. O CASE devolve cada valor ao seu lugar.
  CASE WHEN latitude < -40 THEN longitude ELSE latitude  END AS latitude,
  CASE WHEN latitude < -40 THEN latitude  ELSE longitude END AS longitude,

  -- DERIVAR 1: o alvo de classificacao que a silver nao tem mais.
  REGEXP_CONTAINS(LOWER(titulo),
    r'comercial|galp[aã]o|pr[eé]dio|loja|escrit[oó]rio|barrac[aã]o|industrial')
    AS eh_comercial,

  -- DERIVAR 2: so e segura DEPOIS dos filtros la embaixo.
  ROUND(preco / area_util, 2) AS preco_por_m2,

  -- Mantida de proposito: e a materia-prima dos scripts 5 e 6.
  titulo

FROM `SEU_PROJETO.anuncios.tb_anuncios_silver`
WHERE
      preco IS NOT NULL                     -- sem alvo nao ha treino
  AND preco BETWEEN 50000 AND 50000000      -- corta erro de escala (29 + 6 linhas)
  AND area_util BETWEEN 20 AND 10000        -- corta unidade trocada (83 + 1 linhas)
;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Sintaxe, nenhuma novidade: um SELECT com WHERE virando tabela.
-- O que tem para ler aqui nao e SQL, e DECISAO.
--
-- OS CORTES (WHERE) — cada um joga linha fora PARA SEMPRE:
--
--   preco BETWEEN 50000 AND 50000000
--     BETWEEN inclui as pontas. O teto corta as 29 linhas que o
--     script 1 mediu (2,9% segurando 90% do desvio). O piso corta o
--     caminho oposto: os 6 anuncios de menos de R$ 50 mil — quem
--     digitou em milhares e virou "R$ 29.000" num imovel de luxo.
--
--   area_util BETWEEN 20 AND 10000
--     a fazenda de 63% de Goiania sai por aqui, junto com as outras
--     82, e com o imovel de 1 m2 na outra ponta.
--
-- O CONSERTO (CASE) — a diferenca entre cortar e corrigir:
--
--   As 2 linhas de coordenada trocada NAO foram jogadas fora,
--   porque o erro e reversivel: o valor certo esta no outro campo.
--   Regra pratica: erro reversivel se conserta, erro irreversivel
--   se corta. O preco de R$ 1,4 bi nao da para consertar — era 1,4
--   milhao? 140 mil? — entao sai.
--
-- AS DERIVADAS (SELECT):
--
--   eh_comercial  a regex que voce testou ali em cima, virando
--                 coluna BOOL. E o alvo do script 4.
--
--   preco_por_m2  preco / area_util. Repare que ela so e segura
--                 DEPOIS do filtro: area_util = 0 daria divisao por
--                 zero, e a fazenda daria centavos por metro.
--                 "Primeiro voce decide o que e valido, depois voce
--                  calcula em cima disso."
--
-- O QUE FICOU DE FORA (decisao tao importante quanto o que entrou):
--
--   tipo_contrato, status, cidade  mortas (1-2 valores). Feature
--                                  com um valor so nao ensina nada.
--   rua, anunciante, creci,        identificadores, nao atributos.
--   telefone, datas                Nenhum diz "quanto vale o imovel".
--   area_total                     redundante com area_util e mais
--                                  suja (desafio 2 do script 1).
--
-- Para pensar antes de seguir:
--   os cortes de preco e area sao regras de negocio disfarcadas de
--   SQL. Quem, numa empresa de verdade, deveria assinar embaixo do
--   "50 milhoes" — voces ou a area de negocio?
-- =====================================================================


-- ---------------------------------------------------------------------
-- CONFERENCIA — nao e opcional
-- ---------------------------------------------------------------------
-- Um filtro errado nao da erro. Ele da silencio: tabela vazia, e voce
-- so descobre quando o CREATE MODEL falhar tres queries depois.

SELECT
  COUNT(*)                                        AS anuncios,
  ROUND(APPROX_QUANTILES(preco, 100)[OFFSET(50)]) AS mediana,
  ROUND(AVG(preco))                               AS media,
  ROUND(STDDEV(preco))                            AS desvio,
  COUNTIF(eh_comercial)                           AS comerciais,
  ROUND(100 * COUNTIF(eh_comercial) / COUNT(*), 1) AS pct_comercial
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- RESULTADO ESPERADO:
--   anuncios       887   (sairam 113 linhas — 11,3% do dado; nao eram
--                         dado, eram ruido com o tipo certo)
--   mediana        R$  8.900.000
--   media          R$ 10.762.248   <<< media e mediana proximas AGORA
--   desvio         R$  5.629.269   (era 72 milhoes na silver)
--   comerciais     146 = 16,5%
--
-- Compare com o script 1: media 2,3x a mediana ANTES, 1,2x DEPOIS.
-- A distribuicao ficou honesta. E isso que a Gold e.
--
-- FECHAMENTO DO BLOCO — e a tese da aula:
--   O que este script faz tem nome: ETL, camada Gold. Nao e a parte
--   chata antes do ML. E a parte que decide se o ML vai servir para
--   alguma coisa.


-- ---------------------------------------------------------------------
-- DESAFIOS (para depois da aula)
-- ---------------------------------------------------------------------
-- 1) Em vez de cortar em R$ 50 milhoes na mao, corte pelo percentil
--    99 com APPROX_QUANTILES. Qual dos dois voce defenderia num
--    relatorio, e por que?
-- 2) O desafio 3 do script 1 achou anuncios duplicados — e eles
--    PASSARAM pelos filtros da Gold. Adicione um dedup usando
--    QUALIFY ROW_NUMBER() OVER (PARTITION BY titulo, preco) = 1.
--    Quantas linhas sobram?
-- 3) A regex de eh_comercial tem falso negativo: "sala" e "ponto"
--    tambem indicam imovel comercial. Adicione as palavras e meca
--    quanto o percentual muda. Cuidado: "sala" casa com "Casa"?
--    (dica: \b marca fronteira de palavra)
-- 4) O corte em area_util >= 20 elimina kitnets reais? Quantos
--    anuncios entre 10 e 20 m2 existiam, e o que eram?
