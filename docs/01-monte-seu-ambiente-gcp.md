# Monte o seu ambiente no Google Cloud

> Faça isto **uma vez**, em casa, com calma, **antes da primeira aula prática**. Leva algo entre 20 e 40 minutos, quase tudo esperando tela carregar.
>
> No fim você vai ter: um projeto seu, um bucket seu, um dataset seu, uma tabela apontando para o dado, uma chave do Gemini e um alerta de orçamento. Tudo na sua conta, tudo seu.

---

## Antes de tudo: você não vai gastar dinheiro

Essa é a primeira dúvida de todo mundo, então vamos resolver ela agora.

O Google Cloud tem duas coisas diferentes que costumam ser confundidas:

| | O que é | Vale por quanto tempo |
|---|---|---|
| **Free tier** | uma cota gratuita **permanente**, todo mês, para sempre | sempre |
| **Trial** | US$ 300 de crédito para você experimentar serviços pagos | 90 dias |

**Tudo que a gente faz nesta disciplina cabe no free tier.** O crédito de US$ 300 é rede de segurança, não é o combustível da aula.

O que o free tier te dá, e que é o que a gente usa:

| Serviço | Cota gratuita por mês |
|---|---|
| BigQuery — consulta | **1 TiB** processado |
| BigQuery — armazenamento | **10 GiB** ativo |
| Cloud Storage | **5 GB** armazenados, 5.000 operações de escrita, 50.000 de leitura |

Para você ter dimensão: o dataset da disciplina tem **14,6 MB**. Você caberia nele umas 350 vezes só no armazenamento, e teria que rodar as queries da aula dezenas de milhares de vezes para encostar no 1 TiB.

Treinar modelo com `CREATE MODEL` entra na mesma conta de query. Não tem cobrança separada por "treinar".

> **O trial exige cartão de crédito.** O Google faz uma autorização temporária de US$ 0 a 1 para validar o cartão, e ela é estornada. **Não existe cobrança automática quando o trial acaba** — a conta simplesmente para de funcionar e você tem 30 dias para reativar antes de os recursos serem apagados.
>
> **Se você não tem cartão**, fala comigo ou com o Prof. Sávio **antes** da primeira aula. Existe crédito educacional, mas ele leva alguns dias úteis para sair, então não deixe para a véspera.

---

## Passo 1 — Criar o projeto

No Google Cloud tudo vive dentro de um **projeto**. É a caixa que separa o seu ambiente do ambiente dos outros: recursos, permissões e cobrança são todos por projeto.

1. Entre em [console.cloud.google.com](https://console.cloud.google.com) com a sua conta Google
2. No topo da tela, clique no seletor de projeto (fica ao lado do logo "Google Cloud")
3. **Novo projeto** (*New project*)
4. Nome: `PDM 2026-2` — ou o que você quiser, isso é só rótulo
5. Anote o **ID do projeto**

O ID é diferente do nome. Se o nome é `PDM 2026-2`, o ID vem como algo tipo `pdm-2026-2-471203`. **É o ID que vai em todo lugar**, nos scripts SQL e no `.env`. O nome ninguém usa.

> Guarde o ID agora, num bloco de notas. Você vai precisar dele umas seis vezes nas próximas duas horas.

---

## Passo 2 — Ativar o faturamento

Você precisa de uma conta de faturamento vinculada ao projeto. Sem ela, o Cloud Storage não funciona — e o BigQuery fica limitado.

1. Menu de navegação (☰) → **Faturamento** (*Billing*)
2. Se você nunca usou o Google Cloud, vai aparecer a oferta do trial de US$ 300 — aceite
3. Se você já tem uma conta de faturamento, vincule ela a este projeto

**Confira que ficou vinculado:** a página de Faturamento tem que mostrar o nome de uma conta, e não um convite para criar uma.

---

## Passo 3 — Ligar as APIs

No Google Cloud, cada serviço precisa ser ligado por projeto. Ligar não custa nada — você só paga o que usar, e o que a gente vai usar está no free tier.

Menu de navegação → **APIs e serviços** → **Biblioteca** (*Library*). Busque e clique em **Ativar** em cada uma:

- `BigQuery API`
- `Cloud Storage`
- `BigQuery Connection API` — necessária no bloco de IA generativa, no fim da aula de 04/09

Se alguma já aparecer como "Gerenciar" em vez de "Ativar", é porque já está ligada. Segue o jogo.

---

## Passo 4 — O dado da aula já está num bucket

Você **não precisa subir o `.csv` em lugar nenhum**. O dataset da disciplina já está publicado num bucket público:

```
gs://pdm-2026-2-dados/imoveis/aula-pdm.csv
```

É leitura pública. Não precisa de senha, de chave, nem de permissão. Se quiser conferir agora, cole no navegador:

```
https://storage.googleapis.com/pdm-2026-2-dados/imoveis/aula-pdm.csv
```

O download começa. São 14,6 MB.

> **Por que assim.** Se cada um subisse o próprio arquivo, a primeira aula viraria uma hora de "meu caminho está errado" e "meu bucket está em outra região". O dado é o mesmo para todo mundo — então ele mora num lugar só. O que é **seu** é o processamento: o projeto, o dataset, as tabelas, os modelos. É lá que o trabalho acontece.

### A região — a única escolha irreversível do guia

O bucket da disciplina está em **`us-east1`**.

Para o BigQuery ler um arquivo do Cloud Storage, **o bucket e o dataset precisam estar no mesmo local**. Como o bucket está em `us-east1`, o **seu dataset também tem que estar em `us-east1`**. E o local do dataset é **imutável**: para mudar, só apagando e criando de novo.

Se você errar isso, o erro que aparece daqui a duas telas não vai mencionar região nenhuma.

> `us-east1` também é uma das três regiões onde existe a camada Always Free do Cloud Storage (as outras são `us-west1` e `us-central1`) — o que importa quando você criar o seu próprio bucket, no passo 4b.

### Passo 4b — O seu bucket (opcional agora, obrigatório em 27/11)

Para a aula de 04/09 você não precisa de bucket. Mas na aula de **27/11** o agente vai guardar fotos de imóveis no Cloud Storage, e aí o bucket é seu. Criar leva um minuto — vale fazer junto:

1. Menu de navegação → **Cloud Storage** → **Buckets** → **Criar**
2. **Nome**: precisa ser único no mundo inteiro. Use o seu ID de projeto como prefixo, por exemplo `pdm-2026-2-471203-dados`
3. **Onde armazenar**: `Region` → **`us-east1`** ← a mesma de tudo
4. **Classe**: `Standard`
5. Controle de acesso: deixe o padrão (**uniforme**, com acesso público bloqueado)
6. Criar

---

## Passo 5 — Criar o dataset no BigQuery

O dataset é o equivalente a um "banco" dentro do BigQuery — a pasta onde ficam as tabelas e, depois, os modelos.

1. Menu de navegação → **BigQuery**
2. No painel Explorer à esquerda, ache o seu projeto, clique nos três pontinhos → **Criar conjunto de dados** (*Create dataset*)
3. **ID do conjunto de dados**: `pdm_2026_2`
4. **Tipo de local**: `Region` → **`us-east1`** ← a mesma do bucket da disciplina
5. Criar

> **Underscore, não hífen.** Nome de dataset no BigQuery aceita letras, números e `_`. Se você digitar `pdm-2026-2` ele recusa.

**Confira antes de seguir:** clique no dataset e olhe o painel de detalhes. O campo `Data location` tem que dizer `us-east1`. Se disser outra coisa, apague e crie de novo **agora**.

---

## Passo 6 — Testar

Este é o teste que prova que o seu dataset consegue ler o bucket da disciplina. Abra uma aba de query no BigQuery e rode, trocando só os **dois** placeholders:

```sql
CREATE OR REPLACE EXTERNAL TABLE `SEU_PROJETO.SEU_DATASET.teste_ambiente`
OPTIONS (
  format = 'CSV',
  uris = ['gs://pdm-2026-2-dados/imoveis/aula-pdm.csv'],
  skip_leading_rows = 1
);

SELECT COUNT(*) AS linhas
FROM `SEU_PROJETO.SEU_DATASET.teste_ambiente`;
```

**Resultado esperado: `1000`.**

| Se deu | O que é |
|---|---|
| `1000` | ambiente montado. Pode apagar a `teste_ambiente`, ela não serve para mais nada |
| erro de localização / *dataset and bucket must be in the same location* | seu dataset não está em `us-east1`. Apague e refaça o passo 5 |
| `Access Denied` | a API do Cloud Storage não foi ativada, ou o faturamento não está vinculado |
| `Not found: URIs` | o caminho foi digitado errado. Copie e cole do bloco acima |
| número diferente de 1000 | você esqueceu o `skip_leading_rows = 1` |

**Uma External Table não copia o arquivo.** Ela é um ponteiro: o dado continua no bucket e o BigQuery lê de lá na hora da query. É por isso que criar essa tabela é instantâneo mesmo com 14 MB — e é o conceito que abre a aula de 04/09.

---

## Passo 7 — Chave da API do Gemini

Usada no bloco de IA generativa de 04/09 e nas aulas de n8n.

1. Vá em [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. **Create API key**
3. Quando ele perguntar o projeto, **escolha o projeto que você criou no passo 1**
4. Copie a chave

O Gemini tem uma camada gratuita própria, que **não exige faturamento** e é generosa para o que a gente faz. Os limites exatos variam por conta e ficam visíveis em [aistudio.google.com/rate-limit](https://aistudio.google.com/rate-limit).

> **Essa chave vai direto para o `.env`, nunca para dentro de um arquivo que você commita.** Uma chave de API vazada num repositório público é encontrada por robô em minutos — isso é literal, existem bots que varrem o GitHub em tempo real procurando exatamente isso.

---

## Passo 8 — Alerta de orçamento

Rede de segurança. Custa nada e leva dois minutos.

1. Menu → **Faturamento** → **Orçamentos e alertas** (*Budgets & alerts*) → **Criar orçamento**
2. Nome: `alerta-pdm`
3. Escopo: só o projeto `PDM 2026-2`
4. Valor: **US$ 5**
5. Deixe os limites padrão (50%, 90%, 100%)

**O alerta avisa, ele não bloqueia.** Se algo disparar gasto, o Google manda e-mail — não desliga nada sozinho. Por isso o valor baixo: com US$ 5 você recebe o aviso enquanto ainda são centavos, e tem tempo de ir olhar o que aconteceu.

Se você receber um e-mail desse durante a disciplina, **me avise**. Provavelmente é uma query que ficou rodando em loop ou um recurso esquecido ligado, e é conteúdo bom para a turma inteira.

---

## Passo 9 — Preencher o `.env`

De volta ao repositório clonado:

```bash
cp .env.example .env
```

Abra o `.env` e preencha com o que você anotou nos passos anteriores. O `.env` está no `.gitignore` — ele nunca vai para o repositório.

```bash
# antes de publicar qualquer coisa, confira:
git status          # o .env NÃO pode aparecer aqui
```

---

## Checklist final

Antes da aula de 04/09, você tem que conseguir marcar todos:

- [ ] Projeto criado e **ID anotado**
- [ ] Faturamento vinculado ao projeto
- [ ] BigQuery API, Cloud Storage e BigQuery Connection API ativadas
- [ ] Dataset `pdm_2026_2` em **`us-east1`** (a mesma região do bucket da disciplina)
- [ ] O teste do passo 6 retornou **1000**
- [ ] Chave do Gemini criada e colada no `.env`
- [ ] Alerta de orçamento de US$ 5 configurado
- [ ] `.env` preenchido e **invisível** no `git status`

---

## Se travar

Traga o **erro exato** — mensagem completa, print, o que for — para a aula ou para o canal da disciplina. Não traga "deu erro".

Metade dos problemas de Cloud se resolve lendo a mensagem inteira até o fim: ela quase sempre diz qual recurso, qual permissão e qual projeto. A outra metade é região errada.

---

*Cotas e condições consultadas na documentação oficial do Google Cloud em 25/08/2026. Valores de free tier mudam com o tempo — se algo aqui divergir do que o console te mostrar, o console está certo e eu quero saber.*
