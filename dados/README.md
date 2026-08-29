# O dataset — `aula-pdm.csv`

Anúncios reais de imóveis, coletados do GrupoZAP/VivaReal. **999 dos 1.000 anúncios são de Goiânia.**

## Onde está o dado

O arquivo completo **não está neste repositório**. Ele mora num bucket público do Cloud Storage:

```
gs://pdm-2026-gui/imoveis/aula-pdm.csv
```

Para baixar, ou só espiar no navegador:

```
https://storage.googleapis.com/pdm-2026-gui/imoveis/aula-pdm.csv
```

É leitura pública: não precisa de conta, de chave nem de permissão. **E você não precisa baixar** — o BigQuery lê direto do bucket, que é exatamente o que os scripts da aula fazem.

| | Completo (no bucket) | Amostra (neste repo) |
|---|---|---|
| Arquivo | `aula-pdm.csv` | `dados/amostra-100.csv` |
| Linhas | 1.000 | 100 |
| Tamanho | 14,6 MB | 1,3 MB |
| Colunas | 4 | 4 |
| Região | `us-central1` | — |

## Sobre a amostra

O `amostra-100.csv` é um **sorteio aleatório** de 100 dos 1.000 anúncios, com semente fixa — então é sempre o mesmo recorte para todo mundo. Ele existe para você abrir num editor, no pandas ou no Excel e ver a cara do dado sem baixar 14 MB.

**Não use a amostra para tirar conclusões numéricas.** Com 100 linhas, qualquer proporção que você medir tem margem de erro grande. Os números desta página, e os que aparecem nas queries da aula, vêm todos do arquivo completo.

> **Um aviso que vale a disciplina inteira:** se você fosse amostrar por conta própria pegando "as primeiras 100 linhas", ia se enganar feio. **O arquivo vem ordenado**, e os registros mais estranhos estão concentrados no começo: as 100 primeiras linhas têm **29%** de preços inflados, contra **2,9%** no arquivo inteiro — dez vezes mais.
>
> Amostra é sorteio, não é fatia. É por isso que o `amostra-100.csv` foi sorteado, e não cortado.

---

## Por que 4 colunas ocupam 14 MB

Porque **isto não é uma tabela.** É um CSV com JSON dentro.

| Coluna | Tipo | O que é |
|---|---|---|
| `id_anuncio` | string | identificador do anúncio |
| `data_atualizacao` | timestamp | última atualização do registro |
| `data_insercao` | timestamp | quando entrou na base |
| `listing` | **JSON** | o anúncio inteiro, aninhado, ~14 KB por linha |

Achatado, o `listing` tem **81 campos**. É exatamente o tipo de dado que você encontra na vida real quando puxa de uma API: aninhado, irregular, com listas dentro de objetos dentro de listas.

Abrir isso no Excel não vai funcionar. Abrir no pandas vai te dar uma coluna de string gigante. A camada Bronze → Silver existe justamente para resolver isso, e é o que a gente faz na aula de 04/09.

---

## Os campos que importam

Fora dos 81, estes são os que a gente usa:

| Caminho no JSON | Preenchido | Observação |
|---|---|---|
| `pricingInfos[].price` | 100% | o preço — vai ser o alvo do modelo |
| `pricingInfos[].businessType` | 100% | `SALE` ou `RENTAL` |
| `pricingInfos[].monthlyCondoFee` | 81% | condomínio |
| `pricingInfos[].yearlyIptu` | 69% | IPTU anual |
| `usableAreas[]` | 100% | área útil, em m² |
| `bedrooms[]` | 97% | lista de um elemento só |
| `bathrooms[]` | 98% | idem |
| `suites[]` | 90% | idem |
| `parkingSpaces[]` | 93% | idem |
| `address.neighborhood` | 100% | **100 bairros distintos** |
| `address.point.lat` / `.lon` | 62% | 38% só têm posição aproximada |
| `unitTypes[]` | 100% | CONDOMINIUM, HOME, APARTMENT, ... |
| `usageTypes[]` | 100% | RESIDENTIAL ou COMMERCIAL |
| `amenities[]` | 68% | lista de strings livres |
| `description` | 99,8% | texto livre, mediana de ~1.000 caracteres |
| `account.name` | 100% | 206 imobiliárias distintas |
| `createdAt` | 100% | data de **publicação do anúncio** |

Repare em duas coisas que vão te morder depois:

**`bedrooms` é uma lista, não um número.** Vem como `[3]`, não como `3`. Vários campos numéricos são assim. Se você fizer `SAFE_CAST` direto, vem `NULL`.

**`createdAt` é a data em que o anúncio foi publicado**, não a data em que o imóvel foi vendido. Isso tem consequência: não existe série temporal de vendas aqui. Se você estava pensando em previsão temporal para o trabalho, pense de novo.

---

## Sobre a qualidade dos dados

Este dataset **não foi limpo**. Ele está como veio.

Tem coisa errada aqui dentro — e não é pouca. Uma parte grande da aula de 04/09 é você encontrar essas coisas com SQL, com os seus próprios olhos, antes de treinar qualquer modelo. Por isso não está listado aqui o que está quebrado.

Se você quiser adiantar, o exercício é este:

```sql
-- rode isto e olhe para a distância entre a mediana e a média
SELECT
  COUNT(*)                                        AS anuncios,
  APPROX_QUANTILES(preco, 2)[OFFSET(1)]           AS mediana,
  AVG(preco)                                      AS media,
  STDDEV(preco)                                   AS desvio_padrao,
  MAX(preco)                                      AS maximo
FROM <sua_tabela_silver>;
```

Quando a média é o dobro da mediana e o desvio-padrão é maior que a média, o dado está te avisando de alguma coisa. Traga a sua conclusão para a aula.

---

## Dump completo

Os 1.000 anúncios do bucket já são um recorte: o dump original é bem maior e fica fora do repositório (`dados/dump-completo/` está no `.gitignore`). Os scripts SQL funcionam igual nos dois — só muda a tabela de origem.

---

## Perfilar o dataset você mesmo

Tem um perfilador em [`../ferramentas/perfilar_dataset.py`](../ferramentas/perfilar_dataset.py). Só biblioteca padrão do Python, sem pandas, roda em segundos:

```bash
# na amostra que veio no clone
python3 ferramentas/perfilar_dataset.py dados/amostra-100.csv

# ou no arquivo completo, depois de baixar do bucket
curl -O https://storage.googleapis.com/pdm-2026-gui/imoveis/aula-pdm.csv
python3 ferramentas/perfilar_dataset.py aula-pdm.csv
```

Ele achata o JSON, conta preenchimento por campo, detecta colunas constantes e sinaliza campos suspeitos. Use antes de decidir quais features entram no seu modelo.
