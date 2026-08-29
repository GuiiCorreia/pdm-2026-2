-- =====================================================================
-- PDM 2026.2 — Aula 04/09 — BigQuery ML
-- A ARMADILHA — o modelo bom demais
-- =====================================================================
--
-- Este e o ultimo bloco da aula, e o mais importante dela.
--
-- O seu modelo do ml_03 errou bastante. Vamos melhorar ele.
-- Tem uma coluna que a gente nem usou ainda: a descricao do anuncio.
-- Texto e informacao. Vamos aproveitar.
--
-- RODE OS PASSOS NA ORDEM, ate o fim, ANTES de concluir qualquer coisa.
-- Este arquivo nao e o que parece no PASSO 4.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 — "Vamos extrair informacao do texto"
-- ---------------------------------------------------------------------
-- Qualquer pipeline de NLP comeca assim: puxar entidades do texto livre.
-- Numeros com R$ na frente sao a entidade mais obvia que existe.

CREATE OR REPLACE TABLE `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto` AS
WITH extraido AS (
  SELECT
    *,
    SAFE_CAST(
      REPLACE(
        REPLACE(
          REGEXP_EXTRACT(descricao, r'R\$\s*([0-9][0-9\.]*(?:,[0-9]{2})?)'),
        '.', ''),
      ',', '.') AS FLOAT64
    ) AS valor_bruto
  FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold`
)
SELECT
  * EXCEPT (valor_bruto),
  -- a MESMA poda que a gente fez no preco, agora na feature nova
  IF(valor_bruto BETWEEN 500000 AND 100000000, valor_bruto, NULL)
    AS valor_citado_no_texto
FROM extraido;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Funcao dentro de funcao se le DE DENTRO PARA FORA. Comece pelo miolo:
--
--   1) REGEXP_EXTRACT(descricao, r'R\$\s*([0-9][0-9\.]*(?:,[0-9]{2})?)')
--      Varre o texto e devolve o PRIMEIRO pedaco que casar com o padrao.
--      Devolve TEXTO, nao numero. Se nao achar nada, devolve NULL.
--
--      Destrinchando o padrao:
--        r'...'        o "r" na frente e "raw": trate a barra como barra,
--                      nao como codigo de escape
--        R\$           o literal "R$". A barra e obrigatoria porque, em
--                      regex, $ sozinho significa "fim da linha"
--        \s*           zero ou mais espacos ("R$8000" e "R$ 8000" passam)
--        ( )           o grupo de captura. E SO ISTO que sai da funcao —
--                      o "R$" fica de fora do resultado
--        [0-9]         tem que comecar com digito
--        [0-9\.]*      seguido de digitos e pontos ("8.000.000")
--        (?:,[0-9]{2})? vírgula e dois digitos, OPCIONAL (o ? no fim).
--                      O "?:" diz "agrupe, mas nao capture isto"
--
--   2) REPLACE(  ...  , '.', '')      tira o ponto de milhar
--      "8.000.000" -> "8000000"
--
--   3) REPLACE(  ...  , ',', '.')     vírgula decimal vira ponto
--      "8000000,50" -> "8000000.50", que e como o SQL escreve decimal
--
--   4) SAFE_CAST( ... AS FLOAT64)     texto vira numero
--      O prefixo SAFE_ e o que importa aqui: sem ele, UMA linha
--      estranha derruba a query inteira. Com ele, a linha ruim
--      vira NULL e as outras 891 seguem.
--
-- E a estrutura por fora das funcoes:
--
--   WITH extraido AS ( ... )   da um nome a um resultado intermediario.
--                              Serve so para nao repetir a expressao
--                              gigante la embaixo. Nao cria tabela.
--   SELECT * EXCEPT (valor_bruto)
--                              pega TODAS as colunas menos uma. Aqui:
--                              o rascunho sai, a coluna tratada fica.
--   IF(x BETWEEN a AND b, x, NULL)
--                              "se estiver na faixa, mantem; se nao,
--                              vira NULL". E assim que se descarta um
--                              valor sem descartar a LINHA inteira.
--
-- Pergunta para a turma antes de seguir:
--   por que o SELECT de fora precisa do EXCEPT?
--   (resposta: senao a tabela sairia com as duas colunas, a suja e a
--    limpa, e alguem ia treinar modelo com a errada tres passos depois)
-- =====================================================================

-- POR QUE A PODA. Sem ela, essa coluna e um lixo silencioso:
-- o menor valor extraido era R$ 2 e o maior era R$ 805.585.258.
-- Um anuncio cita o condominio ("R$ 1.500"), outro cita a parcela,
-- outro cita um numero que o regex leu torto. Quatro anuncios
-- passavam de R$ 100 milhoes e sozinhos derrubavam a correlacao
-- da coluna com o preco para -0,02 — ou seja, para NADA.
--
-- E o piso de R$ 500 mil? O imovel mais barato desta base custa
-- R$ 6,9 milhoes. Entao um "R$ 1.500" no texto nao pode ser o
-- preco de nada aqui — e condominio, parcela ou taxa.
-- Trocar o piso de 100 mil para 500 mil sobe a correlacao da
-- coluna de 0,69 para 0,89, sem mudar mais nada.
--
--   "Feature nova nao nasce limpa. Ela e um dado como qualquer
--    outro, e leva o mesmo tratamento que voce deu ao resto."
--
-- Guarde isso: quatro linhas em 892 foram suficientes para apagar
-- o sinal de uma coluna inteira.

-- Quantos anuncios tem um valor aproveitavel na descricao?
SELECT
  COUNT(*)                                   AS total,
  COUNTIF(valor_citado_no_texto IS NOT NULL) AS com_valor_no_texto,
  ROUND(100 * COUNTIF(valor_citado_no_texto IS NOT NULL) / COUNT(*), 1) AS pct
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`;

-- MEDIDO: 197 de 892 anuncios -> 22,1%.
--
-- Por que nao bate exatamente com os 25,9% do silver_02_etl.sql?
-- Por tres motivos, e os tres valem uma anotacao:
--   1. La eram 1.000 linhas; aqui sao 892 (o gold ja filtrou).
--   2. La a gente perguntou "tem 'R$' no texto?". Aqui a gente pergunta
--      "o regex conseguiu extrair um NUMERO depois do R$?".
--   3. E agora ainda podamos os valores fora de faixa.
--
-- Numero parecido nao e numero igual. Saber por que dois numeros seus
-- discordam e metade do trabalho de quem cuida de dado.
--
-- Otimo: temos uma feature nova. Segue para o PASSO 2.


-- ---------------------------------------------------------------------
-- PASSO 2 — Onde a feature nova existe de verdade
-- ---------------------------------------------------------------------
-- A coluna nova esta vazia em 695 dos 892 anuncios (78%).
--
-- Testar uma feature numa base onde ela quase nao existe e um teste
-- ruim: o efeito dela se dilui no meio das linhas vazias e voce
-- conclui que "nao mudou nada" sem nunca ter dado chance a ela.
--
-- Entao a gente faz o que um analista faz: avalia a feature na fatia
-- em que ela existe. Sao os 197 anuncios que citam um valor.
--
-- Guarde essa ideia, ela e reaproveitavel:
--   "Feature esparsa se avalia na fatia onde ela e densa."

SELECT
  COUNT(*)                                     AS anuncios_na_fatia,
  ROUND(CORR(valor_citado_no_texto, preco), 3) AS correlacao_com_o_preco
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`
WHERE valor_citado_no_texto IS NOT NULL;

-- MEDIDO: 197 anuncios, correlacao 0,889 com o preco.
-- Correlacao alta. Promissor. Vamos treinar.


-- ---------------------------------------------------------------------
-- PASSO 3 — Dois modelos GEMEOS
-- ---------------------------------------------------------------------
-- Mesma base, mesmas colunas, mesmo algoritmo.
-- A UNICA diferenca entre os dois e a feature nova.
-- E assim que se mede o efeito de uma feature: mudando uma coisa so.

-- 3a) Sem a feature nova
CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_sem_texto`
OPTIONS (
  model_type            = 'LINEAR_REG',
  input_label_cols      = ['preco'],
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  preco, area_util, quartos, banheiros, suites, vagas,
  qtd_comodidades, bairro, tipo_imovel, uso
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`
WHERE valor_citado_no_texto IS NOT NULL;

-- 3b) Com a feature nova
CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_com_texto`
OPTIONS (
  model_type            = 'LINEAR_REG',
  input_label_cols      = ['preco'],
  data_split_method     = 'AUTO_SPLIT',
  enable_global_explain = TRUE
) AS
SELECT
  preco, area_util, quartos, banheiros, suites, vagas,
  qtd_comodidades, bairro, tipo_imovel, uso,
  valor_citado_no_texto   -- <<< a unica coisa que mudou
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`
WHERE valor_citado_no_texto IS NOT NULL;


-- ---------------------------------------------------------------------
-- PASSO 4 — Comparar
-- ---------------------------------------------------------------------
SELECT 'sem o valor do texto' AS modelo, r2_score, mean_absolute_error
FROM ML.EVALUATE(MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_sem_texto`)
UNION ALL
SELECT 'COM o valor do texto', r2_score, mean_absolute_error
FROM ML.EVALUATE(MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_com_texto`);

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- UNION ALL empilha o resultado de duas queries: as linhas da segunda
-- entram embaixo das linhas da primeira. Serve para ver os dois
-- modelos na MESMA tabela, em vez de rodar duas queries e comparar
-- numero de cabeca.
--
-- Duas regras dele, e as duas pegam gente:
--
--   1) A juncao e POR POSICAO, nao por nome de coluna.
--      A 1a coluna de cima casa com a 1a de baixo, e assim por diante.
--      Se voce trocar a ordem em uma das duas, o SQL nao reclama:
--      voce so vai ler r2 na coluna de erro medio e nao entender nada.
--      O nome que aparece no cabecalho e o da PRIMEIRA query.
--      (Existe UNION ALL BY NAME quando voce quiser casar por nome.)
--
--   2) ALL x sem ALL: UNION ALL empilha tudo. UNION sozinho remove
--      duplicatas — e para isso ele precisa comparar tudo com tudo.
--      Aqui nao ha duplicata possivel, entao ALL e o certo e o barato.
--      Fora daqui: se voce nao quer deduplicar, nunca use UNION puro.
--
-- O 'sem o valor do texto' AS modelo e uma coluna CONSTANTE: um texto
-- fixo que vira coluna. Sem ela, as duas linhas viriam sem etiqueta e
-- voce teria que confiar na ordem para saber qual e qual.
--
-- Pergunta para a turma antes de seguir:
--   por que nao dava para fazer isso com um JOIN?
--   (resposta: JOIN junta lado a lado e precisa de uma chave em comum.
--    Aqui nao existe chave nenhuma — sao dois resultados de uma linha
--    cada, sem nada que os ligue. Comparacao lado a lado quer JOIN;
--    empilhar resultados independentes quer UNION ALL)
-- =====================================================================

-- MEDIDO:
--   sem o valor do texto  ->  R2 0,576   erro medio R$ 1.672.328
--   COM o valor do texto  ->  R2 0,877   erro medio R$   828.794
--
-- O R2 pulou de 0,58 para 0,88. O erro medio caiu PELA METADE.
-- Uma coluna. Uma linha de SQL a mais.
--
-- SE OS SEUS DOIS R2 DEREM IGUAIS, LEIA ISTO.
-- O BigQuery guarda o resultado das consultas em cache. Se voce
-- rodar esta comparacao, retreinar um modelo com o MESMO nome e
-- rodar a comparacao de novo, ele pode devolver o numero VELHO —
-- sem avisar, sem erro, identico ate a ultima casa decimal.
-- Aconteceu comigo enquanto eu preparava esta aula.
-- Para forcar o recalculo: menu "Mais" > "Configuracoes de consulta"
-- > desmarque "Usar resultados armazenados em cache".
--
--   "Dois numeros identicos ate a 16a casa decimal nao sao
--    coincidencia. Sao a mesma resposta servida duas vezes."
--
-- Duas perguntas, nessa ordem:
--   1) "Beleza. Publicamos esse modelo?"
--   2) "De onde saiu esse numero que a gente extraiu?"
--
-- Responda as duas de cabeca. Depois rode o PASSO 5.


-- ---------------------------------------------------------------------
-- PASSO 5 — De onde veio a informacao
-- ---------------------------------------------------------------------
SELECT
  id_anuncio,
  ROUND(preco)                 AS preco_da_coluna,
  ROUND(valor_citado_no_texto) AS valor_extraido_do_texto,
  SUBSTR(descricao, 1, 120)    AS trecho
FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`
WHERE valor_citado_no_texto IS NOT NULL
ORDER BY ABS(valor_citado_no_texto - preco) ASC
LIMIT 15;

-- As duas colunas de numero sao IGUAIS.
--
-- MEDIDO: em 156 dos 197 anuncios da fatia (79%), o valor extraido do texto
-- e EXATAMENTE o preco do anuncio. O anunciante escreveu o preco duas
-- vezes: no campo de preco e no meio da descricao.
--
--   "A gente nao criou uma feature. A gente copiou a resposta
--    de dentro do texto e colou na entrada do modelo.
--    O modelo nao ficou melhor. Ele ficou com a prova na mao."
--
-- O nome disso:
--   VAZAMENTO DE ALVO (data leakage)


-- ---------------------------------------------------------------------
-- PASSO 6 — A prova de que o modelo nao serve
-- ---------------------------------------------------------------------
-- Uma metrica global esconde o crime. Basta separar em grupos.
-- Aqui o modelo treinado na FATIA vai prever a base INTEIRA (892),
-- inclusive os 690 anuncios que ele nunca viu e que nao tem a cola.

SELECT
  CASE
    WHEN valor_citado_no_texto IS NULL THEN '3. SEM preco no texto'
    WHEN valor_citado_no_texto = preco  THEN '1. texto traz o preco EXATO'
    ELSE                                     '2. texto traz outro valor'
  END                                      AS grupo,
  COUNT(*)                                 AS anuncios,
  ROUND(AVG(ABS(predicted_preco - preco))) AS erro_medio_em_reais
FROM ML.PREDICT(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_com_texto`,
  (SELECT * FROM `SEU_PROJETO.SEU_DATASET.imoveis_gold_texto`)
)
GROUP BY grupo
ORDER BY grupo;

-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
-- Esta e a query mais importante do arquivo, e ela e uma pergunta
-- disfarcada: "o erro do modelo depende de o anuncio ter a cola?"
--
-- Leia na ORDEM EM QUE O BIGQUERY EXECUTA, que nao e a ordem em que
-- esta escrito:
--
--   1) FROM ML.PREDICT(modelo, (SELECT * FROM gold_texto))
--      Primeiro o modelo preve. Repare no segundo argumento: a base
--      INTEIRA, 892 linhas — e o modelo foi treinado so nas 197 da
--      fatia. Isso e proposital. A gente esta empurrando pra ele
--      justamente os anuncios que ele nunca viu.
--      Sai a tabela original + a coluna predicted_preco.
--
--   2) CASE WHEN ... THEN ... ELSE ... END
--      Cria uma coluna nova, de rotulo, testando as condicoes NA
--      ORDEM e parando na primeira que der certo. Por isso o teste
--      de NULL vem primeiro: NULL = preco nao e verdadeiro nem
--      falso em SQL, e a linha escaparia dos tres casos.
--      Os numeros "1.", "2.", "3." na frente do texto sao truque
--      barato e util: e o que faz o ORDER BY alfabetico do final
--      sair na ordem da escada, e nao em ordem de dicionario.
--
--   3) GROUP BY grupo
--      Agrupa pelo rotulo que o CASE acabou de inventar. Repare que
--      da para agrupar por uma coluna que nao existe na tabela —
--      ela nasceu nesta mesma query.
--
--   4) ROUND(AVG(ABS(predicted_preco - preco)))
--      De dentro pra fora: a diferenca, o modulo (erro pra cima e
--      pra baixo pesam igual), a media DENTRO DE CADA GRUPO, e o
--      arredondamento. Isso e o MAE — a mesma metrica que o
--      ML.EVALUATE deu la no PASSO 4, so que agora fatiada.
--
-- E ESSE E O PULO DO GATO DA AULA:
--   o PASSO 4 mostrou UM numero para o modelo inteiro, e ele era bom.
--   Aqui, o MESMO calculo quebrado em tres grupos mostra que aquele
--   numero era uma media entre um modelo que cola e um modelo que
--   nao sabe nada.
--
--   "Toda metrica global e uma media. Toda media esconde
--    a distribuicao que gerou ela."
--
-- Pergunta para a turma antes de seguir:
--   que outra coluna voces usariam nesse CASE para fatiar o erro de
--   um modelo?
--   (por bairro, por faixa de preco, por tipo de imovel, por mes de
--    publicacao. Fatiar erro por grupo e o exame mais barato que
--    existe — e quase ninguem faz)
-- =====================================================================

-- MEDIDO — repare que e uma escada:
--
--   1. texto traz o preco EXATO   156 anuncios   erro R$   586.949
--   2. texto traz outro valor      41 anuncios   erro R$ 1.748.983
--   3. SEM preco no texto         695 anuncios   erro R$ 3.513.000
--
-- Quanto melhor a cola, menor o erro. Quando a cola some, o modelo
-- erra SEIS VEZES mais.
--
--   "Esse modelo nao avalia imovel. Ele le anuncio.
--    Quando o anuncio nao diz o preco, ele nao sabe nada.
--    E e exatamente nesses casos que a gente ia querer usar ele."
--
-- E o ponto que fecha o argumento:
--   "Em producao, todo imovel novo chega SEM preco.
--    Se ele tivesse preco, voce nao precisaria do modelo."
--
-- NOTA DE HONESTIDADE (e um bom assunto para o Trabalho 1):
-- o grupo 1 contem anuncios que estavam no TREINO do modelo, entao
-- parte do acerto ali e memorizacao, nao previsao. O que sustenta a
-- conclusao e o grupo 3: 695 anuncios que o modelo nunca viu e onde
-- ele desaba. Sempre pergunte de qual conjunto veio cada numero seu.


-- ---------------------------------------------------------------------
-- PASSO 7 — Confirmar com a explicabilidade
-- ---------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(
  MODEL `SEU_PROJETO.SEU_DATASET.modelo_fatia_com_texto`
)
ORDER BY attribution DESC;

-- MEDIDO:
--   bairro                 2.470.281
--   uso                    2.466.846
--   tipo_imovel            2.466.846
--   valor_citado_no_texto  1.748.680   <<<
--   quartos                  262.070
--   area_util                210.383
--   suites                   165.392
--   banheiros                 88.361
--   vagas                     88.141
--   qtd_comodidades           65.336
--
-- Leia com cuidado, porque tem uma pegadinha aqui.
--
-- A coluna vazada NAO aparece em primeiro lugar. Os tres primeiros
-- sao categoricos (bairro, uso, tipo_imovel): o BigQuery quebra cada
-- um em dezenas de colunas 0/1 e a atribuicao deles soma tudo junto.
-- Comparar um categorico com um numerico nessa lista e injusto.
--
-- Compare com quem da pra comparar — as outras NUMERICAS:
--   valor_citado_no_texto vale 8x mais que area_util, e mais do que
--   TODAS as outras numericas somadas.
--
-- Uma coluna que ninguem pediu, que nasceu de um regex improvisado,
-- pesa mais que a area do imovel. Isso e um alarme.
--
--   "Deu pra descobrir tudo isso com UMA query.
--    A explicabilidade nao e enfeite. E teste de sanidade."


-- ---------------------------------------------------------------------
-- O CHECKLIST — leve este daqui para o Trabalho 1
-- ---------------------------------------------------------------------
-- Antes de acreditar em qualquer metrica boa, tres perguntas:
--
--   1. Essa coluna vai EXISTIR no momento em que eu for prever?
--      (o preco no texto nao existe num imovel que ainda nao tem preco)
--
--   2. Essa coluna foi preenchida DEPOIS de acontecer o que eu quero prever?
--      (data de pagamento para prever inadimplencia; data de alta para
--       prever internacao; status do pedido para prever cancelamento)
--
--   3. O resultado ficou bom demais?
--      Metrica quase perfeita em problema do mundo real e quase sempre
--      vazamento — nao genialidade.
--
--   "Treinar modelo no BigQuery e uma linha de SQL.
--    O trabalho de verdade e tudo que veio ANTES do CREATE MODEL:
--    abrir o JSON, achar a fazenda do tamanho de metade de Goiania,
--    e desconfiar do modelo que acertou demais.
--    Isso nenhuma ferramenta faz por voce."


-- ---------------------------------------------------------------------
-- DESAFIOS
-- ---------------------------------------------------------------------
-- 1) Use o texto do jeito CERTO: remova os valores em R$ da descricao
--    com REGEXP_REPLACE e treine com ML.NGRAMS sobre o texto limpo:
--       ML.NGRAMS(SPLIT(LOWER(descricao_limpa), ' '), [1, 2])
--    Palavras como "alto padrao", "piscina" e "vista" ajudam de verdade?
-- 2) O desafio 2 do arquivo de regressao pedia para usar preco_por_m2
--    como feature. Aquilo era o mesmo crime deste arquivo. Explique
--    por que, em duas frases.
-- 3) Refaca o PASSO 6 avaliando SO em anuncios que ficaram de fora do
--    treino, para eliminar a memorizacao apontada na nota de honestidade.
--    O resultado muda a conclusao ou so muda os numeros?
-- 4) Procure um vazamento no dataset do trabalho do seu grupo.
--    Se voce nao achou nenhum, provavelmente ainda nao procurou direito.
