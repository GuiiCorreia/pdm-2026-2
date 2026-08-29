-- =====================================================================
-- AULA 04/09 — SCRIPT 0: O modelo que voce treinou na aula passada
-- =====================================================================
-- Na aula passada, com o Savio, voce treinou o modelo_preco_imoveis
-- em cima da gold_predicao_preco. O CREATE MODEL rodou, apareceu
-- "O modelo foi criado" e a aula acabou ali.
--
-- Pergunta que ficou no ar: o modelo e BOM?
-- Hoje a aula comeca respondendo isso. Em uma query.
--
-- Troque SEU_PROJETO pelo ID do seu projeto em todas as queries.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 0 (SO se voce nao terminou a aula passada)
-- ---------------------------------------------------------------------
-- Se o seu projeto ja tem anuncios.modelo_preco_imoveis, PULE este
-- passo. Este e exatamente o CREATE MODEL da aula do Savio.
-- Descomente e rode (demora ~1 minuto):

-- CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_preco_imoveis`
-- OPTIONS (
--   model_type        = 'LINEAR_REG',
--   input_label_cols  = ['preco'],
--   data_split_method = 'AUTO_SPLIT'   -- divide treino e teste automaticamente
-- ) AS
-- SELECT
--   preco,
--   bairro,
--   cidade,
--   area_total,
--   quartos,
--   banheiros,
--   garagem,
--   condominio
-- FROM `SEU_PROJETO.anuncios.gold_predicao_preco`;


-- ---------------------------------------------------------------------
-- PASSO 1 — Avaliar o modelo. Uma linha de verdade.
-- ---------------------------------------------------------------------

SELECT *
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco_imoveis`);

-- COMO LER (as duas colunas que importam hoje):
--
--   mean_absolute_error  -> "em media, o palpite erra por quantos reais"
--                           Esperado aqui: ~13.800.000. TREZE MILHOES.
--
--   r2_score             -> "quanto da variacao do preco o modelo explica"
--                           1.0 = perfeito; 0.0 = empata com chutar a
--                           MEDIA para todo mundo; NEGATIVO = pior que
--                           chutar a media.
--                           Esperado aqui: ~ -0.35.  NEGATIVO.
--
-- (Os numeros exatos variam um pouco entre alunos: o AUTO_SPLIT
--  sorteia o conjunto de teste. O tamanho do desastre, nao.)
--
--   "Voces treinaram um modelo que e PIOR do que responder a media
--    para qualquer pergunta. E o CREATE MODEL rodou sem nenhum erro.
--    Modelo ruim nao avisa que e ruim. Voce tem que perguntar."
--
-- Pergunta para a turma ANTES de seguir:
--   De quem e a culpa? Do algoritmo ou do dado?
--
-- A resposta esta no script 01.
