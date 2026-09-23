import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ensaios_carbonatacao/screens/ponto_ensaio_carbonatacao_screen.dart';
import '../../ensaios_carbonatacao/screens/analise_ensaio_todos_screen.dart';
import '../../ensaios_carbonatacao/screens/relatorio_carbonatacao_screen.dart';

import '../../ensaios_resistividade/screens/ponto_ensaio_resistividade_screen.dart';
import '../../ensaios_resistividade/screens/analise_todos_pontos_resistividade.dart';
import '../../ensaios_resistividade/screens/relatorio_resistividade_screen.dart';

import '../../ensaios_potencial_corrosao/screens/relatorio_potencial_screen.dart';

import '../../ensaios_arrancamento_argamassa/screens/relatorio_arrancamento_screen.dart';
import '../../ensaios_arrancamento_ceramica/screens/relatorio_arrancamento_ceramica_screen.dart';
import '../../ensaios_prova_carga_dinamica/pcd_tipo_ensaio.dart';
import '../../ensaios_prova_carga_dinamica/prova_dinamica_indisponivel_screen.dart';
import '../../ensaios_prova_carga/screens/relatorio_prova_carga_screen.dart';
import '../../ensaios_esclerometria/screens/relatorio_esclerometria_screen.dart';

import '../../ensaios_arrancamento_argamassa/screens/ponto_ensaio_arrancamento_screen.dart';
import '../../ensaios_arrancamento_argamassa/screens/analise_todos_arrancamento_screen.dart';

import '../../ensaios_arrancamento_ceramica/screens/ponto_ensaio_arrancamento_ceramica_screen.dart';
import '../../ensaios_arrancamento_ceramica/screens/analise_todos_arrancamento_ceramica_screen.dart';

import '../../ensaios_potencial_corrosao/screens/ponto_ensaio_potencial_screen.dart';
import '../../ensaios_potencial_corrosao/screens/analise_todos_potencial_screen.dart';

import '../../ensaios_prova_carga/screens/ponto_ensaio_prova_carga_screen.dart';

import '../../ensaios_esclerometria/screens/ponto_ensaio_esclerometria_screen.dart';
import '../../ensaios_esclerometria/screens/analise_todos_esclerometria_screen.dart';

import '../../ensaio_ultrassom/ultrassom_direto/screens/ponto_ensaio_ultrassom_direto_screen.dart';
import '../../ensaio_ultrassom/ultrassom_indireto/screens/ponto_ensaio_ultrassom_indireto_screen.dart';
import '../../ensaio_ultrassom/ultrassom_mapeamento/screens/ponto_ensaio_ultrassom_mapeamento_screen.dart';
import '../../ensaio_ultrassom/screens/analise_todos_ultrassom_screen.dart';
import '../../ensaio_ultrassom/screens/relatorio_ultrassom_screen.dart';

import '../../ensaio_monitoramento_fissura/screens/ponto_monitoramento_fissura_screen.dart';
import '../../ensaio_monitoramento_fissura/screens/analise_todos_monitoramento_fissura_screen.dart';
import '../../ensaio_monitoramento_fissura/screens/relatorio_monitoramento_fissura_screen.dart';

import '../../ensaio_chumbador/screens/ponto_chumbador_screen.dart';
import '../../ensaio_chumbador/screens/analise_todos_chumbador_screen.dart';
import '../../ensaio_chumbador/screens/relatorio_chumbador_screen.dart';

import '../../ensaio_extracao_testemunho/screens/ponto_ensaio_extracao_screen.dart';
import '../../ensaio_extracao_testemunho/screens/analise_todos_extracao_screen.dart';
import '../../ensaio_extracao_testemunho/screens/relatorio_extracao_screen.dart';

import '../../ensaio_liquido_penetrante/screens/ponto_liquido_penetrante_screen.dart';
import '../../ensaio_liquido_penetrante/screens/analise_todos_lp_screen.dart';
import '../../ensaio_liquido_penetrante/screens/relatorio_lp_screen.dart';
import 'tipos_ensaio_ids.dart';

class EnsaioRoutesMap {
  static Widget? getFormularioScreen({
    required String tipoEnsaio,
    required String projetoId,
    required String pontoNome,
    required String elementoNome,
    required String tipoElemento,
    required String local,
    required String elementoId,
    required String pontoGeralId,
    required String tipoEnsaioId,
    // Só usados pela Ultrassonografia — ignorados pelos demais ensaios.
    String? tipoMedicao,
    String? pulsoUltrassonico,
  }) {
    final tipo = tipoEnsaio.toLowerCase();

    // Líquido penetrante (estruturas metálicas) — N pontos de LP por elemento.
    if (tipo.contains('penetrante')) {
      return PontoLiquidoPenetranteScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 1. Carbonatação
    if (tipo.contains('carbonatação') || tipo.contains('carbonatacao')) {
      return PontoEnsaioCarbonatacaoScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 2. Resistividade Elétrica
    if (tipo.contains('resistividade')) {
      return PontoEnsaioResistividadeScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 3. Arrancamento em Argamassa (ID: 082321cb-ce13-4205-95f1-ec767b5e7d53)
    if (tipo.contains('arrancamento em argamassa') || tipoEnsaioId == TipoEnsaioId.arrancamentoArgamassa) {
      return PontoEnsaioArrancamentoScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    if (tipo.contains('arrancamento em placa cerâmica') || tipoEnsaioId == TipoEnsaioId.arrancamentoCeramica) {
      return PontoEnsaioArrancamentoCeramicaScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    if (tipo.contains('potencial') ) {
      return PontoEnsaioPotencialScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 6. Prova de Carga Estática — não se vincula a um elemento estrutural,
    // então a tela carrega tudo sozinha a partir do pontoGeralId.
    // A dinâmica (acelerometria) é analisada no computador; no celular abre
    // um aviso. Vem antes da estática porque o nome também contém
    // "prova de carga".
    if (ehProvaCargaDinamica(tipoEnsaioId: tipoEnsaioId, nomeTipoEnsaio: tipoEnsaio)) {
      return ProvaDinamicaIndisponivelScreen(nomePonto: pontoNome);
    }

    if (tipo.contains('prova de carga')) {
      if (pontoGeralId.isEmpty) return null;
      return PontoEnsaioProvaCargaScreen(pontoGeralId: pontoGeralId);
    }

    // 7. Esclerometria
    if (tipo.contains('esclerometria')) {
      return PontoEnsaioEsclerometriaScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 8. Ultrassonografia — Direto, Indireto e Mapeamento têm tela própria.
    // "ultrassom" não é substring de "ultrassonografia" (nome real
    // cadastrado em tipos_ensaio.nome) — checa os dois prefixos.
    if (tipo.contains('ultrassom') || tipo.contains('ultrasson')) {
      final modo = (tipoMedicao ?? 'Direta').toLowerCase();
      if (modo == 'indireta') {
        return PontoEnsaioUltrassomIndiretoScreen(
          projetoId: projetoId,
          pontoNome: pontoNome,
          elementoNome: elementoNome,
          tipoElemento: tipoElemento,
          local: local,
          elementoId: elementoId,
          pontoGeralId: pontoGeralId,
          tipoEnsaioId: tipoEnsaioId,
          pulsoUltrassonico: pulsoUltrassonico ?? 'Longitudinal',
        );
      }
      if (modo == 'mapeamento') {
        return PontoEnsaioUltrassomMapeamentoScreen(
          projetoId: projetoId,
          pontoNome: pontoNome,
          elementoNome: elementoNome,
          tipoElemento: tipoElemento,
          local: local,
          elementoId: elementoId,
          pontoGeralId: pontoGeralId,
          tipoEnsaioId: tipoEnsaioId,
          pulsoUltrassonico: pulsoUltrassonico ?? 'Longitudinal',
        );
      }
      if (modo != 'direta') return null;
      return PontoEnsaioUltrassomDiretoScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
        pulsoUltrassonico: pulsoUltrassonico ?? 'Longitudinal',
      );
    }

    // 9. Monitoramento de Fissuras — tela única (instalação quando o ponto é
    // novo, análise individual com gráficos/medições quando já existe).
    if (tipo.contains('monitoramento de fissura')) {
      return PontoMonitoramentoFissuraScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 10. Tração em Chumbador (nome real em tipos_ensaio.nome: "Tração em
    // elemento chumbado") — casa por "chumbad" pra cobrir chumbado/chumbador.
    if (tipo.contains('chumbad')) {
      return PontoChumbadorScreen(
        projetoId: projetoId,
        pontoNome: pontoNome,
        elementoNome: elementoNome,
        tipoElemento: tipoElemento,
        local: local,
        elementoId: elementoId,
        pontoGeralId: pontoGeralId,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    // 11. Extração e Rompimento de Testemunho — não se vincula a um
    // elemento estrutural (1 ensaio por Local, vários testemunhos cada um
    // com seu próprio elemento), então a tela carrega tudo sozinha a partir
    // do pontoGeralId, igual à Prova de Carga Estática.
    if (tipo.contains('testemunho')) {
      if (pontoGeralId.isEmpty) return null;
      return PontoEnsaioExtracaoScreen(pontoGeralId: pontoGeralId);
    }

    return null;
  }

  // Resolve o modo ('direto'/'indireto'/'mapeamento') e o pulso ultrassônico
  // de um ponto de Ultrassonografia já salvo, direto da tabela
  // `ponto_ensaio_ultrassom` — usado ao REABRIR um ponto existente, onde
  // nenhum dos dois é conhecido de antemão (ao contrário do modal de
  // criação, que já sabe o que o usuário escolheu). Sem isso,
  // `getFormularioScreen` caía sempre no padrão 'Direta'/'Longitudinal' —
  // reabria um ponto Indireto na tela errada, e reabrir um ponto Transversal
  // e salvar de novo silenciosamente sobrescrevia o pulso pra Longitudinal.
  static Future<({String? tipoMedicao, String? pulsoUltrassonico})> resolverModoUltrassom(String pontoGeralId) async {
    if (pontoGeralId.isEmpty) return (tipoMedicao: null, pulsoUltrassonico: null);
    try {
      final res = await Supabase.instance.client
          .from('ponto_ensaio_ultrassom')
          .select('modo, tipo_onda')
          .eq('ponto_ensaio_id', pontoGeralId)
          .maybeSingle();
      final String? tipoMedicao = switch (res?['modo']?.toString().toLowerCase()) {
        'direto' => 'Direta',
        'indireto' => 'Indireta',
        'mapeamento' => 'Mapeamento',
        _ => null,
      };
      return (tipoMedicao: tipoMedicao, pulsoUltrassonico: res?['tipo_onda']?.toString());
    } catch (_) {
      return (tipoMedicao: null, pulsoUltrassonico: null);
    }
  }

  static Widget? getAnaliseScreen({
    required String tipoEnsaio,
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioNome,
    required String tipoEnsaioId,
    required String projetoNome,
    required String estruturaNome,
  }) {
    final tipo = tipoEnsaio.toLowerCase();

    if (tipo.contains('penetrante')) {
      return AnaliseTodosLPScreen(
        projetoId: projetoId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioId: tipoEnsaioId,
      );
    }

    if (tipo.contains('carbonatação') || tipo.contains('carbonatacao')) {
      return AnaliseEnsaioScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        tipoEnsaioNome: tipoEnsaioNome,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('resistividade')) {
      return AnaliseResistividadeScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('arrancamento em argamassa')) {
      return AnaliseArrancamentoScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('arrancamento em placa cerâmica')) {
      return AnaliseTodosArrancamentoCeramicaScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('potencial')) {
      return AnaliseTodosPotencialScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('esclerometria')) {
      return AnaliseTodosEsclerometriaScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('ultrassom') || tipo.contains('ultrasson')) {
      return AnaliseTodosUltrassomScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('monitoramento de fissura')) {
      return AnaliseTodosMonitoramentoFissuraScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('chumbad')) {
      return AnaliseTodosChumbadorScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    if (tipo.contains('testemunho')) {
      return AnaliseTodosExtracaoScreen(
        projetoId: projetoId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    return null;
  }

  // Compositor de relatório "por modelo" (mesmo padrão da Inspeção Visual —
  // ver lib/features/modelos_relatorios/). Carbonatação e Resistividade têm
  // essa tela própria até agora; os outros tipos continuam usando a Central
  // de Relatórios genérica (retorno null aqui = "sem tela própria ainda").
  static Widget? getRelatorioScreen({
    required String tipoEnsaio,
    required String projetoId,
    required String estruturaId,
    required String projetoNome,
    required String estruturaNome,
  }) {
    final tipo = tipoEnsaio.toLowerCase();

    if (tipo.contains('penetrante')) {
      return RelatorioLPScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('carbonatação') || tipo.contains('carbonatacao')) {
      return RelatorioCarbonatacaoScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('resistividade')) {
      return RelatorioResistividadeScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('potencial')) {
      return RelatorioPotencialScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('arrancamento em argamassa')) {
      return RelatorioArrancamentoScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('arrancamento em placa cerâmica') || tipo.contains('arrancamento em placa ceramica')) {
      return RelatorioArrancamentoCeramicaScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (ehProvaCargaDinamica(nomeTipoEnsaio: tipoEnsaio)) {
      return null;
    }

    if (tipo.contains('prova de carga')) {
      return RelatorioProvaCargaScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('esclerometria')) {
      return RelatorioEsclerometriaScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('ultrassom') || tipo.contains('ultrasson')) {
      return RelatorioUltrassomScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('monitoramento de fissura')) {
      return RelatorioMonitoramentoFissuraScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('chumbad')) {
      return RelatorioChumbadorScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('testemunho')) {
      return RelatorioExtracaoScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    return null;
  }
}