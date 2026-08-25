#!/usr/bin/env python3
"""
Perfilador de dataset para preparacao de aula de BigQuery ML.

Uso:
    python3 perfilar_dataset.py caminho/do/arquivo.csv

Responde, em um passe, as perguntas que definem o material da aula:

  1. Que colunas existem, de que tipo, com que cardinalidade?
  2. Ha coluna CONSTANTE? (feature inerte, ruido de schema)
  3. Ha VAZAMENTO ARITMETICO? isto e, alguma coluna que e o produto,
     a soma ou a diferenca exata de outras duas. E o achado que
     sustenta o bloco "A armadilha" da aula.
  4. Qual coluna serve de alvo de REGRESSAO? de CLASSIFICACAO?
  5. Ha coluna de DATA utilizavel em serie temporal (ARIMA_PLUS)?
  6. Ha coluna de TEXTO LIVRE utilizavel no exemplo de NLP?

Sem dependencia externa: roda com Python 3 puro.
"""

import csv
import sys
import math
import statistics
from collections import Counter, defaultdict

# ---------------------------------------------------------------- parametros
AMOSTRA_HUNT = 20_000      # linhas usadas na cacada de vazamento
TOL_REL = 1e-6             # tolerancia relativa para considerar "igual"
MAX_CATEGORIAS = 60        # acima disso, nao e alvo bom de classificacao
MIN_CHARS_TEXTO = 40       # media de caracteres para ser "texto livre"


def num(v):
    """Converte para float aceitando formato brasileiro. None se nao for numero."""
    if v is None:
        return None
    s = v.strip()
    if s == "" or s.lower() in {"na", "n/a", "null", "none", "-"}:
        return None
    # 1.234.567,89 -> 1234567.89   |   1,5 -> 1.5
    if "," in s and "." in s:
        s = s.replace(".", "").replace(",", ".")
    elif "," in s and s.count(",") == 1:
        s = s.replace(",", ".")
    s = s.replace("R$", "").replace("%", "").replace(" ", "")
    try:
        return float(s)
    except ValueError:
        return None


def parece_data(v):
    if not v:
        return False
    s = v.strip()[:10]
    if len(s) != 10:
        return False
    return (s[4] in "-/" and s[7] in "-/") or (s[2] in "-/" and s[5] in "-/")


def quase_igual(a, b):
    if a is None or b is None:
        return False
    if not (math.isfinite(a) and math.isfinite(b)):
        return False
    escala = max(abs(a), abs(b), 1.0)
    return abs(a - b) <= TOL_REL * escala * 1000  # tolerante a arredondamento


def sniff(caminho):
    with open(caminho, newline="", encoding="utf-8", errors="replace") as f:
        amostra = f.read(64 * 1024)
    try:
        return csv.Sniffer().sniff(amostra, delimiters=",;\t|").delimiter
    except csv.Error:
        return ","


def main(caminho):
    delim = sniff(caminho)
    print(f"\n{'='*70}\nPERFIL: {caminho}\nseparador detectado: {delim!r}\n{'='*70}")

    with open(caminho, newline="", encoding="utf-8", errors="replace") as f:
        leitor = csv.DictReader(f, delimiter=delim)
        colunas = leitor.fieldnames or []

        n = 0
        vazios = Counter()
        distintos = defaultdict(set)          # capado para nao estourar memoria
        estourou = set()
        numericos = defaultdict(list)
        nao_numerico = set()
        datas = defaultdict(list)
        comprimento_texto = defaultdict(list)
        amostra_linhas = []

        for linha in leitor:
            n += 1
            for c in colunas:
                v = linha.get(c)
                if v is None or v.strip() == "":
                    vazios[c] += 1
                    continue
                if c not in estourou:
                    distintos[c].add(v)
                    if len(distintos[c]) > 5000:
                        estourou.add(c)
                        distintos[c] = set()
                x = num(v)
                if x is None:
                    nao_numerico.add(c)
                    comprimento_texto[c].append(len(v))
                    if parece_data(v):
                        datas[c].append(v.strip()[:10])
                elif len(numericos[c]) < AMOSTRA_HUNT:
                    numericos[c].append(x)
            if len(amostra_linhas) < AMOSTRA_HUNT:
                amostra_linhas.append(linha)

    print(f"\nlinhas: {n:,}".replace(",", "."))
    print(f"colunas: {len(colunas)}\n")

    # ------------------------------------------------------------ 1. colunas
    print("-" * 70)
    print("COLUNAS")
    print("-" * 70)
    print(f"{'coluna':<28} {'tipo':<10} {'distintos':>10} {'vazios':>8}")
    num_puras, cat_puras, texto_livre, col_datas, constantes = [], [], [], [], []

    for c in colunas:
        card = "5000+" if c in estourou else str(len(distintos[c]))
        eh_num = c not in nao_numerico and len(numericos[c]) > 0
        if c in datas and len(datas[c]) > n * 0.5:
            tipo = "data"
            col_datas.append(c)
        elif eh_num:
            tipo = "numero"
            num_puras.append(c)
        else:
            media_len = statistics.mean(comprimento_texto[c]) if comprimento_texto[c] else 0
            if media_len >= MIN_CHARS_TEXTO:
                tipo = "texto"
                texto_livre.append((c, media_len))
            else:
                tipo = "categoria"
                cat_puras.append(c)
        if c not in estourou and len(distintos[c]) <= 1:
            constantes.append(c)
        print(f"{c[:28]:<28} {tipo:<10} {card:>10} {vazios[c]:>8}")

    # -------------------------------------------------- 2. colunas constantes
    print("\n" + "-" * 70)
    print("COLUNAS CONSTANTES  (feature inerte: ocupa schema, nao informa nada)")
    print("-" * 70)
    if constantes:
        for c in constantes:
            valor = next(iter(distintos[c])) if distintos[c] else "(vazia)"
            print(f"  !! {c}  = sempre {valor!r}")
        print("\n  -> material de aula: mostrar que estao no schema e nao servem.")
    else:
        print("  nenhuma. (nesse dataset o bloco de 'feature inerte' nao se aplica)")

    # ------------------------------------------------ 3. vazamento aritmetico
    print("\n" + "-" * 70)
    print("CACADA DE VAZAMENTO ARITMETICO")
    print("-" * 70)
    print(f"  testando combinacoes entre {len(num_puras)} colunas numericas...")

    cols = [c for c in num_puras if len(numericos[c]) >= 50]
    tam = min([len(numericos[c]) for c in cols], default=0)
    achados = []

    for alvo in cols:
        A = numericos[alvo][:tam]
        for i, a in enumerate(cols):
            if a == alvo:
                continue
            X = numericos[a][:tam]
            # a ~ alvo  (duplicata / escala)
            if all(quase_igual(x, t) for x, t in zip(X[:500], A[:500])):
                achados.append((alvo, f"{a}", "identico"))
            for b in cols[i + 1:]:
                if b == alvo:
                    continue
                Y = numericos[b][:tam]
                for op, fn in (("*", lambda p, q: p * q),
                               ("+", lambda p, q: p + q),
                               ("-", lambda p, q: p - q)):
                    try:
                        if all(quase_igual(fn(x, y), t)
                               for x, y, t in zip(X[:500], Y[:500], A[:500])):
                            ok = sum(1 for x, y, t in zip(X, Y, A)
                                     if quase_igual(fn(x, y), t))
                            achados.append((alvo, f"{a} {op} {b}", f"{100*ok/tam:.2f}%"))
                    except Exception:
                        pass

    if achados:
        for alvo, formula, pct in achados:
            print(f"  !! VAZAMENTO  {alvo}  =  {formula}   ({pct} das linhas)")
        print("\n  -> ESTE e o bloco 'A armadilha'. Treine um modelo prevendo essa")
        print("     coluna usando as colunas da formula: da R2 = 1,000.")
    else:
        print("  nenhuma identidade exata encontrada.")
        print("  -> o bloco 'A armadilha' precisa de outro gancho neste dataset.")
        print("     Alternativas: coluna preenchida so DEPOIS do evento (ex: data de")
        print("     venda para prever se vende), ou id que codifica o alvo.")

    # ------------------------------------------- 4. candidatos a alvo de aula
    print("\n" + "-" * 70)
    print("CANDIDATOS A ALVO")
    print("-" * 70)

    print("\n  REGRESSAO (prever um numero) - preferir o de maior dispersao:")
    for c in sorted(num_puras, key=lambda k: -len(numericos[k]))[:12]:
        vals = [v for v in numericos[c] if math.isfinite(v)]
        if len(vals) < 10:
            continue
        med = statistics.mean(vals)
        dp = statistics.pstdev(vals)
        cv = dp / med if med else 0
        marca = "  <-- bom alvo" if 0.3 < cv < 5 and len(set(vals)) > 100 else ""
        print(f"    {c[:26]:<26} media={med:>12,.2f}  desvio={dp:>12,.2f}{marca}")
    print("\n    (o desvio e o ERRO DO CHUTE BURRO: o modelo tem que ganhar dele)")

    print("\n  CLASSIFICACAO (prever categoria) - poucas categorias, bem povoadas:")
    achou_cls = False
    for c in cat_puras:
        if c in estourou:
            continue
        k = len(distintos[c])
        if 2 <= k <= MAX_CATEGORIAS:
            achou_cls = True
            print(f"    {c[:26]:<26} {k} categorias")
    if not achou_cls:
        print("    nenhuma direta. Alternativa: criar alvo binario a partir de um")
        print("    numero (ex: 'esta acima do percentil 90?'), como fizemos no ERP.")

    print("\n  SERIE TEMPORAL (ARIMA_PLUS):")
    if col_datas:
        for c in col_datas:
            ds = sorted(datas[c])
            meses = len({d[:7] for d in ds})
            ok = "  <-- da para ARIMA" if meses >= 24 else "  (poucos meses)"
            print(f"    {c[:26]:<26} {ds[0]} -> {ds[-1]}   {meses} meses{ok}")
    else:
        print("    nenhuma coluna de data detectada.")
        print("    -> o bloco 'previsao de vendas' precisa de outra fonte.")

    print("\n  NLP (texto livre):")
    if texto_livre:
        for c, ml in sorted(texto_livre, key=lambda t: -t[1]):
            print(f"    {c[:26]:<26} media de {ml:.0f} caracteres  <-- candidato")
        print("\n    -> se houver texto AQUI, o exemplo de NLP sai do PROPRIO dataset")
        print("       e a aula vira uma historia so (nao precisa do B2W-Reviews01).")
    else:
        print("    nenhuma coluna de texto livre.")

    # ------------------------------------------------------------- 5. amostra
    print("\n" + "-" * 70)
    print("AMOSTRA (3 primeiras linhas)")
    print("-" * 70)
    for linha in amostra_linhas[:3]:
        print()
        for c in colunas:
            v = (linha.get(c) or "")[:70]
            print(f"    {c[:26]:<26} {v}")

    print("\n" + "=" * 70)
    print("PROXIMO PASSO: usar este relatorio para fixar os alvos dos scripts")
    print("01_regressao.sql, 02_classificacao.sql, 03_previsao, 04_nlp e 05_armadilha")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
