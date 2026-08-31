import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leitura_prova_carga_model.dart';
import '../models/ponto_medicao_model.dart';
import '../models/ponto_prova_carga_model.dart';

class ProvaCargaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Cria o registro comum (`pontos_ensaios_geral`) e a Área de Ensaio
  /// (`ponto_ensaio_prova_carga`) já com a marcação feita na planta. Usado
  /// no fluxo de criação (passo 1 -> marcação da área -> tela principal).
  Future<Map<String, String>> criarAreaInicial({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    required PontoProvaCargaModel area,
  }) async {
    try {
      final geralResp = await _supabase.from('pontos_ensaios_geral').insert({
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
        'tipo_ensaio_id': tipoEnsaioId,
        'elemento_estrutural_id': area.elementoId,
        'nome_ponto': area.nome,
        'tipo_ensaio': 'Prova de Carga Estática',
        'criado_por': _supabase.auth.currentUser?.id,
        'criado_em': DateTime.now().toIso8601String(),
        'valor_resultado': 'Pendente',
        'cor_resultado': '#BDBDBD',
      }).select('id').single();

      final pontoGeralId = geralResp['id'] as String;

      final areaResp = await _supabase
          .from('ponto_ensaio_prova_carga')
          .insert(area.toJson(pontoGeralId: pontoGeralId))
          .select('id')
          .single();

      return {
        'pontoGeralId': pontoGeralId,
        'pontoCargaId': areaResp['id'] as String,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado ao criar área de ensaio: $e');
    }
  }

  /// Carrega tudo que já existe para um ponto geral: a área, os pontos de
  /// medição e as leituras de cada um (agrupadas pelo nome do ponto).
  Future<Map<String, dynamic>> carregarPonto(String pontoGeralId) async {
    try {
      final geral = await _supabase
          .from('pontos_ensaios_geral')
          .select('*')
          .eq('id', pontoGeralId)
          .maybeSingle();

      final areaResp = await _supabase
          .from('ponto_ensaio_prova_carga')
          .select('*')
          .eq('ponto_geral_id', pontoGeralId)
          .maybeSingle();

      final area = areaResp != null ? PontoProvaCargaModel.fromJson(areaResp) : null;

      List<PontoMedicaoModel> pontosMedicao = [];
      List<LeituraProvaCargaModel> leituras = [];

      if (area?.id != null) {
        final medicoesResp = await _supabase
            .from('ponto_ensaio_prova_carga_ponto_medicao')
            .select('*')
            .eq('ponto_carga_id', area!.id!)
            .order('criado_em', ascending: true);

        pontosMedicao = (medicoesResp as List)
            .map((m) => PontoMedicaoModel.fromJson(m))
            .toList();

        final medicaoIds = pontosMedicao.where((p) => p.id != null).map((p) => p.id!).toList();

        if (medicaoIds.isNotEmpty) {
          final leiturasResp = await _supabase
              .from('ponto_ensaio_prova_carga_ponto_leitura')
              .select('*')
              .inFilter('ponto_medicao_id', medicaoIds)
              .order('criado_em', ascending: true);

          final nomePorId = {for (final p in pontosMedicao) p.id: p.nome};

          leituras = (leiturasResp as List).map((l) {
            final nome = nomePorId[l['ponto_medicao_id']?.toString()] ?? '';
            return LeituraProvaCargaModel.fromJson(l, pontoMedicaoNome: nome);
          }).toList();
        }
      }

      return {
        'nomePonto': geral?['nome_ponto'],
        'estruturaId': geral?['estrutura_id'],
        'projetoId': geral?['projeto_id'],
        'tipoEnsaioId': geral?['tipo_ensaio_id'],
        'area': area,
        'pontosMedicao': pontosMedicao,
        'leituras': leituras,
      };
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    }
  }

  /// Resolve o "Local" de uma prova de carga a partir do elemento estrutural
  /// vinculado (não existe coluna própria de local em `ponto_ensaio_prova_carga`).
  ///
  /// Antes isso era resolvido casando `planta_foto` com `estruturas_plantas`,
  /// mas como `planta_foto` agora também guarda a imagem composta (planta +
  /// marcações, não mais o arquivo original), essa checagem deixou de bater
  /// — resolver via `elemento_id` é robusto independente do que estiver em
  /// `planta_foto`.
  Future<String?> resolverLocalPeloElemento(String? elementoId) async {
    if (elementoId == null || elementoId.isEmpty) return null;
    try {
      final elemento = await _supabase
          .from('elementos_estruturais')
          .select('local')
          .eq('id', elementoId)
          .maybeSingle();
      return elemento?['local'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Salva tudo de uma vez: área, pontos de medição e leituras. Segue o
  /// mesmo padrão "salvar tudo junto" do ensaio de resistividade.
  Future<Map<String, dynamic>> salvarPonto({
    required String pontoGeralId,
    required String nome,
    required PontoProvaCargaModel area,
    required List<PontoMedicaoModel> pontosMedicao,
    required List<LeituraProvaCargaModel> leituras,
    required String valorResultado,
    required String corResultado,
  }) async {
    try {
      await _supabase.from('pontos_ensaios_geral').update({
        'nome_ponto': nome,
        'elemento_estrutural_id': area.elementoId,
        'valor_resultado': valorResultado,
        'cor_resultado': corResultado,
      }).eq('id', pontoGeralId);

      String? pontoCargaId = area.id;
      final areaJson = area.copyWith(nome: nome).toJson(pontoGeralId: pontoGeralId);

      if (pontoCargaId != null) {
        await _supabase.from('ponto_ensaio_prova_carga').update(areaJson).eq('id', pontoCargaId);
      } else {
        final resp = await _supabase
            .from('ponto_ensaio_prova_carga')
            .insert(areaJson)
            .select('id')
            .single();
        pontoCargaId = resp['id'] as String;
      }

      final Map<String, String> idPorNome = {};
      for (final ponto in pontosMedicao) {
        if (ponto.id != null) {
          await _supabase
              .from('ponto_ensaio_prova_carga_ponto_medicao')
              .update(ponto.toJson(pontoCargaId: pontoCargaId))
              .eq('id', ponto.id!);
          idPorNome[ponto.nome] = ponto.id!;
        } else {
          final resp = await _supabase
              .from('ponto_ensaio_prova_carga_ponto_medicao')
              .insert(ponto.toJson(pontoCargaId: pontoCargaId))
              .select('id')
              .single();
          idPorNome[ponto.nome] = resp['id'] as String;
        }
      }

      for (final leitura in leituras) {
        final pontoMedicaoId = idPorNome[leitura.pontoMedicaoNome];
        if (pontoMedicaoId == null) continue;

        if (leitura.id != null) {
          await _supabase
              .from('ponto_ensaio_prova_carga_ponto_leitura')
              .update(leitura.toJson(pontoMedicaoId: pontoMedicaoId))
              .eq('id', leitura.id!);
        } else {
          await _supabase
              .from('ponto_ensaio_prova_carga_ponto_leitura')
              .insert(leitura.toJson(pontoMedicaoId: pontoMedicaoId));
        }
      }

      return {'pontoGeralId': pontoGeralId, 'pontoCargaId': pontoCargaId};
    } on PostgrestException catch (e) {
      throw Exception('Erro de banco de dados: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado ao salvar: $e');
    }
  }

  /// Salva a captura da planta com a Área de Ensaio e os pontos de medição
  /// já desenhados por cima (gerada via `RepaintBoundary` na tela): guarda
  /// tanto na galeria genérica do ponto (substituindo a versão anterior)
  /// quanto em `ponto_ensaio_prova_carga.planta_foto`.
  ///
  /// A partir daqui `planta_foto` deixa de ser o arquivo original da planta
  /// e passa a ser essa imagem composta — por isso o Local é resolvido via
  /// `elemento_id` (`resolverLocalPeloElemento`), não mais casando
  /// `planta_foto` com `estruturas_plantas`. Chame isso sempre DEPOIS de
  /// `salvarPonto`, senão o `update` de área sobrescreve esse valor com o
  /// `plantaFoto` antigo que ainda estiver em memória.
  static const _legendaImagemComposta = 'Planta com marcações';

  Future<void> salvarImagemComposta({required String pontoGeralId, required File imagem}) async {
    try {
      final path = 'ensaios/prova_carga/${pontoGeralId}_marcada_${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('projetos').upload(path, imagem, fileOptions: const FileOptions(upsert: true));
      final url = _supabase.storage.from('projetos').getPublicUrl(path);

      await _supabase
          .from('galeria_pontos_ensaios_geral')
          .delete()
          .eq('ponto_ensaio_id', pontoGeralId)
          .eq('legenda', _legendaImagemComposta);

      await _supabase.from('galeria_pontos_ensaios_geral').insert({
        'ponto_ensaio_id': pontoGeralId,
        'imagem_url': url,
        'legenda': _legendaImagemComposta,
        'criado_por': _supabase.auth.currentUser?.id,
        'criado_em': DateTime.now().toIso8601String(),
      });

      await _supabase
          .from('ponto_ensaio_prova_carga')
          .update({'planta_foto': url})
          .eq('ponto_geral_id', pontoGeralId);
    } catch (e) {
      throw Exception('Erro ao salvar imagem da planta marcada: $e');
    }
  }

  Future<void> deletarLeitura(String idLeitura) async {
    try {
      await _supabase.from('ponto_ensaio_prova_carga_ponto_leitura').delete().eq('id', idLeitura);
    } catch (e) {
      throw Exception('Erro ao deletar medição: $e');
    }
  }

  Future<void> deletarPontoMedicao(String idPontoMedicao) async {
    try {
      await _supabase
          .from('ponto_ensaio_prova_carga_ponto_leitura')
          .delete()
          .eq('ponto_medicao_id', idPontoMedicao);
      await _supabase
          .from('ponto_ensaio_prova_carga_ponto_medicao')
          .delete()
          .eq('id', idPontoMedicao);
    } catch (e) {
      throw Exception('Erro ao deletar ponto de medição: $e');
    }
  }

  Future<void> deletarPontoCompleto(String pontoGeralId) async {
    try {
      final areaResp = await _supabase
          .from('ponto_ensaio_prova_carga')
          .select('id')
          .eq('ponto_geral_id', pontoGeralId)
          .maybeSingle();

      final pontoCargaId = areaResp?['id']?.toString();

      if (pontoCargaId != null) {
        final medicoesResp = await _supabase
            .from('ponto_ensaio_prova_carga_ponto_medicao')
            .select('id')
            .eq('ponto_carga_id', pontoCargaId);

        final medicaoIds = (medicoesResp as List).map((m) => m['id'].toString()).toList();

        if (medicaoIds.isNotEmpty) {
          await _supabase
              .from('ponto_ensaio_prova_carga_ponto_leitura')
              .delete()
              .inFilter('ponto_medicao_id', medicaoIds);
        }

        await _supabase
            .from('ponto_ensaio_prova_carga_ponto_medicao')
            .delete()
            .eq('ponto_carga_id', pontoCargaId);

        await _supabase.from('ponto_ensaio_prova_carga').delete().eq('id', pontoCargaId);
      }

      await _supabase.from('galeria_pontos_ensaios_geral').delete().eq('ponto_ensaio_id', pontoGeralId);
      await _supabase.from('pontos_ensaios_geral').delete().eq('id', pontoGeralId);
    } catch (e) {
      throw Exception('Erro ao excluir ponto: $e');
    }
  }
}
