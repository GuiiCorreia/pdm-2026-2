# 13/11 — MLOps com n8n

> Vocês passaram o semestre construindo peças. Hoje a gente pluga tudo.

Até aqui cada coisa rodou sozinha: você subiu o dado, criou as camadas, treinou o modelo, chamou uma API. Tudo na mão, um passo de cada vez, você clicando.

Orquestrar é tirar você do meio.

---

## O que você vai aprender

O n8n é a ferramenta, mas o conteúdo de verdade é **como um dado anda entre etapas de um pipeline**. Isso vale para n8n, para Airflow, para Cloud Composer e para qualquer coisa que você use depois.

A pergunta central da aula: *o node seguinte recebe uma lista de itens; como eu aponto para um campo de um item?*

Se isso soa familiar, é porque é. Em 04/09 você escreveu:

```sql
JSON_VALUE(listing, '$.address.city')
```

Hoje você vai escrever:

```
{{ $json.address.city }}
```

**Mesmo conceito, mesmo caminho dentro do mesmo JSON.** Uma vez com SQL, outra com o mouse. Você não está aprendendo coisa nova, está reconhecendo.

---

## Antes de começar

- [ ] Sua conta no n8n criada e senha definida
- [ ] Leia [`../../docs/02-n8n-expressoes-e-dados.md`](../../docs/02-n8n-expressoes-e-dados.md) — é o guia de referência da aula
- [ ] `.env` preenchido na raiz do repositório (veja [`../../.env.example`](../../.env.example))

Cada um trabalha na própria conta. O seu fluxo não aparece para os outros e o dos outros não aparece para você.

---

## Como a aula funciona

Não é demonstração. **Você arrasta a caixinha junto.**

O ritmo é o da turma: cada node que aparece na tela lá na frente, aparece na sua também antes de a gente seguir. Se travou, fala na hora — parar dois minutos é mais barato do que você passar a aula inteira perdido.

---

## Arquivos

| Arquivo | O que é |
|---|---|
| `workflows/` | os fluxos prontos, para importar se você se perder no meio |

Os fluxos em `workflows/` são rede de segurança, não atalho. Importar o pronto sem ter montado te deixa com um fluxo que funciona e um aprendizado que não aconteceu.

---

## A regra do segredo

Segredo **nunca** vai dentro de um node. Vai em **credencial** do n8n.

A diferença é concreta: quando você exporta um workflow em JSON, o que está no node vai junto no arquivo. Se você commitar isso, sua chave está pública. O que está na credencial fica no servidor e não sai no export.

O que **pode** ficar visível no canvas é configuração que não é segredo: id do projeto, nome do dataset, nome do bucket. Para isso a gente usa um node `Edit Fields (Set)` chamado `Config` no topo do fluxo, e referencia com:

```
{{ $('Config').first().json.projeto }}
```

Assim a configuração fica num lugar só, visível, e você troca de ambiente mudando um node.

---

## Onde isso te leva

O **Trabalho Final** pede que o fluxo todo seja automatizado e orquestrado com n8n. Esta aula e a de [27/11](../27-11-agente-whatsapp/) são o que você precisa para isso.
