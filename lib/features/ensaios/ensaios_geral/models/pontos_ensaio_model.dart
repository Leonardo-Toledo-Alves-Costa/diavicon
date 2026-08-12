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
  final String avatarEmpresaUrl;

  // Dados de Risco / Resultados (Dinâmicos)
  final String textoRisco;
  final String corFundoRisco;
  final String corTextoRisco;

  PontoEnsaioModel({
    required this.id,
    required this.nome,
    required this.elementoId,
    required this.elementoNome,
    required this.tipoElemento,
    required this.tipoEnsaioId,
    required this.local,
    required this.fotoElementoUrl,
    required this.avatarEmpresaUrl,
    required this.textoRisco,
    required this.corFundoRisco,
    required this.corTextoRisco,
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
      
      // Se houver um join com a empresa criadora, mapeie aqui. Caso contrário, use um placeholder.
      avatarEmpresaUrl: json['avatar_empresa'] ?? 'https://via.placeholder.com/150',

      // 👇 AQUI A MÁGICA ACONTECE: Lendo as novas colunas do banco
      textoRisco: json['valor_resultado'] ?? 'Pendente',
      corFundoRisco: json['cor_resultado'] ?? '#E0E0E0', // Cinza padrão se for nulo
      
      // Lógica dinâmica para a cor da fonte: 
      // Se tiver resultado (não for nulo e não for pendente), a fonte fica Branca.
      // Se estiver pendente, a fonte fica Cinza Escuro.
      corTextoRisco: (json['valor_resultado'] != null && json['valor_resultado'] != 'Pendente') 
          ? '#FFFFFF' 
          : '#3E3E3D',
    );
  }
}