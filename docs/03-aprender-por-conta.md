# Aprender por conta — a CLI do Google, os laboratórios e o agente

Guia de indicações, não de tarefas. Nada aqui vale nota. Serve para quem terminou a aula
com a sensação de que dá para ir mais fundo — e quer saber por onde.

Ele fecha a trinca: o [`README`](../README.md) diz o que a disciplina faz, o
[`CONTEXTOTRABALHO1.md`](../CONTEXTOTRABALHO1.md) descreve o dado e as regras do trabalho, e
este arquivo aponta para fora, para onde o aprendizado continua sem professor no meio.

---

## 1. Sair do console: `gcloud` e `bq`

Tudo que você fez no BigQuery Studio dá para fazer do terminal. Vale a pena, por três
motivos concretos:

- **Você vê a query inteira.** No console o editor completa, sugere e esconde. No terminal
  a query é um texto que você escreveu e pode versionar junto com o resto do trabalho.
- **Repetir fica barato.** Um `.sh` com dez queries roda dez vezes igual. Clicar dez vezes
  no console, não.
- **É assim que o trabalho de verdade acontece.** Ninguém opera pipeline em produção
  clicando.

Instalação: [Google Cloud CLI](https://cloud.google.com/sdk/docs/install). Depois:

```bash
gcloud auth login                     # abre o navegador, você entra com a conta da UFG
gcloud config set project SEU_PROJETO # o mesmo id que você usa nos scripts
bq ls                                 # lista os datasets — se listar, está tudo certo
```

A partir daí, qualquer script da aula roda direto:

```bash
bq query --use_legacy_sql=false --format=prettyjson \
  'SELECT * FROM ML.EVALUATE(MODEL `SEU_PROJETO.anuncios.modelo_preco`)'
```

Duas coisas que economizam tempo:

- `--format=prettyjson` resolve o problema do número truncado. A aba **Resultados** do
  console corta `2581138.334933…`; o JSON mostra inteiro.
- `bq query < arquivo.sql` executa um arquivo. É a forma mais direta de rodar os scripts
  `00` a `07` da aula sem copiar e colar nada.

Um `bq ls -j -a` lista os jobs que você já rodou, com custo e duração de cada um. Boa forma
de descobrir qual dos seus modelos demorou 4 minutos e por quê.

---

## 2. Os laboratórios do Google

O Google mantém uma plataforma de treinamento com laboratórios que provisionam um projeto
GCP temporário — você não gasta o seu crédito nem suja o seu projeto.

**[Google Cloud Skills Boost](https://www.cloudskillsboost.google)** — procure por
`BigQuery ML`. Os laboratórios de introdução cobrem exatamente o esqueleto da aula
(`CREATE MODEL` → `ML.EVALUATE` → `ML.PREDICT`) com outro dataset, o que é justamente o
valor: ver o mesmo conceito em outro dado é o que mostra que você entendeu o conceito, e
não decorou o dataset de imóveis.

Parte do catálogo é paga, parte é gratuita, e o Google costuma liberar trilhas para
estudantes. Vale conferir com o seu e-mail `@discente.ufg.br` antes de pagar qualquer coisa.

**A documentação oficial** é melhor do que a fama que tem:

- [Introdução ao BigQuery ML](https://cloud.google.com/bigquery/docs/bqml-introduction) —
  a lista completa de tipos de modelo. Você usou 4; existem mais de 20, incluindo séries
  temporais, detecção de anomalia e importação de modelos do TensorFlow.
- A referência do `CREATE MODEL` lista **todas** as opções de `OPTIONS`. A aula usou
  `model_type`, `input_label_cols`, `data_split_method` e `enable_global_explain`. Tem
  dezenas de outras — regularização, número de árvores, taxa de aprendizado. É onde você
  vai quando quiser melhorar um modelo além do que a aula mostrou.

---

## 3. O repositório como área de trabalho

Você já clonou este repositório para pegar os scripts. Ele também serve como o lugar onde o
seu trabalho mora:

```bash
git clone <url-do-repositorio>
cd pdm-2026-2
```

Se quiser guardar o seu próprio trabalho aqui, faça um **fork** primeiro. Assim você tem um
repositório seu, com o histórico do material, e ainda consegue puxar atualizações minhas com
`git pull upstream main`.

O ganho real de trabalhar dentro da pasta não é organizacional, é de contexto: um agente
apontado para esta pasta **lê os scripts, o dicionário de dados e o
`CONTEXTOTRABALHO1.md` sozinho**. Você para de colar contexto a cada pergunta, e ele para de
inventar nome de coluna.

Antes de qualquer `push`, a regra do `.env` vale sempre — está explicada no
[`README`](../README.md). Chave vazada em repositório público é varrida por bot em minutos.

---

## 4. Usar agente sem terceirizar o aprendizado

Esta seção é a mais importante do arquivo.

Um agente escreve SQL plausível em segundos. O que ele **não** consegue fazer é produzir
`MAE 2.581.138`. Esse número só aparece se o pipeline estiver realmente certo — se a gold
tiver as 887 linhas certas, com os filtros certos, nas colunas certas. É por isso que este
material publica os números medidos: eles não são gabarito, são **detector de mentira**. Se
o seu resultado não bate, ou o seu pipeline está diferente, ou o texto está descrevendo algo
que você não rodou.

E tem uma ironia útil aqui: **o erro que o agente comete por padrão é exatamente o que a
aula ensina a evitar.** Peça a um agente "melhore o R² deste modelo" e há uma boa chance de
ele incluir `preco_no_titulo`, ou colocar `titulo` como feature do classificador que nasceu
de uma regex sobre `titulo`. Nos dois casos a métrica sobe e o modelo não serve para nada.
Quem sabe disso é você. O agente não sabe — ele otimiza o que você pediu.

Daí a diferença entre os dois modos de usar:

| terceirizar (não aprende) | usar bem (aprende mais rápido) |
|---|---|
| "faz o trabalho 1 pra mim" | "critica a minha escolha de features contra as regras 1 a 3" |
| "escreve o SQL" | "explica por que este `JOIN` duplicou minhas linhas" |
| "melhora o R²" | "meu R² subiu de 0,29 para 0,71 — procure vazamento antes de eu comemorar" |
| aceita a resposta | pede a query, **roda**, e compara com o número de referência |

Três hábitos que funcionam:

1. **Rode antes de acreditar.** O agente não vê o seu dado nem executa a sua query. Ele
   descreve o que *deveria* acontecer. Só o BigQuery diz o que aconteceu.
2. **Peça que ele justifique cada coluna** que virar feature, uma por uma, contra as regras
   de vazamento. Se ele não conseguir justificar, você achou um problema — ou nele, ou na
   sua ideia.
3. **Use-o como adversário, não como autor.** "Encontre o erro nisto que eu escrevi" produz
   mais aprendizado por minuto do que "escreva isto para mim". E é o que você vai fazer
   profissionalmente: revisar código que uma máquina escreveu.

O teste final é simples e você pode aplicar sozinho, antes de entregar qualquer coisa:

> Fecha o computador. Consegue explicar, em voz alta, por que cada filtro do `WHERE` está
> lá e o que aconteceria se você tirasse?

Se sim, o agente foi ferramenta. Se não, ele foi atalho — e o atalho cobra depois, numa
prova, numa entrevista, ou no primeiro dia em que o modelo for para produção e errar.

---

## 5. Se você quiser ir bem além

Ideias que saem do escopo da disciplina e são projeto de verdade:

- **Trocar a regex por embedding.** O `eh_comercial` sai de uma regex sobre o título, que
  acerta muito e erra em silêncio. O BigQuery ML permite gerar embeddings do texto com
  `ML.GENERATE_EMBEDDING` e usar o vetor como feature. É a ponte entre esta disciplina e
  NLP.
- **Detectar anúncio suspeito por resíduo.** Em vez de prever o preço, olhe onde o modelo
  erra mais e pergunte por quê. Boa parte dos seus 20 piores erros são duplicatas e
  anúncios mal preenchidos — ou seja, um modelo de preço vira um detector de qualidade de
  cadastro.
- **Rodar o pipeline inteiro por fora do console.** Os scripts `00` a `07` em um `.sh`,
  versionados, reproduzíveis do zero. É o primeiro passo do que a aula de 13/11 vai chamar
  de MLOps.

Nenhuma delas vale ponto. Todas valem no portfólio.
