/// Ids da tabela `tipos_ensaio` — a chave de verdade de cada ensaio.
///
/// O nome do ensaio é texto editável e muda de acento, de maiúscula e de
/// grafia; onde ele foi usado como chave, algo quebrou em silêncio:
///  * o dashboard da inspeção visual ficava "sem dados suficientes" porque
///    procurava o tipo por "inspeção visual";
///  * "prova de carga" casa também com "Prova de carga dinâmica".
///
/// Quem precisar identificar um ensaio usa estas constantes. Os ids que
/// faltam entram aqui conforme forem confirmados no banco
/// (`select id, nome from tipos_ensaio order by nome;`).
abstract final class TipoEnsaioId {
  static const inspecaoVisual = '20c89940-e44c-4410-8a0b-1f42d20f16d6';
  static const arrancamentoArgamassa = '082321cb-ce13-4205-95f1-ec767b5e7d53';
  static const arrancamentoCeramica = 'f965252e-f5ad-48d2-9ac4-804a40a4a8d8';
  static const provaCargaDinamica = '395d56da-d218-41cd-8b43-6e81b7de3294';
}
