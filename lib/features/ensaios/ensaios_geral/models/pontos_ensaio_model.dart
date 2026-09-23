import '../../../../core/models/autor_exibicao.dart';

class PontoEnsaioModel {
  final String id;
  final String nome;
  final String elementoId;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String tipoEnsaioId;

  // Dados Visuais
  final String fotoElementoUrl;

  /// Quem registrou o ponto: logo da empresa e, pra quem é da mesma empresa
  /// do autor, também o nome e a foto dele. Nulo quando o autor é
  /// desconhecido ou a consulta de autoria falhou — o selo some e o card
  /// segue normal.
  final AutorExibicao? autor;

  // Dados de Risco / Resultados (Dinâmicos)
  final String textoRisco;
  final String corFundoRisco;
  final String corTextoRisco;
  final DateTime criadoEm; // <-- NOVO CAMPO

  // Só preenchidos pra pontos de Ultrassonografia (join com
  // `ponto_ensaio_ultrassom`) — indicam o método de coleta usado
  // ('direto'/'indireto'/'mapeamento') e o pulso ('Longitudinal'/
  // 'Transversal'), pra exibir um badge no card sem precisar abrir o ponto.
  final String? modoUltrassom;
  final String? pulsoUltrassonico;

  PontoEnsaioModel({
    required this.id,
    required this.nome,
    required this.elementoId,
    required this.elementoNome,
    required this.tipoElemento,
    required this.tipoEnsaioId,
    required this.local,
    required this.fotoElementoUrl,
    this.autor,
    required this.textoRisco,
    required this.corFundoRisco,
    required this.corTextoRisco,
    required this.criadoEm, // <-- NOVO CAMPO NO CONSTRUTOR
    this.modoUltrassom,
    this.pulsoUltrassonico,
  });

  factory PontoEnsaioModel.fromJson(Map<String, dynamic> json) {
    // Tratamento para ler os dados do elemento estrutural que vêm via JOIN do Supabase
    final elementoMap = json['elementos_estruturais'] as Map<String, dynamic>? ?? {};
    
    // Tratamento para ler a primeira foto do array de fotos do elemento (se houver)
    String fotoUrl = '';
    if (elementoMap['fotos'] != null && (elementoMap['fotos'] as List).isNotEmpty) {
      fotoUrl = elementoMap['fotos'][0].toString();
    }

    return PontoEnsaioModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome_ponto'] ?? 'Ponto sem nome',
      elementoId: json['elemento_estrutural_id']?.toString() ?? '',
      elementoNome: elementoMap['nome'] ?? 'Elemento',
      tipoElemento: elementoMap['tipo'] ?? '-',
      local: elementoMap['local'] ?? '-',
      fotoElementoUrl: fotoUrl,
      tipoEnsaioId: json['tipo_ensaio_id']?.toString() ?? '',
      
      // Autoria é resolvida à parte, em lote, pelo repositório (uma RPC pra
      // todos os pontos da lista) — não vem neste json.

      // 👇 AQUI A MÁGICA ACONTECE: Lendo as novas colunas do banco
      textoRisco: json['valor_resultado'] ?? 'Pendente',
      corFundoRisco: json['cor_resultado'] ?? '#E0E0E0', // Cinza padrão se for nulo
      criadoEm: json['criado_em'],
      
      // Lógica dinâmica para a cor da fonte: 
      // Se tiver resultado (não for nulo e não for pendente), a fonte fica Branca.
      // Se estiver pendente, a fonte fica Cinza Escuro.
      corTextoRisco: (json['valor_resultado'] != null && json['valor_resultado'] != 'Pendente') 
          ? '#FFFFFF' 
          : '#3E3E3D',
    );
  }
}