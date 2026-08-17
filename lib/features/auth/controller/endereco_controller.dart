import 'package:diavicon/features/auth/models/endereco_model.dart';
import 'package:diavicon/features/auth/providers/endereco_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class EnderecoController extends StateNotifier<EnderecoModel?> {
  final Ref _ref; 
  
  EnderecoController(this._ref) : super(null);

  Future<EnderecoModel?> salvarEndereco(Map<String, dynamic> dadosEndereco) async {
    final enderecoRepository = _ref.read(enderecoRepositoryProvider);
    final enderecoData = await enderecoRepository.salvarEndereco(dadosEndereco);
    if (enderecoData != null) {
      state = EnderecoModel.fromMap(enderecoData);
      return state;
    }
    return null;
  }

  Future<EnderecoModel?> buscarEndereco(String idUsuario) async {
    final enderecoRepository = _ref.read(enderecoRepositoryProvider);
    final enderecoData = await enderecoRepository.getEndereco(idUsuario);
    if (enderecoData != null) {
      state = EnderecoModel.fromMap(enderecoData.toMap());
      return state;
    }
    return null;
  }

  Future<void> atualizarEndereco(String enderecoId, EnderecoModel endereco) async {
    final enderecoRepository = _ref.read(enderecoRepositoryProvider);
    final enderecoData = await enderecoRepository.atualizarEndereco(enderecoId, endereco.toMap());
    if (enderecoData != null) {
      state = EnderecoModel.fromMap(enderecoData);
    }
  }
}