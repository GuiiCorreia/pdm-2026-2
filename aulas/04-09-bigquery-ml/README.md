# 04/09 — BigQuery ML

> Do JSON cru até um modelo treinado, sem sair do SQL.

Hoje a gente fecha o caminho que começou na aula de Medallion: você já sabe **guardar** o dado. Falta fazer ele **decidir** alguma coisa.

No fim da aula você vai ter, na sua conta, treinado por você:
- uma camada Silver construída a partir de um JSON aninhado de verdade
- um modelo de **regressão** que estima o preço de um imóvel
- um modelo de **classificação** que diz se um anúncio é residencial ou comercial
- e uma resposta para a pergunta que vale mais que os dois modelos juntos: *como eu sei se posso confiar nisso?*

---

## Antes de começar

- [ ] Ambiente montado conforme [`../../docs/01-monte-seu-ambiente-gcp.md`](../../docs/01-monte-seu-ambiente-gcp.md)
- [ ] Dataset criado no BigQuery, **em `us-east1`**
- [ ] Você deu uma olhada no [dicionário de dados](../../dados/README.md)

Você **não precisa subir o `.csv`**. O dado da disciplina já está num bucket público:

```
gs://pdm-2026-2-dados/imoveis/aula-pdm.csv
```

Ele está em `us-east1` — por isso o seu dataset também tem que estar. Bucket e dataset em regiões diferentes: o BigQuery se recusa a ler.

**Todos os scripts usam dois placeholders.** Antes de rodar qualquer coisa, troque nos seis arquivos:

| Placeholder | Troque por |
|---|---|
| `SEU_PROJETO` | o id do seu projeto no GCP |
| `SEU_DATASET` | o nome do dataset que você criou no BigQuery (`pdm_2026_2`) |

No editor, é um "substituir em todos os arquivos". Se esquecer, o BigQuery vai reclamar de tabela não encontrada e você vai perder cinco minutos procurando o motivo errado.

---

## O guia interativo

O material completo da aula está em **[`material/aula-04-09.html`](material/aula-04-09.html)**.

Abra com dois cliques. Ele funciona offline, não precisa de internet nem de instalar nada.

- botão de **copiar** em cada bloco de SQL
- **checkpoints** que ficam marcados enquanto você avança
- **Ctrl+P / Cmd+P** gera um PDF, se você preferir estudar impresso
- tecla **P** liga o modo de projeção

Ele é o seu guia de estudo depois da aula também. Não é slide.

---

## Os scripts, na ordem

Rode nesta ordem. Cada um depende do anterior.

| # | Arquivo | O que ele faz |
|---|---|---|
| 0 | [`sql/bronze_00_setup.sql`](sql/bronze_00_setup.sql) | aponta o BigQuery para o CSV no seu bucket, sem copiar o arquivo |
| 1 | [`sql/silver_01_json.sql`](sql/silver_01_json.sql) | quebra o JSON aninhado em colunas |
| 2 | [`sql/silver_02_etl.sql`](sql/silver_02_etl.sql) | olha para o dado antes de confiar nele, e limpa |
| 3 | [`sql/ml_03_regressao.sql`](sql/ml_03_regressao.sql) | treina, avalia, prevê e explica um modelo de regressão |
| 4 | [`sql/ml_04_classificacao.sql`](sql/ml_04_classificacao.sql) | o mesmo caminho, trocando uma palavra |
| 5 | [`sql/ml_05_armadilha.sql`](sql/ml_05_armadilha.sql) | melhora o modelo do passo 3 e investiga o resultado |

> Sobre o passo 5: **rode antes de tirar conclusão.** Ele não é o que parece na primeira leitura.

---

## Os blocos "COMO LER ESTE COMANDO"

Nos comandos mais densos, logo **depois** do SQL, tem um bloco assim:

```
-- =====================================================================
-- COMO LER ESTE COMANDO
-- =====================================================================
```

Ele destrincha a query pedaço por pedaço: o que cada função faz, por que ela está ali, e o que quebra se você tirar. Quase sempre a leitura é **de dentro para fora**, começando pelo miolo.

Cada bloco termina com uma **pergunta**, com a resposta logo abaixo entre parênteses. Vale mais tentar responder antes de ler.

Copiar SQL que funciona é fácil. O que faz diferença no Trabalho 1 é conseguir olhar para uma query de outra pessoa e dizer o que ela faz — e é para isso que esses blocos existem.

Nem todo comando tem um. Os de conferência (`SELECT COUNT(*)`) não precisam.

---

## Os três verbos

A aula inteira cabe em três comandos. Repare que você já conhece o primeiro verbo:

```sql
CREATE MODEL   ...   OPTIONS (model_type = '...')   AS SELECT ...
ML.EVALUATE    (MODEL ...)
ML.PREDICT     (MODEL ..., (SELECT ...))
```

`CREATE TABLE` você já sabe. `CREATE MODEL` é o mesmo verbo, com um `OPTIONS` no meio. Não existe `pip install`, não existe `train_test_split`, não existe notebook. O modelo vira um objeto do dataset, do lado das suas tabelas.

---

## Custo

Zero.

O dataset tem 14,6 MB. O free tier do BigQuery cobre 1 TiB de query processada por mês. Você teria que rodar os scripts desta aula dezenas de milhares de vezes para chegar perto do limite. Treinar modelo com `CREATE MODEL` também entra nessa conta.

---

## Onde isso te leva

O **Trabalho 1** pede para treinar um modelo a partir da camada Gold usando **puramente BigQuery ML**. Os passos 3 e 4 são exatamente o esqueleto disso.

O passo 5 é o que separa um trabalho que roda de um trabalho que está certo. Vale a pena reler antes de entregar.

---

## Desafios

Cada script termina com desafios. Eles não valem nota, mas são o que você vai querer ter feito quando o trabalho chegar. Se for fazer só um, faça o de trocar `LINEAR_REG` por `BOOSTED_TREE_REGRESSOR` e comparar as métricas: é uma linha de diferença e o resultado costuma surpreender.
