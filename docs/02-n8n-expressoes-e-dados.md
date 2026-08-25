# Expressões e referência de dados no n8n

> Guia de referência das aulas de 13/11 e 27/11. Deixe aberto numa aba durante a aula.

---

## 1. O modelo mental

Antes de qualquer sintaxe, entenda isto, porque **tudo** depois decorre daqui:

> **Todo node recebe uma lista de itens. Cada item é um JSON.**
> A chave é o contrato. O valor muda a cada item.
> Uma expressão é um caminho até uma chave.

Imagine que o node anterior leu uma planilha com três alunos. O que chega no próximo node é isto:

```json
[
  { "nome": "Ana",   "email": "ana@ufg.br"   },
  { "nome": "Bruno", "email": "bruno@ufg.br" },
  { "nome": "Carla", "email": "carla@ufg.br" }
]
```

Três itens. Todos com as **mesmas chaves** (`nome`, `email`) e **valores diferentes**.

Quando você escreve `{{ $json.email }}` num campo, você não está escrevendo um e-mail. Está escrevendo *"o campo `email` do item que estiver passando agora"*. O n8n roda o node três vezes, uma por item, e a cada volta a mesma expressão devolve um valor diferente.

É por isso que um fluxo com três alunos e um fluxo com quarenta alunos são **exatamente o mesmo fluxo**.

---

## 2. Fixed vs Expression

Todo campo de todo node tem dois modos. Passe o mouse por cima de um campo e aparece o alternador:

| Modo | O que significa |
|---|---|
| **Fixed** | o que você digitar é o valor, literal |
| **Expression** | o que você digitar é uma *fórmula*, avaliada a cada item |

Em modo Expression, o n8n mostra o **resultado ao vivo** logo abaixo do campo. Use isso o tempo todo: se o resultado apareceu, sua expressão está certa; se apareceu `undefined`, o caminho está errado.

### O truque de arrastar

Você quase nunca precisa digitar uma expressão. No painel da esquerda (INPUT) estão os dados que chegaram. **Arraste o campo** de lá para dentro do campo do node e o n8n faz três coisas sozinho:

1. escreve a expressão correta
2. muda o campo de Fixed para Expression
3. mostra o valor resolvido

Agora clique na seta para ir do item 1 para o item 2. Repare no que acontece:

> **a expressão continua idêntica, o valor muda.**

Esse é o conceito inteiro da aula em um gesto.

### O prefixo `=` — a prova disso

Exporte o workflow (menu do fluxo → Download) e abra o JSON. Um campo em modo Fixed aparece assim:

```json
"url": "https://api.exemplo.com/usuarios"
```

O mesmo campo em modo Expression aparece assim:

```json
"url": "=https://api.exemplo.com/usuarios/{{ $json.id }}"
```

**O `=` no começo é o n8n dizendo "isto é fórmula, não texto".** É o parâmetro fixo e o valor variável, visíveis no arquivo.

---

## 3. Tabela de referência

| Expressão | Para quê |
|---|---|
| `{{ $json.email }}` | campo do item atual, vindo do node imediatamente anterior |
| `{{ $json['E-mail do aluno'] }}` | **obrigatório** quando a chave tem espaço, acento ou hífen |
| `{{ $json.address.city }}` | campo aninhado |
| `{{ $json.pricingInfos[0].price }}` | primeiro elemento de uma lista |
| `{{ $('Ler Planilha').item.json.email }}` | campo de um node específico, item correspondente |
| `{{ $('Ler Planilha').first().json.id }}` | primeiro item daquele node — determinístico |
| `{{ $('Ler Planilha').all().length }}` | quantos itens aquele node produziu |
| `{{ $json.status ?? 'pendente' }}` | valor padrão quando a chave **não existe** |
| `{{ $json.status \|\| 'pendente' }}` | valor padrão quando a chave não existe **ou está vazia** |

Sobre nomes de node: `$('Ler Planilha')` usa o **nome exato** do node no canvas, incluindo maiúsculas e espaços. Se você renomear o node, a expressão quebra.

> Você vai encontrar `$node["Ler Planilha"].json.email` em tutoriais antigos. Ainda funciona, mas é a forma legada. A interface de hoje gera `$('Ler Planilha')`. Use a nova.

---

## 4. A ponte com o BigQuery

Em 04/09 você escreveu isto para pegar a cidade de dentro de um JSON:

```sql
JSON_VALUE(listing, '$.address.city')
```

Aqui você escreve isto:

```
{{ $json.address.city }}
```

**É o mesmo caminho, dentro do mesmo tipo de estrutura.** Lá o JSON estava numa coluna do BigQuery; aqui ele é o item que trafega entre dois nodes. Lá você navegou com SQL; aqui, com ponto.

Você não está aprendendo um conceito novo. Está reconhecendo um que já usou.

---

## 5. As cinco armadilhas

Estas cinco respondem pela maioria esmagadora dos fluxos quebrados. Vamos cair em todas de propósito na aula.

### Armadilha 1 — chave com espaço, acento ou hífen

```
{{ $json.E-mail do aluno }}      ← quebra
{{ $json['E-mail do aluno'] }}   ← certo
```

**Por que quebra, e são dois motivos diferentes:**

- **espaço**: a expressão é JavaScript. `$json.E-mail do aluno` não é uma expressão válida, o parser para.
- **hífen**: pior, porque é *silencioso na leitura*. `$json.E-mail` é lido como **subtração**: `$json.E` menos `mail`. O n8n tenta subtrair duas coisas indefinidas e devolve `NaN`.

Isso importa muito mais do que parece, porque **todo cabeçalho de Google Sheets cai aqui**. "Nome do aluno", "E-mail", "Data de entrega" — todos precisam de colchete. A regra prática:

> Se a chave não é uma palavra só, sem acento, use colchete.

### Armadilha 2 — célula vazia não dá erro

Uma célula em branco na planilha não vira erro. Vira `undefined` ou string vazia `""`, e o fluxo segue em frente carregando o vazio até estourar três nodes depois, num lugar que não tem nada a ver com a causa.

Os dois operadores de valor padrão **não são equivalentes**:

```
{{ $json.status ?? 'pendente' }}    ← só cobre null e undefined
{{ $json.status || 'pendente' }}    ← cobre também "" e 0
```

Célula em branco do Sheets pode chegar das duas formas, dependendo de como a planilha foi lida. Então:

| Situação | Use |
|---|---|
| campo de texto que pode vir vazio | `\|\|` |
| campo numérico onde **zero é um valor válido** | `??` |

Cuidado com o segundo caso, e ele é real: `{{ $json.vagas \|\| 1 }}` num imóvel **sem garagem** transforma `0` em `1`. O `\|\|` considera zero "vazio". Aí o seu modelo recebe dado errado e você nunca vai desconfiar da expressão.

### Armadilha 3 — `.item` depois de agregação

```
{{ $('Ler Planilha').item.json.email }}     ← pode quebrar
{{ $('Ler Planilha').first().json.email }}  ← determinístico
```

`.item` significa *"o item daquele node que corresponde ao item atual"*. O n8n rastreia essa correspondência item a item.

Quando um node no meio do caminho **junta ou divide itens** (Aggregate, Merge, Summarize, Code que devolve outra quantidade), a correspondência se perde: não existe mais "o item correspondente", porque cinquenta viraram um. O n8n não consegue decidir e o node falha.

A mensagem varia conforme a versão, mas gira em torno de *não conseguir determinar qual item usar* ou de informação de pareamento ausente. Se você viu algo assim, é isto.

**Correção:** troque para `.first()` quando você quer um valor único e sabe que ele é o mesmo para todos os itens — id do projeto, nome do dataset, token. É o caso da maioria esmagadora das vezes.

### Armadilha 4 — `{{ }}` dentro do Code node

Dentro de um node **Code** não existe `{{ }}`. Ali é JavaScript direto:

```javascript
// ERRADO
const email = {{ $json.email }};        // Unexpected token '{'

// ERRADO E PIOR — não dá erro nenhum
const email = "{{ $json.email }}";      // devolve o texto literal "{{ $json.email }}"

// CERTO
const email = $json.email;
const todos = $input.all();
```

A segunda forma é a que atrasa aluno. **O node fica verde, sem erro**, e você segue adiante com a string literal `{{ $json.email }}` correndo pelo fluxo. Você só descobre lá na frente, quando algo tenta usar aquilo como e-mail.

Regra: `{{ }}` é para **campos de node**. Code node é código.

### Armadilha 5 — dado de Webhook fica sob `.body`

Esta é a número um em fluxos com webhook, e a de 27/11 depende dela.

Quando uma requisição HTTP chega num Webhook, o n8n **não** entrega o corpo na raiz do item. Ele entrega o pacote inteiro da requisição:

```json
{
  "headers": { "content-type": "application/json", "...": "..." },
  "params":  {},
  "query":   {},
  "body":    { "email": "ana@ufg.br", "mensagem": "quero um ap de 3 quartos" }
}
```

Então:

```
{{ $json.email }}        ← undefined
{{ $json.body.email }}   ← certo
```

Sempre que um webhook parecer não receber nada, **abra o item e olhe a estrutura real** antes de mexer em qualquer outra coisa.

---

## 6. `$vars` e `$env` não existem aqui

Se você achar um tutorial na internet usando `$vars.alguma_coisa`, ele não vai funcionar nesta instância.

- **`$vars`** (a feature "Variables") é do plano Enterprise. Esta instância é Community Edition.
- **`$env`** (variáveis de ambiente do servidor) está bloqueado de propósito, por segurança. Um Code node executa código no servidor; se `$env` estivesse liberado, qualquer aluno poderia ler as variáveis de ambiente da máquina.

### O que usar no lugar

Um node **Edit Fields (Set)** no topo do fluxo, chamado `Config`, com a configuração que não é segredo:

```
projeto  = pdm-2026-2
dataset  = imoveis
bucket   = pdm-2026-2-dados
```

E daí para a frente, no fluxo inteiro:

```
{{ $('Config').first().json.projeto }}
```

Duas vantagens: a configuração fica **num lugar só** e **visível no canvas**, e trocar de ambiente é editar um node.

> **Segredo nunca vai no `Config`.** Chave de API, senha e token vão em **credencial** do n8n. A diferença é concreta: o que está no node sai junto quando você exporta o workflow em JSON. Se você commitar esse arquivo, sua chave está pública. O que está na credencial fica no servidor e não sai no export.

---

## 7. Exercícios

Escreva a expressão. As respostas estão no fim.

1. Um node **Ler Planilha** entrega itens com a chave `Nome completo`. Escreva a expressão que pega esse campo do item atual.

2. Um Webhook recebe `{"cliente": {"telefone": "62999999999"}}`. Escreva a expressão que pega o telefone.

3. Um node **Config** tem o campo `dataset`. Escreva a expressão que pega esse valor de qualquer ponto do fluxo, de forma determinística.

4. Um item tem `{"quartos": 0, "bairro": "Setor Bueno"}`. Escreva a expressão que devolve o número de quartos, usando `1` como padrão **apenas** se a chave não existir. Cuidado: `0` é um valor válido.

5. Um item vem do BigQuery com `{"listing": {"address": {"neighborhood": "Setor Oeste"}}}`. Escreva a expressão que pega o bairro.

---

<details>
<summary>Respostas</summary>

1. `{{ $json['Nome completo'] }}` — colchete, porque tem espaço.

2. `{{ $json.body.cliente.telefone }}` — o `.body` é obrigatório em webhook.

3. `{{ $('Config').first().json.dataset }}` — `.first()` e não `.item`, para não quebrar depois de um node de agregação.

4. `{{ $json.quartos ?? 1 }}` — tem que ser `??`. Com `||`, um imóvel de zero quartos viraria um imóvel de um quarto.

5. `{{ $json.listing.address.neighborhood }}` — o mesmo caminho que em 04/09 era `JSON_VALUE(listing, '$.address.neighborhood')`.

</details>
