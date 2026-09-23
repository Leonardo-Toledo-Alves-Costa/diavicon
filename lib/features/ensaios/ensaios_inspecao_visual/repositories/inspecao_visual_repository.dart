import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspecao_visual_geral_model.dart';

final inspecaoVisualRepoProvider = Provider((ref) => InspecaoVisualRepository(Supabase.instance.client));

// Provider atualizado para exigir Projeto e Estrutura
// Sem retry automático do Riverpod 3: em caso de erro ele repetia a consulta
// por ~38s com a tela em "carregando", e o erro real nunca aparecia.
final listaInspecoesGeraisProvider = FutureProvider.family.autoDispose<List<InspecaoVisualGeralModel>, ({String projetoId, String estruturaId})>(
  (ref, params) async {
    final repo = ref.read(inspecaoVisualRepoProvider);
    return repo.buscarInspecoesGerais(params.projetoId, params.estruturaId);
  },
  retry: (_, _) => null,
);

class InspecaoVisualRepository {
  final SupabaseClient _supabase;

  InspecaoVisualRepository(this._supabase);

  Future<List<InspecaoVisualGeralModel>> buscarInspecoesGerais(String projetoId, String estruturaId) async {
    try {
      final response = await _supabase
          .from('ponto_inspecao_visual_geral')
          .select('''
            *,
            pontos_ensaios_geral!inner (
              projeto_id,
              estrutura_id,
              criado_em,
              tipos_ensaio ( icone_path )
            ),
            ponto_inspecao_visual (
              id,
              estruturas_locais (nome),
              ponto_inspecao_visual_anomalia (risco_maj)
            )
          ''')
          // Filtra rigidamente pelo Projeto e pela Estrutura
          .eq('pontos_ensaios_geral.projeto_id', projetoId)
          .eq('pontos_ensaios_geral.estrutura_id', estruturaId);

      return (response as List).map((e) => InspecaoVisualGeralModel.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro de base de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  Future<void> criarNovaInspecao({
    required String nome,
    required String tipo,
    required String descricao,
    required String projetoId,
    required String estruturaId,
  }) async {
    String? idPontoGeral;
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Salva na tabela mãe com a estrutura_id
      final resGeral = await _supabase.from('pontos_ensaios_geral').insert({
        'nome_ponto': nome,
        'tipo_ensaio': 'Inspeção Visual',
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'criado_por': userId,
        // ID do tipo_ensaio para garantir que puxa o ícone correto depois
        'tipo_ensaio_id': '20c89940-e44c-4410-8a0b-1f42d20f16d6',
      }).select('id').single();

      idPontoGeral = resGeral['id'] as String;

      await _supabase.from('ponto_inspecao_visual_geral').insert({
        'nome': nome,
        'tipo': tipo,
        'descricao': descricao,
        'criado_por': userId,
        'id_ponto_geral': idPontoGeral,
      });
    } on PostgrestException catch (e) {
      // Se só o segundo insert falhou, a linha em pontos_ensaios_geral ficaria
      // órfã (invisível na lista de inspeções, mas contando em outras telas).
      if (idPontoGeral != null) {
        try {
          await _supabase.from('pontos_ensaios_geral').delete().eq('id', idPontoGeral);
        } catch (_) {}
      }
      throw Exception(mensagemErroCriacaoPonto(e));
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  /// Traduz a recusa do banco ao criar um ponto/campanha de ensaio. O RLS de
  /// `pontos_ensaios_geral` (private.can_access_project_member) exige usuário
  /// ativo, empresa vinculada ao projeto e o usuário ser admin da empresa OU
  /// estar ativo na equipe interna do projeto — o erro cru ("new row violates
  /// row-level security policy") não diz qual dessas faltou.
  static String mensagemErroCriacaoPonto(PostgrestException e) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return 'Seu usuário não tem permissão para criar ensaios neste projeto. '
          'Verifique se ele está ativo, se a sua empresa está vinculada ao projeto '
          'e se você faz parte da equipe do projeto (ou é admin da empresa).';
    }
    // Mensagens do trigger set_point_actor_company já são legíveis
    // (ex.: "A estrutura do ponto não pertence ao projeto.").
    return 'Erro ao criar inspeção: ${e.message}';
  }

  /// Exclui um único registro de inspeção (ON DELETE CASCADE já limpa suas
  /// anomalias, galeria e marcações em planta — não afeta os demais registros
  /// nem a campanha/o local a que ele pertence).
  Future<void> excluirRegistro(String pontoInspecaoId) async {
    try {
      await _supabase.from('ponto_inspecao_visual').delete().eq('id', pontoInspecaoId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir registro: ${e.message}');
    }
  }

  /// Exclui todos os registros de um local DENTRO de uma campanha específica
  /// — não apaga o local em si (`estruturas_locais`), que é da estrutura e
  /// pode ser usado por outras campanhas/ensaios.
  Future<void> excluirRegistrosDoLocal({required String inspecaoGeralId, required String localId}) async {
    try {
      await _supabase.from('ponto_inspecao_visual').delete().eq('id_ponto_geral', inspecaoGeralId).eq('id_local', localId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir registros do local: ${e.message}');
    }
  }

  /// Exclui a campanha de inspeção inteira. Apaga pela ponta de cima
  /// (`pontos_ensaios_geral`, a tabela guarda-chuva compartilhada entre todo
  /// tipo de ensaio) em vez de só `ponto_inspecao_visual_geral`, senão a
  /// linha em pontos_ensaios_geral ficaria órfã — o cascade desce sozinho até
  /// cada registro, anomalia, foto e marcação.
  Future<void> excluirInspecaoCompleta(String inspecaoGeralId) async {
    try {
      final campanha = await _supabase.from('ponto_inspecao_visual_geral').select('id_ponto_geral').eq('id', inspecaoGeralId).single();
      final idPontoGeral = campanha['id_ponto_geral'];
      if (idPontoGeral == null) {
        // Sem o vínculo pra pontos_ensaios_geral (dado legado/inconsistente):
        // exclui pelo menos a linha da campanha em si.
        await _supabase.from('ponto_inspecao_visual_geral').delete().eq('id', inspecaoGeralId);
        return;
      }
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', idPontoGeral);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir inspeção: ${e.message}');
    }
  }
}