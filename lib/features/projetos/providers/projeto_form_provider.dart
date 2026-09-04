import 'package:diavicon/features/projetos/models/projeto_form_state.dart';
import 'package:flutter_riverpod/legacy.dart';

final projetoFormProvider = StateProvider<ProjetoFormState>((ref) {
  return const ProjetoFormState();
});
