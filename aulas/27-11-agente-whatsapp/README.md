# 27/11 — Agente no WhatsApp

> O modelo que você treinou em setembro respondendo uma mensagem em novembro.

Uma pessoa manda no WhatsApp: *"quero um apartamento de 3 quartos no Setor Bueno, uns 90 metros"*. Alguns segundos depois recebe uma estimativa de preço.

No meio disso tem: um agente que lê linguagem natural e extrai campos, uma consulta ao **seu** modelo no BigQuery, e uma resposta escrita de volta. Nada disso é novo — todas as peças você já construiu. Hoje elas viram uma coisa só.

---

## O que você vai aprender

Duas coisas, e a segunda vale mais que a primeira.

**A técnica:** como um agente transforma texto livre em campos estruturados, e como esses campos viram um `ML.PREDICT`.

**A discussão:** **API oficial e API não oficial** — o que é cada uma, como se entra, o que muda entre elas. Assunto que aparece cedo na vida profissional.

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
| Custo | zero | varia por provedor |
| Bloqueio do número | não se aplica | possível |

**Para fazer em casa, sugiro o Telegram**: o aprendizado é o mesmo e você não precisa expor um número.

**O WhatsApp não oficial eu demonstro ao vivo**, no meu número, para vocês verem funcionando com um exemplo concreto na tela.

---

## API oficial e API não oficial

Existem dois caminhos para colocar software para conversar pelo WhatsApp. Eles são diferentes em quase tudo: como você entra, quanto custa, o que pode e o que acontece quando dá problema.

Vale conhecer os dois, porque na vida profissional você vai esbarrar nos dois.

### O que é cada uma

**Oficial** — a WhatsApp Business Platform (Cloud API), da Meta. Você cadastra um negócio, passa por verificação, usa modelos de mensagem aprovados e paga pelas mensagens. É uma relação contratual com a Meta.

**Não oficial** — bibliotecas e serviços que conversam com o WhatsApp se apresentando como o WhatsApp Web. Você lê um QR code com o celular e a sessão fica de pé. Não há cadastro nem aprovação.

### Lado a lado

| | Oficial (Cloud API) | Não oficial |
|---|---|---|
| **Entrada** | Business Manager, verificação de negócio com CNPJ, número dedicado que não pode estar ativo no app comum | QR code, minutos |
| **Custo** | por mensagem, em quatro categorias: marketing, utilidade, autenticação e serviço | plano do provedor ou auto-hospedado |
| **Mensagens** | modelos aprovados pela Meta para iniciar conversa | texto livre |
| **Volume** | começa em 250 destinatários únicos/24h, sobe por faixas (2.000 → 10.000 → 100.000 → ilimitado) | sem faixa definida |
| **Suporte** | canal da Meta, documentação versionada | do provedor, quando existe |
| **Estabilidade** | mudanças anunciadas | pode parar sem aviso quando o protocolo muda |
| **Termos de uso** | é o uso previsto | os Termos do WhatsApp proíbem engenharia reversa e APIs substancialmente similares |

> Sobre os Termos: eles proíbem, entre outras coisas, "fazer engenharia reversa, alterar, modificar, criar obras derivadas, descompilar ou extrair código dos nossos Serviços" e "criar software ou APIs que funcionem substancialmente da mesma forma que os nossos Serviços e oferecê-los para uso de terceiros de forma não autorizada". Na prática, o risco concreto é o **número** ser bloqueado.

*Preços, faixas e regras consultados em 25/08/2026. Isso muda com frequência — confira na documentação da Meta antes de orçar qualquer coisa.*

### Por que a aula usa a não oficial

Por um motivo prático: **é o que cabe numa aula.** A oficial exige CNPJ, verificação de negócio e um número dedicado — nada disso um aluno monta em duas horas para fazer o exercício junto.

Isso não é um veredito sobre qual das duas é melhor. A escolha real, num projeto real, depende do contexto: quem é o cliente, qual o volume, quem assume o risco, quanto tempo você tem. **O que eu quero é que vocês conheçam as duas e saibam fazer essa conta.**

O que a gente monta hoje — gatilho, contexto, modelo, resposta — **é o mesmo dos dois lados**. Muda o node de entrada e o node de saída. O miolo, que é o que interessa nesta disciplina, é idêntico.

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
