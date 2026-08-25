# 27/11 — Agente no WhatsApp

> O modelo que você treinou em setembro respondendo uma mensagem em novembro.

Uma pessoa manda no WhatsApp: *"quero um apartamento de 3 quartos no Setor Bueno, uns 90 metros"*. Alguns segundos depois recebe uma estimativa de preço.

No meio disso tem: um agente que lê linguagem natural e extrai campos, uma consulta ao **seu** modelo no BigQuery, e uma resposta escrita de volta. Nada disso é novo — todas as peças você já construiu. Hoje elas viram uma coisa só.

---

## O que você vai aprender

Duas coisas, e a segunda vale mais que a primeira.

**A técnica:** como um agente transforma texto livre em campos estruturados, e como esses campos viram um `ML.PREDICT`.

**A discussão:** **API oficial versus API não oficial.** Esse é um assunto que você vai encarar na vida profissional em algum momento — provavelmente antes do que imagina, e provavelmente com um cliente te pedindo a opção errada.

---

## O fio do semestre fecha aqui

```
04/09   você treinou um modelo de preço no BigQuery ML
13/11   você aprendeu a mover dado entre nodes
27/11   uma mensagem de WhatsApp chega no modelo e volta como resposta
```

O `ML.PREDICT` desta aula é o **mesmo** que você rodou em setembro. Muda só quem faz a pergunta.

---

## Antes de começar

- [ ] O modelo de 04/09 treinado e vivo no seu dataset
- [ ] A aula de [13/11](../13-11-mlops-n8n/) feita — esta depende direto dela
- [ ] Sua conta no n8n funcionando
- [ ] `.env` preenchido na raiz do repositório (veja [`../../.env.example`](../../.env.example))
- [ ] **Escolha o seu canal** — leia a seção abaixo antes de decidir

---

## Os dois caminhos

Você vai escolher um. Os dois entregam o mesmo agente; muda o que está entre ele e o usuário.

| | **Telegram** | **WhatsApp não oficial** |
|---|---|---|
| Node no n8n | nativo (Telegram Trigger) | HTTP Request + Webhook |
| Como conecta | token do BotFather | QR code, sessão de aparelho |
| Precisa de número? | não | sim, um número real |
| Risco de banimento | nenhum | **real** |
| Custo | zero | varia por provedor |
| Reprodutível na sua máquina | sim | sim, com o risco acima |

**A minha recomendação para você fazer em casa é o Telegram.** Não é o caminho "mais fraco" — é o caminho onde o aprendizado é idêntico e o risco é zero.

**O WhatsApp não oficial eu demonstro ao vivo**, no meu número, para vocês verem funcionando e para a gente ter a conversa que vem a seguir com um exemplo concreto na tela.

---

## API oficial versus não oficial

Essa parte não é filosofia. É a diferença entre um sistema que sobrevive e um que morre numa terça-feira.

### O que é cada uma

**Oficial** — a WhatsApp Business Platform (Cloud API), da Meta. Você se cadastra, verifica o negócio, usa modelos de mensagem aprovados e paga por mensagem. É um contrato.

**Não oficial** — bibliotecas e serviços que conversam com o WhatsApp fingindo ser o WhatsApp Web. Você lê um QR code com o celular e a sessão fica de pé. Não tem cadastro, não tem aprovação, não tem contrato — e é aí que mora tudo.

### Por que a não oficial é tentadora

Ela é honestamente atraente, e ignorar isso seria desonesto:

- funciona em minutos, não em dias
- não precisa de verificação de negócio nem de CNPJ
- não tem modelo de mensagem para aprovar
- manda mensagem para quem você quiser, na hora
- é barata

Para um protótipo, uma demo, um trabalho de faculdade, ela resolve.

### Por que ela quebra

Os **Termos de Serviço do WhatsApp** proíbem, entre outras coisas, "fazer engenharia reversa, alterar, modificar, criar obras derivadas, descompilar ou extrair código dos nossos Serviços" e "criar software ou APIs que funcionem substancialmente da mesma forma que os nossos Serviços e oferecê-los para uso de terceiros de forma não autorizada".

Um cliente que imita o WhatsApp Web cai exatamente aí. Na prática, isso quer dizer:

- **o número pode ser banido**, e quem é banido normalmente é o número, não o servidor
- não existe SLA, não existe suporte, não existe recurso — você não tem com quem falar
- **a quebra é silenciosa e sem aviso**: o WhatsApp muda um detalhe do protocolo e a sua integração para de funcionar numa quarta-feira de manhã, sem changelog

O ponto que eu quero que fique: **o risco não é técnico, é de negócio.** O código funciona. O que não é confiável é a permissão para o código continuar funcionando.

### E a oficial, por que não é sempre a resposta

Porque ela tem um preço, e não é só o financeiro:

- **cobrança por mensagem**, com categorias diferentes (marketing, utilidade, autenticação, serviço) e regras que mudam de tempos em tempos
- **não existe camada gratuita para desenvolvimento** — o modelo antigo de conversas grátis por mês acabou
- **limite inicial de 250 destinatários únicos por 24 horas** para um portfólio novo. Você sobe de faixa (2.000 → 10.000 → 100.000 → ilimitado) conforme verifica o negócio e mantém boa qualidade
- verificação de negócio, modelos de mensagem para aprovar, e a burocracia que vem junto

### A resposta profissional

Não é "sempre oficial" nem "oficial quando der". É:

> **Protótipo em qualquer coisa. Produção com o número de um cliente, só oficial.**

E, quando você for defender isso numa reunião, o argumento que funciona não é "os termos proíbem". É este: *o número de atendimento da empresa é um ativo. Colocar esse ativo em cima de uma integração que pode ser desligada sem aviso é um risco que ninguém aceita quando entende o que está aceitando.*

Se você sair desta aula só com essa frase, ela já valeu.

> Ah, e vale a pena saber: os provedores não oficiais existem, são um mercado grande e boa parte deles é honesta sobre o que é. **O problema não é o provedor — é a base em que ele está de pé.**

---

## Como a aula funciona

Igual à de 13/11: **você monta junto**. Cada node que aparece na tela lá na frente aparece na sua antes de a gente seguir.

O roteiro:

1. o gatilho recebe a mensagem
2. um agente lê o texto e devolve os campos estruturados (bairro, quartos, área)
3. um `Config` guarda projeto e dataset
4. o BigQuery roda o `ML.PREDICT` contra o **seu** modelo
5. a resposta volta formatada para a conversa

O passo 4 é literalmente o SQL de 04/09.

---

## Arquivos

| Arquivo | O que é |
|---|---|
| `workflows/` | os fluxos prontos, para importar se você se perder no meio |

Os fluxos são rede de segurança, não atalho.

---

## A armadilha que sempre pega

Dado que chega por **Webhook** fica embaixo de `.body`:

```
{{ $json.mensagem }}        ← undefined
{{ $json.body.mensagem }}   ← certo
```

Está explicado em [`../../docs/02-n8n-expressoes-e-dados.md`](../../docs/02-n8n-expressoes-e-dados.md), armadilha 5. Se o seu fluxo parecer não estar recebendo nada, comece por aí — e **olhe a estrutura real do item** antes de mexer em qualquer outra coisa.

---

## Onde isso te leva

O **Trabalho Final** (entrega 04/12) pede o fluxo todo automatizado e orquestrado com n8n. Esta aula é a ponta que faz o pipeline encostar num usuário de verdade.

---

*Preços, limites e termos consultados nas fontes oficiais em 25/08/2026. Esse cenário muda rápido — confira antes de usar em algo sério.*
