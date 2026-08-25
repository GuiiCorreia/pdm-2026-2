# O dataset — `aula-pdm.csv`

Anúncios reais de imóveis, coletados do GrupoZAP/VivaReal. **999 dos 1.000 anúncios são de Goiânia.**

| | |
|---|---|
| Arquivo | `aula-pdm.csv` |
| Tamanho | 14,6 MB |
| Linhas | 1.000 |
| Colunas | 4 |

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

O arquivo versionado aqui tem 1.000 linhas — é a amostra, e serve para tudo que a gente faz em sala. O dump completo é maior e fica fora do repositório (`dados/dump-completo/` está no `.gitignore`). Os scripts SQL funcionam igual nos dois: só muda a tabela de origem.

---

## Perfilar o dataset você mesmo

Tem um perfilador em [`../ferramentas/perfilar_dataset.py`](../ferramentas/perfilar_dataset.py). Só biblioteca padrão do Python, sem pandas, roda em segundos:

```bash
python3 ferramentas/perfilar_dataset.py dados/aula-pdm.csv
```

Ele achata o JSON, conta preenchimento por campo, detecta colunas constantes e sinaliza campos suspeitos. Use antes de decidir quais features entram no seu modelo.
