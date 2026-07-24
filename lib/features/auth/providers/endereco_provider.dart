import 'package:diavicon/features/auth/controller/endereco_controller.dart';
import 'package:diavicon/features/auth/models/endereco_model.dart';
import 'package:diavicon/features/auth/repositories/endereco_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final enderecoControllerProvider = StateNotifierProvider<EnderecoController, EnderecoModel?>((ref) {
  return EnderecoController(ref);
});


final enderecoRepositoryProvider = Provider((ref) => EnderecoRepository());