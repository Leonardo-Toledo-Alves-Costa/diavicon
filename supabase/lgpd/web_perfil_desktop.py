#!/usr/bin/env python3
"""Web app: telas do Perfil ganham layout desktop (PerfilMolduraDesktop).

Uso: python3 web_perfil_desktop.py <raiz_web_app>

Para cada tela, o conteúdo (a Column dentro do SingleChildScrollView) vira
uma função local `conteudo(bool desktop)` no build; no celular o layout
original continua igual, e com largura >= 600 a mesma Column vai para a
moldura desktop (menu lateral + painel), sem o título duplicado.
"""
import os
import re
import sys

RAIZ = sys.argv[1]
IMPORTS = [
    "import 'package:diavicon/core/constants/app_breakpoints.dart';",
    "import 'package:diavicon/features/home/widgets/perfil_moldura_desktop.dart';",
]

TELAS = [
    # arquivo, seção, subtítulo, regex do título a esconder no desktop, usa Form
    ('perfil_dados_screen.dart', 'dados', 'Informações pessoais, endereço, formação e redes sociais.',
     r"const Text\(\s*'Perfil',", True),
    ('perfil_minha_conta_screen.dart', 'conta', 'Dados de acesso, troca de senha e exclusão da conta.',
     r"const Center\(\s*child:\s*Text\(\s*'Minha conta',", False),
    ('perfil_notificacoes_screen.dart', 'notificacoes', 'Como e quando a DIAVICON fala com você.',
     r"const Center\(\s*child:\s*Text\(\s*'Notificações',", False),
    ('perfil_minha_privacidade_screen.dart', 'privacidade', 'Visibilidade do perfil, uso dos seus dados e cópia dos seus dados.',
     r"const Center\(\s*child:\s*Text\(\s*'Privacidade',", False),
    ('perfil_central_ajuda_screen.dart', 'ajuda', 'Documentos legais, licenças e suporte.',
     r"const Center\(\s*child:\s*Text\(\s*'Central de ajuda',", False),
]


def fim_string(t, i):
    """t[i] abre uma string ('/"). Devolve o índice logo após o fechamento,
    tratando escapes e interpolação ${...} com aninhamento."""
    q = t[i]
    triplo = t[i:i + 3] == q * 3
    fecha = q * 3 if triplo else q
    raw = i > 0 and t[i - 1] == 'r'
    j = i + (3 if triplo else 1)
    while j < len(t):
        if not raw and t[j] == '\\':
            j += 2
            continue
        if t.startswith(fecha, j):
            return j + len(fecha)
        if not raw and t.startswith('${', j):
            j = fim_bloco(t, j + 1, '{', '}')
            continue
        j += 1
    raise ValueError('string sem fim')


def fim_bloco(t, i, abre, fecha):
    """t[i] == abre. Devolve o índice logo após o fechamento correspondente,
    ignorando o conteúdo de strings e comentários."""
    prof = 0
    j = i
    while j < len(t):
        c = t[j]
        if c in "'\"":
            j = fim_string(t, j)
            continue
        if t.startswith('//', j):
            j = t.index('\n', j)
            continue
        if t.startswith('/*', j):
            j = t.index('*/', j) + 2
            continue
        if c == abre:
            prof += 1
        elif c == fecha:
            prof -= 1
            if prof == 0:
                return j + 1
        j += 1
    raise ValueError('bloco sem fim')


for nome, secao, subtitulo, rx_titulo, usa_form in TELAS:
    p = os.path.join(RAIZ, 'lib/features/home/screens', nome)
    t = open(p, 'rb').read().decode('utf-8')
    crlf = '\r\n' in t
    t = t.replace('\r\n', '\n')
    if 'PerfilMolduraDesktop(' in t:
        print(nome, ': já aplicado')
        continue

    ib = t.index('Widget build(BuildContext context')
    ir = t.index('    return Scaffold(', ib)
    isc = t.index('SingleChildScrollView(', ir)
    m = re.compile(r'child:\s*Column\(').search(t, isc)
    ini_col = m.start() + len('child: ') if t[m.start():m.start() + 7] == 'child: ' else m.start() + t[m.start():].index('Column(')
    ini_col = t.index('Column(', m.start())
    fim_col = fim_bloco(t, ini_col + len('Column'), '(', ')')
    coluna = t[ini_col:fim_col]

    coluna_flag, n = re.subn(rx_titulo, lambda mm: 'if (!desktop) ' + mm.group(0), coluna, count=1)
    if n != 1:
        print(nome, ': AVISO título não encontrado; o desktop mostra o título duas vezes')

    filho_desktop = 'Form(key: _formKey, child: conteudo(true))' if usa_form else 'conteudo(true)'
    bloco = (
        '    Widget conteudo(bool desktop) => ' + coluna_flag + ';\n'
        '    if (!context.isMobile) {\n'
        '      return PerfilMolduraDesktop(\n'
        f'        secao: PerfilSecao.{secao},\n'
        f"        subtitulo: '{subtitulo}',\n"
        f'        child: {filho_desktop},\n'
        '      );\n'
        '    }\n'
    )
    t = t[:ini_col] + 'conteudo(false)' + t[fim_col:]
    t = t[:ir] + bloco + t[ir:]

    for imp in IMPORTS:
        if imp not in t:
            mi = re.search(r'^import .*?;\n', t, re.M)
            t = t[:mi.start()] + imp + '\n' + t[mi.start():]

    open(p, 'wb').write((t.replace('\n', '\r\n') if crlf else t).encode('utf-8'))
    print(nome, ': ok')
