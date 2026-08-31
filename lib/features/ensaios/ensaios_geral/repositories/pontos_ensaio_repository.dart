import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pontos_ensaio_model.dart';

class PontosEnsaioRepository {
  final SupabaseClient _supabase;
  PontosEnsaioRepository(this._supabase);

  Future<List<PontoEnsaioModel>> getPontosEnsaio({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    String? elementoId,
  }) async {
    try {
      // 1. Busca os pontos de ensaio cruzando com os elementos
      // Left join: ensaios como a prova de carga estática não se vinculam a
      // um elemento_estrutural (elemento_estrutural_id fica nulo), então um
      // inner join aqui os excluiria da lista. Filtramos por estrutura_id
      // diretamente em pontos_ensaios_geral (coluna já preenchida por todos
      // os ensaios) em vez de via elementos_estruturais.
      var query = _supabase
          .from('pontos_ensaios_geral')
          .select('''
            id,
            nome_ponto,
            criado_por,
            criado_em,
            valor_resultado,
            cor_resultado,
            tipo_ensaio_id,
            elementos_estruturais (
              id,
              nome,
              tipo,
              local,
              fotos
            )
          ''') // <-- 'criado_em' adicionado
          .eq('projeto_id', projetoId)
          .eq('tipo_ensaio_id', tipoEnsaioId)
          .eq('estrutura_id', estruturaId);

          // 2. Aplica o filtro de elemento dinamicamente
      if (elementoId != null && elementoId.isNotEmpty) {
        query = query.eq('elemento_estrutural_id', elementoId);
      }

      final response = await query;

      final List data = response as List;
      if (data.isEmpty) return [];

      // 2. Coletar IDs dos autores para buscar a logo das empresas
      final autoresIds = data
          .map((row) => row['criado_por']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, String> logosEmpresas = {};

      if (autoresIds.isNotEmpty) {
        final usuariosResp = await _supabase
            .from('usuarios')
            .select('id, empresas(foto_url)')
            .inFilter('id', autoresIds);

        for (var u in usuariosResp) {
          final emp = u['empresas'] as Map<String, dynamic>?;
          logosEmpresas[u['id'].toString()] = emp?['foto_url'] ?? '';
        }
      }

      // 3. Montar a lista final
      return data.map((row) {
        final el = row['elementos_estruturais'] as Map<String, dynamic>?;
        final String criadoPor = row['criado_por']?.toString() ?? '';

        final List? arrayFotos = el?['fotos'] as List?;
        final String fotoElemento = (arrayFotos != null && arrayFotos.isNotEmpty)
            ? arrayFotos.first.toString()
            : 'https://via.placeholder.com/150';

        final String? valorBanco = row['valor_resultado']?.toString();
        final String? corBanco = row['cor_resultado']?.toString();

        String txtRisco = valorBanco ?? 'Pendente';
        String bgRisco = corBanco ?? '#F5F5F5';
        String txtCorRisco = (valorBanco != null && valorBanco != 'Pendente') 
            ? '#FFFFFF' 
            : '#3E3E3D';
            
        // Tratamento seguro do DateTime
        DateTime dataCriacao = DateTime.now();
        if (row['criado_em'] != null) {
          dataCriacao = DateTime.tryParse(row['criado_em'].toString()) ?? DateTime.now();
        }

        return PontoEnsaioModel(
          id: row['id'].toString(),
          nome: row['nome_ponto'] ?? 'Ponto sem nome',
          elementoId: el?['id']?.toString() ?? '',
          elementoNome: el?['nome'] ?? row['nome_ponto'] ?? 'Ponto sem nome',
          tipoElemento: el?['tipo'] ?? '-',
          local: el?['local'] ?? 'Não informado',
          fotoElementoUrl: fotoElemento,
          avatarEmpresaUrl: logosEmpresas[criadoPor] != null && logosEmpresas[criadoPor]!.isNotEmpty
              ? logosEmpresas[criadoPor]!
              : 'https://via.placeholder.com/150',
          textoRisco: txtRisco.toUpperCase(),
          corFundoRisco: bgRisco,
          corTextoRisco: txtCorRisco,
          tipoEnsaioId: row['tipo_ensaio_id']?.toString() ?? tipoEnsaioId,
          criadoEm: dataCriacao, // <-- Passando a data para o Model
        );
      }).toList();

    } on PostgrestException catch (e) {
      throw Exception('Erro ao buscar pontos de ensaio: ${e.message}');
    }
  }
}