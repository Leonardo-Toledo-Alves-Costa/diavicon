import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/planos/screens/meu_plano_screen.dart' show kEmailComercial;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pop-up que aparece ao tocar em "Cadastre-se", antes do cadastro.
///
/// Só quem vai abrir uma empresa nova segue para o cadastro. Quem trabalha
/// numa empresa que já usa a DIAVICON recebe o convite do gestor dela; quem
/// é estudante ou professor (sem CNPJ) pede o acesso acadêmico por e-mail à
/// equipe DIAVICON, que libera manualmente.
Future<void> abrirBoasVindasCadastro(BuildContext context) async {
  final escolha = await showDialog<_CasoCadastro>(
    context: context,
    builder: (_) => const _DialogoBoasVindas(),
  );
  if (escolha == null || !context.mounted) return;

  switch (escolha) {
    case _CasoCadastro.empresaJaCadastrada:
      await _avisoEmpresaJaCadastrada(context);
    case _CasoCadastro.academico:
      await _acessoAcademico(context);
    case _CasoCadastro.novaEmpresa:
      context.push('/register');
  }
}

enum _CasoCadastro { empresaJaCadastrada, academico, novaEmpresa }

// ---------------------------------------------------------------------------
// Moldura comum dos pop-ups
// ---------------------------------------------------------------------------
class _Moldura extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final List<Widget> acoes;

  const _Moldura({
    required this.icone,
    required this.titulo,
    this.subtitulo,
    required this.children,
    required this.acoes,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icone, color: const Color(0xFFA85A00)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E3033),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitulo!,
                  style: const TextStyle(fontFamily: 'Lato', fontSize: 14, height: 1.45, color: Color(0xFF6B6D70)),
                ),
              ],
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: acoes,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ButtonStyle _estiloBotaoPrincipal() => ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: const Color(0xFF2E3033),
      elevation: 0,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w800, fontSize: 14),
    );

ButtonStyle _estiloBotaoTexto() => TextButton.styleFrom(
      foregroundColor: const Color(0xFF2E3033),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w700, fontSize: 14),
    );

// ---------------------------------------------------------------------------
// 1. Boas-vindas: qual é o seu caso?
// ---------------------------------------------------------------------------
class _DialogoBoasVindas extends StatelessWidget {
  const _DialogoBoasVindas();

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      icone: Icons.waving_hand_outlined,
      titulo: 'Bem-vindo à DIAVICON!',
      subtitulo: 'Antes de se cadastrar, escolha a opção que descreve o seu caso:',
      acoes: [
        TextButton(
          style: _estiloBotaoTexto(),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
      children: const [
        _OpcaoCaso(
          caso: _CasoCadastro.empresaJaCadastrada,
          icone: Icons.apartment_outlined,
          titulo: 'Minha empresa já usa a DIAVICON',
          descricao: 'Você não precisa criar outra conta.',
        ),
        SizedBox(height: 10),
        _OpcaoCaso(
          caso: _CasoCadastro.academico,
          icone: Icons.school_outlined,
          titulo: 'Sou estudante ou professor',
          descricao: 'Acesso acadêmico para alunos, professores e grupos de pesquisa, sem CNPJ.',
        ),
        SizedBox(height: 10),
        _OpcaoCaso(
          caso: _CasoCadastro.novaEmpresa,
          icone: Icons.add_business_outlined,
          titulo: 'Quero cadastrar minha empresa',
          descricao: 'Crie a conta da sua empresa com o CNPJ, no plano gratuito.',
          destaque: true,
        ),
      ],
    );
  }
}

class _OpcaoCaso extends StatelessWidget {
  final _CasoCadastro caso;
  final IconData icone;
  final String titulo;
  final String descricao;
  final bool destaque;

  const _OpcaoCaso({
    required this.caso,
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: destaque ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.pop(context, caso),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: destaque ? AppColors.primary : const Color(0xFFE7E3DC), width: destaque ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(icone, size: 26, color: destaque ? const Color(0xFFA85A00) : const Color(0xFF6B6D70)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontFamily: 'Lato', fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2E3033)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descricao,
                        style: const TextStyle(fontFamily: 'Lato', fontSize: 13, height: 1.35, color: Color(0xFF6B6D70)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF6B6D70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. A empresa já usa a DIAVICON
// ---------------------------------------------------------------------------
Future<void> _avisoEmpresaJaCadastrada(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _Moldura(
      icone: Icons.mark_email_read_outlined,
      titulo: 'Você não precisa se cadastrar',
      subtitulo: 'Cada empresa cadastra a própria equipe na DIAVICON.',
      acoes: [
        ElevatedButton(
          style: _estiloBotaoPrincipal(),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendi'),
        ),
      ],
      children: const [
        _Passo(numero: 1, texto: 'Fale com o gestor ou administrador da sua empresa na DIAVICON.'),
        _Passo(numero: 2, texto: 'Ele convida você pelo Painel da empresa › Colaboradores.'),
        _Passo(numero: 3, texto: 'Você recebe por e-mail uma senha provisória e entra direto por esta tela de login.'),
      ],
    ),
  );
}

class _Passo extends StatelessWidget {
  final int numero;
  final String texto;
  const _Passo({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
            child: Text(
              '$numero',
              style: const TextStyle(fontFamily: 'Lato', fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFA85A00)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                texto,
                style: const TextStyle(fontFamily: 'Lato', fontSize: 14, height: 1.45, color: Color(0xFF2E3033)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Estudante ou professor: pedido de acesso acadêmico por e-mail
// ---------------------------------------------------------------------------
Future<void> _acessoAcademico(BuildContext context) async {
  final solicitar = await showDialog<bool>(
    context: context,
    builder: (ctx) => _Moldura(
      icone: Icons.school_outlined,
      titulo: 'Acesso acadêmico',
      subtitulo: 'Para estudantes, professores e grupos de pesquisa, o acesso é liberado pela equipe DIAVICON. '
          'Envie um pedido e respondemos por e-mail.',
      acoes: [
        TextButton(
          style: _estiloBotaoTexto(),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Voltar'),
        ),
        ElevatedButton.icon(
          style: _estiloBotaoPrincipal(),
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Solicitar acesso'),
        ),
      ],
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF6F5F2), borderRadius: BorderRadius.circular(12)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pedido, informe:',
                style: TextStyle(fontFamily: 'Lato', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2E3033)),
              ),
              SizedBox(height: 8),
              _ItemLista('Seu nome e se é aluno ou professor'),
              _ItemLista('Instituição de ensino e curso'),
              _ItemLista('Grupo de pesquisa ou laboratório, se houver'),
              _ItemLista('Para que vai usar a DIAVICON (TCC, pesquisa, aula…)'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ao tocar em "Solicitar acesso", abrimos seu e-mail com a mensagem já montada.',
          style: TextStyle(fontFamily: 'Lato', fontSize: 12.5, color: Color(0xFF6B6D70)),
        ),
      ],
    ),
  );
  if (solicitar != true || !context.mounted) return;

  final uri = Uri(
    scheme: 'mailto',
    path: kEmailComercial,
    query: _consulta({
      'subject': 'Pedido de acesso acadêmico à DIAVICON',
      'body': 'Olá, equipe DIAVICON!\n\n'
          'Gostaria de solicitar acesso acadêmico à plataforma.\n\n'
          'Nome completo: \n'
          'Sou: ( ) aluno(a)  ( ) professor(a)  ( ) pesquisador(a)\n'
          'Instituição de ensino: \n'
          'Curso: \n'
          'Grupo de pesquisa / laboratório (se houver): \n'
          'Para que vou usar a DIAVICON: \n\n'
          'Obrigado(a)!',
    }),
  );

  var abriu = false;
  try {
    abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (abriu || !context.mounted) return;

  // Sem aplicativo de e-mail: copia o endereço e avisa.
  await Clipboard.setData(const ClipboardData(text: kEmailComercial));
  if (context.mounted) {
    DiaviconAlerts.show(
      context,
      'E-mail copiado',
      'Não encontramos um aplicativo de e-mail. Escreva para $kEmailComercial com seu nome, instituição, curso e para que vai usar a DIAVICON.',
    );
  }
}

/// `Uri(queryParameters:)` troca espaço por "+", que alguns programas de
/// e-mail mostram literalmente; aqui o espaço vira %20.
String _consulta(Map<String, String> campos) =>
    campos.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

class _ItemLista extends StatelessWidget {
  final String texto;
  const _ItemLista(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: Color(0xFFA85A00)),
          ),
          Expanded(
            child: Text(texto, style: const TextStyle(fontFamily: 'Lato', fontSize: 13.5, height: 1.4, color: Color(0xFF2E3033))),
          ),
        ],
      ),
    );
  }
}
