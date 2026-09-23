import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. MODELS
// ==========================================
class EmpresaDetalheModel {
  final String id;
  final String nome;
  final String? descricao;
  final String? sobre;
  final String? fotoUrl;
  final String? fotoCapa;
  final String? cidade;
  final String? estado;
  final String? linkedin;
  final String? instagram;
  final String? youtube;
  final String? site;
  final String? emailContato;
  final String? whatsapp;
  final String? ramoAtuacao;
  final String cnpj;

  EmpresaDetalheModel({
    required this.id, required this.nome, required this.cnpj, this.descricao, this.fotoUrl, this.fotoCapa, this.sobre, this.ramoAtuacao,
    this.cidade, this.estado, this.linkedin, this.instagram, this.youtube,
    this.site, this.emailContato, this.whatsapp,
  });
}

class ColaboradorModel {
  final String id;
  final String nome;
  final String? sobrenome;
  final String? cargo;
  final String? fotoUrl;

  ColaboradorModel({
    required this.id, required this.nome, this.sobrenome, this.cargo, this.fotoUrl,
  });
}

class ServicoEmpresaModel {
  final String id;
  final String nome;
  final String? objetivo;
  final String? fotoPrincipal;
  final String? categoria;
  final String? linkAnexo;
  final String? nomeAnexo;
  final String empresaNome;
  final String? empresaFotoUrl;
  final String? cidade;
  final String? estado;
  final String? descricao;

  ServicoEmpresaModel({
    required this.id, required this.nome, this.objetivo, this.fotoPrincipal, this.nomeAnexo,
    this.categoria, this.linkAnexo, required this.empresaNome, this.empresaFotoUrl,
    this.cidade, this.estado, this.descricao,
  });
}

// ==========================================
// 2. CONTROLES DE ESTADO (UI)
// ==========================================
class EmpresaProfileTabNotifier extends Notifier<int> {
  @override int build() => 0; // 0 = Sobre, 1 = Serviços
  void set(int index) => state = index;
}
final empresaProfileTabProvider = NotifierProvider<EmpresaProfileTabNotifier, int>(EmpresaProfileTabNotifier.new);

class EmpresaServicoSearchNotifier extends Notifier<String> {
  @override String build() => '';
  void setBusca(String val) => state = val;
}
final empresaServicoSearchProvider = NotifierProvider<EmpresaServicoSearchNotifier, String>(EmpresaServicoSearchNotifier.new);

// ==========================================
// 3. PROVIDERS DE DADOS (SUPABASE)
// ==========================================

// Busca os detalhes da Empresa
final empresaDetalheProvider = FutureProvider.family.autoDispose<EmpresaDetalheModel, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client.rpc(
      'get_public_company',
      params: {'p_empresa_id': empresaId},
    );
    if (response is! List || response.isEmpty) {
      throw Exception('Empresa não encontrada ou inativa.');
    }
    final row = Map<String, dynamic>.from(response.first as Map);
    return EmpresaDetalheModel(
      id: row['empresa_id'].toString(),
      nome: row['nome']?.toString() ?? 'Empresa sem nome',
      descricao: row['descricao']?.toString(),
      sobre: row['sobre']?.toString(),
      fotoUrl: row['foto_url']?.toString(),
      fotoCapa: row['foto_capa']?.toString(),
      cidade: row['cidade']?.toString(),
      estado: row['estado']?.toString(),
      linkedin: row['linkedin']?.toString(),
      instagram: row['instagram']?.toString(),
      youtube: row['youtube']?.toString(),
      site: row['site']?.toString(),
      emailContato: row['email_contato']?.toString(),
      whatsapp: row['whatsapp']?.toString(),
      ramoAtuacao: row['ramo_atuacao']?.toString(),
      cnpj: row['cnpj']?.toString() ?? '',
    );
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar empresa: ${e.message}');
  }
});

// Busca os colaboradores públicos de QUALQUER empresa (não só a própria) —
// via `get_public_company_colaboradores`, mesmo padrão de exposição pública
// controlada já usado pra dados de outra empresa/usuário nesta tela
// (get_public_company, get_perfis_feed): só nome/sobrenome/cargo/foto de
// quem está ativo, nunca email/celular/is_admin etc.
final empresaColaboradoresProvider = FutureProvider.family.autoDispose<List<ColaboradorModel>, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client.rpc(
      'get_public_company_colaboradores',
      params: {'p_empresa_id': empresaId},
    );
    return (response as List).whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return ColaboradorModel(
        id: map['usuario_id'].toString(),
        nome: map['nome']?.toString() ?? '',
        sobrenome: map['sobrenome']?.toString(),
        cargo: map['cargo']?.toString(),
        fotoUrl: map['foto_url']?.toString(),
      );
    }).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar colaboradores: ${e.message}');
  }
});

// Busca os Serviços da Empresa filtrados pela busca
final empresaProfileServicosProvider = FutureProvider.family.autoDispose<List<ServicoEmpresaModel>, String>((ref, empresaId) async {
  final busca = ref.watch(empresaServicoSearchProvider).trim();
  
  try {
    final response = await Supabase.instance.client.rpc(
      'list_public_company_services',
      params: {
        'p_empresa_id': empresaId,
        'p_search': busca.isEmpty ? null : busca,
        'p_categoria': null,
        'p_limit': 100,
        'p_offset': 0,
      },
    );

    return (response as List).whereType<Map>().map((raw) {
      final e = Map<String, dynamic>.from(raw);
      return ServicoEmpresaModel(
        id: e['servico_id'].toString(),
        nome: e['nome']?.toString() ?? 'Serviço',
        objetivo: e['objetivo']?.toString(),
        fotoPrincipal: e['foto_principal']?.toString(),
        categoria: e['categoria']?.toString(),
        linkAnexo: e['link_anexo']?.toString(),
        nomeAnexo: e['nome_anexo']?.toString(),
        descricao: e['descricao']?.toString(),
        empresaNome: e['empresa_nome']?.toString() ?? '',
        empresaFotoUrl: e['empresa_foto_url']?.toString(),
        cidade: e['cidade']?.toString(),
        estado: e['estado']?.toString(),
      );
    }).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar serviços: ${e.message}');
  }
});
