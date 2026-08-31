import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

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
    final response = await Supabase.instance.client
        .from('empresas')
        .select('*, enderecos(cidade, estado)')
        .eq('id', empresaId)
        .single();

    final end = response['enderecos'] as Map<String, dynamic>?;
    return EmpresaDetalheModel(
      id: response['id'],
      nome: response['nome'] ?? 'Empresa sem nome',
      descricao: response['descricao'],
      sobre: response['sobre'], // 🔥 N
      fotoUrl: response['foto_url'],
      fotoCapa: response['foto_capa'],
      cidade: end?['cidade'],
      estado: end?['estado'],
      linkedin: response['linkedin'],
      instagram: response['instagram'],
      youtube: response['youtube'],
      site: response['site'],
      emailContato: response['email_contato'],
      whatsapp: response['whatsapp'],
      ramoAtuacao: response['ramo_atuacao'],
      cnpj: response['cnpj'],
    );
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar empresa: ${e.message}');
  }
});

// Busca os colaboradores da Empresa
final empresaColaboradoresProvider = FutureProvider.family.autoDispose<List<ColaboradorModel>, String>((ref, empresaId) async {
  try {
    final response = await Supabase.instance.client
        .from('usuarios')
        .select('id, nome, sobrenome, cargo, foto_url')
        .eq('empresa_id', empresaId)
        .eq('ativo', true);

    return response.map((e) => ColaboradorModel(
      id: e['id'],
      nome: e['nome'] ?? '',
      sobrenome: e['sobrenome'],
      cargo: e['cargo'],
      fotoUrl: e['foto_url'],
    )).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar colaboradores: ${e.message}');
  }
});

// Busca os Serviços da Empresa filtrados pela busca
final empresaProfileServicosProvider = FutureProvider.family.autoDispose<List<ServicoEmpresaModel>, String>((ref, empresaId) async {
  final busca = ref.watch(empresaServicoSearchProvider).trim();
  
  try {
    var query = Supabase.instance.client
        .from('empresa_servicos')
        .select('*, empresas!inner(nome, foto_url, enderecos(cidade, estado))')
        .eq('empresa_id', empresaId);

    if (busca.isNotEmpty) {
      query = query.ilike('nome', '%$busca%');
    }

    final response = await query;

    return response.map((e) {
      final emp = e['empresas'] as Map<String, dynamic>;
      final end = emp['enderecos'] as Map<String, dynamic>?;
      return ServicoEmpresaModel(
        id: e['id'],
        nome: e['nome'] ?? 'Serviço',
        objetivo: e['objetivo'],
        fotoPrincipal: e['foto_principal'],
        categoria: e['categoria'],
        linkAnexo: e['link_anexo'],
        nomeAnexo: e['nome_anexo'],
        descricao: e['descricao'],
        empresaNome: emp['nome'] ?? '',
        empresaFotoUrl: emp['foto_url'],
        cidade: end?['cidade'],
        estado: end?['estado'],
      );
    }).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar serviços: ${e.message}');
  }
});