import 'package:diavicon/features/ensaios/ensaios_geral/models/regiao_ensaio_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//PROVIDER PARA BUSCAR AS EMPRESAS DO PROJETO E AS PERMISSÕES
typedef InfoPlanejamentoParams = ({String estruturaId, String projetoId});

final infoPlanejamentoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, InfoPlanejamentoParams>((ref, params) async {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) throw Exception('Sessão expirada');

      //  Descobre a empresa do usuário logado
      final userResp = await supabase
          .from('usuarios')
          .select('empresa_id')
          .eq('id', userId)
          .maybeSingle();
      final minhaEmpresaId = userResp?['empresa_id'];

      // Busca a empresa gestora da Estrutura
      final estResp = await supabase
          .from('estruturas')
          .select('empresa_gestora_id')
          .eq('id', params.estruturaId)
          .maybeSingle();
      final gestoraId = estResp?['empresa_gestora_id'];

      // O projeto vem do contexto de navegação. Uma estrutura pode estar vinculada
      // a vários projetos, portanto não use maybeSingle() sem esse filtro.
      final projetoVinculo = await supabase
          .from('projeto_estruturas')
          .select('projeto_id')
          .eq('estrutura_id', params.estruturaId)
          .eq('projeto_id', params.projetoId)
          .maybeSingle();
      if (projetoVinculo == null) {
        throw Exception('Estrutura não vinculada ao projeto selecionado.');
      }
      final projetoId = params.projetoId;

      // Monta a lista de empresas (Gestora + Colaboradoras Aceitas)
      List<Map<String, dynamic>> empresas = [];

      // Adiciona a Gestora
      if (gestoraId != null) {
        final gestResp = await supabase
            .from('empresas')
            .select('id, nome, foto_url')
            .eq('id', gestoraId)
            .maybeSingle();
        if (gestResp != null) empresas.add(gestResp);
      }

      // Adiciona as Colaboradoras
      final colabResp = await supabase
          .from('projeto_empresas_colaboradoras')
          .select('empresas:empresa_id(id, nome, foto_url)')
          .eq('projeto_id', projetoId)
          .eq('status', 'aceito');

      for (var item in (colabResp as List)) {
        final emp = item['empresas'];
        if (emp != null && !empresas.any((e) => e['id'] == emp['id'])) {
          empresas.add(emp);
        }
      }

      return {
        'minhaEmpresaId': minhaEmpresaId,
        'gestoraId': gestoraId,
        'empresas': empresas,
      };
    });

class RegioesFiltro {
  final String plantaId;
  final String projetoId;
  final String empresaId;

  RegioesFiltro({
    required this.plantaId,
    required this.projetoId,
    required this.empresaId,
  });

  // Ensina o Dart a comparar os valores reais, resolvendo o loop infinito
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegioesFiltro &&
          runtimeType == other.runtimeType &&
          plantaId == other.plantaId &&
          projetoId == other.projetoId &&
          empresaId == other.empresaId;

  @override
  int get hashCode =>
      plantaId.hashCode ^ projetoId.hashCode ^ empresaId.hashCode;
}

/// Quantidade de tipos de ensaio contratados por região (agrupado por
/// `regiao_id` em `ensaios_contratados`). A região em si só guarda o
/// desenho/marcação da planta; os quantitativos contratados vivem em
/// `ensaios_contratados`.
final quantidadeEnsaiosPorRegiaoProvider = FutureProvider.autoDispose
    .family<Map<String, int>, RegioesFiltro>((ref, filtro) async {
      final supabase = Supabase.instance.client;

      final regioesResp = await supabase
          .from('regioes_ensaio')
          .select('id')
          .eq('planta_id', filtro.plantaId)
          .eq('projeto_id', filtro.projetoId)
          .eq('empresa_id', filtro.empresaId);

      final regiaoIds = (regioesResp as List)
          .map((r) => r['id'].toString())
          .toList();
      if (regiaoIds.isEmpty) return {};

      final contratadosResp = await supabase
          .from('ensaios_contratados')
          .select('regiao_id')
          .inFilter('regiao_id', regiaoIds)
          .eq('projeto_id', filtro.projetoId);

      final Map<String, int> contagem = {};
      for (final row in (contratadosResp as List)) {
        final regiaoId = row['regiao_id']?.toString();
        if (regiaoId != null) {
          contagem[regiaoId] = (contagem[regiaoId] ?? 0) + 1;
        }
      }
      return contagem;
    });

final regioesEnsaioProvider = StreamProvider.autoDispose
    .family<List<RegiaoEnsaioModel>, RegioesFiltro>((ref, filtro) {
      final supabase = Supabase.instance.client;

      return supabase
          .from('regioes_ensaio')
          .stream(primaryKey: ['id'])
          .order('numero', ascending: true)
          .asyncMap((data) async {
            List<RegiaoEnsaioModel> regioes = [];

            for (var row in data) {
              // Filtro secundário na memória do Dart
              if (row['planta_id'] != filtro.plantaId ||
                  row['projeto_id'] != filtro.projetoId ||
                  row['empresa_id'] != filtro.empresaId) {
                continue;
              }

              Map<String, dynamic> rowData = Map<String, dynamic>.from(row);

              // Busca o nome do elemento vinculado
              if (row['elemento_id'] != null) {
                final elResp = await supabase
                    .from('elementos_estruturais')
                    .select('nome, tipo')
                    .eq('id', row['elemento_id'])
                    .maybeSingle();
                if (elResp != null) rowData['elementos_estruturais'] = elResp;
              }
              regioes.add(RegiaoEnsaioModel.fromMap(rowData));
            }
            return regioes;
          });
    });
