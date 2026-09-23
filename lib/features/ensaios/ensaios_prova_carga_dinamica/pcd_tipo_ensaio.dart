/// Identificação do ensaio "Prova de carga dinâmica".
///
/// O certo é reconhecer o ensaio pelo **id** do tipo em `tipos_ensaio`: o nome
/// pode ser editado no painel da empresa e contém "prova de carga", igual ao
/// da estática. O nome fica só como reserva, para o caso de o id ainda não
/// estar preenchido aqui.
library;

import '../ensaios_geral/models/tipos_ensaio_ids.dart';

/// Id da linha de `tipos_ensaio` com o nome "Prova de carga dinâmica".
const String kTipoEnsaioPcdId = TipoEnsaioId.provaCargaDinamica;

/// Nome usado ao criar os pontos deste ensaio.
const String kNomeTipoEnsaioPcd = 'Prova de carga dinâmica';

/// Verdadeiro quando o ensaio é o de prova de carga dinâmica.
///
/// Com o id preenchido em [kTipoEnsaioPcdId], a decisão é só pelo id. Sem
/// ele, cai na comparação por nome, que aceita com e sem acento.
bool ehProvaCargaDinamica({String? tipoEnsaioId, String? nomeTipoEnsaio}) {
  if (kTipoEnsaioPcdId.isNotEmpty) {
    if (tipoEnsaioId != null && tipoEnsaioId.isNotEmpty) {
      return tipoEnsaioId == kTipoEnsaioPcdId;
    }
  }
  final t = (nomeTipoEnsaio ?? '').toLowerCase();
  if (t.isEmpty) return false;
  return t.contains('dinâmic') ||
      t.contains('dinamic') ||
      t.contains('acelerometr') ||
      t.contains('acelerômetr');
}
