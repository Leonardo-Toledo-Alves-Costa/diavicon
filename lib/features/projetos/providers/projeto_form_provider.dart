import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';

/// Representa o estado temporário do formulário de criação de projeto
class ProjetoFormState {
  final String nome;
  
  // Dados do Cliente (Se já existir no sistema)
  final String? clienteId;
  final String? clienteNome;
  final String? localCliente; 
  final String? clienteFotoUrl;
  final File? imagemProjeto;

  // Dados para Convite/Novo Cliente (Se não existir)
  final bool isNovoCliente;
  final String? emailNovoCliente;
  final String? tipoNovoCliente;
  final String? areaAtuacaoNovoCliente;

  ProjetoFormState({
    this.nome = '',
    this.clienteId,
    this.clienteNome,
    this.localCliente,
    this.clienteFotoUrl,
    this.isNovoCliente = false,
    this.emailNovoCliente,
    this.tipoNovoCliente,
    this.areaAtuacaoNovoCliente,
    this.imagemProjeto,
  });

  /// Método para atualizar apenas partes do estado sem perder o resto
  ProjetoFormState copyWith({
    String? nome,
    String? clienteId,
    String? clienteNome,
    String? localCliente, 
    String? clienteFotoUrl,
    bool? isNovoCliente,
    String? emailNovoCliente,
    String? tipoNovoCliente,
    String? areaAtuacaoNovoCliente,
    File? imagemProjeto,
  }) {
    return ProjetoFormState(
      nome: nome ?? this.nome,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      localCliente: localCliente ?? this.localCliente, 
      clienteFotoUrl: clienteFotoUrl ?? this.clienteFotoUrl,
      isNovoCliente: isNovoCliente ?? this.isNovoCliente,
      emailNovoCliente: emailNovoCliente ?? this.emailNovoCliente,
      tipoNovoCliente: tipoNovoCliente ?? this.tipoNovoCliente,
      areaAtuacaoNovoCliente: areaAtuacaoNovoCliente ?? this.areaAtuacaoNovoCliente,
      imagemProjeto: imagemProjeto ?? this.imagemProjeto,
    );
  }

  /// Helper para saber se o formulário está minimamente preenchido
  bool get isValid => nome.isNotEmpty && (clienteId != null || emailNovoCliente != null);
}

/// O Provider que será lido e alterado pelas telas do fluxo de criação
final projetoFormProvider = StateProvider<ProjetoFormState>((ref) {
  return ProjetoFormState();
});