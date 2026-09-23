import 'package:diavicon/features/modelos_relatorios/models/modelo_relatorio_schema.dart'
    show SecaoQuadroConfig, InformacoesIniciaisConfig, GaleriaConfig, DecoracaoGlobalConfig;
import 'package:diavicon/features/modelos_relatorios/models/quadro_model.dart' show Quadro;

/// Schema de um modelo de relatório de RDO. Cabeçalho, Informações iniciais,
/// Registros (agora um `QuadroEditor` normal, como nos ensaios — ver
/// `campos_registro_rdo.dart`), Galeria e Decoração reaproveitam
/// integralmente os tipos/editores genéricos já usados pelos relatórios de
/// ensaio; RDO não tem Referencial/Registros agrupados/Tabela resumo.
class ModeloRdoSchema {
  final SecaoQuadroConfig cabecalho;
  final InformacoesIniciaisConfig informacoesIniciais;
  final SecaoQuadroConfig registros;
  final GaleriaConfig galeria;
  final DecoracaoGlobalConfig decoracao;

  const ModeloRdoSchema({
    required this.cabecalho,
    required this.informacoesIniciais,
    required this.registros,
    required this.galeria,
    required this.decoracao,
  });

  factory ModeloRdoSchema.vazio() => ModeloRdoSchema(
    cabecalho: const SecaoQuadroConfig(ativo: true, quadro: Quadro(linhas: [])),
    informacoesIniciais: InformacoesIniciaisConfig.vazio(),
    registros: const SecaoQuadroConfig(ativo: true, quadro: Quadro(linhas: [])),
    galeria: GaleriaConfig.vazio(),
    decoracao: DecoracaoGlobalConfig.vazio(),
  );

  factory ModeloRdoSchema.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return ModeloRdoSchema.vazio();
    return ModeloRdoSchema(
      cabecalho: SecaoQuadroConfig.fromJson((json['cabecalho'] as Map?)?.cast<String, dynamic>() ?? const {}),
      informacoesIniciais: InformacoesIniciaisConfig.fromJson((json['informacoes_iniciais'] as Map?)?.cast<String, dynamic>() ?? const {}),
      registros: SecaoQuadroConfig.fromJson((json['registros'] as Map?)?.cast<String, dynamic>() ?? const {}),
      galeria: GaleriaConfig.fromJson((json['galeria'] as Map?)?.cast<String, dynamic>() ?? const {}),
      decoracao: DecoracaoGlobalConfig.fromJson((json['decoracao'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'cabecalho': cabecalho.toJson(),
    'informacoes_iniciais': informacoesIniciais.toJson(),
    'registros': registros.toJson(),
    'galeria': galeria.toJson(),
    'decoracao': decoracao.toJson(),
  };

  ModeloRdoSchema copyWith({
    SecaoQuadroConfig? cabecalho,
    InformacoesIniciaisConfig? informacoesIniciais,
    SecaoQuadroConfig? registros,
    GaleriaConfig? galeria,
    DecoracaoGlobalConfig? decoracao,
  }) {
    return ModeloRdoSchema(
      cabecalho: cabecalho ?? this.cabecalho,
      informacoesIniciais: informacoesIniciais ?? this.informacoesIniciais,
      registros: registros ?? this.registros,
      galeria: galeria ?? this.galeria,
      decoracao: decoracao ?? this.decoracao,
    );
  }
}
