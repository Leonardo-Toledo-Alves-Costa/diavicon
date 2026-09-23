import '../../../modelos_relatorios/html/quadro_html_helpers.dart';
import '../../../modelos_relatorios/models/quadro_model.dart';
import '../models/campos_registro_rdo.dart';
import '../models/modelo_rdo_schema.dart';
import '../models/rdo_realizado_model.dart';
import 'rdo_modelo_report_data.dart';

/// Monta o HTML de um relatório de RDO — mesmo desenho de
/// `InspecaoVisualHtmlBuilder`: pura montagem, sem buscar nada. "Registros"
/// usa o mesmo `QuadroHtmlHelpers.montarQuadro` compartilhado que os
/// ensaios, com "Turnos" como sub-lista (mesmo mecanismo de "Pontos de
/// leitura"/"Anomalias") — cada RDO gera até 3 linhas de turno.
class RdoModeloHtmlBuilder {
  static String montar({
    required ModeloRdoSchema schema,
    required String nomeRelatorio,
    required Map<String, String> dadosCabecalho,
    required InformacoesIniciaisReal informacoesIniciais,
    required List<RegistroRdoReal> registros,
  }) {
    final d = schema.decoracao;

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    buffer.writeln('<style>${QuadroHtmlHelpers.css(d)}</style></head><body>');
    buffer.writeln('<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)}</h1>');

    if (schema.cabecalho.ativo) {
      buffer.writeln(QuadroHtmlHelpers.secao(
        'Cabeçalho',
        d,
        () => QuadroHtmlHelpers.montarQuadro(schema.cabecalho.quadro, dadosCabecalho, camposCabecalho, d, const [], const []),
      ));
    }

    if (schema.informacoesIniciais.ativo) {
      buffer.writeln(QuadroHtmlHelpers.secao('Informações iniciais', d, () {
        final blocos = StringBuffer();
        blocos.writeln(QuadroHtmlHelpers.blocoRepetido(
            'Equipe', schema.informacoesIniciais.equipe, camposEquipe, d, informacoesIniciais.equipe));
        blocos.writeln(QuadroHtmlHelpers.blocoRepetido('Empresas no projeto',
            schema.informacoesIniciais.empresas, camposEmpresasProjeto, d, informacoesIniciais.empresas));
        blocos.writeln(QuadroHtmlHelpers.blocoRepetido('Estruturas do projeto',
            schema.informacoesIniciais.estruturas, camposEstruturasProjeto, d, informacoesIniciais.estruturas));
        return blocos.toString();
      }));
    }

    if (schema.registros.ativo) {
      buffer.writeln(QuadroHtmlHelpers.secao('Registros', d, () {
        if (registros.isEmpty) return '<p class="vazio">Nenhum RDO encontrado.</p>';
        final cartoes = StringBuffer();
        for (final registro in registros) {
          cartoes.writeln('<div class="cartao-registro">${QuadroHtmlHelpers.montarQuadro(
            schema.registros.quadro,
            _dadosRegistro(registro.rdo),
            camposRegistroRdo,
            d,
            const [],
            registro.fotos,
            subLista: _subListaTurnos(registro.rdo),
            catalogoSubLista: camposTurnoRdo,
          )}</div>');
        }
        return cartoes.toString();
      }));
    }

    if (schema.galeria.ativo) {
      final todasFotos = registros.expand((r) => r.fotos).toList();
      buffer.writeln(QuadroHtmlHelpers.secao(
        'Galeria',
        d,
        () => QuadroHtmlHelpers.galeria(todasFotos, schema.galeria),
        quebraPaginaAntes: true,
      ));
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static Map<String, String> _dadosRegistro(RdoRealizadoModel rdo) => {
    'status_rdo': rdo.status.rotulo,
    'data_rdo': rdo.data,
    'equipe_rdo': rdo.equipe.join(', '),
    'atividades_rdo': rdo.atividadesRealizadas,
    'equipamentos_rdo': rdo.equipamentosUtilizados,
    'observacoes_rdo': rdo.observacoes,
  };

  static List<Map<String, String>> _subListaTurnos(RdoRealizadoModel rdo) {
    final turnos = <Map<String, String>>[];
    for (final par in [('Manhã', rdo.manha), ('Tarde', rdo.tarde), ('Noite', rdo.noite)]) {
      if (!par.$2.preenchido) continue;
      turnos.add({
        'periodo_turno': par.$1,
        'chegada_turno': par.$2.chegada,
        'inicio_turno': par.$2.inicio,
        'saida_turno': par.$2.saida,
        'cond_trabalho_turno': par.$2.condTrabalho,
        'cond_clima_turno': par.$2.condClima,
      });
    }
    return turnos;
  }
}
