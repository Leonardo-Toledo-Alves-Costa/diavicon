#!/usr/bin/env python3
"""Aplica as mudanças LGPD num repositório Flutter da DIAVICON.

Uso: python3 aplicar_lgpd.py <raiz_do_repo> [--dry]

Preserva CRLF. Imprime o que mudou em cada arquivo e avisos para revisão.
"""
import os
import re
import sys

RAIZ = sys.argv[1]
DRY = '--dry' in sys.argv
LIB = os.path.join(RAIZ, 'lib')

NOVOS = {  # arquivos novos: não passam pelas substituições
    'lib/core/services/storage_urls.dart',
    'lib/core/widgets/imagem_storage.dart',
    'lib/core/services/foto_metadados.dart',
}

IMP_IMG = "import 'package:diavicon/core/widgets/imagem_storage.dart';"
IMP_URL = "import 'package:diavicon/core/services/storage_urls.dart';"
IMP_META = "import 'package:diavicon/core/services/foto_metadados.dart';"

avisos = []
resumo = {}


def ler(p):
    with open(p, 'rb') as f:
        b = f.read()
    t = b.decode('utf-8')
    crlf = '\r\n' in t
    return t.replace('\r\n', '\n'), crlf


def gravar(p, t, crlf):
    if crlf:
        t = t.replace('\n', '\r\n')
    if not DRY:
        with open(p, 'wb') as f:
            f.write(t.encode('utf-8'))


def add_import(t, imp, rel):
    if imp in t:
        return t
    if re.search(r'^part of ', t, re.M):
        avisos.append(f'{rel}: é "part of" — import {imp} precisa ir no arquivo principal')
        return t
    m = re.search(r'^import .*?;\n', t, re.M | re.S)
    if not m:
        return imp + '\n' + t
    return t[:m.start()] + imp + '\n' + t[m.start():]


def conta(rel, chave, n=1):
    resumo.setdefault(rel, {}).setdefault(chave, 0)
    resumo[rel][chave] += n


HTML_ABRIR = re.compile(r'(relatorio_[a-z_]+_screen|relatorios_item_screen|relatorio_rdo_screen|meus_relatorios_rdo_screen)\.dart$')
ARG = r'((?:[^()]|\([^()]*\))+)'

for base, _, arquivos in os.walk(LIB):
    for nome in arquivos:
        if not nome.endswith('.dart'):
            continue
        p = os.path.join(base, nome)
        rel = os.path.relpath(p, RAIZ).replace(os.sep, '/')
        if rel in NOVOS:
            continue
        t, crlf = ler(p)
        o = t

        # 1. Imagens de rede -> provider com link temporário
        n1 = len(re.findall(r'(?<![\w.])Image\.network\(', t))
        t = re.sub(r'(?<![\w.])Image\.network\(', 'ImagemStorage.network(', t)
        n2 = len(re.findall(r'(?<![\w])NetworkImage\(', t))
        t = re.sub(r'(?<![\w])NetworkImage\(', 'StorageNetworkImage(', t)
        if n1 or n2:
            conta(rel, 'imagens', n1 + n2)
            t = add_import(t, IMP_IMG, rel)
            if 'webHtmlElementStrategy' in t:
                avisos.append(f'{rel}: usa webHtmlElementStrategy (não suportado por ImagemStorage.network)')

        # 2. Downloads http.get(Uri.parse(x)) de URLs do Storage
        if '/reports/' not in rel or 'carbonatacao_report_service' in rel or 'ultrassom_mapa_calor' in rel:
            alvo = 'StorageUrls.baixarHtml' if HTML_ABRIR.search(rel) else 'StorageUrls.baixar'
            padrao = re.compile(r'http\.get\(Uri\.parse\(' + ARG + r'\)\)')
            def troca(m):
                arg = m.group(1).strip()
                if arg.startswith(("'", '"')):
                    return m.group(0)
                return f'{alvo}({arg})'
            t2 = padrao.sub(troca, t)
            if t2 != t:
                conta(rel, alvo, 1)
                t = t2

        # 3. PDF via InternetFile
        if 'InternetFile.get(widget.url)' in t:
            t = t.replace('InternetFile.get(widget.url)', 'StorageUrls.assinar(widget.url).then((u) => InternetFile.get(u))')
            conta(rel, 'InternetFile', 1)

        # 4. HTML -> PDF: imagens com link temporário antes de converter
        padrao_pdf = re.compile(r'(convertFromHtmlContent\(\s*content:\s*)([A-Za-z_]\w*)(\s*[,)])')
        t2 = padrao_pdf.sub(lambda m: f'{m.group(1)}await StorageUrls.assinarUrlsNoTexto({m.group(2)}){m.group(3)}', t)
        if t2 != t:
            conta(rel, 'html_pdf', len(padrao_pdf.findall(t)))
            t = t2

        # 5. Anexos do feed abertos no navegador
        if rel.endswith('feed_educacao/screens/feed_screen.dart') and 'Uri.parse(parsedUrl),' in t:
            t = t.replace('Uri.parse(parsedUrl),', 'Uri.parse(await StorageUrls.assinar(parsedUrl)),', 1)
            conta(rel, 'launch_anexo', 1)

        # 6. Uploads sem metadados (EXIF) — fora de relatórios/PDF
        if '/reports/' not in rel and not rel.endswith('gerar_relatorio_screen.dart'):
            n_up = len(re.findall(r'\.upload\(', t))
            n_bin = len(re.findall(r'\.uploadBinary\(', t))
            if n_up or n_bin:
                t = re.sub(r'\.uploadBinary\(', '.uploadBinarySemMetadados(', t)
                t = re.sub(r'\.upload\(', '.uploadSemMetadados(', t)
                conta(rel, 'upload_sem_exif', n_up + n_bin)
                t = add_import(t, IMP_META, rel)

        if 'StorageUrls.' in t and 'StorageUrls.' not in o:
            t = add_import(t, IMP_URL, rel)

        if t != o:
            gravar(p, t, crlf)

for rel in sorted(resumo):
    print(rel, resumo[rel])
print('arquivos alterados:', len(resumo))
for a in avisos:
    print('AVISO:', a)
