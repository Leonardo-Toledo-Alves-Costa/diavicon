import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/aviso_topo.dart';
import 'financeiro_repository.dart';

// Peças visuais do controle financeiro, usadas no painel da DIAVICON e na
// tela Meu Plano do Gestor.

const _tinta = Color(0xFF2E3033);
const _apagado = Color(0xFF6B6D70);
const _borda = Color(0xFFE7E3DC);
const _laranjaTexto = Color(0xFFA85A00);

void mostrarAvisoFinanceiro(BuildContext context, String mensagem) =>
    mostrarAviso(context, mensagem, tipo: TipoAviso.sucesso);

/// Erro legível. Tabela inexistente = migration ainda não aplicada.
String mensagemErroFinanceiro(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42P01' || e.code == 'PGRST205' || e.code == 'PGRST202') {
      return 'O controle financeiro ainda não está ativo no servidor. A equipe precisa aplicar a atualização do banco (financeiro_empresas).';
    }
    if (e.code == '42501') return 'Acesso restrito à administração da DIAVICON.';
    if (e.code == '23505') return 'Já existe uma cobrança deste contrato para esse mês.';
    return e.message;
  }
  if (e is StorageException) {
    if (e.statusCode == '404' && e.message.toLowerCase().contains('bucket')) {
      return 'O espaço de arquivos do financeiro ainda não foi criado no servidor.';
    }
    return 'Falha no arquivo: ${e.message}';
  }
  final t = e.toString().replaceFirst('Exception: ', '').trim();
  return t.isEmpty ? 'Tente de novo em instantes.' : t;
}

Future<bool> confirmarFinanceiro(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String confirmar,
  bool perigoso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _tinta)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(mensagem, style: const TextStyle(fontSize: 14, height: 1.45, color: _apagado)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: _tinta, minimumSize: const Size(44, 44)),
          child: const Text('Voltar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: perigoso ? AppColors.error : AppColors.primary,
            foregroundColor: perigoso ? Colors.white : _tinta,
            elevation: 0,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(confirmar, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return r == true;
}

Color corStatusCobranca(StatusCobranca s) => switch (s) {
      StatusCobranca.pendente => const Color(0xFF8A5A00),
      StatusCobranca.atrasado => const Color(0xFFC62828),
      StatusCobranca.pago => const Color(0xFF1B7F4B),
      StatusCobranca.cancelado => _apagado,
    };

Color _fundoStatus(StatusCobranca s) => switch (s) {
      StatusCobranca.pendente => const Color(0xFFFFF3E0),
      StatusCobranca.atrasado => const Color(0xFFFDECEA),
      StatusCobranca.pago => const Color(0xFFE6F4EC),
      StatusCobranca.cancelado => const Color(0xFFF1F1F1),
    };

IconData _iconeStatus(StatusCobranca s) => switch (s) {
      StatusCobranca.pendente => Icons.schedule_rounded,
      StatusCobranca.atrasado => Icons.warning_amber_rounded,
      StatusCobranca.pago => Icons.check_circle_rounded,
      StatusCobranca.cancelado => Icons.block_rounded,
    };

class SeloStatusCobranca extends StatelessWidget {
  final StatusCobranca status;
  const SeloStatusCobranca(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final cor = corStatusCobranca(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: _fundoStatus(status), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconeStatus(status), size: 14, color: cor),
          const SizedBox(width: 4),
          Text(status.rotulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }
}

class CartaoFinanceiro extends StatelessWidget {
  final String? titulo;
  final Widget? acao;
  final Widget child;

  const CartaoFinanceiro({super.key, this.titulo, this.acao, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(titulo!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _tinta)),
                  ),
                ),
                ?acao,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class IndicadorFinanceiro extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;
  final String? detalhe;
  final Color? cor;

  const IndicadorFinanceiro({super.key, required this.icone, required this.rotulo, required this.valor, this.detalhe, this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor ?? AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo, style: const TextStyle(fontSize: 12, color: _apagado)),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: cor ?? _tinta,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (detalhe != null) Text(detalhe!, style: const TextStyle(fontSize: 11.5, color: _apagado)),
            ],
          ),
        ],
      ),
    );
  }
}

class BotaoFinanceiro extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback? onPressed;
  final bool secundario;

  const BotaoFinanceiro({super.key, required this.icone, required this.texto, required this.onPressed, this.secundario = false});

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const texto2 = TextStyle(fontWeight: FontWeight.w800, fontSize: 14);
    if (secundario) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icone, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: _tinta,
          side: const BorderSide(color: _borda),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: forma,
          textStyle: texto2,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 18),
      label: Text(texto),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: _tinta,
        elevation: 0,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: forma,
        textStyle: texto2,
      ),
    );
  }
}

class EstadoFinanceiro extends StatelessWidget {
  final IconData icone;
  final String texto;

  const EstadoFinanceiro({super.key, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 36, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: _apagado)),
        ],
      ),
    );
  }
}

/// Uma cobrança: mês, valor, vencimento, status e os arquivos.
/// Sem [aoAnexar], a linha é só de consulta (visão do Gestor).
class LinhaCobranca extends StatelessWidget {
  final CobrancaEmpresa cobranca;
  final bool largo;
  final void Function(TipoAnexo) aoAbrirAnexo;
  final void Function(TipoAnexo)? aoAnexar;
  final void Function(TipoAnexo)? aoRemoverAnexo;
  final Widget? menu;

  const LinhaCobranca({
    super.key,
    required this.cobranca,
    required this.largo,
    required this.aoAbrirAnexo,
    this.aoAnexar,
    this.aoRemoverAnexo,
    this.menu,
  });

  bool get _edita => aoAnexar != null;

  @override
  Widget build(BuildContext context) {
    final c = cobranca;
    final st = c.status;
    final cancelada = st == StatusCobranca.cancelado;

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatarCompetencia(c.competencia),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: cancelada ? _apagado : _tinta,
            decoration: cancelada ? TextDecoration.lineThrough : null,
          ),
        ),
        Text(
          [if (c.descricao.isNotEmpty) c.descricao, if (c.contratoId == null) 'avulsa'].join(' · ').ifEmpty('Cobrança'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: _apagado),
        ),
      ],
    );

    final valores = Column(
      crossAxisAlignment: largo ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          formatarReais(c.valor),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _tinta, fontFeatures: [FontFeature.tabularFigures()]),
        ),
        Text(
          st == StatusCobranca.pago && c.pagoEm != null ? 'Pago em ${formatarDataBr(c.pagoEm!)}' : 'Vence ${formatarDataBr(c.vencimento)}',
          style: TextStyle(fontSize: 12.5, color: st == StatusCobranca.atrasado ? corStatusCobranca(st) : _apagado),
        ),
      ],
    );

    final anexos = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in TipoAnexo.values) _chipAnexo(context, t)],
    );

    final conteudo = largo
        ? Row(
            children: [
              Expanded(flex: 3, child: titulo),
              SizedBox(width: 130, child: Align(alignment: Alignment.centerLeft, child: SeloStatusCobranca(st))),
              Expanded(flex: 4, child: anexos),
              const SizedBox(width: 12),
              SizedBox(width: 150, child: valores),
              if (menu != null) menu! else const SizedBox(width: 8),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titulo),
                  SeloStatusCobranca(st),
                  ?menu,
                ],
              ),
              const SizedBox(height: 8),
              valores,
              const SizedBox(height: 10),
              anexos,
            ],
          );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: EdgeInsets.fromLTRB(14, 12, menu == null ? 14 : 4, 12),
      decoration: BoxDecoration(
        color: st == StatusCobranca.atrasado ? const Color(0xFFFFFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: st == StatusCobranca.atrasado ? const Color(0xFFF3C7C3) : _borda),
      ),
      child: conteudo,
    );
  }

  Widget _chipAnexo(BuildContext context, TipoAnexo tipo) {
    final caminho = tipo == TipoAnexo.boleto ? cobranca.boletoPath : cobranca.notaFiscalPath;
    final icone = tipo == TipoAnexo.boleto ? Icons.receipt_long_outlined : Icons.description_outlined;

    if (caminho == null) {
      if (!_edita) {
        return _Chip(icone: icone, texto: '${tipo.rotulo}: ainda não disponível', apagado: true);
      }
      return _Chip(icone: Icons.upload_file_rounded, texto: 'Anexar ${tipo.rotulo.toLowerCase()}', tracejado: true, aoTocar: () => aoAnexar!(tipo));
    }

    if (!_edita) {
      return _Chip(icone: icone, texto: 'Baixar ${tipo.rotulo.toLowerCase()}', destaque: true, aoTocar: () => aoAbrirAnexo(tipo));
    }

    return PopupMenuButton<String>(
      tooltip: tipo.rotulo,
      color: Colors.white,
      onSelected: (v) {
        if (v == 'abrir') aoAbrirAnexo(tipo);
        if (v == 'trocar') aoAnexar?.call(tipo);
        if (v == 'remover') aoRemoverAnexo?.call(tipo);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
        const PopupMenuItem(value: 'trocar', child: Text('Substituir arquivo')),
        const PopupMenuItem(value: 'remover', child: Text('Remover', style: TextStyle(color: AppColors.error))),
      ],
      child: _Chip(icone: icone, texto: tipo.rotulo, destaque: true, seta: true),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback? aoTocar;
  final bool destaque;
  final bool apagado;
  final bool tracejado;
  final bool seta;

  const _Chip({
    required this.icone,
    required this.texto,
    this.aoTocar,
    this.destaque = false,
    this.apagado = false,
    this.tracejado = false,
    this.seta = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = apagado ? _apagado : (destaque ? _laranjaTexto : _tinta);
    final corpo = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFF3E0) : (apagado ? const Color(0xFFF6F5F2) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: destaque ? const Color(0xFFF6DDB5) : _borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: apagado ? FontWeight.w500 : FontWeight.w700, color: cor),
            ),
          ),
          if (seta) Icon(Icons.arrow_drop_down, size: 18, color: cor),
        ],
      ),
    );
    if (aoTocar == null) return corpo;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: aoTocar, borderRadius: BorderRadius.circular(10), child: corpo),
    );
  }
}

// --- Formulários -------------------------------------------------------------

class DialogoFinanceiro extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget child;
  final List<Widget> acoes;

  const DialogoFinanceiro({super.key, required this.titulo, this.subtitulo, required this.child, required this.acoes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _tinta)),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo!, style: const TextStyle(fontSize: 13, color: _apagado)),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: acoes),
            ),
          ],
        ),
      ),
    );
  }
}

class RotuloFinanceiro extends StatelessWidget {
  final String texto;
  final bool obrigatorio;
  const RotuloFinanceiro(this.texto, {super.key, this.obrigatorio = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: texto),
          if (obrigatorio) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
        ]),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _tinta),
      ),
    );
  }
}

InputDecoration decoracaoFinanceiro(String dica) => InputDecoration(
      hintText: dica.isEmpty ? null : dica,
      hintStyle: const TextStyle(fontSize: 14, color: _apagado),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borda)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    );

class CampoDataFinanceiro extends StatelessWidget {
  final DateTime? valor;
  final String dica;
  final String? texto;
  final VoidCallback aoTocar;
  final VoidCallback? aoLimpar;

  const CampoDataFinanceiro({super.key, required this.valor, required this.dica, this.texto, required this.aoTocar, this.aoLimpar});

  @override
  Widget build(BuildContext context) {
    final vazio = valor == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _borda)),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: vazio ? _apagado : _laranjaTexto),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vazio ? dica : (texto ?? formatarDataBr(valor!)),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: vazio ? _apagado : _tinta, fontWeight: vazio ? FontWeight.w400 : FontWeight.w600),
                ),
              ),
              if (aoLimpar != null)
                IconButton(
                  tooltip: 'Limpar',
                  visualDensity: VisualDensity.compact,
                  onPressed: aoLimpar,
                  icon: const Icon(Icons.close, size: 16, color: _apagado),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String alternativa) => isEmpty ? alternativa : this;
}
