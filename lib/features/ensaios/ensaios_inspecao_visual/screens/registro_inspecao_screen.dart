import 'package:diavicon/core/security/upload_seguro.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/foto_otimizacao_service.dart';
import '../../../../core/services/foto_watermark_service.dart';
import '../../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../empresa/models/timestamp_foto_padrao_model.dart';
import '../../../elementos/providers/plantas_provider.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../../../empresa/providers/empresa_profile_provider.dart';
import '../../../empresa/repositories/timestamp_foto_padrao_repository.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../repositories/inspecao_visual_repository.dart';
import '../utils/risco_gut_calculo.dart';
import 'inspecao_visual_local_screen.dart';
import 'visao_geral_inspecao_screen.dart';

// TODO: Ajuste os imports abaixo para o caminho correto dos seus arquivos no projeto
import '../widgets/novo_local_modal.dart';
import '../widgets/novo_tipo_elemento_modal.dart';
import '../widgets/iv_ui.dart';
import '../../../../core/widgets/foto_ensaio.dart';
import '../../../../core/web/escolher_foto.dart';

// ==========================================
// CLASSES AUXILIARES DE ESTADO
// ==========================================
class FotoGaleriaItem {
  File? arquivo;
  String? urlOriginal;
  String descricao;
  FotoGaleriaItem({this.arquivo, this.urlOriginal, this.descricao = ''});

  // Miniatura decodificada já no tamanho de exibição. Um FileImage puro
  // decodifica a foto da câmera inteira (~4000x3000 = ~48MB de bitmap) mesmo
  // num quadradinho de 80px, e todas as miniaturas da galeria ficam vivas ao
  // mesmo tempo: com ~20 fotos isso passava de 900MB e o Android matava o
  // app (que reabria na home). Assim cada uma ocupa ~0,5MB.
  ImageProvider miniatura(double lado) {
    final ImageProvider base = arquivo != null ? FileImage(arquivo!) : StorageNetworkImage(urlOriginal!);
    return ResizeImage(base, width: (lado * 4).round());
  }
}

class MarcacaoPlantaData {
  Offset posicao;
  String formato;
  Color cor;
  double largura;
  double altura;
  double rotacao;

  MarcacaoPlantaData({
    required this.posicao,
    this.formato = 'Círculo',
    this.cor = Colors.orange,
    this.largura = 0.05,
    this.altura = 0.05,
    this.rotacao = 0.0,
  });

  MarcacaoPlantaData copiar() => MarcacaoPlantaData(posicao: posicao, formato: formato, cor: cor, largura: largura, altura: altura, rotacao: rotacao);
}

// Resultado do ModalMarcacaoPlantaApp: a lista de marcações (pode ter mais de
// uma) e a captura composta (planta + todas as marcações) gerada na
// confirmação — uma imagem só, reaproveitada em todas as linhas de
// ponto_inspecao_regiao desse registro.
typedef ResultadoMarcacaoPlanta = ({List<MarcacaoPlantaData> marcacoes, File? fotoComposta});

// ==========================================
// PROVIDERS DE DADOS DINÂMICOS
// ==========================================

final locaisProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, estruturaId) async {
  final supabase = Supabase.instance.client;

  try {
    var query = supabase.from('estruturas_locais').select('id, nome').eq('estrutura_id', estruturaId);
    // Filtro por empresa desativado: a tabela não tem a coluna empresa_id.
    // (A consulta a `usuarios` que existia aqui só servia a esse filtro e
    // era uma ida ao banco desperdiçada a cada carregamento da lista.)
    final res = await query.order('nome');
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    final res = await supabase.from('estruturas_locais').select('id, nome').eq('estrutura_id', estruturaId).order('nome');
    return List<Map<String, dynamic>>.from(res);
  }
});

// Um local pode ter N plantas cadastradas — antes esse provider pegava só
// uma (`.limit(1)`, sem ORDER BY), arbitrária e sem o usuário poder escolher.
// Agora a tela lê a lista inteira via `plantasPorEstruturaProvider` (mesmo
// provider já usado pela Prova de Carga) e oferece um seletor.

final tiposElementoProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  const String diaviconEmpresaId = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc';
  final supabase = Supabase.instance.client;
  
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Busca a empresa do usuário logado
    final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    final String? empresaId = userRes?['empresa_id']?.toString();

    // Como a tabela tipos_elemento pode ou não ter empresa_id no seu banco, fazemos a query segura:
    var query = supabase.from('tipos_elemento').select('*');
    final response = await query.order('nome', ascending: true);

    // Filtra aplicando a regra de negócio (Padrão Diavicon ou da própria empresa)
    var lista = List<Map<String, dynamic>>.from(response);
    
    lista = lista.where((item) {
      final itemEmpresaId = item['empresa_id']?.toString();
      // É padrão se não tiver empresa_id ou se pertencer à Diavicon
      final bool isPadrao =  itemEmpresaId == diaviconEmpresaId;
      // Pertence à empresa logada
      final bool daEmpresa = empresaId != null && itemEmpresaId == empresaId;

      return isPadrao || daEmpresa;
    }).toList();

    return lista;
  } on PostgrestException catch (e) {
    throw Exception('Erro ao carregar tipos de elemento: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});


final elementosProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ({String estruturaId, String? tipoNome})>((ref, params) async {
  if (params.tipoNome == null) return [];
  final res = await Supabase.instance.client.from('elementos_estruturais').select('id, nome').eq('estrutura_id', params.estruturaId).eq('tipo', params.tipoNome!).order('nome');
  return List<Map<String, dynamic>>.from(res);
});

final sistemasHabitacionaisProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final empresaId = userRes?['empresa_id']?.toString();
  if (empresaId == null) return [];

  final res = await supabase
      .from('sistemas_habitacionais')
      .select('id, nome')
      .inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID])
      .order('nome');
  return List<Map<String, dynamic>>.from(res);
});

final catalogoAnomaliasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  String? empresaId;
  if (userId != null) {
    final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    empresaId = userRes?['empresa_id']?.toString();
  }

  var query = supabase
      .from('anomalias')
      .select(
        'id, nome, descricao, categoria, risco_tipo, risco_valor, risco_descricao, gravidade_valor, urgencia_valor, tendencia_valor, sistema_construtivo, empresa_id',
      );

  final res = empresaId != null
      ? await query.inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID]).order('nome')
      : await query.eq('empresa_id', DIAVICON_EMPRESA_ID).order('nome');

  return List<Map<String, dynamic>>.from(res);
});

// A tela recebe o id de `ponto_inspecao_visual_geral`, enquanto o provider
// compartilhado de permissões resolve autoria em `pontos_ensaios_geral`.
final pontoRaizDaInspecaoVisualProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, inspecaoVisualGeralId) async {
  final res = await Supabase.instance.client
      .from('ponto_inspecao_visual_geral')
      .select('id_ponto_geral')
      .eq('id', inspecaoVisualGeralId)
      .maybeSingle();
  return res?['id_ponto_geral']?.toString();
});

final permissoesInspecaoVisualProvider = FutureProvider.family
    .autoDispose<EnsaioPermissoes, String>((ref, inspecaoVisualGeralId) async {
  final pontoRaizId = await ref.watch(
    pontoRaizDaInspecaoVisualProvider(inspecaoVisualGeralId).future,
  );
  if (pontoRaizId == null || pontoRaizId.isEmpty) {
    return EnsaioPermissoes.somenteVisualizar;
  }
  return ref.watch(ensaioPermissoesProvider(pontoRaizId).future);
});
/// Pontuação de risco de uma anomalia já adicionada ao ponto (usa a chave
/// local `area`, diferente da coluna `area_afetada` do banco).
double _calcularPontuacaoRisco(Map<String, dynamic> anomalia) {
  return calcularPontuacaoRiscoGut(
    gravidadeValor: anomalia['gravidade_valor'],
    urgenciaValor: anomalia['urgencia_valor'],
    tendenciaValor: anomalia['tendencia_valor'],
    majoracao: anomalia['risco_maj'],
    areaAfetada: anomalia['area'],
  );
}

// ==========================================
// TELA PRINCIPAL
// ==========================================
class RegistroInspecaoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String inspecaoGeralId;
  final String? localPreSelecionadoId;
  final String? pontoInspecaoId; 

  const RegistroInspecaoScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.inspecaoGeralId,
    this.localPreSelecionadoId,
    this.pontoInspecaoId,
  });

  @override
  ConsumerState<RegistroInspecaoScreen> createState() => _RegistroInspecaoScreenState();
}

class _RegistroInspecaoScreenState extends ConsumerState<RegistroInspecaoScreen> {
  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _localSelecionadoId;
  String? _sistemaSelecionadoId;
  String? _tipoElementoSelecionadoNome;
  String? _elementoSelecionadoId;

  bool _carregandoEdicao = false;
  bool _salvando = false;
  // Progresso do salvamento, mostrado no botão ("Enviando fotos 3/20").
  int _fotosEnviadas = 0;
  int _fotosParaEnviar = 0;
  // Id do ponto criado por um salvamento que falhou depois do insert —
  // a nova tentativa atualiza esse ponto em vez de duplicar.
  String? _pontoIdCriado;

  // Uma planta pode ter mais de uma marcação por registro (ex: a mesma
  // anomalia aparece em dois pontos do ambiente).
  List<MarcacaoPlantaData> _marcacoesPlanta = [];
  File? _fotoMarcacaoGerada;
  String? _plantaIdVinculada;
  // URL do foto_marcacao já salvo no banco (edição): se o usuário não reabrir
  // o modal "Marcar" pra gerar uma imagem nova, reaproveitamos essa em vez de
  // gravar null e perder a imagem que já existia.
  String? _fotoMarcacaoExistente;
  final List<FotoGaleriaItem> _fotosGaleria = [];
  final List<Map<String, dynamic>> _anomaliasSelecionadas = [];

  @override
  void initState() {
    super.initState();
    _localSelecionadoId = widget.localPreSelecionadoId;
    if (widget.pontoInspecaoId != null) {
      _carregarDadosEdicao();
    }
  }

  Future<void> _carregarDadosEdicao() async {
    setState(() => _carregandoEdicao = true);
    try {
      final db = Supabase.instance.client;
      
            // `inspecaoGeralId` é o id de `ponto_inspecao_visual_geral`.
      // `ponto_inspecao_visual.id_ponto_geral` referencia essa linha, não o
      // id do ponto raiz em `pontos_ensaios_geral`.
      final resPonto = await db
          .from('ponto_inspecao_visual')
          .select('''*, tipos_elemento(nome, sistemas_id)''')
          .eq('id', widget.pontoInspecaoId!)
          .eq('id_projeto', widget.projetoId)
          .eq('id_estrutura', widget.estruturaId)
          .eq('id_ponto_geral', widget.inspecaoGeralId)
          .single();

      _nomeCtrl.text = resPonto['registro'] ?? '';
      _descCtrl.text = resPonto['descricao'] ?? '';
      _localSelecionadoId = resPonto['id_local'];
      _elementoSelecionadoId = resPonto['id_elemento'];
      _tipoElementoSelecionadoNome = resPonto['tipos_elemento']?['nome'];
      _sistemaSelecionadoId = resPonto['tipos_elemento']?['sistemas_id'];

      // Um registro pode ter mais de uma marcação/região na mesma planta.
      final resRegioes = await db.from('ponto_inspecao_regiao').select().eq('ponto_id', widget.pontoInspecaoId!);
      for (final regiao in (resRegioes as List)) {
        _plantaIdVinculada ??= regiao['planta_id'];
        _fotoMarcacaoExistente ??= regiao['foto_marcacao'];

        // Lê qualquer cor salva em hex (antes só azul e vermelho eram
        // reconhecidos e o resto voltava laranja).
        final hex = regiao['cor_marcacao']?.toString().replaceFirst('#', '');
        final corLida = hex != null && hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
        final Color corBD = corLida != null ? Color(0xFF000000 | corLida) : const Color(0xFFFF9800);

        _marcacoesPlanta.add(MarcacaoPlantaData(
          posicao: Offset((regiao['pos_x'] as num?)?.toDouble() ?? 0.5, (regiao['pos_y'] as num?)?.toDouble() ?? 0.5),
          formato: regiao['tipo_marcacao'] ?? 'Círculo',
          cor: corBD,
          largura: (regiao['marcacao_largura'] as num?)?.toDouble() ?? 0.05,
          altura: (regiao['marcacao_altura'] as num?)?.toDouble() ?? 0.05,
          rotacao: (regiao['marcacao_rotacao'] as num?)?.toDouble() ?? 0.0,
        ));
      }

      final resGaleria = await db.from('ponto_inspecao_visual_galeria').select().eq('id_inspecao', widget.pontoInspecaoId!);
      for (var f in resGaleria) {
        _fotosGaleria.add(FotoGaleriaItem(urlOriginal: f['foto_url'], descricao: f['descricao'] ?? ''));
      }

      final resAnomalias = await db
          .from('ponto_inspecao_visual_anomalia')
          .select('''*, anomalias(nome, gravidade_valor, urgencia_valor, tendencia_valor)''')
          .eq('id_inspecao', widget.pontoInspecaoId!);
      for (var a in resAnomalias) {
        final anomaliaCatalogo = a['anomalias'] as Map<String, dynamic>?;
        _anomaliasSelecionadas.add({
          'id_anomalia': a['id_anomalia'],
          'nome': anomaliaCatalogo?['nome'] ?? 'Anomalia',
          'area': a['area_afetada']?.toString() ?? '0',
          'risco_tipo': a['risco_tipo'],
          'risco_valor': a['risco_valor'],
          'risco_descricao': a['risco_descricao'],
          'anomalia_descricao': a['anomalia_descricao'],
          'risco_maj': a['risco_maj']?.toString() ?? '0',
          'gravidade_valor': anomaliaCatalogo?['gravidade_valor'],
          'urgencia_valor': anomaliaCatalogo?['urgencia_valor'],
          'tendencia_valor': anomaliaCatalogo?['tendencia_valor'],
        });
      }

    } catch (e) {
      debugPrint("Erro ao carregar edição: $e");
    } finally {
      setState(() => _carregandoEdicao = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirOpcoesCaptura() async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt, color: Color(0xFFFFA726)), title: const Text('Tirar Foto da Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library, color: Color(0xFFFFA726)), title: const Text('Escolher da Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );

    if (source == ImageSource.gallery) {
      // Galeria do celular: seleção múltipla, entra direto sem descrição —
      // o usuário preenche depois tocando na foto (_abrirModalEdicaoFoto já
      // cobre esse caso de edição).
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final pickedFile in pickedFiles) {
            _fotosGaleria.add(FotoGaleriaItem(arquivo: File(pickedFile.path), descricao: ''));
          }
        });
      }
      return;
    }

    if (source != null) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        final arquivo = File(pickedFile.path);
        // Foto tirada na hora (câmera): guarda também no álbum de fotos do
        // celular, além de anexar ao registro.
        unawaited(FotoWatermarkService.salvarNaGaleriaDoDispositivo(arquivo));
        final novoItem = FotoGaleriaItem(arquivo: arquivo, descricao: '');
        _abrirModalEdicaoFoto(novoItem, isNovo: true);
      }
    }
  }

  void _abrirModalEdicaoFoto(FotoGaleriaItem item, {bool isNovo = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModalEdicaoFoto(
        item: item,
        onSalvar: (String descricaoAtualizada, File? arquivoAtualizado) {
          setState(() {
            item.descricao = descricaoAtualizada;
            if (arquivoAtualizado != null) item.arquivo = arquivoAtualizado;
            if (isNovo) _fotosGaleria.add(item);
          });
        },
        onApagar: () => setState(() => _fotosGaleria.remove(item)),
      ),
    );
  }

  void _abrirFluxoNovaAnomalia() {
    final sistemas = ref.read(sistemasHabitacionaisProvider).value ?? const [];
    final sistemaNomeFiltro = _sistemaSelecionadoId == null
        ? null
        : sistemas.firstWhere(
            (s) => s['id']?.toString() == _sistemaSelecionadoId,
            orElse: () => const {},
          )['nome']?.toString();

    showDialog(
      context: context,
      builder: (_) => ModalSelecionarAnomalia(
        sistemaFiltro: sistemaNomeFiltro,
        onSelecionar: (anomaliaBase) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ModalDetalheAnomalia(
              anomaliaBase: anomaliaBase,
              onSalvar: (dadosDetalhados) {
                setState(() => _anomaliasSelecionadas.add(dadosDetalhados));
                Navigator.pop(context);
              },
              onApagar: () => Navigator.pop(context),
            ),
          );
        }
      ),
    );
  }

  void _abrirEdicaoAnomalia(int index) {
    final atual = _anomaliasSelecionadas[index];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModalDetalheAnomalia(
        anomaliaBase: atual,
        onSalvar: (dadosAtualizados) {
          setState(() => _anomaliasSelecionadas[index] = dadosAtualizados);
          Navigator.pop(context);
        },
        onApagar: () {
          setState(() => _anomaliasSelecionadas.removeAt(index));
          Navigator.pop(context);
        },
        onFechar: () => Navigator.pop(context),
      ),
    );
  }

  Future<TimestampFotoPadraoModel?> _buscarPadraoLegenda() async {
    try {
      final empresaId = ref.read(currentUserProvider)?.empresaId;
      if (empresaId == null) {
        debugPrint('[FotoWatermark] sem empresaId no usuário logado, pulando legenda');
        return null;
      }
      return await ref.read(timestampFotoPadraoRepositoryProvider).buscarPadrao(empresaId);
    } catch (e) {
      debugPrint('[FotoWatermark] erro ao buscar padrão de legenda: $e');
      return null;
    }
  }

  Future<WatermarkFotoContexto> _resolverContextoLegenda(TimestampFotoPadraoModel padrao) async {
    final usuario = ref.read(currentUserProvider);
    final empresaId = usuario?.empresaId;

    String? nomeEmpresa;
    String? logoUrl;
    if (empresaId != null && (padrao.nomeEmpresa || padrao.logo)) {
      try {
        final empresa = await ref.read(empresaDetalheProvider(empresaId).future);
        nomeEmpresa = empresa.nome;
        logoUrl = empresa.fotoUrl;
      } catch (e) {
        debugPrint('[FotoWatermark] falha ao buscar nome/logo da empresa: $e');
      }
    }

    String? nomeLocal;
    if (padrao.local && _localSelecionadoId != null) {
      try {
        final locais = await ref.read(locaisProvider(widget.estruturaId).future);
        final match = locais.firstWhere(
          (l) => l['id']?.toString() == _localSelecionadoId,
          orElse: () => const {},
        );
        nomeLocal = match['nome']?.toString();
      } catch (e) {
        debugPrint('[FotoWatermark] falha ao buscar nome do local: $e');
      }
    }

    debugPrint('[FotoWatermark] contexto: usuario=${usuario?.nome} empresa=$nomeEmpresa logo=${logoUrl != null} local=$nomeLocal');

    return FotoWatermarkService.resolverContexto(
      padrao: padrao,
      supabase: Supabase.instance.client,
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
      sistemaId: _sistemaSelecionadoId,
      elementoId: _elementoSelecionadoId,
      nomeLocal: nomeLocal,
      nomeTipoElemento: _tipoElementoSelecionadoNome,
      nomeUsuario: usuario?.nome,
      nomeEmpresa: nomeEmpresa,
      logoUrl: logoUrl,
    );
  }

  Future<void> _excluirRegistro() async {
    if (widget.pontoInspecaoId == null) return;
    final navigator = Navigator.of(context);
    navigator.pop(); // fecha o drawer antes do diálogo

    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      titulo: 'Excluir registro',
      mensagem: 'Este registro de inspeção será excluído definitivamente, com suas fotos, marcações e anomalias. Esta ação não poderá ser desfeita.',
    );
    if (confirmar != true || !mounted) return;

    try {
      await ref.read(inspecaoVisualRepoProvider).excluirRegistro(widget.pontoInspecaoId!);
      if (_localSelecionadoId != null) {
        ref.invalidate(pontosLocalProvider((inspecaoGeralId: widget.inspecaoGeralId, localId: _localSelecionadoId!)));
      }
      ref.invalidate(visaoGeralProvider(widget.inspecaoGeralId));
      ref.invalidate(listaInspecoesGeraisProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro excluído com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir registro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _salvarRegistroCompleto() async {
    // Trava síncrona de reentrância — a única proteção antes era o próprio
    // botão ficar desabilitado (`onPressed: _salvando ? null : ...`), mas
    // isso só passa a valer no PRÓXIMO rebuild/frame. Num toque duplo rápido
    // o segundo toque ainda acha o botão antigo com o `onPressed` de antes
    // anexado e chamaria esta função de novo antes do rebuild. Setar
    // `_salvando` aqui é síncrono, então a segunda chamada sai na hora.
    if (_salvando) return;

    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome do registro.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }

    // Todo registro pertence a um local da estrutura: é por ele que o
    // registro aparece na lista de locais, na planta baixa e nas análises.
    // Salvo sem local, o registro fica órfão e só some. Por isso para aqui.
    if (_localSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha o local do registro.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }

    final fotosNovas = _fotosGaleria.where((f) => f.arquivo != null).length;
    setState(() {
      _salvando = true;
      _fotosEnviadas = 0;
      _fotosParaEnviar = fotosNovas;
    });

    // Capturados antes de qualquer await: o SnackBar final precisa aparecer
    // mesmo que a tela já tenha saído da pilha.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final supabase = Supabase.instance.client;
    final storage = supabase.storage.from('projetos');
    final temporarios = <File>[];
    final enviadosAoStorage = <String>[];
    var gravouNoBanco = false;

    try {
      final userId = supabase.auth.currentUser?.id;

      // ETAPA 1 — fotos para o Storage, ANTES de tocar no banco.
      //
      // Antes a ordem era: grava o ponto, (na edição) APAGA galeria/anomalias/
      // regiões, e só então processa e sobe foto por foto, inserindo uma
      // linha por vez. Processar 20 fotos leva minutos; se qualquer coisa
      // interrompesse no meio (sem sinal, app morto pelo sistema, o bug de
      // auth que jogava pra home), o registro ficava pela metade — e numa
      // edição as fotos e anomalias antigas já tinham sido apagadas.
      // Agora a parte lenta e frágil acontece primeiro; o banco só é tocado
      // com tudo já no Storage, e em poucas chamadas.
      final padraoLegenda = await _buscarPadraoLegenda();
      WatermarkFotoContexto? contextoLegendaBase;
      if (padraoLegenda != null && padraoLegenda.temAlgumCampoAtivo) {
        contextoLegendaBase = await _resolverContextoLegenda(padraoLegenda);
      } else {
        debugPrint('[FotoWatermark] sem padrão ativo para esta empresa (padrao=${padraoLegenda != null}); fotos serão salvas sem legenda');
      }

      final linhasGaleria = <Map<String, dynamic>>[];
      for (final item in _fotosGaleria) {
        var urlParaSalvar = item.urlOriginal ?? '';
        final original = item.arquivo;
        if (original != null) {
          // Reduz ANTES da legenda: o watermark compõe num Canvas do tamanho
          // da foto, e a legenda sai mais nítida desenhada já na resolução final.
          var arquivoParaSubir = await FotoOtimizacaoService.reduzirParaRelatorio(original);
          if (arquivoParaSubir.path != original.path) temporarios.add(arquivoParaSubir);
          if (padraoLegenda != null && contextoLegendaBase != null) {
            final comLegenda = await FotoWatermarkService.aplicarLegenda(
              foto: arquivoParaSubir,
              padrao: padraoLegenda,
              contexto: contextoLegendaBase.copyWith(descricaoImagem: item.descricao),
            );
            if (comLegenda.path != arquivoParaSubir.path) temporarios.add(comLegenda);
            arquivoParaSubir = comLegenda;
          }
          // Nome gerado pelo app (uuid): não colide e não leva o nome do
          // arquivo do usuário para o Storage (ver upload_seguro.dart).
          final fileName = await storage.enviarArquivoSeguro('inspecoes', arquivoParaSubir);
          enviadosAoStorage.add(fileName);
          urlParaSalvar = storage.getPublicUrl(fileName);
          if (mounted) setState(() => _fotosEnviadas++);
        }
        linhasGaleria.add({'foto_url': urlParaSalvar, 'descricao': item.descricao, 'criado_por': userId});
      }

      String? urlFotoMarcacao = _fotoMarcacaoExistente;
      if (_marcacoesPlanta.isNotEmpty && _fotoMarcacaoGerada != null) {
        // A mesma imagem composta (planta + todos os pinos) vai em toda linha
        // de ponto_inspecao_regiao desse registro.
        final fileName = await storage.enviarArquivoSeguro('marcacoes', _fotoMarcacaoGerada!);
        enviadosAoStorage.add(fileName);
        urlFotoMarcacao = storage.getPublicUrl(fileName);
      }

      // ETAPA 2 — banco.
      String? idTipoElemento;
      if (_tipoElementoSelecionadoNome != null) {
        // O mesmo nome pode existir em mais de um sistema habitacional, então
        // filtra pelo sistema selecionado e limita a 1 resultado.
        var queryTipo = supabase.from('tipos_elemento').select('id').eq('nome', _tipoElementoSelecionadoNome!);
        if (_sistemaSelecionadoId != null) {
          queryTipo = queryTipo.eq('sistemas_id', _sistemaSelecionadoId!);
        }
        final resTipo = await queryTipo.limit(1).maybeSingle();
        if (resTipo != null) idTipoElemento = resTipo['id'] as String;
      }

      // `_pontoIdCriado`: se um salvamento anterior desta mesma tela chegou a
      // criar o ponto e falhou depois, a nova tentativa atualiza esse ponto
      // em vez de inserir um duplicado.
      final pontoExistente = widget.pontoInspecaoId ?? _pontoIdCriado;
      final isEdicao = widget.pontoInspecaoId != null;
      String pontoId;

      final dadosPonto = {
        'registro': _nomeCtrl.text,
        'descricao': _descCtrl.text,
        'id_projeto': widget.projetoId,
        'id_estrutura': widget.estruturaId,
        'id_ponto_geral': widget.inspecaoGeralId,
        'id_local': _localSelecionadoId,
        'id_elemento': _elementoSelecionadoId,
        'id_tipo_elemento': idTipoElemento,
      };

      if (pontoExistente != null) {
        pontoId = pontoExistente;
        await supabase
            .from('ponto_inspecao_visual')
            .update(dadosPonto)
            .eq('id', pontoId)
            .eq('id_projeto', widget.projetoId)
            .eq('id_estrutura', widget.estruturaId)
            .eq('id_ponto_geral', widget.inspecaoGeralId);
        gravouNoBanco = true;
        await supabase.from('ponto_inspecao_regiao').delete().eq('ponto_id', pontoId);
        await supabase.from('ponto_inspecao_visual_galeria').delete().eq('id_inspecao', pontoId);
        await supabase.from('ponto_inspecao_visual_anomalia').delete().eq('id_inspecao', pontoId);
      } else {
        dadosPonto['criado_por'] = userId;
        final resPonto = await supabase.from('ponto_inspecao_visual').insert(dadosPonto).select('id').single();
        pontoId = resPonto['id'] as String;
        _pontoIdCriado = pontoId;
        gravouNoBanco = true;
      }

      // Um insert por tabela (antes era um por foto e um por anomalia).
      if (_marcacoesPlanta.isNotEmpty) {
        await supabase.from('ponto_inspecao_regiao').insert([
          for (final marcacao in _marcacoesPlanta)
            {
              'ponto_id': pontoId,
              'planta_id': _plantaIdVinculada,
              'pos_x': marcacao.posicao.dx,
              'pos_y': marcacao.posicao.dy,
              'tipo_marcacao': marcacao.formato,
              'cor_marcacao': '#${marcacao.cor.toARGB32().toRadixString(16).substring(2)}',
              'marcacao_largura': marcacao.largura,
              'marcacao_altura': marcacao.altura,
              'marcacao_rotacao': marcacao.rotacao,
              'foto_marcacao': urlFotoMarcacao,
              'criado_por': userId,
            },
        ]);
      }

      if (linhasGaleria.isNotEmpty) {
        await supabase.from('ponto_inspecao_visual_galeria').insert([
          for (final linha in linhasGaleria) {...linha, 'id_inspecao': pontoId},
        ]);
      }

      if (_anomaliasSelecionadas.isNotEmpty) {
        await supabase.from('ponto_inspecao_visual_anomalia').insert([
          for (final anomalia in _anomaliasSelecionadas)
            {
              'id_inspecao': pontoId,
              'id_anomalia': anomalia['id_anomalia'],
              'area_afetada': double.tryParse(anomalia['area'].toString()) ?? 0.0,
              'risco_tipo': anomalia['risco_tipo'],
              'risco_valor': anomalia['risco_valor'],
              'risco_descricao': anomalia['risco_descricao'],
              'anomalia_descricao': anomalia['anomalia_descricao'],
              'risco_maj': double.tryParse(anomalia['risco_maj'].toString()) ?? 0.0,
              'criado_por': userId,
            },
        ]);
      }

      if (mounted) {
        // Libera o PopScope antes de sair da tela.
        setState(() => _salvando = false);
        navigator.pop();
      }
      messenger.showSnackBar(SnackBar(content: Text(isEdicao ? 'Registro atualizado com sucesso!' : 'Registro salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e, st) {
      debugPrint('[InspecaoVisual] falha ao salvar registro: $e\n$st');
      // Nada chegou ao banco: as fotos já enviadas ficariam órfãs no Storage.
      if (!gravouNoBanco && enviadosAoStorage.isNotEmpty) {
        unawaited(storage.remove(enviadosAoStorage).then((_) {}, onError: (_) {}));
      }
      final mensagem = e is PostgrestException
          ? 'Erro no banco: ${e.message}'
          : e is StorageException
              ? 'Erro ao enviar foto: ${e.message}'
              : 'Erro inesperado: $e';
      messenger.showSnackBar(SnackBar(content: Text('$mensagem\nSeus dados continuam na tela — tente salvar de novo.'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
    } finally {
      // Arquivos reduzidos/legendados são só intermediários do upload.
      for (final f in temporarios) {
        unawaited(f.delete().then((_) {}, onError: (_) {}));
      }
      if (mounted && _salvando) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoEdicao) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final permissoes = ref.watch(permissoesInspecaoVisualProvider(widget.inspecaoGeralId)).value ?? EnsaioPermissoes.somenteVisualizar;
    // Só existe algo pra excluir num registro já salvo, e só quem pode
    // editar esse registro pode excluí-lo.
    final podeExcluirRegistro = widget.pontoInspecaoId != null && permissoes.canEdit;
    final editando = widget.pontoInspecaoId != null;

    // Sair da tela no meio do salvamento deixava o upload rodando sem dono
    // (e sem aviso de sucesso/erro). Durante o salvamento o voltar é segurado.
    return PopScope(
      canPop: !_salvando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aguarde o salvamento terminar.'), duration: Duration(seconds: 2)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: kIvFundo,
        endDrawer: podeExcluirRegistro
            ? MenuDrawerAppBar(
                title: 'Inspeção Visual\nRegistro',
                items: [
                  DiaviconMenuItem(
                    icon: Icons.delete_outline,
                    label: 'Excluir registro',
                    onTap: _excluirRegistro,
                  ),
                ],
              )
            : null,
        appBar: CustomAppBar(
          title: 'Painel',
          showBackButton: true,
          // maybePop respeita o PopScope (o padrão do CustomAppBar usa pop()).
          onBackPressed: () => Navigator.of(context).maybePop(),
          showMenuButton: podeExcluirRegistro,
          titleWidget: Column(
            children: [
              const Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(editando ? 'Edição' : 'Registro', style: const TextStyle(fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: CorpoIv(
                children: [
                  if (!permissoes.canEdit)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kIvBorda)),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: kIvSuave),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.',
                              style: TextStyle(fontSize: 13, color: kIvTexto),
                            ),
                          ),
                        ],
                      ),
                    ),
                  CabecalhoIv(
                    titulo: editando ? (_nomeCtrl.text.trim().isEmpty ? 'Editar registro' : _nomeCtrl.text.trim()) : 'Novo registro',
                    subtitulo: editando ? 'Registro de inspeção visual' : 'Registre o elemento, as fotos e as anomalias encontradas.',
                  ),
                  const SizedBox(height: 20),
                  AbsorbPointer(
                    absorbing: !permissoes.canEdit,
                    child: DuasColunasIv(
                      esquerda: [
                        _secaoIdentificacao(),
                        _secaoLocalizacao(),
                        _secaoElemento(),
                      ],
                      direita: [
                        _secaoFotos(),
                        _secaoAnomalias(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (permissoes.canEdit) _barraSalvar(editando),
          ],
        ),
      ),
    );
  }

  // --- SEÇÕES DO FORMULÁRIO ---

  Widget _rotulo(String texto, {bool obrigatorio = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: texto,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kIvTexto),
          children: [if (obrigatorio) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFB3261E)))],
        ),
      ),
    );
  }

  Widget _secaoIdentificacao() {
    return SecaoIv(
      titulo: '1. Identificação',
      icone: Icons.edit_note_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotulo('Nome do registro', obrigatorio: true),
          TextField(
            controller: _nomeCtrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco('Ex.: Trincas nas paredes do térreo'),
          ),
          const SizedBox(height: 14),
          _rotulo('Descrição'),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDeco('O que foi observado, onde e em que condição.'),
          ),
        ],
      ),
    );
  }

  Widget _secaoLocalizacao() {
    final locaisAsync = ref.watch(locaisProvider(widget.estruturaId));
    final plantasAsync = ref.watch(plantasPorEstruturaProvider(widget.estruturaId));

    return SecaoIv(
      titulo: '2. Localização',
      descricao: 'Local da estrutura e posição na planta baixa.',
      icone: Icons.place_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotulo('Local', obrigatorio: true),
          Row(
            children: [
              Expanded(
                child: locaisAsync.when(
                  loading: () => const LinearProgressIndicator(color: AppColors.primary),
                  error: (e, _) => const Text('Erro ao carregar locais'),
                  data: (locais) => _buildDropdown(
                    value: _localSelecionadoId,
                    items: locais.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text(l['nome'].toString()))).toList(),
                    onChanged: (val) => setState(() {
                      _localSelecionadoId = val;
                      _marcacoesPlanta = [];
                      _fotoMarcacaoGerada = null;
                      _plantaIdVinculada = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAddButton('Novo local', () async {
                final res = await showDialog(
                  context: context,
                  builder: (_) => NovoLocalModal(estruturaId: widget.estruturaId),
                );
                if (res != null) {
                  // Espera o provider recarregar com o novo local ANTES de
                  // marcá-lo como selecionado — senão o Dropdown recebe um
                  // `value` que ainda não está na lista de `items` (a lista
                  // antiga fica visível durante o refresh) e o Flutter
                  // derruba o app com "There should be exactly one item...".
                  final locaisAtualizados = await ref.refresh(locaisProvider(widget.estruturaId).future);
                  if (!mounted) return;
                  if (res is Map && res['id'] != null && locaisAtualizados.any((l) => l['id']?.toString() == res['id'].toString())) {
                    setState(() {
                      _localSelecionadoId = res['id'].toString();
                      _marcacoesPlanta = [];
                      _fotoMarcacaoGerada = null;
                      _plantaIdVinculada = null;
                    });
                  }
                }
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _rotulo('Posição na planta')),
              if (_marcacoesPlanta.isNotEmpty)
                EtiquetaIv(
                  texto: _marcacoesPlanta.length == 1 ? '1 marcação' : '${_marcacoesPlanta.length} marcações',
                  icone: Icons.check_circle_outline,
                  cor: const Color(0xFF2E7D32),
                  fundo: const Color(0xFFE8F5E9),
                ),
            ],
          ),
          if (_localSelecionadoId == null)
            _avisoPlanta(Icons.touch_app_outlined, 'Escolha o local para marcar a posição na planta.')
          else
            plantasAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (e, _) => _avisoPlanta(Icons.error_outline, 'Erro ao carregar a planta.'),
              data: (todasPlantas) {
                // Um local pode ter N plantas — deixa o usuário
                // escolher qual usar em vez de pegar uma arbitrária.
                final plantasDoLocal = todasPlantas.where((p) => p.localVinculado == _localSelecionadoId).toList();
                if (plantasDoLocal.isEmpty) {
                  return _avisoPlanta(Icons.map_outlined, 'Nenhuma planta cadastrada para este local.');
                }
                if (_plantaIdVinculada == null || !plantasDoLocal.any((p) => p.id == _plantaIdVinculada)) {
                  _plantaIdVinculada = plantasDoLocal.first.id;
                }
                final plantaData = plantasDoLocal.firstWhere((p) => p.id == _plantaIdVinculada);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (plantasDoLocal.length > 1) ...[
                      _buildDropdown(
                        value: _plantaIdVinculada,
                        items: plantasDoLocal.map((p) => DropdownMenuItem(value: p.id, child: Text(p.titulo.isEmpty ? 'Sem título' : p.titulo))).toList(),
                        onChanged: (val) => setState(() {
                          _plantaIdVinculada = val;
                          _marcacoesPlanta = [];
                          _fotoMarcacaoGerada = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                      height: 240,
                      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: kIvBorda)),
                      clipBehavior: Clip.hardEdge,
                      child: _fotoMarcacaoGerada != null
                          // `contain`: a imagem composta mostra a planta
                          // inteira com as marcações, sem corte.
                          ? Image(image: FileImage(_fotoMarcacaoGerada!), fit: BoxFit.contain, width: double.infinity)
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // Mesma lógica de proporção (área quadrada = renderSize)
                                // usada em ModalMarcacaoPlantaApp, pra a marcação
                                // aparecer no mesmo lugar aqui e lá.
                                final renderSize = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
                                return Center(
                                  child: SizedBox(
                                    width: renderSize,
                                    height: renderSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ImagemStorage.network(
                                          plantaData.arquivoUrl,
                                          fit: BoxFit.contain,
                                          width: renderSize,
                                          height: renderSize,
                                          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                        ),
                                        for (final marcacao in _marcacoesPlanta)
                                          Positioned(
                                            left: (marcacao.posicao.dx * renderSize) - ((marcacao.largura * renderSize) / 2),
                                            top: (marcacao.posicao.dy * renderSize) - ((marcacao.altura * renderSize) / 2),
                                            child: Transform.rotate(
                                              angle: marcacao.rotacao,
                                              child: Container(
                                                width: marcacao.largura * renderSize,
                                                height: marcacao.altura * renderSize,
                                                decoration: BoxDecoration(
                                                  color: marcacao.cor.withValues(alpha: 0.6),
                                                  shape: marcacao.formato == 'Círculo' ? BoxShape.circle : BoxShape.rectangle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: BotaoIv(
                        rotulo: _marcacoesPlanta.isNotEmpty ? 'Editar marcação' : 'Marcar na planta',
                        icone: Icons.ads_click_rounded,
                        aoTocar: () async {
                          final result = await showDialog<ResultadoMarcacaoPlanta>(
                            context: context,
                            builder: (_) => ModalMarcacaoPlantaApp(
                              marcacoesIniciais: _marcacoesPlanta,
                              imageUrl: plantaData.arquivoUrl,
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _marcacoesPlanta = result.marcacoes;
                              if (result.fotoComposta != null) _fotoMarcacaoGerada = result.fotoComposta;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _avisoPlanta(IconData icone, String texto) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: kIvBorda)),
      child: Row(
        children: [
          Icon(icone, size: 20, color: kIvSuave),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, color: kIvSuave))),
        ],
      ),
    );
  }

  Widget _secaoElemento() {
    final sistemasAsync = ref.watch(sistemasHabitacionaisProvider);
    final tiposAsync = ref.watch(tiposElementoProvider);
    final elementosAsync = ref.watch(elementosProvider((estruturaId: widget.estruturaId, tipoNome: _tipoElementoSelecionadoNome)));

    return SecaoIv(
      titulo: '3. Elemento inspecionado',
      descricao: 'Sistema construtivo, tipo e o elemento da estrutura.',
      icone: Icons.view_in_ar_outlined,
      acao: _sistemaSelecionadoId != null
          ? TextButton.icon(
              onPressed: () => setState(() {
                _sistemaSelecionadoId = null;
                _tipoElementoSelecionadoNome = null;
                _elementoSelecionadoId = null;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Limpar'),
              style: TextButton.styleFrom(foregroundColor: kIvSuave),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotulo('Sistema'),
          sistemasAsync.when(
            loading: () => const LinearProgressIndicator(color: AppColors.primary),
            error: (e, _) => const Text('Erro ao carregar sistemas'),
            data: (sistemas) => _buildDropdown(
              value: _sistemaSelecionadoId,
              items: sistemas.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nome'].toString(), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setState(() {
                _sistemaSelecionadoId = val;
                _tipoElementoSelecionadoNome = null;
                _elementoSelecionadoId = null;
              }),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final tipo = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rotulo('Tipo de elemento'),
                  tiposAsync.when(
                    loading: () => const LinearProgressIndicator(color: AppColors.primary),
                    error: (e, _) => const Text('Erro ao carregar'),
                    data: (tipos) {
                      final tiposFiltrados = _sistemaSelecionadoId == null
                          ? tipos
                          : tipos.where((t) => t['sistemas_id']?.toString() == _sistemaSelecionadoId).toList();
                      return _buildDropdown(
                        value: _tipoElementoSelecionadoNome,
                        items: tiposFiltrados.map((t) => DropdownMenuItem(value: t['nome'].toString(), child: Text(t['nome'].toString(), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() {
                          _tipoElementoSelecionadoNome = val;
                          _elementoSelecionadoId = null;
                        }),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildTextButtonAdd('Novo tipo', () async {
                      final res = await showDialog(
                        context: context,
                        builder: (_) => NovoTipoElementoModal(sistemaIdInicial: _sistemaSelecionadoId),
                      );
                      if (res != null && res is String) {
                        // Mesmo cuidado do "Novo Local": espera o provider
                        // recarregar antes de selecionar, senão o Dropdown
                        // quebra com um `value` que ainda não está nos `items`.
                        final tiposAtualizados = await ref.refresh(tiposElementoProvider.future);
                        if (!mounted) return;
                        if (tiposAtualizados.any((t) => t['nome']?.toString() == res)) {
                          setState(() {
                            _tipoElementoSelecionadoNome = res;
                            _elementoSelecionadoId = null;
                          });
                        }
                      }
                    }),
                  ),
                ],
              );
              final elemento = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rotulo('Elemento estrutural'),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _tipoElementoSelecionadoNome == null ? 0.45 : 1.0,
                    child: IgnorePointer(
                      ignoring: _tipoElementoSelecionadoNome == null,
                      child: elementosAsync.when(
                        loading: () => const LinearProgressIndicator(color: AppColors.primary),
                        error: (e, _) => const Text('Erro ao carregar'),
                        data: (elementos) => _buildDropdown(
                          value: _elementoSelecionadoId,
                          hint: _tipoElementoSelecionadoNome == null ? 'Escolha o tipo antes' : 'Selecione',
                          items: elementos.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nome'].toString(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _elementoSelecionadoId = val),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tipoElementoSelecionadoNome == null
                        ? const SizedBox(height: 36)
                        : _buildTextButtonAdd('Novo elemento', () async {
                            final res = await showDialog(
                              context: context,
                              builder: (_) {
                                final sistemas = ref.read(sistemasHabitacionaisProvider).value ?? const [];
                                final sistemaNome = _sistemaSelecionadoId == null
                                    ? null
                                    : sistemas.firstWhere(
                                        (s) => s['id']?.toString() == _sistemaSelecionadoId,
                                        orElse: () => const {},
                                      )['nome']?.toString();
                                return ModalNovoElementoEstrutural(
                                  estruturaId: widget.estruturaId,
                                  tipoElemento: _tipoElementoSelecionadoNome!,
                                  localId: _localSelecionadoId,
                                  sistemaNome: sistemaNome,
                                );
                              },
                            );
                            if (res != null && res is String) {
                              final elementosAtualizados = await ref.refresh(
                                elementosProvider((estruturaId: widget.estruturaId, tipoNome: _tipoElementoSelecionadoNome)).future,
                              );
                              if (!mounted) return;
                              if (elementosAtualizados.any((e) => e['id']?.toString() == res)) {
                                setState(() => _elementoSelecionadoId = res);
                              }
                            }
                          }),
                  ),
                ],
              );
              if (c.maxWidth < 420) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tipo, const SizedBox(height: 6), elemento]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: tipo), const SizedBox(width: 12), Expanded(child: elemento)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _secaoFotos() {
    return SecaoIv(
      titulo: '4. Fotos',
      descricao: _fotosGaleria.isEmpty
          ? 'Registre o elemento e cada anomalia. Toque na foto para descrever.'
          : '${_fotosGaleria.length} ${_fotosGaleria.length == 1 ? 'foto' : 'fotos'} · toque para descrever ou trocar',
      icone: Icons.photo_library_outlined,
      child: LayoutBuilder(
        builder: (context, c) {
          const espaco = 8.0;
          final colunas = ((c.maxWidth + espaco) / (110 + espaco)).floor().clamp(3, 6);
          final lado = (c.maxWidth - espaco * (colunas - 1)) / colunas;
          // Visualizador em tela cheia: resolução limitada para não
          // decodificar a foto da câmera inteira na memória.
          final ampliadas = [
            for (final f in _fotosGaleria)
              ResizeImage(f.arquivo != null ? FileImage(f.arquivo!) : StorageNetworkImage(f.urlOriginal!) as ImageProvider, width: 2000, policy: ResizeImagePolicy.fit),
          ];
          final legendas = [for (final f in _fotosGaleria) f.descricao];
          return Wrap(
            spacing: espaco,
            runSpacing: espaco,
            children: [
              for (var i = 0; i < _fotosGaleria.length; i++)
                SizedBox(
                  width: lado,
                  height: lado,
                  child: FotoEnsaio(
                    imagem: _fotosGaleria[i].miniatura(lado),
                    proporcao: 1,
                    larguraMaxima: null,
                    raio: 10,
                    aoTocar: () => _abrirModalEdicaoFoto(_fotosGaleria[i]),
                    acao: Tooltip(
                      message: 'Ampliar',
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => abrirFotoTelaCheia(context, ampliadas, inicial: i, legendas: legendas),
                          child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.zoom_out_map_rounded, size: 16, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(width: lado, height: lado, child: BotaoAdicionarFoto(aoTocar: _abrirOpcoesCaptura, texto: 'Adicionar fotos')),
            ],
          );
        },
      ),
    );
  }

  Widget _secaoAnomalias() {
    final gutRegistro = _anomaliasSelecionadas.fold<double>(0, (t, a) => t + _calcularPontuacaoRisco(a));
    return SecaoIv(
      titulo: '5. Anomalias',
      descricao: _anomaliasSelecionadas.isEmpty
          ? 'Manifestações patológicas encontradas no elemento.'
          : 'Toque numa anomalia para ajustar área, majoração e risco.',
      icone: Icons.report_gmailerrorred_outlined,
      acao: _anomaliasSelecionadas.isEmpty ? null : SeloGut(valor: gutRegistro, grande: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_anomaliasSelecionadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nenhuma anomalia inserida. Se o elemento tiver problemas, insira cada um deles.',
                      style: TextStyle(fontSize: 13, color: kIvTexto),
                    ),
                  ),
                ],
              ),
            ),
          for (var index = 0; index < _anomaliasSelecionadas.length; index++) ...[
            _cartaoAnomalia(index),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _abrirFluxoNovaAnomalia,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Inserir anomalia', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: kIvLaranjaTexto,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoAnomalia(int index) {
    final anomalia = _anomaliasSelecionadas[index];
    final pontuacao = _calcularPontuacaoRisco(anomalia);
    final f = FaixaGut.de(pontuacao);
    final classe = anomalia['risco_valor']?.toString() ?? '';
    final corClasse = switch (classe.toLowerCase()) {
      'alto' => const Color(0xFFB3261E),
      'médio' || 'medio' => const Color(0xFFB26A00),
      _ => const Color(0xFF2E7D32),
    };
    final maj = anomalia['risco_maj']?.toString() ?? '0';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirEdicaoAnomalia(index),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kIvBorda)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(color: f.cor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                anomalia['nome']?.toString() ?? 'Anomalia',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kIvTinta),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SeloGut(valor: pontuacao),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            EtiquetaIv(texto: 'Área ${anomalia['area']}%', icone: Icons.crop_free_rounded),
                            if (maj != '0' && maj.isNotEmpty) EtiquetaIv(texto: 'Majoração $maj%', icone: Icons.trending_up_rounded),
                            EtiquetaIv(
                              texto: 'Risco ${anomalia['risco_tipo'] ?? ''} ${classe.toLowerCase()}'.trim(),
                              icone: Icons.shield_outlined,
                              cor: corClasse,
                              fundo: corClasse.withValues(alpha: 0.1),
                            ),
                            EtiquetaIv(
                              texto: 'G${anomalia['gravidade_valor'] ?? '-'} · U${anomalia['urgencia_valor'] ?? '-'} · T${anomalia['tendencia_valor'] ?? '-'}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: kIvSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraSalvar(bool editando) {
    final gutRegistro = _anomaliasSelecionadas.fold<double>(0, (t, a) => t + _calcularPontuacaoRisco(a));
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kIvBorda)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: LayoutBuilder(
                builder: (context, c) {
                  final resumo = Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EtiquetaIv(texto: '${_fotosGaleria.length} ${_fotosGaleria.length == 1 ? 'foto' : 'fotos'}', icone: Icons.photo_library_outlined),
                      EtiquetaIv(
                        texto: '${_anomaliasSelecionadas.length} ${_anomaliasSelecionadas.length == 1 ? 'anomalia' : 'anomalias'}',
                        icone: Icons.report_gmailerrorred_outlined,
                      ),
                      if (_anomaliasSelecionadas.isNotEmpty) SeloGut(valor: gutRegistro),
                    ],
                  );
                  final botao = FilledButton(
                    onPressed: _salvando ? null : _salvarRegistroCompleto,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: kIvTinta,
                      // Desabilitado (salvando) continua laranja, senão o
                      // progresso some no cinza claro padrão.
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
                      disabledForegroundColor: kIvTinta,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _salvando
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: kIvTinta, strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Text(
                                _fotosEnviadas < _fotosParaEnviar ? 'Enviando fotos $_fotosEnviadas/$_fotosParaEnviar' : 'Salvando...',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ],
                          )
                        : Text(editando ? 'Salvar alterações' : 'Salvar registro', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  );
                  if (c.maxWidth < 560) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [resumo, const SizedBox(height: 8), botao],
                    );
                  }
                  return Row(children: [Expanded(child: resumo), const SizedBox(width: 16), botao]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE UI ---
  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kIvSuave, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Widget _buildDropdown({String? value, String hint = 'Selecione', required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    // Guarda contra o crash do DropdownButton quando `value` ainda não está
    // entre os `items` (ex: acabou de criar um local/tipo/elemento novo e o
    // provider ainda não recarregou nesse frame) — em vez de derrubar o app,
    // volta pro estado "Selecione" até o valor aparecer na lista.
    final valorValido = value != null && items.any((item) => item.value == value);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: valorValido ? const Color(0xFFD0D0D0) : kIvBorda),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: kIvSuave, fontSize: 14)),
          value: valorValido ? value : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextButtonAdd(String text, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(foregroundColor: kIvLaranjaTexto, padding: const EdgeInsets.symmetric(horizontal: 4)),
    );
  }

  Widget _buildAddButton(String dica, VoidCallback onTap) {
    return Tooltip(
      message: dica,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: const SizedBox(width: 48, height: 48, child: Icon(Icons.add, color: kIvTinta)),
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DEDICADO: NOVO ELEMENTO ESTRUTURAL
// ==========================================
class ModalNovoElementoEstrutural extends StatefulWidget {
  final String estruturaId;
  final String tipoElemento;
  final String? localId;
  // Só para exibição — confirma que o elemento herda automaticamente o tipo
  // e o sistema já selecionados na tela de registro, sem pedir de novo.
  final String? sistemaNome;

  const ModalNovoElementoEstrutural({super.key, required this.estruturaId, required this.tipoElemento, this.localId, this.sistemaNome});

  @override
  State<ModalNovoElementoEstrutural> createState() => _ModalNovoElementoEstruturalState();
}

class _ModalNovoElementoEstruturalState extends State<ModalNovoElementoEstrutural> {
  final _nomeCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('elementos_estruturais').insert({
        'estrutura_id': widget.estruturaId,
        'nome': nome,
        'tipo': widget.tipoElemento,
        'local_id': widget.localId,
      }).select('id').single();
      
      if (mounted) Navigator.of(context).pop(res['id'].toString());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Novo Elemento Estrutural', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey))]),
            const SizedBox(height: 4),
            Text(
              widget.sistemaNome == null
                  ? 'Tipo: ${widget.tipoElemento}'
                  : 'Tipo: ${widget.tipoElemento} · Sistema: ${widget.sistemaNome}',
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            TextField(controller: _nomeCtrl, decoration: InputDecoration(hintText: 'Nome (ex: Viga 01)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _salvar,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar Elemento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DE EDIÇÃO DE FOTO DA GALERIA
// ==========================================
class ModalEdicaoFoto extends StatefulWidget {
  final FotoGaleriaItem item;
  final Function(String descricao, File? arquivo) onSalvar;
  final VoidCallback onApagar;
  const ModalEdicaoFoto({super.key, required this.item, required this.onSalvar, required this.onApagar});
  @override
  State<ModalEdicaoFoto> createState() => _ModalEdicaoFotoState();
}

class _ModalEdicaoFotoState extends State<ModalEdicaoFoto> {
  late TextEditingController _descCtrl;
  File? _arquivoEditado;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.descricao);
    _arquivoEditado = widget.item.arquivo;
  }

  Future<void> _substituirFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _arquivoEditado = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider provider = const AssetImage('assets/images/placeholder.png');
    // Mesmo cuidado da miniatura da galeria: decodifica no tamanho exibido.
    if (_arquivoEditado != null) {
      provider = ResizeImage(FileImage(_arquivoEditado!), width: 560);
    } else if (widget.item.urlOriginal != null) {
      provider = ResizeImage(StorageNetworkImage(widget.item.urlOriginal!), width: 560);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Nova imagem', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.red)), GestureDetector(onTap: () { if (widget.item.descricao.isEmpty) widget.onApagar(); Navigator.pop(context); }, child: const Icon(Icons.close, color: Colors.grey))]),
            const SizedBox(height: 24),
            Center(child: GestureDetector(onTap: _substituirFoto, child: Stack(alignment: Alignment.bottomRight, children: [Container(height: 140, width: 140, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: DecorationImage(image: provider, fit: BoxFit.cover))), Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)))]))),
            const SizedBox(height: 16),
            Text('Descrição', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, decoration: InputDecoration(hintText: 'Descrição da foto', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))))),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [OutlinedButton(onPressed: () { widget.onApagar(); Navigator.pop(context); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text('Apagar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), ElevatedButton(onPressed: () { widget.onSalvar(_descCtrl.text, _arquivoEditado); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1º MODAL: SELECIONAR ANOMALIA DA LISTA
// ==========================================
class ModalSelecionarAnomalia extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onSelecionar;
  final String? sistemaFiltro;
  const ModalSelecionarAnomalia({super.key, required this.onSelecionar, this.sistemaFiltro});

  @override
  ConsumerState<ModalSelecionarAnomalia> createState() => _ModalSelecionarAnomaliaState();
}

class _ModalSelecionarAnomaliaState extends ConsumerState<ModalSelecionarAnomalia> {
  final _buscaCtrl = TextEditingController();
  String _termoBusca = '';
  String? _categoriaSelecionada;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anomaliasAsync = ref.watch(catalogoAnomaliasProvider).whenData((lista) {
      if (widget.sistemaFiltro == null) return lista;
      return lista.where((a) => a['sistema_construtivo'] == widget.sistemaFiltro).toList();
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Selecione a Anomalia', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey))]),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaCtrl,
                onChanged: (val) => setState(() => _termoBusca = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar anomalia...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _termoBusca.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: () => setState(() { _buscaCtrl.clear(); _termoBusca = ''; }),
                          child: const Icon(Icons.clear, color: Colors.grey, size: 20),
                        ),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: anomaliasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => const Center(child: Text('Erro ao carregar catálogo')),
                  data: (lista) {
                    if (lista.isEmpty) return const Center(child: Text('Nenhuma anomalia cadastrada.', style: TextStyle(color: Colors.grey)));

                    final categorias = lista
                        .map((a) => a['categoria']?.toString())
                        .whereType<String>()
                        .where((c) => c.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                    final listaFiltrada = lista.where((a) {
                      final categoriaOk = _categoriaSelecionada == null || a['categoria']?.toString() == _categoriaSelecionada;
                      if (!categoriaOk) return false;
                      if (_termoBusca.isEmpty) return true;
                      final nome = a['nome']?.toString().toLowerCase() ?? '';
                      final descricao = a['descricao']?.toString().toLowerCase() ?? '';
                      return nome.contains(_termoBusca) || descricao.contains(_termoBusca);
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (categorias.isNotEmpty)
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildFiltroCategoriaChip('Todas', selecionado: _categoriaSelecionada == null, onTap: () => setState(() => _categoriaSelecionada = null)),
                                ...categorias.map((c) => _buildFiltroCategoriaChip(c, selecionado: _categoriaSelecionada == c, onTap: () => setState(() => _categoriaSelecionada = c))),
                              ],
                            ),
                          ),
                        if (categorias.isNotEmpty) const SizedBox(height: 12),
                        Expanded(
                          child: listaFiltrada.isEmpty
                              ? const Center(child: Text('Nenhuma anomalia encontrada.', style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  itemCount: listaFiltrada.length, separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = listaFiltrada[index];
                                    final categoria = item['categoria']?.toString();
                                    return GestureDetector(
                                      onTap: () => widget.onSelecionar(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(item['nome'].toString(), style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))),
                                                if (categoria != null && categoria.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                                                    child: Text(categoria, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFFFA726))),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(item['descricao']?.toString() ?? 'Sem descrição', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 8),
                                            // G, U e T do catálogo: ajuda a escolher entre
                                            // anomalias parecidas pela gravidade.
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                EtiquetaIv(texto: 'Gravidade ${item['gravidade_valor'] ?? '-'}'),
                                                EtiquetaIv(texto: 'Urgência ${item['urgencia_valor'] ?? '-'}'),
                                                EtiquetaIv(texto: 'Tendência ${item['tendencia_valor'] ?? '-'}'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltroCategoriaChip(String label, {required bool selecionado, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? const Color(0xFFFFA726) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selecionado ? const Color(0xFFFFA726) : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: selecionado ? Colors.white : Colors.grey.shade700)),
        ),
      ),
    );
  }
}

// ==========================================
// 2º MODAL: DETALHE DA ANOMALIA
// ==========================================
class ModalDetalheAnomalia extends StatefulWidget {
  final Map<String, dynamic> anomaliaBase;
  final Function(Map<String, dynamic>) onSalvar;
  final VoidCallback onApagar;
  final VoidCallback? onFechar;
  const ModalDetalheAnomalia({super.key, required this.anomaliaBase, required this.onSalvar, required this.onApagar, this.onFechar});
  @override
  State<ModalDetalheAnomalia> createState() => _ModalDetalheAnomaliaState();
}

class _ModalDetalheAnomaliaState extends State<ModalDetalheAnomalia> {
  final _areaCtrl = TextEditingController();
  final _majCtrl = TextEditingController();
  final _anomaliaDescCtrl = TextEditingController();
  final _riscoDescCtrl = TextEditingController();
  String _tipoRisco = 'Humano';
  String _classeRisco = 'Alto';

  @override
  void initState() {
    super.initState();
    _tipoRisco = widget.anomaliaBase['risco_tipo'] ?? 'Humano';
    _classeRisco = widget.anomaliaBase['risco_valor'] ?? 'Alto';
    _areaCtrl.text = widget.anomaliaBase['area']?.toString() ?? '';
    _majCtrl.text = widget.anomaliaBase['risco_maj']?.toString() ?? '0';
    // "Descrição da Anomalia" parte da descrição padrão do catálogo
    // (`anomalias.descricao`) mas fica editável por ocorrência
    // (`ponto_inspecao_visual_anomalia.anomalia_descricao`) — se já existe uma
    // versão editada, usa ela; senão usa a padrão do catálogo como ponto de partida.
    _anomaliaDescCtrl.text = (widget.anomaliaBase['anomalia_descricao'] ?? widget.anomaliaBase['descricao'])?.toString() ?? '';
    // "Descrição do Risco" segue a mesma lógica, mas a partir de `anomalias.risco_descricao`.
    _riscoDescCtrl.text = (widget.anomaliaBase['risco_descricao'])?.toString() ?? '';
    _areaCtrl.addListener(_atualizarGut);
    _majCtrl.addListener(_atualizarGut);
  }

  @override
  void dispose() {
    _areaCtrl.removeListener(_atualizarGut);
    _majCtrl.removeListener(_atualizarGut);
    _areaCtrl.dispose();
    _majCtrl.dispose();
    _anomaliaDescCtrl.dispose();
    _riscoDescCtrl.dispose();
    super.dispose();
  }

  void _atualizarGut() => setState(() {});

  double get _gutAtual => calcularPontuacaoRiscoGut(
        gravidadeValor: widget.anomaliaBase['gravidade_valor'],
        urgenciaValor: widget.anomaliaBase['urgencia_valor'],
        tendenciaValor: widget.anomaliaBase['tendencia_valor'],
        majoracao: _majCtrl.text,
        areaAfetada: _areaCtrl.text,
      );

  String? _erroArea;

  void _salvar() {
    final area = double.tryParse(_areaCtrl.text.replaceAll(',', '.'));
    final maj = double.tryParse(_majCtrl.text.replaceAll(',', '.').isEmpty ? '0' : _majCtrl.text.replaceAll(',', '.'));
    // Antes o "Salvar" não fazia nada com a área vazia, sem dizer por quê.
    if (area == null || area <= 0 || area > 100) {
      setState(() => _erroArea = 'Informe a área afetada, de 1 a 100%.');
      return;
    }
    if (maj == null || maj < 0) {
      setState(() => _erroArea = 'A majoração precisa ser um número igual ou maior que 0.');
      return;
    }
    widget.onSalvar({
      'id_anomalia': widget.anomaliaBase['id_anomalia'] ?? widget.anomaliaBase['id'],
      'nome': widget.anomaliaBase['nome'],
      'area': _areaCtrl.text.replaceAll(',', '.'),
      'risco_tipo': _tipoRisco,
      'risco_valor': _classeRisco,
      'risco_maj': _majCtrl.text.trim().isEmpty ? '0' : _majCtrl.text.replaceAll(',', '.'),
      'risco_descricao': _riscoDescCtrl.text,
      'anomalia_descricao': _anomaliaDescCtrl.text,
      'gravidade_valor': widget.anomaliaBase['gravidade_valor'],
      'urgencia_valor': widget.anomaliaBase['urgencia_valor'],
      'tendencia_valor': widget.anomaliaBase['tendencia_valor'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = int.tryParse('${widget.anomaliaBase['gravidade_valor'] ?? ''}') ?? 0;
    final u = int.tryParse('${widget.anomaliaBase['urgencia_valor'] ?? ''}') ?? 0;
    final t = int.tryParse('${widget.anomaliaBase['tendencia_valor'] ?? ''}') ?? 0;
    final faixa = FaixaGut.de(_gutAtual);

    InputDecoration deco(String dica, {String? sufixo}) => InputDecoration(
          hintText: dica,
          suffixText: sufixo,
          hintStyle: const TextStyle(color: kIvSuave),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kIvBorda)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        );
    Widget rotulo(String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kIvTexto)),
        );
    Widget fator(String letra, String nome, int valor) => Expanded(
          child: Column(
            children: [
              Text('$valor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kIvTinta)),
              Text(nome, style: const TextStyle(fontSize: 11, color: kIvSuave)),
            ],
          ),
        );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Anomalia', style: TextStyle(fontSize: 12, color: kIvSuave)),
                        Text(
                          widget.anomaliaBase['nome']?.toString() ?? '',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kIvTinta),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: widget.onFechar ?? widget.onApagar,
                    icon: const Icon(Icons.close, color: kIvSuave),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cálculo do G.U.T à vista: quem preenche entende de onde vem
              // o número (G × U × T × majoração × área).
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: faixa.fundo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: faixa.cor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        fator('G', 'Gravidade', g),
                        const Text('×', style: TextStyle(fontSize: 18, color: kIvSuave)),
                        fator('U', 'Urgência', u),
                        const Text('×', style: TextStyle(fontSize: 18, color: kIvSuave)),
                        fator('T', 'Tendência', t),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${g * u * t} × (1 + ${_majCtrl.text.isEmpty ? '0' : _majCtrl.text}%) × ${_areaCtrl.text.isEmpty ? '0' : _areaCtrl.text}%',
                            style: const TextStyle(fontSize: 12, color: kIvTexto),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatarGut(_gutAtual),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: faixa.cor),
                            ),
                            Text('G.U.T · ${faixa.rotulo}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: faixa.cor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              rotulo('Área afetada'),
              TextField(
                controller: _areaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_erroArea != null) setState(() => _erroArea = null);
                },
                decoration: deco('0', sufixo: '%').copyWith(errorText: _erroArea),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in const [5, 10, 25, 50, 75, 100])
                    ActionChip(
                      label: Text('$v%'),
                      onPressed: () => setState(() {
                        _areaCtrl.text = '$v';
                        _erroArea = null;
                      }),
                      backgroundColor: _areaCtrl.text == '$v' ? const Color(0xFFFFF3E0) : Colors.white,
                      side: BorderSide(color: _areaCtrl.text == '$v' ? AppColors.primary : kIvBorda),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              rotulo('Majoração'),
              TextField(
                controller: _majCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: deco('0', sufixo: '%'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Acréscimo sobre o risco quando há agravantes (ex.: 100% dobra a pontuação).',
                style: TextStyle(fontSize: 11, color: kIvSuave),
              ),
              const SizedBox(height: 16),

              rotulo('Descrição da anomalia'),
              TextField(
                controller: _anomaliaDescCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: deco('Como a anomalia se apresenta neste elemento'),
              ),
              const SizedBox(height: 16),

              rotulo('Tipo do risco'),
              PilulasIv<String>(
                opcoes: const [('Humano', 'Humano'), ('Ambiental', 'Ambiental'), ('Material', 'Material')],
                valor: _tipoRisco,
                aoMudar: (v) => setState(() => _tipoRisco = v),
              ),
              const SizedBox(height: 14),
              rotulo('Classe do risco'),
              PilulasIv<String>(
                opcoes: const [('Baixo', 'Baixo'), ('Médio', 'Médio'), ('Alto', 'Alto')],
                valor: _classeRisco,
                aoMudar: (v) => setState(() => _classeRisco = v),
                corDe: (v) => switch (v) {
                  'Alto' => const Color(0xFFB3261E),
                  'Médio' => const Color(0xFFB26A00),
                  _ => const Color(0xFF2E7D32),
                },
              ),
              const SizedBox(height: 16),

              rotulo('Descrição do risco'),
              TextField(
                controller: _riscoDescCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: deco('Que risco a anomalia oferece'),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onApagar,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFB3261E)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: kIvTinta,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Salvar anomalia', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DE MARCAÇÃO DA PLANTA
// ==========================================
// ==========================================
// MODAL DE MARCAÇÃO DA PLANTA (CORRIGIDO)
// ==========================================
class ModalMarcacaoPlantaApp extends StatefulWidget {
  final List<MarcacaoPlantaData> marcacoesIniciais;
  final String imageUrl;
  const ModalMarcacaoPlantaApp({super.key, required this.marcacoesIniciais, required this.imageUrl});
  @override
  State<ModalMarcacaoPlantaApp> createState() => _ModalMarcacaoPlantaAppState();
}

class _ModalMarcacaoPlantaAppState extends State<ModalMarcacaoPlantaApp> {
  late List<MarcacaoPlantaData> _marcacoes;
  int? _indiceSelecionado;
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _zoom = TransformationController();
  bool _confirmando = false;

  static const double _tamanhoMinimo = 0.02;

  // As três primeiras são as cores de sempre (compatíveis com o que já está
  // salvo); as demais ajudam a diferenciar várias marcações na mesma planta.
  static const _cores = <(Color, String)>[
    (Color(0xFFFF9800), 'Laranja'),
    (Color(0xFFF44336), 'Vermelho'),
    (Color(0xFF2196F3), 'Azul'),
    (Color(0xFF2E7D32), 'Verde'),
    (Color(0xFF8E24AA), 'Roxo'),
    (Color(0xFF2E3033), 'Grafite'),
  ];

  @override
  void initState() {
    super.initState();
    _marcacoes = widget.marcacoesIniciais.map((m) => m.copiar()).toList();
    _indiceSelecionado = _marcacoes.isEmpty ? null : 0;
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  MarcacaoPlantaData? get _selecionada =>
      _indiceSelecionado != null && _indiceSelecionado! < _marcacoes.length ? _marcacoes[_indiceSelecionado!] : null;

  Offset _dentro(Offset p, MarcacaoPlantaData m) => Offset(
        p.dx.clamp(m.largura / 2, 1.0 - m.largura / 2),
        p.dy.clamp(m.altura / 2, 1.0 - m.altura / 2),
      );

  void _adicionarMarcacao([Offset posicao = const Offset(0.5, 0.5)]) {
    setState(() {
      final base = _selecionada;
      // A nova herda formato, cor e tamanho da selecionada: marcar vários
      // pontos iguais fica rápido.
      final nova = MarcacaoPlantaData(
        posicao: posicao,
        formato: base?.formato ?? 'Círculo',
        cor: base?.cor ?? _cores.first.$1,
        largura: base?.largura ?? 0.05,
        altura: base?.altura ?? 0.05,
      );
      nova.posicao = _dentro(posicao, nova);
      _marcacoes.add(nova);
      _indiceSelecionado = _marcacoes.length - 1;
    });
  }

  void _duplicarSelecionada() {
    final m = _selecionada;
    if (m == null) return;
    setState(() {
      final copia = m.copiar()..posicao = _dentro(m.posicao + const Offset(0.06, 0.06), m);
      _marcacoes.add(copia);
      _indiceSelecionado = _marcacoes.length - 1;
    });
  }

  void _removerSelecionada() {
    final indice = _indiceSelecionado;
    if (indice == null) return;
    setState(() {
      _marcacoes.removeAt(indice);
      _indiceSelecionado = _marcacoes.isEmpty ? null : (indice >= _marcacoes.length ? _marcacoes.length - 1 : indice);
    });
  }

  /// Toque em área livre da planta: leva a marcação selecionada até ali (ou
  /// cria a primeira). Antes só dava para arrastar a partir do centro.
  void _tocarNaPlanta(Offset local, double lado) {
    final ponto = Offset(local.dx / lado, local.dy / lado);
    final m = _selecionada;
    if (m == null) {
      _adicionarMarcacao(ponto);
      return;
    }
    setState(() => m.posicao = _dentro(ponto, m));
  }

  Size _viewport = Size.zero;

  /// Zoom pelos botões, mantendo o centro da área visível no lugar.
  void _ajustarZoom(double fator) {
    final atual = _zoom.value.getMaxScaleOnAxis();
    final alvo = (atual * fator).clamp(1.0, 5.0).toDouble();
    final centro = _zoom.toScene(_viewport.center(Offset.zero));
    _zoom.value = Matrix4.translationValues(_viewport.width / 2 - centro.dx * alvo, _viewport.height / 2 - centro.dy * alvo, 0)
      ..multiply(Matrix4.diagonal3Values(alvo, alvo, 1));
  }

  // Maior largura/altura (fração da planta) que cabe sem passar da borda,
  // dada a posição atual do centro da marcação — "sem limites, até a borda".
  double _larguraMaxima(MarcacaoPlantaData m) =>
      (2 * (m.posicao.dx < (1 - m.posicao.dx) ? m.posicao.dx : (1 - m.posicao.dx))).clamp(_tamanhoMinimo, 1.0);
  double _alturaMaxima(MarcacaoPlantaData m) =>
      (2 * (m.posicao.dy < (1 - m.posicao.dy) ? m.posicao.dy : (1 - m.posicao.dy))).clamp(_tamanhoMinimo, 1.0);

  Future<void> _confirmar() async {
    setState(() {
      _confirmando = true;
      // A imagem composta vai para o relatório: sem o destaque de seleção
      // e sem zoom, a planta inteira com as marcações como ficaram.
      _indiceSelecionado = null;
      _zoom.value = Matrix4.identity();
    });
    File? fotoComposta;
    try {
      // Garante que a planta (Image.network) já terminou de carregar/pintar
      // antes de capturar o RepaintBoundary — senão a captura pode sair em
      // branco (imagem ainda carregando) mesmo com as marcações posicionadas.
      if (mounted) await precacheImage(StorageNetworkImage(widget.imageUrl), context);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final tempDir = Directory.systemTemp;
            final file = File('${tempDir.path}/marcacao_${DateTime.now().millisecondsSinceEpoch}.png');
            await file.writeAsBytes(byteData.buffer.asUint8List());
            fotoComposta = file;
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso: RepaintBoundary falhou, salvando apenas coordenadas. Erro: $e');
    }
    if (mounted) Navigator.pop(context, (marcacoes: _marcacoes, fotoComposta: fotoComposta));
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1180, maxHeight: tela.height * 0.94),
        child: LayoutBuilder(
          builder: (context, c) {
            final largo = c.maxWidth >= 820;
            final planta = _buildPlanta();
            final painel = _buildPainel(largo: largo);
            return Column(
              children: [
                _buildCabecalho(),
                Expanded(
                  child: largo
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: planta),
                            Container(
                              width: 320,
                              decoration: const BoxDecoration(border: Border(left: BorderSide(color: kIvBorda))),
                              child: painel,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 5, child: planta),
                            Container(
                              constraints: BoxConstraints(maxHeight: c.maxHeight * 0.42),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kIvBorda))),
                              child: painel,
                            ),
                          ],
                        ),
                ),
                _buildRodape(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.ads_click_rounded, color: kIvLaranjaTexto, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Marcar o local na planta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kIvTinta)),
                Text(
                  'Toque na planta para posicionar · arraste a marcação para ajustar · use dois dedos ou a roda do mouse para zoom',
                  style: TextStyle(fontSize: 12, color: kIvSuave, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Fechar sem salvar', onPressed: _confirmando ? null : () => Navigator.pop(context), icon: const Icon(Icons.close, color: kIvSuave)),
        ],
      ),
    );
  }

  Widget _buildPlanta() {
    return Container(
      color: const Color(0xFFF1F1EF),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Área quadrada = mesma referência usada ao salvar e ao mostrar
              // a prévia no registro — as posições (0 a 1) não mudam.
              final lado = (constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight) - 24;
              _viewport = constraints.biggest;
              return InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Container(
                    width: lado,
                    height: lado,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _tocarNaPlanta(d.localPosition, lado),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            ImagemStorage.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              width: lado,
                              height: lado,
                              loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              errorBuilder: (c, e, s) => const Center(child: Text('Erro ao carregar a planta', style: TextStyle(color: kIvSuave))),
                            ),
                            for (var i = 0; i < _marcacoes.length; i++) _buildMarcacao(i, lado),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Zoom por botão: no computador sem touchpad não havia como aproximar.
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: 'Aproximar', onPressed: () => _ajustarZoom(1.5), icon: const Icon(Icons.add, size: 20)),
                  IconButton(tooltip: 'Afastar', onPressed: () => _ajustarZoom(1 / 1.5), icon: const Icon(Icons.remove, size: 20)),
                  IconButton(tooltip: 'Planta inteira', onPressed: () => _zoom.value = Matrix4.identity(), icon: const Icon(Icons.fit_screen_outlined, size: 20)),
                ],
              ),
            ),
          ),
          if (_marcacoes.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: kIvTinta.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Toque na planta onde fica o local', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarcacao(int i, double lado) {
    final m = _marcacoes[i];
    final selecionada = i == _indiceSelecionado;
    final largura = m.largura * lado;
    final altura = m.altura * lado;
    // Área de toque mínima: marcações pequenas eram difíceis de pegar.
    const toqueMinimo = 36.0;
    final areaL = largura < toqueMinimo ? toqueMinimo : largura;
    final areaA = altura < toqueMinimo ? toqueMinimo : altura;
    return Positioned(
      left: (m.posicao.dx * lado) - areaL / 2,
      top: (m.posicao.dy * lado) - areaA / 2,
      width: areaL,
      height: areaA,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _indiceSelecionado = i),
        onPanStart: (_) => setState(() => _indiceSelecionado = i),
        onPanUpdate: (details) {
          // `delta` já vem no espaço da planta (descontado o zoom).
          setState(() => m.posicao = _dentro(m.posicao + Offset(details.delta.dx / lado, details.delta.dy / lado), m));
        },
        child: Center(
          child: Transform.rotate(
            angle: m.rotacao,
            child: Container(
              width: largura,
              height: altura,
              decoration: BoxDecoration(
                color: m.cor.withValues(alpha: selecionada ? 0.65 : 0.5),
                shape: m.formato == 'Círculo' ? BoxShape.circle : BoxShape.rectangle,
                border: Border.all(color: Colors.white, width: selecionada ? 3 : 2),
                boxShadow: selecionada ? [BoxShadow(color: m.cor.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)] : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rotuloPainel(String texto, {String? valor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kIvTexto))),
          if (valor != null) Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kIvTinta)),
        ],
      ),
    );
  }

  Widget _buildPainel({required bool largo}) {
    final sel = _selecionada;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _marcacoes.isEmpty ? 'Marcações' : 'Marcações (${_marcacoes.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kIvTinta),
                ),
              ),
              TextButton.icon(
                onPressed: () => _adicionarMarcacao(),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Nova', style: TextStyle(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: kIvLaranjaTexto),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_marcacoes.isEmpty)
            const Text('Nenhuma marcação ainda.', style: TextStyle(fontSize: 13, color: kIvSuave))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _marcacoes.length; i++)
                  ChoiceChip(
                    avatar: Icon(
                      _marcacoes[i].formato == 'Círculo' ? Icons.circle : Icons.square_rounded,
                      size: 14,
                      color: _marcacoes[i].cor,
                    ),
                    label: Text('${i + 1}'),
                    selected: i == _indiceSelecionado,
                    onSelected: (_) => setState(() => _indiceSelecionado = i),
                    showCheckmark: false,
                    selectedColor: const Color(0xFFFFF3E0),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: i == _indiceSelecionado ? AppColors.primary : kIvBorda),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: kIvTinta),
                  ),
              ],
            ),
          if (sel != null) ...[
            const Divider(height: 28),
            _rotuloPainel('Formato'),
            PilulasIv<String>(
              opcoes: const [('Círculo', 'Círculo'), ('Retângulo', 'Retângulo')],
              valor: sel.formato,
              aoMudar: (v) => setState(() => sel.formato = v),
            ),
            const SizedBox(height: 16),
            _rotuloPainel('Cor'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (cor, nome) in _cores)
                  Tooltip(
                    message: nome,
                    child: Semantics(
                      label: 'Cor $nome',
                      selected: sel.cor.toARGB32() == cor.toARGB32(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => sel.cor = cor),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: cor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel.cor.toARGB32() == cor.toARGB32() ? kIvTinta : Colors.white,
                              width: sel.cor.toARGB32() == cor.toARGB32() ? 3 : 2,
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
                          ),
                          child: sel.cor.toARGB32() == cor.toARGB32() ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _rotuloPainel('Largura', valor: '${(sel.largura * 100).round()}%'),
            _slider(
              valor: sel.largura,
              maximo: _larguraMaxima(sel),
              aoMudar: (v) => setState(() {
                if (sel.formato == 'Círculo') {
                  // Círculo continua círculo: altura acompanha a largura.
                  final lim = v.clamp(_tamanhoMinimo, _alturaMaxima(sel));
                  sel.largura = lim;
                  sel.altura = lim;
                } else {
                  sel.largura = v;
                }
              }),
            ),
            if (sel.formato != 'Círculo') ...[
              _rotuloPainel('Altura', valor: '${(sel.altura * 100).round()}%'),
              _slider(valor: sel.altura, maximo: _alturaMaxima(sel), aoMudar: (v) => setState(() => sel.altura = v)),
              _rotuloPainel('Rotação', valor: '${(sel.rotacao * 180 / 3.141592653589793).round()}°'),
              _slider(valor: sel.rotacao, minimo: 0, maximo: 6.28, aoMudar: (v) => setState(() => sel.rotacao = v)),
              Wrap(
                spacing: 6,
                children: [
                  for (final graus in const [0, 45, 90, 135])
                    ActionChip(
                      label: Text('$graus°'),
                      onPressed: () => setState(() => sel.rotacao = graus * 3.141592653589793 / 180),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kIvBorda),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _duplicarSelecionada,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Duplicar'),
                    style: OutlinedButton.styleFrom(foregroundColor: kIvTinta, side: const BorderSide(color: kIvBorda), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removerSelecionada,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remover'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB3261E),
                      side: const BorderSide(color: Color(0xFFF5C2C0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider({required double valor, double minimo = _tamanhoMinimo, required double maximo, required ValueChanged<double> aoMudar}) {
    final max = maximo <= minimo ? minimo + 0.001 : maximo;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: const Color(0xFFEDEDED),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 4,
      ),
      child: Slider(value: valor.clamp(minimo, max), min: minimo, max: max, onChanged: aoMudar),
    );
  }

  Widget _buildRodape() {
    final n = _marcacoes.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kIvBorda))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                n == 0 ? 'Nenhuma marcação' : (n == 1 ? '1 marcação' : '$n marcações'),
                style: const TextStyle(fontSize: 13, color: kIvSuave),
              ),
            ),
            TextButton(onPressed: _confirmando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _confirmando ? null : _confirmar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: kIvTinta,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _confirmando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kIvTinta))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_confirmando ? 'Gerando imagem...' : 'Confirmar', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
