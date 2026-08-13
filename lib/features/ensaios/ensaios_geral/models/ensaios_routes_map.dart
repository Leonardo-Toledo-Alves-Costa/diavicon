import 'package:flutter/material.dart';

// Importe aqui as telas dos ensaios já desenvolvidas
import '../../ensaios_carbonatacao/screens/ponto_ensaio_carbonatacao_screen.dart';
import '../../ensaios_carbonatacao/screens/analise_ensaio_todos_screen.dart'; // Tela de análise geral
import '../../ensaios_resistividade/screens/ponto_ensaio_resistividade_screen.dart'; 
import '../../ensaios_resistividade/screens/analise_todos_pontos_resistividade.dart';


class EnsaioRoutesMap {
  /// Retorna a Tela de Formulário do Ponto de Ensaio (Galeria)
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

    // 1. Frente de Carbonatação
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

    // 2. Resistividade
    if (tipo.contains('resistividade') || tipo.contains('resistividade')) {
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
    
    // 2. Potencial de Corrosão (Descomente quando criar a tela)
    /*
    if (tipo.contains('potencial')) {
      return PontoEnsaioPotencialScreen(...);
    }
    */

    // Retorna null se não houver rota mapeada (Em desenvolvimento)
    return null;
  }

  /// Retorna a Tela de Análise Geral do Ensaio
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

    // 1. Frente de Carbonatação
    if (tipo.contains('carbonatação') || tipo.contains('carbonatacao')) {
      return AnaliseEnsaioScreen(
        projetoId: projetoId,
        estruturaId: estruturaId,
        tipoEnsaioNome: tipoEnsaioNome,
        projetoNome: projetoNome,
        estruturaNome: estruturaNome,
      );
    }

    if (tipo.contains('resistividade') || tipo.contains('Resistividade')){
      return AnaliseResistividadeScreen(
        projetoId: projetoId,
        //estruturaId: estruturaId,
        tipoEnsaioId: tipoEnsaioId,
        projetoNome: projetoNome,
        estruturaId: estruturaId,
        estruturaNome: estruturaNome,
        tipoEnsaioNome: tipoEnsaioNome,
      );
    }

    // Retorna null se não houver rota mapeada (Em desenvolvimento)
    return null;
  }

}