# 04/09 — BigQuery ML

> Na aula passada você treinou um modelo. Esta aula começa descobrindo se ele presta.

Com o Sávio você fez `raw → bronze → silver` e rodou um `CREATE MODEL` em cima de uma gold. Apareceu **"o modelo foi criado"** e a aula acabou ali.

Ficou uma pergunta no ar: **o modelo é bom?**

A aula começa respondendo isso — em uma query — e a resposta é ruim. A partir daí, o trabalho todo é consertar. No fim você vai ter, na sua conta, treinados por você:

- um diagnóstico honesto do modelo de 28/08 (spoiler: R² **negativo**)
- uma camada **Gold** construída com critério, não com sorte
- **features de texto** arrancadas do título do anúncio com NLP simples
- **quatro modelos de preço** comparados num placar só
- um modelo de **classificação** (comercial vs residencial) medido contra baseline
- uma **segmentação de mercado** sem label nenhum (KMeans)
- e a armadilha que faz um modelo parecer ótimo e ser inútil

---

## Antes de começar

- [ ] Ambiente montado conforme [`../../docs/01-monte-seu-ambiente-gcp.md`](../../docs/01-monte-seu-ambiente-gcp.md)
- [ ] Você tem o dataset **`anuncios`** com a tabela `tb_anuncios_silver` (feita na aula do Sávio)
- [ ] Você deu uma olhada no [dicionário de dados](../../dados/README.md)

**Não terminou a aula passada?** Sem problema. O `sql/00_avaliar_modelo_de_hoje.sql` tem, comentado no topo, o `CREATE MODEL` exato do Sávio. Descomente, rode, e você entra na aula no mesmo ponto que a turma.

**Um placeholder só.** Todos os scripts usam `SEU_PROJETO`. Troque pelo id do seu projeto no GCP, em todos os arquivos, antes de rodar qualquer coisa. O dataset é `anuncios` e já vem escrito.

No editor é um "substituir em todos os arquivos". Se esquecer, o BigQuery reclama de tabela não encontrada e você perde cinco minutos procurando o motivo errado.

---

## O guia interativo

O material completo da aula está em **[`material/aula-04-09.html`](material/aula-04-09.html)**.

Abra com dois cliques. Funciona offline, não precisa de internet nem de instalar nada. É por ele que a aula caminha, alternando com o console do BigQuery.

- botão de **copiar** em cada bloco de SQL
- **checkpoints** que ficam marcados enquanto você avança
- **spoilers**: tenta responder antes de clicar
- **Ctrl+P / Cmd+P** gera um PDF, se preferir estudar impresso
- tecla **P** liga o modo de projeção

Dois diagramas acompanham o material:

- **[`material/medallion.html`](material/medallion.html)** — a revisão da arquitetura medalhão: o que bronze, silver e gold se comprometem a entregar, quem consome a gold e o que acontece quando uma camada não cumpre a sua parte. É por onde a aula começa.
- **[`material/pipeline.html`](material/pipeline.html)** — o pipeline inteiro desta aula, do bucket aos quatro modelos comparados, em uma tela.

Ele é o seu guia de estudo depois da aula também. Não é slide.

---

## Os scripts, na ordem

Rode nesta ordem. Cada um depende do anterior.

| # | Arquivo | O que ele faz |
|---|---|---|
| 0 | [`sql/00_avaliar_modelo_de_hoje.sql`](sql/00_avaliar_modelo_de_hoje.sql) | julga o modelo que você treinou em 28/08. Uma query |
| 1 | [`sql/01_auditoria_silver.sql`](sql/01_auditoria_silver.sql) | audita a silver e mede a dívida de ETL que ela deixou em aberto |
| 2 | [`sql/02_gold_etl.sql`](sql/02_gold_etl.sql) | constrói a Gold de verdade, decidindo o que entra e o que sai |
| 3 | [`sql/03_regressao.sql`](sql/03_regressao.sql) | retreina o preço na Gold e compara com o modelo velho |
| 4 | [`sql/04_classificacao.sql`](sql/04_classificacao.sql) | comercial ou residencial: outro problema, mesmos três verbos |
| 5 | [`sql/05_features_texto.sql`](sql/05_features_texto.sql) | tira feature do título do anúncio (piscina, alto padrão, terreno) |
| 6 | [`sql/06_armadilha.sql`](sql/06_armadilha.sql) | o modelo que melhora e mesmo assim está errado |
| 7 | [`sql/07_modelos_prontos.sql`](sql/07_modelos_prontos.sql) | árvore no lugar da reta, e um KMeans sem label nenhum |

> Sobre o passo 6: **rode antes de tirar conclusão.** Ele não é o que parece na primeira leitura.

---

## Os notebooks (extra)

A aula acontece no console do BigQuery. Os notebooks em [`notebooks/`](notebooks/) são a mesma aula rodando de Python, para quando você for estudar sozinho:

| # | Notebook | Cobre |
|---|---|---|
| 1 | [`01-do-bucket-a-gold.ipynb`](notebooks/01-do-bucket-a-gold.ipynb) | scripts 1 e 2 |
| 2 | [`02-modelos-e-features.ipynb`](notebooks/02-modelos-e-features.ipynb) | scripts 0, 3, 4 e 5 |
| 3 | [`03-armadilha-e-modelos-prontos.ipynb`](notebooks/03-armadilha-e-modelos-prontos.ipynb) | scripts 6 e 7 |

O SQL é o mesmo, palavra por palavra. O que muda é que o resultado volta como DataFrame e dá para desenhar o placar em gráfico, em vez de olhar número solto.

Rodam no Colab sem instalar nada. Localmente, precisam de `google-cloud-bigquery`, `pandas`, `db-dtypes` e `matplotlib`. A primeira célula é a única que você edita: troque `SEU_PROJETO` pelo id do seu projeto.

Não são pré-requisito da aula. Se você só quer o Trabalho 1, o `sql/` basta.

---

## O placar que a aula constrói

Tudo que a aula faz cabe nesta tabela. Ela é o resumo da disciplina inteira:

| modelo | o que mudou | MAE | R² |
|---|---|---:|---:|
| v0 | o dado como estava | R$ 13.835.427 | **−0,350** |
| v1 | Gold limpa | R$ 2.581.138 | +0,298 |
| v3 | Gold + features de texto | R$ 2.469.775 | +0,471 |
| v4 | mesmo dado, árvore no lugar da reta | R$ 1.823.401 | **+0,556** |

Três alavancas, nesta ordem de impacto:

1. **limpar o dado** (v0 → v1) — o erro caiu 5,4×
2. **criar feature** (v1 → v3) — o R² subiu de 0,298 para 0,471
3. **trocar o algoritmo** (v3 → v4) — o erro caiu mais 26%

A aposta natural é na terceira. É a primeira que decide o jogo, e é a que ninguém quer fazer.

---

## Os blocos "COMO LER ESTE COMANDO"

Nos comandos mais densos, logo **depois** do SQL, tem um bloco assim:

```
-- ---------------------------------------------------------------------
-- COMO LER ESTE COMANDO
-- ---------------------------------------------------------------------
```

Ele destrincha a query pedaço por pedaço: o que cada função faz, por que ela está ali, e o que quebra se você tirar. Quase sempre a leitura é **de dentro para fora**, começando pelo miolo.

Copiar SQL que funciona é fácil. O que faz diferença no Trabalho 1 é conseguir olhar para uma query de outra pessoa e dizer o que ela faz — e é para isso que esses blocos existem.

Nem todo comando tem um. Os de conferência (`SELECT COUNT(*)`) não precisam.

---

## Os três verbos

A aula inteira cabe em três comandos. E você já conhece o primeiro:

```sql
CREATE MODEL   ...   OPTIONS (model_type = '...')   AS SELECT ...
ML.EVALUATE    (MODEL ...)
ML.PREDICT     (MODEL ..., (SELECT ...))
```

`CREATE TABLE` você já sabe. `CREATE MODEL` é o mesmo verbo, com um `OPTIONS` no meio. Não existe `pip install`, não existe `train_test_split`, não existe notebook. O modelo vira um objeto do dataset, do lado das suas tabelas.

Mais dois que aparecem hoje:

```sql
ML.GLOBAL_EXPLAIN    (MODEL ...)   -- quais colunas o modelo usou
ML.CONFUSION_MATRIX  (MODEL ...)   -- onde a classificação erra
```

---

## Custo

Zero.

O dataset tem 14,6 MB. O free tier do BigQuery cobre 1 TiB de query processada por mês, e o `CREATE MODEL` entra na mesma conta. Você teria que rodar os scripts desta aula dezenas de milhares de vezes para chegar perto do limite.

---

## Onde isso te leva

O **Trabalho 1** pede um modelo treinado a partir da camada Gold usando **puramente BigQuery ML**. Os scripts 2, 3 e 4 são o esqueleto disso.

O script 6 é o que separa um trabalho que roda de um trabalho que está certo. Vale reler antes de entregar.

E o script 5 é o que separa um trabalho correto de um trabalho interessante: qualquer um treina no que já está tabelado; poucos param para perguntar o que mais tem escondido no texto.

---

## Desafios

Cada script termina com desafios. Não valem nota, mas são exatamente o que você vai querer ter feito quando o trabalho chegar.

Se for fazer só um: no script 7, treine a árvore **sem** as features de texto e descubra quanto do ganho veio do algoritmo e quanto veio da feature. Essa é a pergunta que separa relatório bom de relatório ruim.
