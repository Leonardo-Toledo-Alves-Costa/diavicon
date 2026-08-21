import 'package:flutter/material.dart';

import '../../ensaios_carbonatacao/screens/ponto_ensaio_carbonatacao_screen.dart';
import '../../ensaios_carbonatacao/screens/analise_ensaio_todos_screen.dart';

import '../../ensaios_resistividade/screens/ponto_ensaio_resistividade_screen.dart';
import '../../ensaios_resistividade/screens/analise_todos_pontos_resistividade.dart';

import '../../ensaios_arrancamento_argamassa/screens/ponto_ensaio_arrancamento_screen.dart';
import '../../ensaios_arrancamento_argamassa/screens/analise_todos_arrancamento_screen.dart';

import '../../ensaios_arrancamento_ceramica/screens/ponto_ensaio_arrancamento_ceramica_screen.dart';
import '../../ensaios_arrancamento_ceramica/screens/analise_todos_arrancamento_ceramica_screen.dart';

import '../../ensaios_potencial_corrosao/screens/ponto_ensaio_potencial_screen.dart';
import '../../ensaios_potencial_corrosao/screens/analise_todos_potencial_screen.dart';

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
  }) {
    final tipo = tipoEnsaio.toLowerCase();

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
    if (tipo.contains('arrancamento em argamassa') || tipoEnsaioId == '082321cb-ce13-4205-95f1-ec767b5e7d53') {
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

    if (tipo.contains('arrancamento em placa cerâmica') || tipoEnsaioId == 'f965252e-f5ad-48d2-9ac4-804a40a4a8d8') {
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

    

    return null;
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

    

    return null;
  }
}