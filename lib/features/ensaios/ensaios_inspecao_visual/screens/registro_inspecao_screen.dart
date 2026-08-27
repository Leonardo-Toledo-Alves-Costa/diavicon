import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../empresa/providers/campos_personalizaveis_provider.dart';
import '../utils/risco_gut_calculo.dart';

// TODO: Ajuste os imports abaixo para o caminho correto dos seus arquivos no projeto
import '../widgets/novo_local_modal.dart';
import '../widgets/novo_tipo_elemento_modal.dart';

// ==========================================
// CLASSES AUXILIARES DE ESTADO
// ==========================================
class FotoGaleriaItem {
  File? arquivo;
  String? urlOriginal;
  String descricao;
  FotoGaleriaItem({this.arquivo, this.urlOriginal, this.descricao = ''});
}

class MarcacaoPlantaData {
  Offset posicao;
  String formato; 
  Color cor;
  double largura;
  double altura;
  double rotacao;
  File? fotoMarcacaoGerada; 

  MarcacaoPlantaData({
    required this.posicao,
    this.formato = 'Círculo',
    this.cor = Colors.orange,
    this.largura = 0.05,
    this.altura = 0.05,
    this.rotacao = 0.0,
    this.fotoMarcacaoGerada,
  });
}

// ==========================================
// PROVIDERS DE DADOS DINÂMICOS
// ==========================================

final locaisProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, estruturaId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  
  try {
    var query = supabase.from('estruturas_locais').select('id, nome').eq('estrutura_id', estruturaId);
    // Filtro por empresa desativado temporariamente pois a tabela não tem a coluna no Sql_final.txt
    // Se a sua tiver, adicione: if (userRes != null && userRes['empresa_id'] != null) query = query.eq('empresa_id', userRes['empresa_id']);
    final res = await query.order('nome');
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    final res = await supabase.from('estruturas_locais').select('id, nome').eq('estrutura_id', estruturaId).order('nome');
    return List<Map<String, dynamic>>.from(res);
  }
});

final plantaProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String?>((ref, localId) async {
  if (localId == null) return null;
  final supabase = Supabase.instance.client;
  final resLocal = await supabase.from('estruturas_plantas').select('id, arquivo_url').or('local_id.eq.$localId,local_vinculado.eq.$localId').limit(1).maybeSingle();
  return resLocal;
});

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
        'id, nome, descricao, risco_tipo, risco_valor, gravidade_valor, urgencia_valor, tendencia_valor, sistema_construtivo, empresa_id',
      );

  final res = empresaId != null
      ? await query.inFilter('empresa_id', [empresaId, DIAVICON_EMPRESA_ID]).order('nome')
      : await query.eq('empresa_id', DIAVICON_EMPRESA_ID).order('nome');

  return List<Map<String, dynamic>>.from(res);
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
  
  MarcacaoPlantaData? _marcacaoPlanta;
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
      
      final resPonto = await db.from('ponto_inspecao_visual').select('''*, tipos_elemento(nome, sistemas_id)''').eq('id', widget.pontoInspecaoId!).single();

      _nomeCtrl.text = resPonto['registro'] ?? '';
      _descCtrl.text = resPonto['descricao'] ?? '';
      _localSelecionadoId = resPonto['id_local'];
      _elementoSelecionadoId = resPonto['id_elemento'];
      _tipoElementoSelecionadoNome = resPonto['tipos_elemento']?['nome'];
      _sistemaSelecionadoId = resPonto['tipos_elemento']?['sistemas_id'];

      final resRegiao = await db.from('ponto_inspecao_regiao').select().eq('ponto_id', widget.pontoInspecaoId!).maybeSingle();
      if (resRegiao != null) {
        _plantaIdVinculada = resRegiao['planta_id'];
        _fotoMarcacaoExistente = resRegiao['foto_marcacao'];

        Color corBD = Colors.orange;
        if (resRegiao['cor_marcacao'] == '#2196f3') corBD = Colors.blue;
        if (resRegiao['cor_marcacao'] == '#f44336') corBD = Colors.red;

        _marcacaoPlanta = MarcacaoPlantaData(
          posicao: Offset((resRegiao['pos_x'] as num?)?.toDouble() ?? 0.5, (resRegiao['pos_y'] as num?)?.toDouble() ?? 0.5),
          formato: resRegiao['tipo_marcacao'] ?? 'Círculo',
          cor: corBD,
          largura: (resRegiao['marcacao_largura'] as num?)?.toDouble() ?? 0.05,
          altura: (resRegiao['marcacao_altura'] as num?)?.toDouble() ?? 0.05,
          rotacao: (resRegiao['marcacao_rotacao'] as num?)?.toDouble() ?? 0.0,
        );
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
    final source = await showModalBottomSheet<ImageSource>(
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

    if (source != null) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        final novoItem = FotoGaleriaItem(arquivo: File(pickedFile.path), descricao: '');
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

  Future<void> _salvarRegistroCompleto() async {
    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome do registro.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      String? idTipoElemento;
      if (_tipoElementoSelecionadoNome != null) {
        // O mesmo nome pode existir em mais de um sistema habitacional (ex:
        // "Viga" cadastrada pela empresa e também como padrão Diavicon), então
        // não dá pra confiar em .maybeSingle() só pelo nome — filtra pelo
        // sistema selecionado quando houver, e sempre limita a 1 resultado
        // pra nunca quebrar com "multiple rows returned".
        var queryTipo = supabase.from('tipos_elemento').select('id').eq('nome', _tipoElementoSelecionadoNome!);
        if (_sistemaSelecionadoId != null) {
          queryTipo = queryTipo.eq('sistemas_id', _sistemaSelecionadoId!);
        }
        final resTipo = await queryTipo.limit(1).maybeSingle();
        if (resTipo != null) idTipoElemento = resTipo['id'] as String;
      }

      final isEdicao = widget.pontoInspecaoId != null;
      String pontoId = widget.pontoInspecaoId ?? '';

      final dadosPonto = {
        'registro': _nomeCtrl.text,
        'descricao': _descCtrl.text,
        'id_projeto': widget.projetoId,
        'id_estrutura': widget.estruturaId,
        'id_ponto_geral': widget.inspecaoGeralId,
        'id_local': _localSelecionadoId,
        'id_elemento': _elementoSelecionadoId,
        'id_tipo_elemento': idTipoElemento, 
        'criado_por': userId,
      };

      if (isEdicao) {
        await supabase.from('ponto_inspecao_visual').update(dadosPonto).eq('id', pontoId);
        await supabase.from('ponto_inspecao_regiao').delete().eq('ponto_id', pontoId);
        await supabase.from('ponto_inspecao_visual_galeria').delete().eq('id_inspecao', pontoId);
        await supabase.from('ponto_inspecao_visual_anomalia').delete().eq('id_inspecao', pontoId);
      } else {
        final resPonto = await supabase.from('ponto_inspecao_visual').insert(dadosPonto).select('id').single();
        pontoId = resPonto['id'];
      }

      if (_marcacaoPlanta != null) {
        // Se o usuário reabriu o modal "Marcar" e confirmou, temos uma nova
        // captura pra subir; senão, reaproveita a URL já salva (edição sem
        // remarcar não pode apagar a imagem que já existia).
        String? urlFotoMarcacao = _fotoMarcacaoExistente;
        if (_marcacaoPlanta!.fotoMarcacaoGerada != null) {
           final fileName = 'marcacoes/${DateTime.now().millisecondsSinceEpoch}.png';
           await supabase.storage.from('projetos').upload(fileName, _marcacaoPlanta!.fotoMarcacaoGerada!);
           urlFotoMarcacao = supabase.storage.from('projetos').getPublicUrl(fileName);
        }

        await supabase.from('ponto_inspecao_regiao').insert({
          'ponto_id': pontoId,
          'planta_id': _plantaIdVinculada,
          'pos_x': _marcacaoPlanta!.posicao.dx,
          'pos_y': _marcacaoPlanta!.posicao.dy,
          'tipo_marcacao': _marcacaoPlanta!.formato, 
          'cor_marcacao': '#${_marcacaoPlanta!.cor.toARGB32().toRadixString(16).substring(2)}',
          'marcacao_largura': _marcacaoPlanta!.largura,
          'marcacao_altura': _marcacaoPlanta!.altura,
          'marcacao_rotacao': _marcacaoPlanta!.rotacao,
          'foto_marcacao': urlFotoMarcacao,
          'criado_por': userId,
        });
      }

      for (var item in _fotosGaleria) {
        String urlParaSalvar = item.urlOriginal ?? '';
        if (item.arquivo != null) {
          final fileName = 'inspecoes/${DateTime.now().millisecondsSinceEpoch}_${item.arquivo!.path.split('/').last}';
          await supabase.storage.from('projetos').upload(fileName, item.arquivo!);
          urlParaSalvar = supabase.storage.from('projetos').getPublicUrl(fileName);
        }
        await supabase.from('ponto_inspecao_visual_galeria').insert({'id_inspecao': pontoId, 'foto_url': urlParaSalvar, 'descricao': item.descricao, 'criado_por': userId});
      }

      for (var anomalia in _anomaliasSelecionadas) {
        await supabase.from('ponto_inspecao_visual_anomalia').insert({
          'id_inspecao': pontoId,
          'id_anomalia': anomalia['id_anomalia'],
          'area_afetada': double.tryParse(anomalia['area'].toString()) ?? 0.0,
          'risco_tipo': anomalia['risco_tipo'],
          'risco_valor': anomalia['risco_valor'],
          'risco_descricao': anomalia['risco_descricao'],
          'risco_maj': double.tryParse(anomalia['risco_maj'].toString()) ?? 0.0,
          'criado_por': userId,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdicao ? 'Registro atualizado com sucesso!' : 'Registro salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no banco: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoEdicao) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final locaisAsync = ref.watch(locaisProvider(widget.estruturaId));
    final sistemasAsync = ref.watch(sistemasHabitacionaisProvider);
    final tiposAsync = ref.watch(tiposElementoProvider);
    final elementosAsync = ref.watch(elementosProvider((estruturaId: widget.estruturaId, tipoNome: _tipoElementoSelecionadoNome)));
    final plantaAsync = ref.watch(plantaProvider(_localSelecionadoId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
     
      appBar:  CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            //Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Inspeção Visual', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text( widget.pontoInspecaoId != null ? 'Edição' : 'Registro',style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.pontoInspecaoId != null ? 'Edição de Inspeção' : 'Registro de Inspeção', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 24),

            Text('Nome do Registro', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            TextField(controller: _nomeCtrl, decoration: _inputDeco('Ex: Trincas presentes nas paredes')),
            const SizedBox(height: 16),

            Text('Descrição', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, maxLines: 3, decoration: _inputDeco('Abertura linear de pequena dimensão...')),
            const SizedBox(height: 16),

            Text('Local', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: locaisAsync.when(
                    loading: () => const Center(child: LinearProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => const Text('Erro ao carregar locais'),
                    data: (locais) => _buildDropdown(
                      value: _localSelecionadoId,
                      items: locais.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text(l['nome'].toString()))).toList(),
                      onChanged: (val) => setState(() {
                        _localSelecionadoId = val;
                        _marcacaoPlanta = null; 
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildAddButton(() async {
                  // AQUI CHAMAMOS O NOVO LOCAL MODAL NATIVO DA PLATAFORMA[cite: 12]
                  final res = await showDialog(
                    context: context,
                    builder: (_) => NovoLocalModal(estruturaId: widget.estruturaId), // Assumindo que a classe esteja importada ou declarada
                  );
                  if (res != null) {
                    ref.invalidate(locaisProvider(widget.estruturaId));
                    // Supõe-se que o res contenha os dados do local criado, caso não, deixe o usuário selecionar do dropdown.
                    if (res is Map && res['id'] != null) {
                      setState(() { _localSelecionadoId = res['id'].toString(); _marcacaoPlanta = null; });
                    }
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text('Sistema Habitacional', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
                ),
                if (_sistemaSelecionadoId != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _sistemaSelecionadoId = null;
                      _tipoElementoSelecionadoNome = null;
                      _elementoSelecionadoId = null;
                    }),
                    child: const Icon(Icons.clear, color: Colors.redAccent, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo de Elemento', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Elemento Estrutural', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _tipoElementoSelecionadoNome == null ? 0.4 : 1.0,
                        child: IgnorePointer(
                          ignoring: _tipoElementoSelecionadoNome == null,
                          child: elementosAsync.when(
                            loading: () => const LinearProgressIndicator(color: AppColors.primary),
                            error: (e, _) => const Text('Erro ao carregar'),
                            data: (elementos) => _buildDropdown(
                              value: _elementoSelecionadoId,
                              items: elementos.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nome'].toString(), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) => setState(() => _elementoSelecionadoId = val),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
           // Padding(
            //  padding: const EdgeInsets.only(top: 8.0),
           //  
          //    child: Row(
         //       children: [
         //         Expanded(
          //          child: Align(
            //          alignment: Alignment.centerLeft,
            //          child: _buildTextButtonAdd('Novo Tipo', () async {
           //             // AQUI CHAMAMOS O MODAL NATIVO NOVO TIPO ELEMENTO[cite: 14]
          //              final res = await showDialog(
           //               context: context,
           //               builder: (_) => const NovoTipoElementoModal(),
          //              );
          //              if (res != null && res is String) {
         //                 ref.invalidate(tiposElementoProvider);
         //                 setState(() { _tipoElementoSelecionadoNome = res; _elementoSelecionadoId = null; });
         //               }
        //              }),
        //            ),
        //          ),
             //     const SizedBox(width: 12),
            //      Expanded(
           //         child: Align(
          //            alignment: Alignment.centerLeft,
         //             child: _tipoElementoSelecionadoNome == null 
        //                  ? const SizedBox.shrink() 
       //                   : _buildTextButtonAdd('Novo Elemento', () async {
      //                       // AQUI CHAMAMOS O NOVO MODAL INTERNO DO ELEMENTO ESTRUTURAL
                  //            final res = await showDialog(
                //                context: context,
              //                  builder: (_) => ModalNovoElementoEstrutural(
            //                      estruturaId: widget.estruturaId,
          //                        tipoElemento: _tipoElementoSelecionadoNome!,
        //                          localId: _localSelecionadoId,
      //                          )
    //                          );
  //                            
//
                         //     if (res != null && res is String) {
                        //        ref.invalidate(elementosProvider((estruturaId: widget.estruturaId, tipoNome: _tipoElementoSelecionadoNome)));
                       //         setState(() => _elementoSelecionadoId = res);
                      //        }
                     //       }),
                   //// ),
                 // ),
               // ],
             // ),
           // ),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)]),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text('Localização em Planta', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  iconColor: const Color(0xFFFFA726), collapsedIconColor: const Color(0xFFFFA726),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_marcacaoPlanta != null ? 'Editar' : 'Inserir', style: GoogleFonts.lato(color: const Color(0xFFFFA726), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 4), const Icon(Icons.arrow_downward, color: Color(0xFFFFA726), size: 16),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _localSelecionadoId == null
                        ? const Padding(padding: EdgeInsets.all(16), child: Text('Selecione um local primeiro.', style: TextStyle(color: Colors.grey)))
                        : plantaAsync.when(
                        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                        error: (e, _) => const Padding(padding: EdgeInsets.all(24), child: Text('Erro ao carregar planta.')),
                        data: (plantaData) {
                          if (plantaData == null) return const Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma planta cadastrada para este local.', style: TextStyle(color: Colors.grey)));
                          _plantaIdVinculada = plantaData['id']?.toString();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 160,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                clipBehavior: Clip.hardEdge,
                                child: _marcacaoPlanta?.fotoMarcacaoGerada != null
                                    ? Image.file(_marcacaoPlanta!.fotoMarcacaoGerada!, fit: BoxFit.cover, width: double.infinity)
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          // Mesma lógica de proporção (área quadrada = renderSize)
                                          // usada em ModalMarcacaoPlantaApp, pra a marcação
                                          // aparecer no mesmo lugar aqui e lá.
                                          final renderSize = constraints.maxWidth < constraints.maxHeight
                                              ? constraints.maxWidth
                                              : constraints.maxHeight;
                                          return Center(
                                            child: SizedBox(
                                              width: renderSize,
                                              height: renderSize,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Image.network(
                                                    plantaData['arquivo_url'],
                                                    fit: BoxFit.contain,
                                                    width: renderSize,
                                                    height: renderSize,
                                                    errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                                  ),
                                                  if (_marcacaoPlanta != null)
                                                    Positioned(
                                                      left: (_marcacaoPlanta!.posicao.dx * renderSize) - ((_marcacaoPlanta!.largura * renderSize) / 2),
                                                      top: (_marcacaoPlanta!.posicao.dy * renderSize) - ((_marcacaoPlanta!.altura * renderSize) / 2),
                                                      child: Transform.rotate(
                                                        angle: _marcacaoPlanta!.rotacao,
                                                        child: Container(
                                                          width: _marcacaoPlanta!.largura * renderSize,
                                                          height: _marcacaoPlanta!.altura * renderSize,
                                                          decoration: BoxDecoration(color: _marcacaoPlanta!.cor.withValues(alpha: 0.6), shape: _marcacaoPlanta!.formato == 'Círculo' ? BoxShape.circle : BoxShape.rectangle, border: Border.all(color: Colors.white, width: 2)),
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
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final result = await showDialog<MarcacaoPlantaData>(
                                      context: context,
                                      builder: (_) => ModalMarcacaoPlantaApp(dadosIniciais: _marcacaoPlanta, imageUrl: plantaData['arquivo_url']),
                                    );
                                    if (result != null) setState(() => _marcacaoPlanta = result);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                                  child: const Text('Marcar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Galeria', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._fotosGaleria.map((item) => GestureDetector(
                          onTap: () => _abrirModalEdicaoFoto(item),
                          child: Container(
                            width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: item.arquivo != null ? FileImage(item.arquivo!) as ImageProvider : NetworkImage(item.urlOriginal!), fit: BoxFit.cover)),
                          ),
                        )),
                        GestureDetector(
                          onTap: _abrirOpcoesCaptura,
                          child: Container(
                            width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400, width: 1.5)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_outlined, color: Colors.grey), const SizedBox(height: 4), Text('Adicionar fotos', style: GoogleFonts.lato(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center)]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Anomalias Identificadas', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                ElevatedButton(
                  onPressed: _abrirFluxoNovaAnomalia,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                  child: const Text('Inserir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_anomaliasSelecionadas.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nenhuma anomalia inserida.', style: TextStyle(color: Colors.grey)))),
              
            ..._anomaliasSelecionadas.asMap().entries.map((entry) {
              final index = entry.key;
              final anomalia = entry.value;
              Color corRisco = anomalia['risco_valor'].toString().toLowerCase() == 'alto' ? Colors.red : Colors.orange;
              Color bgRisco = anomalia['risco_valor'].toString().toLowerCase() == 'alto' ? Colors.red.shade50 : Colors.orange.shade50;
              final pontuacao = _calcularPontuacaoRisco(anomalia);

              return GestureDetector(
                onTap: () => _abrirEdicaoAnomalia(index),
                child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(anomalia['nome'], style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 4),
                          Text('Área afetada ${anomalia['area']}%', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bgRisco, borderRadius: BorderRadius.circular(12)), child: Text('Risco ${anomalia['risco_tipo']} ${anomalia['risco_valor']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corRisco))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text('G.U.T', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(width: 8),
                            Text(pontuacao.toStringAsFixed(2), style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text('Majoração ${anomalia['risco_maj'] ?? '0'}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))),
                      ],
                    ),
                  ],
                ),
                ),
              );
            }),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _salvando ? null : _salvarRegistroCompleto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: _salvando 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(widget.pontoInspecaoId != null ? 'Atualizar Registro' : 'Salvar Registro Completo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE UI ---
  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFA726))),
    );
  }

  Widget _buildDropdown({String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, hint: Text('Selecione', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)), value: value, items: items, onChanged: onChanged)),
    );
  }

  Widget _buildTextButtonAdd(String text, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('+ $text', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFFFA726)))));
  }

  Widget _buildAddButton(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: const CircleAvatar(backgroundColor: Color(0xFFFFA726), radius: 24, child: Icon(Icons.add, color: Colors.white)));
  }
}

// ==========================================
// MODAL DEDICADO: NOVO ELEMENTO ESTRUTURAL
// ==========================================
class ModalNovoElementoEstrutural extends StatefulWidget {
  final String estruturaId;
  final String tipoElemento;
  final String? localId;

  const ModalNovoElementoEstrutural({super.key, required this.estruturaId, required this.tipoElemento, this.localId});

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
            const SizedBox(height: 24),
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
    if (_arquivoEditado != null) {
      provider = FileImage(_arquivoEditado!);
    } else if (widget.item.urlOriginal != null) {
      provider = NetworkImage(widget.item.urlOriginal!);
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
class ModalSelecionarAnomalia extends ConsumerWidget {
  final Function(Map<String, dynamic>) onSelecionar;
  final String? sistemaFiltro;
  const ModalSelecionarAnomalia({super.key, required this.onSelecionar, this.sistemaFiltro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomaliasAsync = ref.watch(catalogoAnomaliasProvider).whenData((lista) {
      if (sistemaFiltro == null) return lista;
      return lista.where((a) => a['sistema_construtivo'] == sistemaFiltro).toList();
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Selecione a Anomalia', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey))]),
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
              child: anomaliasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => const Center(child: Text('Erro ao carregar catálogo')),
                data: (lista) {
                  if (lista.isEmpty) return const Center(child: Text('Nenhuma anomalia cadastrada.', style: TextStyle(color: Colors.grey)));
                  return ListView.separated(
                    itemCount: lista.length, separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = lista[index];
                      return GestureDetector(
                        onTap: () => onSelecionar(item),
                        child: Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['nome'].toString(), style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), const SizedBox(height: 4), Text(item['descricao']?.toString() ?? 'Sem descrição', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)]),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ],
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
  final _descCtrl = TextEditingController();
  String _tipoRisco = 'Humano';
  String _classeRisco = 'Alto';

  @override
  void initState() {
    super.initState();
    _tipoRisco = widget.anomaliaBase['risco_tipo'] ?? 'Humano';
    _classeRisco = widget.anomaliaBase['risco_valor'] ?? 'Alto';
    _areaCtrl.text = widget.anomaliaBase['area']?.toString() ?? '';
    _majCtrl.text = widget.anomaliaBase['risco_maj']?.toString() ?? '0';
    _descCtrl.text = (widget.anomaliaBase['risco_descricao'] ?? widget.anomaliaBase['descricao'])?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Detalhe da Anomalia', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))), GestureDetector(onTap: widget.onFechar ?? widget.onApagar, child: const Icon(Icons.close, color: Colors.grey))]),
            const SizedBox(height: 16),
            Text(widget.anomaliaBase['nome'], style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 4),
            Text(
              'Gravidade ${widget.anomaliaBase['gravidade_valor'] ?? '-'} · Urgência ${widget.anomaliaBase['urgencia_valor'] ?? '-'} · Tendência ${widget.anomaliaBase['tendencia_valor'] ?? '-'}',
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(children: [Expanded(flex: 2, child: Text('Área Afetada (%)', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600))), Expanded(flex: 1, child: TextField(controller: _areaCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(hintText: '00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 8))))]),
            const SizedBox(height: 16),
            Text('Tipo de Risco', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _tipoRisco, items: ['Humano', 'Ambiental', 'Material'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _tipoRisco = val!)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Classe do Risco', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)), const SizedBox(height: 4), Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _classeRisco, items: ['Alto', 'Médio', 'Baixo'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _classeRisco = val!))))])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Majoração (%)', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)), const SizedBox(height: 4), TextField(controller: _majCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(hintText: '00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(vertical: 14)))])),
              ],
            ),
            const SizedBox(height: 16),
            Text('Descrição', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Descrição da anomalia', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(onPressed: widget.onApagar, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text('Apagar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  onPressed: () {
                    if (_areaCtrl.text.isEmpty) return;
                    widget.onSalvar({
                      'id_anomalia': widget.anomaliaBase['id_anomalia'] ?? widget.anomaliaBase['id'],
                      'nome': widget.anomaliaBase['nome'],
                      'area': _areaCtrl.text,
                      'risco_tipo': _tipoRisco,
                      'risco_valor': _classeRisco,
                      'risco_maj': _majCtrl.text,
                      'risco_descricao': _descCtrl.text,
                      'gravidade_valor': widget.anomaliaBase['gravidade_valor'],
                      'urgencia_valor': widget.anomaliaBase['urgencia_valor'],
                      'tendencia_valor': widget.anomaliaBase['tendencia_valor'],
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                  child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
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
  final MarcacaoPlantaData? dadosIniciais;
  final String imageUrl;
  const ModalMarcacaoPlantaApp({super.key, this.dadosIniciais, required this.imageUrl});
  @override
  State<ModalMarcacaoPlantaApp> createState() => _ModalMarcacaoPlantaAppState();
}

class _ModalMarcacaoPlantaAppState extends State<ModalMarcacaoPlantaApp> {
  late MarcacaoPlantaData _dados;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _dados = widget.dadosIniciais ?? MarcacaoPlantaData(posicao: const Offset(0.5, 0.5));
  }

  Future<void> _salvarMarcacao() async {
    try {
      // Garante que a planta (Image.network) já terminou de carregar/pintar
      // antes de capturar o RepaintBoundary — senão a captura pode sair em
      // branco (imagem ainda carregando) mesmo com a marcação posicionada.
      if (mounted) await precacheImage(NetworkImage(widget.imageUrl), context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      RenderRepaintBoundary? boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/marcacao_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
          _dados.fotoMarcacaoGerada = file;
        }
      }
    } catch (e) {
      debugPrint('Aviso: RepaintBoundary falhou, salvando apenas coordenadas. Erro: $e');
    }
    if (mounted) Navigator.pop(context, _dados);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Marcação do local em planta', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              color: const Color(0xFFF0F0F0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Definimos a área base proporcional (quadrada responsiva ao container)
                  double renderSize = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;

                  return InteractiveViewer(
                    minScale: 0.5, maxScale: 5.0,
                    child: Center(
                      child: SizedBox(
                        width: renderSize,
                        height: renderSize, 
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.network(widget.imageUrl, fit: BoxFit.contain, width: renderSize, height: renderSize, errorBuilder: (c,e,s) => const Center(child: Text('Erro ao carregar planta'))),
                              Positioned(
                                // Correção proporcional baseada no renderSize real da tela
                                left: (_dados.posicao.dx * renderSize) - ((_dados.largura * renderSize) / 2),
                                top: (_dados.posicao.dy * renderSize) - ((_dados.altura * renderSize) / 2),
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      double newX = _dados.posicao.dx + (details.delta.dx / renderSize);
                                      double newY = _dados.posicao.dy + (details.delta.dy / renderSize);
                                      _dados.posicao = Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0));
                                    });
                                  },
                                  child: Transform.rotate(
                                    angle: _dados.rotacao,
                                    child: Container(
                                      // Proporção correta em relação ao tamanho da área da planta
                                      width: _dados.largura * renderSize, 
                                      height: _dados.altura * renderSize,
                                      decoration: BoxDecoration(
                                        color: _dados.cor.withValues(alpha: 0.5), 
                                        shape: _dados.formato == 'Círculo' ? BoxShape.circle : BoxShape.rectangle, 
                                        border: Border.all(color: Colors.white, width: 2)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(onTap: () => setState(() => _dados.cor = Colors.orange), child: CircleAvatar(backgroundColor: Colors.orange, radius: 16, child: _dados.cor == Colors.orange ? const Icon(Icons.check, size: 16, color: Colors.white) : null)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() => _dados.cor = Colors.blue), child: CircleAvatar(backgroundColor: Colors.blue, radius: 16, child: _dados.cor == Colors.blue ? const Icon(Icons.check, size: 16, color: Colors.white) : null)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() => _dados.cor = Colors.red), child: CircleAvatar(backgroundColor: Colors.red, radius: 16, child: _dados.cor == Colors.red ? const Icon(Icons.check, size: 16, color: Colors.white) : null)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          GestureDetector(onTap: () => setState(() => _dados.formato = 'Círculo'), child: Icon(Icons.circle_outlined, color: _dados.formato == 'Círculo' ? Colors.orange : Colors.grey)), const SizedBox(width: 12), 
                          GestureDetector(onTap: () => setState(() => _dados.formato = 'Retângulo'), child: Icon(Icons.square_outlined, color: _dados.formato == 'Retângulo' ? Colors.orange : Colors.grey)),
                        ]
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Largura', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), Slider(value: _dados.largura, min: 0.02, max: 0.3, onChanged: (v) => setState(() => _dados.largura = v), activeColor: Colors.orange)])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Altura', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), Slider(value: _dados.altura, min: 0.02, max: 0.3, onChanged: (v) => setState(() => _dados.altura = v), activeColor: Colors.orange)])),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Rotação', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), Slider(value: _dados.rotacao, min: 0.0, max: 6.28, onChanged: (v) => setState(() => _dados.rotacao = v), activeColor: Colors.orange)])),
                    Expanded(child: Container(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _salvarMarcacao, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}