-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- SCRIPT 4: CLASSIFICACAO — este anuncio e comercial ou residencial?
-- =====================================================================
--
-- Abra o script 3 do lado. Compare os dois CREATE MODEL.
-- Mudou UMA palavra no model_type e UMA no input_label_cols.
-- E toda a estrutura — EVALUATE, PREDICT, EXPLAIN — continua igual.
--
-- O alvo (eh_comercial) foi criado por VOCE, no script 2, a partir
-- do titulo. Guarde isso: vai virar uma regra daqui a pouco.
--
-- COMO USAR: troque SEU_PROJETO. Requer a anuncios_gold (script 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 0 — A linha de corte, ANTES de treinar
-- ---------------------------------------------------------------------
-- A pergunta mais importante da aula de avaliacao, feita antes do
-- modelo existir:
--
--   "Se eu criar um 'modelo' que responde RESIDENCIAL para tudo,
--    sem olhar NADA, qual a acuracia dele?"

SELECT
  COUNT(*)                                          AS total,
  COUNTIF(NOT eh_comercial)                         AS residenciais,
  ROUND(100 * COUNTIF(NOT eh_comercial) / COUNT(*), 1) AS acuracia_do_chute
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- RESULTADO ESPERADO: 83,5%.
--
-- ESCREVA ESSE NUMERO NO QUADRO. Ele e a regua do bloco:
--   modelo com acuracia 84% num problema onde chutar da 83,5%
--   aprendeu quase NADA. Acuracia so faz sentido comparada com
--   a classe majoritaria.


-- ---------------------------------------------------------------------
-- PASSO 1 — Treinar
-- ---------------------------------------------------------------------
CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.modelo_comercial`
OPTIONS (
  model_type            = 'LOGISTIC_REG',      -- <<< era LINEAR_REG
  input_label_cols      = ['eh_comercial'],    -- <<< era preco
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  eh_comercial,     -- label
  preco,            -- agora o preco pode ser feature!
  area_util,
  quartos,
  banheiros,
  suites,
  garagem,
  condominio,
  iptu,
  bairro
FROM `SEU_PROJETO.anuncios.anuncios_gold`;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Duas mudancas em relacao ao script 3:
--
--   LOGISTIC_REG  apesar do nome, e CLASSIFICACAO (heranca
--                 historica da estatistica). Devolve a probabilidade
--                 de cada classe.
--
--   input_label_cols = ['eh_comercial']
--                 o label agora e BOOL. E repare: preco VIROU
--                 feature — a coluna que era resposta no script 3
--                 e pergunta neste. Label e feature sao papeis,
--                 nao propriedades da coluna.
--
-- A REGRA NOVA — e ela vale nota no Trabalho 1:
--
--   O titulo NAO PODE ser feature deste modelo. Nem nada derivada
--   dele. Por que? O label NASCEU do titulo (a regex do script 2).
--   Se o titulo entrar, o modelo nao aprende "o que e um imovel
--   comercial" — ele reaprende a MINHA REGEX, com acuracia perfeita
--   e utilidade zero.
--
--   "Se o rotulo veio de uma coluna, essa coluna esta proibida
--    de entrar no modelo."
--
--   (E se essa regra for quebrada de proposito? Script 6.)
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 2 — Avaliar contra a regua
-- ---------------------------------------------------------------------
SELECT *
FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_comercial`);

-- O QUE VEM: precision, recall, accuracy, f1_score, log_loss, roc_auc
--
-- COMO LER (nesta ordem):
--
--   accuracy  -> compare com 83,5%. Acima? Quanto acima? So essa
--                distancia e merito do modelo.
--   recall    -> dos comerciais DE VERDADE, quantos ele achou?
--                Com 16,5% de classe positiva, da para ter accuracy
--                alta achando quase nenhum comercial.
--   precision -> dos que ele CHAMOU de comercial, quantos eram?
--
-- RESULTADO MEDIDO (pdm-2026-gui, 28/08):
--   accuracy 0,953   precision 0,762   recall 0,842
--   f1_score 0,800   roc_auc 0,959
--
--   95,3% contra a regua de 83,5%: esses ~12 pontos sao o merito
--   real. E repare como precision (0,76) e recall (0,84) contam uma
--   historia bem menos gloriosa que a accuracy sozinha.
--
--   "Numa turma onde 83,5% passa de ano, decorar 'passou' acerta
--    83,5%. Accuracy alta em classe desbalanceada e a coisa mais
--    barata que existe."


-- ---------------------------------------------------------------------
-- PASSO 3 — A matriz de confusao
-- ---------------------------------------------------------------------
SELECT *
FROM ML.CONFUSION_MATRIX(MODEL `SEU_PROJETO.anuncios.modelo_comercial`);

-- Duas linhas (verdade) x duas colunas (palpite):
--
--                     previu FALSE    previu TRUE
--   era FALSE       [acerto        ] [falso alarme  ]
--   era TRUE        [comercial que ] [acerto        ]
--                   [ passou batido]
--
-- RESULTADO MEDIDO (fatia de avaliacao, 170 anuncios):
--
--                     previu FALSE    previu TRUE
--   era FALSE            146                5
--   era TRUE               3               16
--
--   3 comerciais passaram batidos (dai o recall 0,842) e 5
--   residenciais foram acusados sem razao (dai a precision 0,762).
--   Confira: 162/170 = 0,953 — a accuracy inteira sai daqui.
--
-- A pergunta certa nao e "quantos acertou?" — e "QUAL erro doi mais
-- no meu problema?". Aqui: deixar comercial passar batido (recall)
-- ou acusar residencial sem razao (precision)? Depende de quem usa.


-- ---------------------------------------------------------------------
-- PASSO 4 — Os erros mais confiantes
-- ---------------------------------------------------------------------
SELECT
  bairro,
  area_util,
  quartos,
  ROUND(preco)     AS preco,
  eh_comercial     AS verdade,
  predicted_eh_comercial AS palpite,
  ROUND((SELECT p.prob FROM UNNEST(predicted_eh_comercial_probs) p
         WHERE p.label = predicted_eh_comercial), 3) AS confianca
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.anuncios.modelo_comercial`,
  (SELECT * FROM `SEU_PROJETO.anuncios.anuncios_gold`)
)
WHERE predicted_eh_comercial != eh_comercial
ORDER BY confianca DESC
LIMIT 15;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Classificacao devolve DUAS colunas novas:
--   predicted_eh_comercial        o palpite
--   predicted_eh_comercial_probs  ARRAY com a probabilidade de cada
--                                 classe — por isso o UNNEST no
--                                 sub-select, para pescar a prob da
--                                 classe escolhida.
--
-- O WHERE fica so com os ERROS, ordenados pela CONFIANCA:
--
--   "Um modelo errando com 51% esta em duvida — problema de dado
--    ambiguo. Errando com 98%, ele aprendeu a coisa errada —
--    problema de feature. Sao doencas diferentes, com remedios
--    diferentes."
--
-- Olhe as linhas: um "residencial" de 800 m2 com 0 quartos e preco
-- de galpao... sera que a REGEX errou o rotulo, e o modelo esta
-- CERTO? Tambem acontece — e chama-se ruido de label.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 5 — O que pesou
-- ---------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.modelo_comercial`)
ORDER BY attribution DESC;

-- Palpite antes de rodar: quartos (comercial nao tem), area_util
-- (galpao e grande) e preco. Confira.
--
-- RESULTADO MEDIDO (attribution): bairro 1,91 > suites 1,28 >
-- garagem 0,48 — NENHUM dos palpites obvios no topo.
-- Faz sentido depois de ver: comercial se concentra em certos
-- bairros, e comercial NAO tem suite — a AUSENCIA de um atributo
-- tambem e informacao. O modelo achou um atalho melhor que o nosso
-- palpite. E por isso que se pergunta ao modelo, em vez de supor.


-- ---------------------------------------------------------------------
-- DESAFIOS (para depois da aula)
-- ---------------------------------------------------------------------
-- 1) So 16,5% da base e comercial. Adicione auto_class_weights=TRUE
--    no OPTIONS e compare recall e precision. O que mudou, e por que?
-- 2) ML.PREDICT aceita threshold: ML.PREDICT(MODEL ..., TABLE ...,
--    STRUCT(0.3 AS threshold)). Baixe o corte de 0,5 para 0,3 e
--    refaca a matriz de confusao. Qual erro aumentou, qual diminuiu?
-- 3) Troque para BOOSTED_TREE_CLASSIFIER. A acuracia sobe? E o
--    ML.GLOBAL_EXPLAIN — as features importantes mudaram?
