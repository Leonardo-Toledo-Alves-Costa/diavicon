import 'dart:io';

/// Estado temporário do formulário de criação de projeto.
class ProjetoFormState {
  const ProjetoFormState({
    this.nome = '',
    this.clienteId,
    this.clienteNome,
    this.localCliente,
    this.clienteFotoUrl,
    this.isNovoCliente = false,
    this.emailNovoCliente,
    this.imagemProjeto,
  });

  final String nome;
  final String? clienteId;
  final String? clienteNome;
  final String? localCliente;
  final String? clienteFotoUrl;
  final File? imagemProjeto;
  final bool isNovoCliente;
  final String? emailNovoCliente;

  ProjetoFormState copyWith({
    String? nome,
    String? clienteId,
    String? clienteNome,
    String? localCliente,
    String? clienteFotoUrl,
    bool? isNovoCliente,
    String? emailNovoCliente,
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
      imagemProjeto: imagemProjeto ?? this.imagemProjeto,
    );
  }

  bool get isValid =>
      nome.trim().isNotEmpty &&
      (clienteId != null ||
          (emailNovoCliente != null && emailNovoCliente!.trim().isNotEmpty));

  ProjetoFormState withExistingClient({
    required String id,
    required String name,
    String? location,
    String? photoUrl,
  }) {
    return ProjetoFormState(
      nome: nome,
      clienteId: id,
      clienteNome: name,
      localCliente: location,
      clienteFotoUrl: photoUrl,
      imagemProjeto: imagemProjeto,
    );
  }

  ProjetoFormState withNewClient({
    required String name,
    required String email,
    String? localPhotoPath,
  }) {
    return ProjetoFormState(
      nome: nome,
      clienteNome: name,
      clienteFotoUrl: localPhotoPath,
      isNovoCliente: true,
      emailNovoCliente: email,
      imagemProjeto: imagemProjeto,
    );
  }
}
