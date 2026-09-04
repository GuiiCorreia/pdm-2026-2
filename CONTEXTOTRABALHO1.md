# Contexto — Trabalho 1 (PDM 2026.2, BigQuery ML)

Arquivo de contexto para você colar no seu agente (Claude Code, Cursor, Copilot) antes de
pedir ajuda com o Trabalho 1. Ele descreve o dado, o que já foi construído na aula de 04/09
e as regras que valem nota. Todos os números aqui foram medidos no dataset oficial da
disciplina — se o seu resultado divergir, o problema está no seu pipeline, não no enunciado.

---

## Ambiente

- BigQuery Studio, no seu projeto GCP. Substitua `SEU_PROJETO` em todos os códigos.
- Dataset: `SEU_PROJETO.anuncios`
- Dialeto: GoogleSQL (BigQuery). Modelos treinam com `CREATE MODEL`, sem Python.
- O esqueleto é sempre o mesmo: `CREATE MODEL` (treina) → `ML.EVALUATE` (vale alguma
  coisa?) → `ML.PREDICT` (usa).

## Tabelas

### `tb_anuncios_silver` — 1.000 linhas, NÃO limpa
Saiu dos notebooks (raw → bronze → silver). Está estruturada e tipada, mas a limpeza ficou
em aberto. Problemas medidos, que você precisa tratar antes de treinar qualquer coisa:

| problema | medida |
|---|---|
| preço | mediana R$ 9.076.455 · média R$ 20.638.086 · máximo **R$ 1.419.000.000** |
| outliers de preço | 29 anúncios acima de R$ 50 mi controlam 90% da variação (desvio cai de R$ 72,1 mi para R$ 6,9 mi sem eles) |
| área | 83 anúncios com `area_util` > 10.000 m² e 1 com ≤ 1 m²; o campeão tem 459.800.000 m² (63% de Goiânia) |
| colunas mortas | `tipo_contrato` e `status` têm 1 valor único; `cidade` é 999× Goiânia |
| coordenadas | 2 anúncios com lat/lon trocadas; 377 (37,7%) sem coordenada nenhuma |
| duplicatas | o mesmo imóvel aparece repetido (mesmo `titulo` + mesmo `preco`) |

Atenção: `data_insercao` é a data de **publicação do anúncio**, não de venda. Não existe
série temporal aqui — ARIMA_PLUS não se aplica.

### `anuncios_gold` — 887 linhas (script `02_gold_etl.sql`)
Filtros aplicados: `preco IS NOT NULL`, `preco BETWEEN 50000 AND 50000000`,
`area_util BETWEEN 20 AND 10000`. Lat/lon consertadas por `CASE WHEN latitude < -40`.
Colunas derivadas: `eh_comercial` (regex sobre `titulo`) e `preco_por_m2`.
Confirmação esperada: 887 linhas · mediana R$ 8.900.000 · média R$ 10.762.248 ·
desvio R$ 5.632.444 · 146 comerciais (16,5%).

### `gold_texto` — 887 linhas (script `05_features_texto.sql`)
A gold mais seis flags booleanas extraídas do título, com esta cobertura medida:
`tem_piscina` 31 · `eh_alto_padrao` 80 · `tem_mobilia` 51 · `eh_terreno` 120 ·
`eh_apartamento` 104 · `eh_casa` 382.

### `gold_com_titulo` — exemplo de VAZAMENTO (script `06_armadilha.sql`)
Tem a coluna `preco_no_titulo`, extraída do texto do anúncio. **Não use como feature.**
Ela existe em só 4% das linhas, não muda o `ML.EVALUATE` agregado, e mesmo assim é
vazamento de alvo: o modelo aprende a *ler* o preço, não a avaliar o imóvel.

## Números de referência dos modelos

| modelo | o que mudou | MAE | R² |
|---|---|---|---|
| v0 `modelo_preco_imoveis` | dado como estava | R$ 13.835.427 | −0,350 |
| v1 `modelo_preco` | Gold limpa (887 linhas) | R$ 2.581.138 | +0,298 |
| v3 `modelo_preco_v3` | + 6 features de texto | R$ 2.469.775 | +0,471 |
| v4 `modelo_preco_arvore` | BOOSTED_TREE no mesmo dado | ~R$ 1,8–2,2 mi | ~+0,55 a +0,65 |

`modelo_comercial` (LOGISTIC_REG, alvo `eh_comercial`): accuracy 0,953 · precision 0,762 ·
recall 0,842 · ROC AUC 0,959 · matriz 146/5/3/16 em 170 anúncios de avaliação.

`segmentos_imoveis` (KMEANS, 4 grupos, `standardize_features = TRUE`): 610 residenciais
padrão · 188 comerciais de 0 quarto e 12 vagas · 11 prédios inteiros · 78 alto padrão.

**Baselines contra os quais o seu modelo tem que ganhar:**
- Regressão: chutar a média = R² 0. R² negativo é pior que não ter modelo.
- Classificação comercial × residencial: responder "residencial" para tudo dá **83,5%** de
  acurácia. Um modelo com 84% não aprendeu nada.

## Regras que valem nota

1. **A feature existiria no momento da predição?** Imóvel novo chega sem preço.
2. **A feature foi preenchida depois do que você quer prever?** Se sim, é vazamento.
3. **Se o seu alvo nasceu de uma coluna, essa coluna fica FORA das features.** O
   `eh_comercial` veio de uma regex sobre `titulo` — então `titulo`, e qualquer coluna
   derivada dele, está proibido no classificador. Senão o modelo reaprende a sua regex,
   com acurácia perfeita e utilidade zero.
4. **Compare sempre com o baseline** e saiba explicar o que cada métrica significa.
5. **Métrica boa demais não se comemora, se investiga.** Modelo perfeito é tratado como
   vazamento até prova em contrário.

## Armadilhas técnicas já mapeadas

- `APPROX_QUANTILES(preco, 100)[OFFSET(50)]` é aproximado e devolve um valor que existe na
  base — não é igual à mediana exata de `PERCENTILE_CONT`. Os dois estão certos; diga qual
  você usou.
- O `BOOSTED_TREE` muda a cada treino. Rode mais de uma vez antes de afirmar que um modelo
  ganhou do outro por uma diferença pequena.
- Importância de feature é confissão de um modelo específico, não verdade sobre o mundo: o
  linear e a árvore discordam sobre qual coluna é a mais importante, e as duas leituras
  estão certas. Sempre diga de qual modelo veio o ranking.
- Em `ML.PREDICT` com valores inventados, respeite o tipo da coluna: `180 AS area_util`
  (INT64) funciona, `180.0` dá erro de coerção.
- Tempo de treino observado: LINEAR_REG ~25 s · KMEANS ~40 s · LOGISTIC_REG ~3 min ·
  BOOSTED_TREE_REGRESSOR ~4-5 min. Planeje.
- Para ler número completo no resultado, use a aba **JSON** do BigQuery — a aba Resultados
  trunca (`2581138.334933...`).

## Comandos que você vai usar

```sql
-- treinar
CREATE OR REPLACE MODEL `SEU_PROJETO.anuncios.meu_modelo`
OPTIONS (
  model_type = 'LINEAR_REG',        -- ou BOOSTED_TREE_REGRESSOR, LOGISTIC_REG, KMEANS...
  input_label_cols = ['preco'],     -- a coluna que você quer prever
  data_split_method = 'AUTO_SPLIT',
  enable_global_explain = TRUE      -- só liga ANTES do treino
) AS
SELECT preco, area_util, quartos /* ... */ FROM `SEU_PROJETO.anuncios.gold_texto`;

-- avaliar, explicar, prever
SELECT * FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.meu_modelo`);
SELECT * FROM ML.CONFUSION_MATRIX(MODEL `SEU_PROJETO.anuncios.meu_modelo`);  -- classificação
SELECT * FROM ML.GLOBAL_EXPLAIN(MODEL `SEU_PROJETO.anuncios.meu_modelo`) ORDER BY attribution DESC;
SELECT * FROM ML.PREDICT(MODEL `SEU_PROJETO.anuncios.meu_modelo`,
                         (SELECT * FROM `SEU_PROJETO.anuncios.gold_texto`));
```

Não existe lista de features: `input_label_cols` diz qual coluna é a resposta e **todo o
resto do SELECT vira entrada**. Engenharia de features aqui é editar o SELECT.

## Como usar este arquivo com um agente

Cole este arquivo inteiro no contexto e diga o que você quer fazer. Exemplo de pedido bom:

> Com o contexto acima, quero construir um detector de anúncio suspeito por análise de
> resíduo sobre a `gold_texto`. Proponha o SQL, aponte onde eu posso estar criando
> vazamento e me diga contra qual baseline eu tenho que comparar.

Peça sempre que o agente **justifique cada coluna que virar feature** contra as regras 1 a 3.
E confira o que ele responder: o agente não roda a sua query nem vê o seu dado.
