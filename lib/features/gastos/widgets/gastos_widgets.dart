import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/gasto_model.dart';
import '../repositories/gastos_repository.dart' show mensagemErroGastos;
import '../utils/agregacao_gastos.dart';

// Peças visuais compartilhadas pelas três telas de gastos.

class CoresGastos {
  const CoresGastos._();
  static const barra = Color(0xFF2F74D0);
  static const barraFundo = Color(0xFFE3ECF8);
  static const reembolsavel = Color(0xFF2E9E62);
  static const reembolsavelFundo = Color(0xFFCDEBD6);
  static const reembolsavelTexto = Color(0xFF1E6B3F);
  static const naoReembolsavel = Color(0xFF8A94A6);
  static const cartao = Color(0xFFF7F6F3);
  static const texto = Color(0xFF3E3E3D);
}

class TituloSecaoGastos extends StatelessWidget {
  final String texto;
  const TituloSecaoGastos(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
      );
}

/// Os três cards do topo: Total · Reembolsável (destacado) · Não reemb.
class ResumoTotaisGastos extends StatelessWidget {
  final TotaisGastos totais;
  const ResumoTotaisGastos({super.key, required this.totais});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: CardValorGasto(rotulo: 'Total', valor: totais.total)),
        const SizedBox(width: 8),
        Expanded(child: CardValorGasto(rotulo: 'Reembolsável', valor: totais.reembolsavel, destaque: true)),
        const SizedBox(width: 8),
        Expanded(child: CardValorGasto(rotulo: 'Não reemb.', valor: totais.naoReembolsavel)),
      ],
    );
  }
}

class CardValorGasto extends StatelessWidget {
  final String rotulo;
  final double valor;
  final bool destaque;

  /// Soma de dinheiro se mostra inteira. Arredondar para o real mais próximo
  /// fazia a conta da tela não bater com a do extrato.
  final bool centavos;
  final CrossAxisAlignment alinhamento;

  const CardValorGasto({
    super.key,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    this.centavos = true,
    this.alinhamento = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: destaque ? CoresGastos.reembolsavelFundo : CoresGastos.cartao,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: alinhamento,
        children: [
          Text(
            rotulo,
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: destaque ? FontWeight.w700 : FontWeight.w500,
              color: destaque ? CoresGastos.reembolsavelTexto : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatarMoeda(valor, centavos: centavos),
              style: GoogleFonts.lato(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: destaque ? CoresGastos.reembolsavelTexto : CoresGastos.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controle segmentado no estilo dos prints (pílula branca no selecionado).
class SeletorSegmentadoGastos<T> extends StatelessWidget {
  final List<(T, String)> opcoes;
  final T selecionado;
  final ValueChanged<T> onChanged;
  final bool compacto;

  const SeletorSegmentadoGastos({
    super.key,
    required this.opcoes,
    required this.selecionado,
    required this.onChanged,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: CoresGastos.cartao, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final (valor, rotulo) in opcoes)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(valor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: compacto ? 6 : 9),
                  decoration: BoxDecoration(
                    color: valor == selecionado ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: valor == selecionado ? Border.all(color: Colors.grey.shade400) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rotulo,
                    style: GoogleFonts.lato(
                      fontSize: compacto ? 12 : 13,
                      fontWeight: valor == selecionado ? FontWeight.w800 : FontWeight.w500,
                      color: CoresGastos.texto,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha "rótulo ........ valor" com a barra proporcional embaixo.
class BarraValorGasto extends StatelessWidget {
  final String rotulo;
  final double valor;
  final double maximo;
  final Color cor;

  const BarraValorGasto({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.maximo,
    this.cor = CoresGastos.barra,
  });

  @override
  Widget build(BuildContext context) {
    final fracao = maximo <= 0 ? 0.0 : (valor / maximo).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // Nome de projeto costuma ser comprido: duas linhas antes de
                // cortar, senão vira "Reforço estrutural da ponte…" e não dá
                // para saber de qual ponte se trata.
                child: Text(
                  rotulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(fontSize: 13, color: CoresGastos.texto, height: 1.25),
                ),
              ),
              Text(formatarMoeda(valor), style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w800, color: CoresGastos.texto)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: CoresGastos.barraFundo),
                FractionallySizedBox(widthFactor: fracao, child: Container(height: 6, color: cor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de [BarraValorGasto] a partir de uma agregação (a maior barra = 100%).
class RankingBarrasGastos extends StatelessWidget {
  final List<ItemAgregado> itens;
  final String vazio;
  const RankingBarrasGastos({super.key, required this.itens, this.vazio = 'Sem gastos no período.'});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(vazio, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
      );
    }
    final maximo = itens.map((i) => i.valor).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [for (final i in itens) BarraValorGasto(rotulo: i.rotulo, valor: i.valor, maximo: maximo)],
    );
  }
}

/// Gráfico de colunas simples (gasto por projeto, gasto por mês).
class GraficoColunasGastos extends StatelessWidget {
  final List<(String, double)> dados;
  final Color cor;
  final bool mostrarEixoY;
  final double altura;

  const GraficoColunasGastos({
    super.key,
    required this.dados,
    this.cor = CoresGastos.barra,
    this.mostrarEixoY = true,
    this.altura = 170,
  });

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty || dados.every((d) => d.$2 <= 0)) {
      return SizedBox(
        height: altura * 0.6,
        child: Center(child: Text('Sem gastos no período.', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey))),
      );
    }
    return SizedBox(
      height: altura,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: GoogleFonts.lato(fontSize: 11, color: CoresGastos.texto),
          labelIntersectAction: AxisLabelIntersectAction.wrap,
          // Sem largura máxima, um nome comprido empurra os vizinhos e o
          // eixo passa a mostrar só um em cada três rótulos.
          maximumLabelWidth: 72,
          labelAlignment: LabelAlignment.center,
        ),
        primaryYAxis: NumericAxis(
          isVisible: mostrarEixoY,
          minimum: 0,
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: MajorGridLines(width: 0.6, color: Colors.grey.shade300),
          labelStyle: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade700),
          axisLabelFormatter: (args) => ChartAxisLabel(formatarMoeda(args.value.toDouble(), centavos: false), args.textStyle),
        ),
        tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y'),
        series: <CartesianSeries<(String, double), String>>[
          ColumnSeries<(String, double), String>(
            dataSource: dados,
            xValueMapper: (d, _) => d.$1,
            yValueMapper: (d, _) => d.$2,
            color: cor,
            width: 0.45,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

/// Um gasto na lista (Meus Gastos / Gastos do Projeto).
class ItemGastoTile extends StatelessWidget {
  final GastoModel gasto;
  final bool mostrarUsuario;
  final VoidCallback? onTap;

  const ItemGastoTile({super.key, required this.gasto, this.mostrarUsuario = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final titulo = gasto.categoriaNome;
    final detalhes = [
      if (mostrarUsuario) gasto.usuarioNome,
      gasto.projetoNome,
      gasto.meioPagamento.rotulo,
      formatarData(gasto.data),
    ].join(' · ');
    final statusTexto = gasto.reembolsavel ? 'Reembolsável' : 'Não reembolsável';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: CoresGastos.cartao, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: CoresGastos.texto)),
                      ),
                      if (gasto.anexoUrl != null) ...[
                        const SizedBox(width: 4),
                        Icon(gasto.anexoTipo == TipoAnexoGasto.pdf ? Icons.picture_as_pdf_outlined : Icons.attach_file, size: 14, color: Colors.grey.shade600),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(detalhes, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  statusTexto,
                  style: GoogleFonts.lato(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: gasto.reembolsavel ? CoresGastos.reembolsavelTexto : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(formatarMoeda(gasto.valor), style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: CoresGastos.texto)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CarregandoGastos extends StatelessWidget {
  const CarregandoGastos({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
}

class ErroGastos extends StatelessWidget {
  final Object erro;
  final VoidCallback onTentarDeNovo;
  const ErroGastos({super.key, required this.erro, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Não foi possível carregar os gastos.', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(mensagemErroGastos(erro), textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onTentarDeNovo, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}


/// Chips de categoria que filtram a análise inteira.
///
/// Antes esta lista era só um ranking desenhado, mas com cara de botão — as
/// pessoas clicavam e nada acontecia. Agora clicar filtra de verdade; nenhuma
/// selecionada quer dizer "todas".
class FiltroCategoriasGastos extends StatelessWidget {
  final List<ItemAgregado> categorias;
  final Set<String> selecionadas;
  final void Function(String chave) aoAlternar;
  final VoidCallback aoLimpar;

  const FiltroCategoriasGastos({
    super.key,
    required this.categorias,
    required this.selecionadas,
    required this.aoAlternar,
    required this.aoLimpar,
  });

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          texto: 'Todas',
          marcada: selecionadas.isEmpty,
          aoTocar: aoLimpar,
        ),
        for (final c in categorias)
          _Chip(
            texto: '${c.rotulo}  ·  ${formatarMoeda(c.valor, centavos: false)}',
            marcada: selecionadas.contains(c.chave),
            aoTocar: () => aoAlternar(c.chave),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final bool marcada;
  final VoidCallback aoTocar;

  const _Chip({required this.texto, required this.marcada, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: marcada ? CoresGastos.barra : CoresGastos.cartao,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (marcada) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                texto,
                style: GoogleFonts.lato(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: marcada ? Colors.white : CoresGastos.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
