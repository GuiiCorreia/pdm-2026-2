# Contexto — Trabalho 1 (PDM 2026.2, BigQuery ML)

Arquivo para você colar no seu agente (Claude Code, Cursor, Copilot) antes de pedir ajuda com
o Trabalho 1.

**Leia isto primeiro, porque muda como o resto do arquivo deve ser usado.** O Trabalho 1 é
sobre **o dataset do seu grupo** — aquele que vocês escolheram nas primeiras aulas. O dataset
de imóveis que aparece daqui para baixo é o **exemplo trabalhado da disciplina**, o mesmo da
aula de 04/09. Ele está aqui para mostrar *como se audita um dado e como se avalia um modelo*,
não como gabarito do seu.

Na prática:

- A **Parte 1** vale para qualquer dataset. É o que o professor vai cobrar.
- A **Parte 2** é o exemplo. Os números dela são reais e conferidos, mas são de imóveis. Se o
  seu resultado divergir deles, isso não quer dizer nada — o dado é outro.

Se você colar este arquivo no agente e não avisar qual é o seu dado, ele vai escrever SQL sobre
`anuncios_gold`, `area_util` e `eh_comercial` com toda a confiança do mundo. Diga qual é o seu
dataset, quais são as suas colunas, e qual é o seu alvo.

---

## O que o Trabalho 1 pede

Enunciado, do cronograma da disciplina (11/09, Prof. Sávio):

> Os alunos farão a ingestão de um dataset no GCS e usarão o poder computacional do BigQuery
> (ELT) para processar as camadas da Arquitetura Medallion (Bronze, Silver, Gold). A partir da
> camada Gold, devem treinar um modelo inicial de mineração de dados usando puramente
> BigQuery ML.

São cinco etapas, e este arquivo cobre as duas últimas:

| | Etapa | Onde está |
|---|---|---|
| 1 | Ingestão do dataset no GCS | aula do Sávio, 21/08 (`Raw_to_bronze`) |
| 2 | Bronze | aula do Sávio, 21/08 (`Raw_to_bronze`) |
| 3 | Silver | aula do Sávio, 21/08 (`Bronze_to_silver`) |
| 4 | **Gold** | **aqui** + `sql/02_gold_etl.sql` |
| 5 | **Modelo em BigQuery ML** | **aqui** + `sql/03` a `sql/07` |

Um aviso sobre a etapa 1: no [`docs/01`](docs/01-monte-seu-ambiente-gcp.md) eu digo que você
*não* precisa subir arquivo nenhum. Aquilo vale para a **aula**, onde o dado é o mesmo para
todo mundo e mora num bucket só. No **trabalho** é o contrário: subir o arquivo do seu grupo
para o seu bucket é a primeira coisa que vale nota.

---

# Parte 1 — Vale para qualquer dataset

## Regras que valem nota

1. **A feature existiria no momento da predição?** Se você prevê o preço de um imóvel novo,
   ele chega sem preço. Se você prevê churn, o motivo do cancelamento só existe depois do
   cancelamento.
2. **A feature foi preenchida depois do que você quer prever?** Se sim, é vazamento.
3. **Se o seu alvo nasceu de uma coluna, essa coluna fica FORA das features.** Esta é a que
   mais pega gente. Se você criou o rótulo com um `CASE WHEN` ou uma regex sobre alguma
   coluna, essa coluna — e qualquer coisa derivada dela — está proibida. Senão o modelo
   reaprende a sua regra, com acurácia quase perfeita e utilidade zero.
4. **Compare sempre com o baseline** e saiba explicar o que cada métrica significa.
5. **Métrica boa demais não se comemora, se investiga.** Modelo perfeito é tratado como
   vazamento até prova em contrário.

## A auditoria mínima antes de treinar

Estes números do **seu** dado você precisa ter medido antes de escrever qualquer `CREATE MODEL`.
Não porque valham ponto isoladamente, mas porque sem eles você não consegue defender nenhuma
decisão do seu ETL — e é exatamente isso que o professor vai perguntar.

Um agente não consegue inventar nenhum deles. Ele não vê o seu dado.

```sql
-- 1. Tamanho, alvo e cauda. Se a media for muito maior que a mediana, voce tem outlier.
SELECT COUNT(*)                                      AS linhas,
       COUNTIF(SEU_ALVO IS NULL)                     AS alvo_nulo,
       MIN(SEU_ALVO)                                 AS minimo,
       APPROX_QUANTILES(SEU_ALVO, 100)[OFFSET(50)]   AS mediana,
       AVG(SEU_ALVO)                                 AS media,
       MAX(SEU_ALVO)                                 AS maximo,
       STDDEV(SEU_ALVO)                              AS desvio
FROM `SEU_PROJETO.SEU_DATASET.sua_silver`;

-- 2. Colunas mortas: uma coluna com 1 valor unico nao ensina nada ao modelo.
SELECT COUNT(DISTINCT coluna_a) AS distintos_a,
       COUNT(DISTINCT coluna_b) AS distintos_b
FROM `SEU_PROJETO.SEU_DATASET.sua_silver`;

-- 3. Buracos: quanto de cada coluna esta vazio.
SELECT COUNTIF(coluna_a IS NULL) AS nulos_a,
       COUNTIF(coluna_b IS NULL) AS nulos_b,
       COUNT(*)                  AS total
FROM `SEU_PROJETO.SEU_DATASET.sua_silver`;

-- 4. Duplicatas: o mesmo registro repetido infla o treino e vaza para a avaliacao.
SELECT chave_natural, COUNT(*) AS vezes
FROM `SEU_PROJETO.SEU_DATASET.sua_silver`
GROUP BY chave_natural HAVING vezes > 1
ORDER BY vezes DESC;
```

Cada filtro que você colocar no `WHERE` da sua gold precisa sair de um destes números. Filtro
sem número por trás é chute, e chute não se defende na apresentação.

## Os baselines

O seu modelo não compete contra zero. Ele compete contra a resposta preguiçosa:

- **Regressão** — chutar sempre a média do alvo. Isso dá **R² = 0** por definição. R² negativo
  significa que o seu modelo é *pior* que chutar a média. O MAE desse chute é o número que o
  seu modelo tem que bater.
- **Classificação** — responder sempre a classe majoritária. A acurácia disso é a proporção da
  classe maior. Se 90% do seu dado é da classe A, um modelo com 90% de acurácia não aprendeu
  nada. É por isso que você olha **precision, recall e a matriz de confusão**, não só acurácia.

```sql
-- baseline de classificacao: qual e a fatia da classe majoritaria?
SELECT seu_rotulo, COUNT(*) AS n,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `SEU_PROJETO.SEU_DATASET.sua_gold`
GROUP BY seu_rotulo ORDER BY n DESC;
```

## Armadilhas técnicas já mapeadas

- `APPROX_QUANTILES(x, 100)[OFFSET(50)]` é aproximado e devolve um valor que **existe** na
  base; `PERCENTILE_CONT` interpola e pode devolver um valor que não existe. Os dois estão
  certos — diga qual você usou.
- O `BOOSTED_TREE` **muda a cada treino**. Rode mais de uma vez antes de afirmar que um modelo
  ganhou do outro por uma diferença pequena. `LINEAR_REG` com `AUTO_SPLIT` reproduz igual.
- Importância de feature é confissão de um modelo específico, não verdade sobre o mundo: o
  linear e a árvore discordam sobre qual coluna é a mais importante, e as duas leituras estão
  certas. Sempre diga de qual modelo veio o ranking.
- Em `ML.PREDICT` com valores inventados, respeite o tipo da coluna: `180 AS area` (INT64)
  funciona, `180.0` dá erro de coerção.
- Tempo de treino observado: `LINEAR_REG` ~25 s · `KMEANS` ~40 s · `LOGISTIC_REG` ~3 min ·
  `BOOSTED_TREE_REGRESSOR` ~4-5 min. Uma coluna categórica com muitos valores distintos é o
  que mais encarece. Planeje.
- Para ler número completo, use a aba **JSON** do BigQuery — a aba Resultados trunca
  (`2581138.334933…`).
- Se o seu dado tem data, confira o que ela significa antes de sonhar com série temporal. Data
  de *cadastro* não é data de *evento*, e sem série temporal `ARIMA_PLUS` não se aplica.

## Comandos que você vai usar

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

# Parte 2 — O exemplo trabalhado: imóveis de Goiânia

Daqui para baixo, tudo se refere ao dataset da **aula**, não ao seu. Serve como modelo de
raciocínio: veja o tipo de problema que a auditoria encontrou e o tamanho do estrago que cada
um causava no modelo.

## As tabelas

### `tb_anuncios_silver` — 1.000 linhas, NÃO limpa

Saiu dos notebooks (raw → bronze → silver). Está estruturada e tipada, mas a limpeza ficou em
aberto. Problemas medidos:

| problema | medida |
|---|---|
| preço | mediana R$ 9.076.455 · média R$ 20.638.086 · máximo **R$ 1.419.000.000** |
| outliers de preço | 29 anúncios acima de R$ 50 mi controlam 90% da variação (desvio cai de R$ 72,1 mi para R$ 6,9 mi sem eles) |
| área | 83 anúncios com `area_util` > 10.000 m² e 1 com ≤ 1 m²; o campeão tem 459.800.000 m² (63% de Goiânia) |
| colunas mortas | `tipo_contrato` e `status` têm 1 valor único; `cidade` é 999× Goiânia |
| coordenadas | 2 anúncios com lat/lon trocadas; 377 (37,7%) sem coordenada nenhuma |
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

A gold mais seis flags booleanas do título: `tem_piscina` 31 · `eh_alto_padrao` 80 ·
`tem_mobilia` 51 · `eh_terreno` 120 · `eh_apartamento` 104 · `eh_casa` 382.

### `gold_com_titulo` — exemplo de VAZAMENTO (`sql/06_armadilha.sql`)

Tem `preco_no_titulo`, extraída do texto do anúncio. Existe em só 4% das linhas, não muda o
`ML.EVALUATE` agregado, e mesmo assim é vazamento: o modelo aprende a *ler* o preço, não a
avaliar o imóvel.

## Números de referência dos modelos

| modelo | o que mudou | MAE | R² |
|---|---|---|---|
| v0 `modelo_preco_imoveis` | dado como estava | R$ 13.835.427 | −0,350 |
| v1 `modelo_preco` | Gold limpa (887 linhas) | R$ 2.581.138 | +0,298 |
| v3 `modelo_preco_v3` | + 6 features de texto | R$ 2.469.775 | +0,471 |
| v4 `modelo_preco_arvore` | BOOSTED_TREE no mesmo dado | ~R$ 1,8–2,2 mi | ~+0,55 a +0,65 |

`modelo_comercial` (LOGISTIC_REG, alvo `eh_comercial`): accuracy 0,953 · precision 0,762 ·
recall 0,842 · ROC AUC 0,959 · matriz 146/5/3/16 em 170 anúncios de avaliação. O baseline
("residencial para tudo") dá **83,5%**.

`segmentos_imoveis` (KMEANS, 4 grupos, `standardize_features = TRUE`): 610 residenciais padrão ·
188 comerciais de 0 quarto e 12 vagas · 11 prédios inteiros · 78 alto padrão.

**O que esses números provam:** limpar o dado tirou o erro de R$ 13,8 mi para R$ 2,58 mi — 81%
do ganho total veio do ETL, não do modelo. Trocar o algoritmo no fim rendeu menos que o
`WHERE` do começo. É o argumento inteiro da disciplina em duas linhas.

---

## Como usar este arquivo com um agente

Cole o arquivo inteiro e **diga qual é o seu dado** — dataset, tabela, colunas e alvo. Sem
isso, o agente vai responder sobre imóveis.

Exemplo de pedido bom:

> Com o contexto acima: meu dataset é de [assunto], minha silver é
> `meu_projeto.meu_dataset.silver` com as colunas [lista], e eu quero prever [alvo].
> Proponha a auditoria da Parte 1 adaptada às minhas colunas, e depois o `WHERE` da gold —
> justificando cada filtro contra um número que eu vou medir.

Peça sempre que ele **justifique cada coluna que virar feature** contra as regras 1 a 3. E
confira o que ele responder: o agente não roda a sua query nem vê o seu dado. Ele descreve o
que *deveria* acontecer; só o BigQuery diz o que aconteceu.

O teste, antes de entregar: feche o computador e explique em voz alta por que cada filtro do
seu `WHERE` está lá e o que aconteceria se você o tirasse. Se conseguir, o agente foi
ferramenta. Se não, foi atalho.
