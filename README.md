# PDM 2026.2 — Material prático

**Processamento de Dados Massivos** · 6º período de Inteligência Artificial · Instituto de Informática — UFG

Este repositório reúne tudo que você vai usar nas aulas práticas de **BigQuery ML** e de **MLOps com n8n**: scripts SQL, guias de estudo, fluxos do n8n, o dataset e os templates de configuração.

A ideia é simples: você dá um `git clone`, segue o guia de ambiente uma vez, e a partir daí toda aula já está pronta para rodar na sua máquina e na sua conta.

```bash
git clone <url-do-repositorio>
cd pdm-2026-2
cp .env.example .env      # depois preencha com os seus valores
```

---

## Comece por aqui

Faça isto **antes da primeira aula prática**, com calma, em casa:

| Ordem | O que fazer | Onde |
|---|---|---|
| 1 | Montar o seu ambiente no Google Cloud | [`docs/01-monte-seu-ambiente-gcp.md`](docs/01-monte-seu-ambiente-gcp.md) |
| 2 | Copiar `.env.example` para `.env` e preencher | raiz do repositório |
| 3 | Conferir o dataset e o dicionário de dados | [`dados/README.md`](dados/README.md) |

Depois da primeira aula prática, quando quiser ir além do que foi visto em sala:

| | O que é | Onde |
|---|---|---|
| Contexto do Trabalho 1 | o dado, os números medidos e as regras que valem nota — feito para colar no seu agente | [`CONTEXTOTRABALHO1.md`](CONTEXTOTRABALHO1.md) |
| Aprender por conta | a CLI do Google, os laboratórios, a documentação e como usar um agente sem terceirizar o aprendizado | [`docs/03-aprender-por-conta.md`](docs/03-aprender-por-conta.md) |

> **Você não vai gastar dinheiro nesta disciplina.** O BigQuery tem uma camada gratuita permanente muito maior do que tudo que a gente vai fazer aqui, e o dataset tem cerca de 15 MB. O guia de ambiente explica isso em detalhe e ensina a configurar um alerta de orçamento como rede de segurança.

---

## Estrutura

```
pdm-2026-2/
├── docs/                        guias que valem para o semestre inteiro
├── dados/                       o dataset e o dicionário de dados
├── ferramentas/                 utilitários (perfilador do dataset)
└── aulas/
    ├── 04-09-bigquery-ml/       treinar modelos sem sair do SQL
    ├── 13-11-mlops-n8n/         orquestrar o pipeline
    └── 27-11-agente-whatsapp/   colocar o modelo na mão do usuário
```

---

## As aulas

### 04/09 — BigQuery ML: o dado vira decisão

Do JSON cru até um modelo treinado, tudo em SQL. Bronze → Silver → Gold → `CREATE MODEL`.
Habilita o **Trabalho 1**: treinar um modelo a partir da camada Gold usando puramente BigQuery ML.

- Guia interativo: [`aulas/04-09-bigquery-ml/material/aula-04-09.html`](aulas/04-09-bigquery-ml/material/aula-04-09.html) — abre no navegador com dois cliques, funciona offline, dá para imprimir em PDF
- Scripts: [`aulas/04-09-bigquery-ml/sql/`](aulas/04-09-bigquery-ml/sql/)

### 13/11 — MLOps com n8n: as peças viram sistema

Expressões, referência de dados entre nodes e orquestração do pipeline.
Habilita o **Trabalho Final**: automatizar o fluxo todo com n8n.

- Guia: [`docs/02-n8n-expressoes-e-dados.md`](docs/02-n8n-expressoes-e-dados.md)

### 27/11 — Agente no WhatsApp: o modelo na mão do usuário

Um agente que recebe uma mensagem em linguagem natural, extrai os campos, consulta o modelo que **você treinou em setembro** e devolve a estimativa na conversa. De quebra, a discussão sobre API oficial versus não oficial.

- Guia: [`aulas/27-11-agente-whatsapp/README.md`](aulas/27-11-agente-whatsapp/README.md)

---

## O fio condutor

O mesmo dataset atravessa o semestre inteiro, e não é por preguiça — é para você ver o mesmo conceito voltando de outra forma:

```
04/09   JSON_VALUE(listing, '$.address.city')      <- caminho dentro de um JSON, com SQL
13/11   {{ $json.address.city }}                   <- o mesmo caminho, com o mouse
27/11   o modelo treinado no 04/09 respondendo uma mensagem
```

---

## A regra do `.env`

Todo valor que identifica **você** (id do projeto, nome do bucket, API key) fica num arquivo `.env`, que está no `.gitignore` e **nunca** vai para o repositório. O que é versionado é o `.env.example`, só com placeholders.

Se você for publicar o seu trabalho no GitHub, confira isso antes de dar `push`. Chave de API vazada é um problema real e caro, e bot varre repositório público em minutos.

```bash
# antes de publicar qualquer coisa
git status          # o .env NÃO pode aparecer aqui
```

---

## Ajuda

Travou em algum passo? Traz o erro exato (mensagem completa, não "deu erro") para a aula ou para o canal da disciplina. Metade dos problemas de Cloud se resolve lendo a mensagem inteira.

---

*Material das aulas de Guilherme C. Dutra. Disciplina sob responsabilidade do Prof. Sávio.*
