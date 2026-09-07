# Contexto — Trabalho 1 (PDM 2026.2, BigQuery ML)

Arquivo para você colar no seu agente (Claude Code, Cursor, Copilot) antes de pedir ajuda com
a parte de BigQuery ML do Trabalho 1.

**O que este arquivo é e o que não é.** O escopo do trabalho, o prazo e o formato da
apresentação são os que o **Prof. Sávio** passou em aula — é por ele que você se orienta, não
por aqui. O que este arquivo traz é o conteúdo técnico da aula de 04/09, organizado para o seu
agente não errar.

**Um aviso que muda como o resto é lido:** o trabalho é sobre o **dataset do seu grupo**. O
dado de imóveis que aparece na Parte 2 é o exemplo da aula. Se você colar este arquivo no
agente e não disser qual é o seu dado, ele vai escrever SQL sobre `anuncios_gold` e `area_util`
com toda a confiança do mundo. Diga o seu dataset, as suas colunas e o seu alvo.

- **Parte 1** vale para qualquer dataset.
- **Parte 2** é o exemplo. Os números dela são reais e conferidos, mas são de imóveis — se o
  seu resultado divergir, isso não quer dizer nada. O dado é outro.

---

# Parte 1 — Vale para qualquer dataset

## As cinco regras de vazamento

1. **A feature existiria no momento da predição?** Se você prevê o preço de um imóvel novo, ele
   chega sem preço. Se prevê churn, o motivo do cancelamento só existe depois do cancelamento.
2. **A feature foi preenchida depois do que você quer prever?** Se sim, é vazamento.
3. **Se o seu alvo nasceu de uma coluna, essa coluna fica FORA das features.** Esta é a que mais
   pega gente. Criou o rótulo com um `CASE WHEN` ou uma regex sobre alguma coluna? Então essa
   coluna, e qualquer coisa derivada dela, está proibida. Senão o modelo reaprende a sua regra,
   com acurácia quase perfeita e utilidade zero.
4. **Compare sempre com o baseline** e saiba explicar o que cada métrica significa.
5. **Métrica boa demais não se comemora, se investiga.** Modelo perfeito é tratado como
   vazamento até prova em contrário.

## A auditoria mínima antes de treinar

Estes números do **seu** dado você precisa ter medido antes de escrever qualquer `CREATE MODEL`.
Sem eles você não consegue defender nenhuma decisão do seu ETL — e é isso que vão te perguntar.

Um agente não inventa nenhum deles, porque não vê o seu dado.

```sql
-- 1. Tamanho, alvo e cauda. Media muito maior que a mediana = outlier.
SELECT COUNT(*)                                      AS linhas,
       COUNTIF(SEU_ALVO IS NULL)                     AS alvo_nulo,
       MIN(SEU_ALVO)                                 AS minimo,
       APPROX_QUANTILES(SEU_ALVO, 100)[OFFSET(50)]   AS mediana,
       AVG(SEU_ALVO)                                 AS media,
       MAX(SEU_ALVO)                                 AS maximo,
       STDDEV(SEU_ALVO)                              AS desvio
FROM `SEU_PROJETO.SEU_DATASET.sua_tabela`;

-- 2. Colunas mortas: 1 valor unico nao ensina nada ao modelo.
SELECT COUNT(DISTINCT coluna_a) AS distintos_a,
       COUNT(DISTINCT coluna_b) AS distintos_b
FROM `SEU_PROJETO.SEU_DATASET.sua_tabela`;

-- 3. Buracos: quanto de cada coluna esta vazio.
SELECT COUNTIF(coluna_a IS NULL) AS nulos_a,
       COUNTIF(coluna_b IS NULL) AS nulos_b,
       COUNT(*)                  AS total
FROM `SEU_PROJETO.SEU_DATASET.sua_tabela`;

-- 4. Duplicatas: registro repetido infla o treino e vaza para a avaliacao.
SELECT chave_natural, COUNT(*) AS vezes
FROM `SEU_PROJETO.SEU_DATASET.sua_tabela`
GROUP BY chave_natural HAVING vezes > 1
ORDER BY vezes DESC;
```

Cada filtro que você colocar no `WHERE` da sua gold precisa sair de um destes números. Filtro
sem número por trás é chute, e chute não se defende.

## Os baselines

O seu modelo não compete contra zero. Compete contra a resposta preguiçosa:

- **Regressão** — chutar sempre a média do alvo dá **R² = 0** por definição. R² negativo
  significa que o seu modelo é *pior* que chutar a média.
- **Classificação** — responder sempre a classe majoritária. A acurácia disso é a proporção da
  classe maior. Se 90% do seu dado é da classe A, um modelo com 90% não aprendeu nada. Por isso
  se olha **precision, recall e matriz de confusão**, não só acurácia.

```sql
-- baseline de classificacao: qual e a fatia da classe majoritaria?
SELECT seu_rotulo, COUNT(*) AS n,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `SEU_PROJETO.SEU_DATASET.sua_tabela`
GROUP BY seu_rotulo ORDER BY n DESC;
```

## Armadilhas técnicas já mapeadas

- `APPROX_QUANTILES(x, 100)[OFFSET(50)]` é aproximado e devolve um valor que **existe** na base;
  `PERCENTILE_CONT` interpola e pode devolver um que não existe. Os dois estão certos — diga
  qual você usou.
- O `BOOSTED_TREE` **muda a cada treino**. Rode mais de uma vez antes de afirmar que um modelo
  ganhou do outro por pouco. `LINEAR_REG` com `AUTO_SPLIT` reproduz igual.
- Importância de feature é confissão de um modelo específico, não verdade sobre o mundo: o
  linear e a árvore discordam sobre qual coluna é a mais importante, e as duas leituras estão
  certas. Diga de qual modelo veio o ranking.
- Em `ML.PREDICT` com valores inventados, respeite o tipo: `180 AS area` (INT64) funciona,
  `180.0` dá erro de coerção.
- Tempo de treino observado: `LINEAR_REG` ~25 s · `KMEANS` ~40 s · `LOGISTIC_REG` ~3 min ·
  `BOOSTED_TREE_REGRESSOR` ~4-5 min. Coluna categórica com muitos valores distintos é o que mais
  encarece.
- Para ler número completo, use a aba **JSON** do BigQuery — a aba Resultados trunca
  (`2581138.334933…`).
- Se o seu dado tem data, confira o que ela significa antes de sonhar com série temporal. Data
  de *cadastro* não é data de *evento*.

## Comandos

```sql
-- treinar
CREATE OR REPLACE MODEL `SEU_PROJETO.SEU_DATASET.meu_modelo`
OPTIONS (
  model_type = 'LINEAR_REG',        -- ou BOOSTED_TREE_REGRESSOR, LOGISTIC_REG, KMEANS...
  input_label_cols = ['SEU_ALVO'],  -- a coluna que você quer prever
  data_split_method = 'AUTO_SPLIT',
  enable_global_explain = TRUE      -- só liga ANTES do treino
) AS
SELECT SEU_ALVO, coluna_a, coluna_b /* ... */ FROM `SEU_PROJETO.SEU_DATASET.sua_gold`;

-- avaliar, explicar, prever
SELECT * FROM ML.EVALUATE(MODEL `SEU_PROJETO.SEU_DATASET.meu_modelo`);
SELECT * FROM ML.CONFUSION_MATRIX(MODEL `SEU_PROJETO.SEU_DATASET.meu_modelo`);  -- classificação
SELECT * FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.SEU_DATASET.meu_modelo`) ORDER BY attribution DESC;
SELECT * FROM ML.PREDICT(MODEL `SEU_PROJETO.SEU_DATASET.meu_modelo`,
                         (SELECT * FROM `SEU_PROJETO.SEU_DATASET.sua_gold`));
```

Não existe lista de features: `input_label_cols` diz qual coluna é a resposta e **todo o resto
do SELECT vira entrada**. Engenharia de features aqui é editar o SELECT.

---

# Parte 2 — O exemplo da aula: imóveis de Goiânia

Daqui para baixo, tudo se refere ao dado da **aula**. Serve como modelo de raciocínio: o tipo de
problema que a auditoria encontrou e o tamanho do estrago que cada um causava no modelo.

### `tb_anuncios_silver` — 1.000 linhas, não limpa

| problema | medida |
|---|---|
| preço | mediana R$ 9.076.455 · média R$ 20.638.086 · máximo **R$ 1.419.000.000** |
| outliers de preço | 29 anúncios acima de R$ 50 mi controlam 90% da variação (desvio cai de R$ 72,1 mi para R$ 6,9 mi sem eles) |
| área | 83 anúncios com `area_util` > 10.000 m² e 1 com ≤ 1 m²; o campeão tem 459.800.000 m² |
| colunas mortas | `tipo_contrato` e `status` têm 1 valor único; `cidade` é 999× Goiânia |
| coordenadas | 2 anúncios com lat/lon trocadas; 377 (37,7%) sem coordenada |
| duplicatas | o mesmo imóvel repetido (mesmo `titulo` + mesmo `preco`) |

Repare que **média 2,3× maior que a mediana** foi o sinal que denunciou a cauda. É o primeiro
número da auditoria da Parte 1.

### `anuncios_gold` — 887 linhas (`sql/02_gold_etl.sql`)

Filtros: `preco IS NOT NULL`, `preco BETWEEN 50000 AND 50000000`,
`area_util BETWEEN 20 AND 10000`. Lat/lon consertadas por `CASE WHEN latitude < -40`.
Derivadas: `eh_comercial` (regex sobre `titulo`) e `preco_por_m2`.
Confirmação: 887 linhas · mediana R$ 8.900.000 · média R$ 10.762.248 · desvio R$ 5.632.444 ·
146 comerciais (16,5%).

### `gold_texto` — 887 linhas (`sql/05_features_texto.sql`)

A gold mais seis flags do título: `tem_piscina` 31 · `eh_alto_padrao` 80 · `tem_mobilia` 51 ·
`eh_terreno` 120 · `eh_apartamento` 104 · `eh_casa` 382.

### `gold_com_titulo` — exemplo de vazamento (`sql/06_armadilha.sql`)

Tem `preco_no_titulo`, extraída do texto do anúncio. Existe em só 4% das linhas, não muda o
`ML.EVALUATE` agregado, e mesmo assim é vazamento: o modelo aprende a *ler* o preço, não a
avaliar o imóvel.

### Números de referência dos modelos

| modelo | o que mudou | MAE | R² |
|---|---|---|---|
| v0 `modelo_preco_imoveis` | dado como estava | R$ 13.835.427 | −0,350 |
| v1 `modelo_preco` | Gold limpa (887 linhas) | R$ 2.581.138 | +0,298 |
| v3 `modelo_preco_v3` | + 6 features de texto | R$ 2.469.775 | +0,471 |
| v4 `modelo_preco_arvore` | BOOSTED_TREE no mesmo dado | ~R$ 1,8–2,2 mi | ~+0,55 a +0,65 |

`modelo_comercial` (LOGISTIC_REG, alvo `eh_comercial`): accuracy 0,953 · precision 0,762 ·
recall 0,842 · ROC AUC 0,959. O baseline ("residencial para tudo") dá **83,5%**.

`segmentos_imoveis` (KMEANS, 4 grupos, `standardize_features = TRUE`): 610 residenciais padrão ·
188 comerciais de 0 quarto e 12 vagas · 11 prédios inteiros · 78 alto padrão.

**O que esses números provam:** limpar o dado tirou o erro de R$ 13,8 mi para R$ 2,58 mi — 81%
do ganho veio do ETL, não do modelo. Trocar o algoritmo no fim rendeu menos que o `WHERE` do
começo.

---

## Como usar este arquivo com um agente

Cole o arquivo inteiro e **diga qual é o seu dado** — dataset, tabela, colunas e alvo. Sem isso,
o agente responde sobre imóveis.

> Com o contexto acima: meu dataset é de [assunto], minha tabela é
> `meu_projeto.meu_dataset.silver` com as colunas [lista], e eu quero prever [alvo].
> Proponha a auditoria da Parte 1 adaptada às minhas colunas, e depois o `WHERE` da gold —
> justificando cada filtro contra um número que eu vou medir.

Peça sempre que ele **justifique cada coluna que virar feature** contra as regras 1 a 3. E
confira: o agente não roda a sua query nem vê o seu dado. Ele descreve o que *deveria*
acontecer; só o BigQuery diz o que aconteceu.

O teste, antes de entregar: feche o computador e explique em voz alta por que cada filtro do seu
`WHERE` está lá e o que aconteceria se você o tirasse. Se conseguir, o agente foi ferramenta. Se
não, foi atalho.
