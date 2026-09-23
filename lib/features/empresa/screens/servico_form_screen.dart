import 'package:diavicon/core/security/upload_seguro.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import '../../empresas_servicos/screens/servico_detalhe_screen.dart';
import '../providers/empresa_profile_provider.dart' show empresaDetalheProvider;
import '../../../core/widgets/aviso_topo.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/painel_servicos_provider.dart';

class ServicoFormScreen extends ConsumerStatefulWidget {
  final String empresaId;
  final ServicoEmpresaModel? servico; // Se nulo = CRIAR, Se preenchido = EDITAR

  const ServicoFormScreen({super.key, required this.empresaId, this.servico});

  @override
  ConsumerState<ServicoFormScreen> createState() => _ServicoFormScreenState();
}

class _ServicoFormScreenState extends ConsumerState<ServicoFormScreen> {
  bool _isLoading = false;

  final _nomeCtrl = TextEditingController();
  final _nomeAnexoCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();

  String? _categoriaSelecionada;
  final List<String> _categorias = [ 'Serviço', 'Produto', 'Equipamento'];

  File? _fotoPrincipalLocal;
  List<File> _novasFotosGaleria = [];

  @override
  void initState() {
    super.initState();
    if (widget.servico != null) {
      _nomeCtrl.text = widget.servico!.nome;
      _nomeAnexoCtrl.text = widget.servico!.nomeAnexo ?? '';
      _linkCtrl.text = widget.servico!.linkAnexo ?? '';
      _objetivoCtrl.text = widget.servico!.objetivo ?? '';
      _descricaoCtrl.text = widget.servico!.descricao ?? '';
      _categoriaSelecionada = widget.servico!.categoria;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _nomeAnexoCtrl.dispose();
    _linkCtrl.dispose();
    _objetivoCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarFotoPrincipal() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [AndroidUiSettings(toolbarTitle: 'Ajustar Imagem', toolbarColor: AppColors.primary, toolbarWidgetColor: Colors.white, lockAspectRatio: true)],
      );

      if (cropped != null) {
        setState(() => _fotoPrincipalLocal = File(cropped.path));
      }
    }
  }

  Future<void> _adicionarFotoGaleria() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 80);
    
    if (images.isNotEmpty) {
      setState(() {
        _novasFotosGaleria.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  // =======================================================================
  // NOVOS MÉTODOS PARA REMOÇÃO DE FOTOS DA GALERIA
  // =======================================================================

  /// Remove uma foto recém-adicionada que ainda está apenas no estado local.
  void _removerNovaFotoGaleria(int index) {
    setState(() {
      _novasFotosGaleria.removeAt(index);
    });
  }

  /// Remove uma foto que já foi salva no banco de dados (tabela empresa_servicos_galeria).
  Future<void> _removerFotoAntigaGaleria(String idFoto) async {
    // Solicita confirmação do usuário antes de deletar um dado permanente
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover foto da galeria?'),
        content: const Text('Esta ação apagará a foto permanentemente. Deseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Realiza a exclusão do registro na tabela correspondente do Supabase
      await supabase.from('empresa_servicos_galeria').delete().eq('id', idFoto);

      // Invalida o provedor para forçar uma nova busca e atualizar a interface automaticamente
      if (widget.servico != null) {
        ref.invalidate(servicoGaleriaProvider(widget.servico!.id));
      }

      if (mounted) {
        mostrarAviso(context, 'Foto removida da galeria.', tipo: TipoAviso.sucesso);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        mostrarAviso(context, 'Erro no banco ao remover a foto: ${e.message}', tipo: TipoAviso.erro);
      }
    } on AuthException catch (e) {
      if (mounted) {
        mostrarAviso(context, 'Erro de autenticação ao remover a foto: ${e.message}', tipo: TipoAviso.erro);
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'Erro inesperado ao remover a foto: $e', tipo: TipoAviso.erro);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =======================================================================

  /// Abre a tela que o cliente vê, com o que está no formulário agora.
  ///
  /// Serve para conferir como o item fica no perfil público sem precisar
  /// salvar, sair, procurar na lista e abrir. A galeria mostrada é a que já
  /// está salva — fotos ainda não enviadas não aparecem aqui.
  void _preVisualizar() {
    final servicoSalvo = widget.servico;
    if (servicoSalvo == null) {
      mostrarAviso(
        context,
        'Salve o item uma primeira vez para poder pré-visualizar.',
        tipo: TipoAviso.neutro,
      );
      return;
    }

    final empresa = ref.read(empresaDetalheProvider(widget.empresaId)).value;
    final previa = ServicoEmpresaModel(
      id: servicoSalvo.id,
      empresaId: widget.empresaId,
      nome: _nomeCtrl.text.trim().isEmpty ? servicoSalvo.nome : _nomeCtrl.text.trim(),
      descricao: _descricaoCtrl.text.trim(),
      objetivo: _objetivoCtrl.text.trim(),
      categoria: _categoriaSelecionada,
      fotoPrincipal: servicoSalvo.fotoPrincipal,
      linkAnexo: _linkCtrl.text.trim(),
      nomeAnexo: _nomeAnexoCtrl.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServicoDetalheScreen(
          servico: previa,
          empresaNome: empresa?.nome ?? 'Sua empresa',
          empresaFotoUrl: empresa?.fotoUrl,
          empresaCidade: empresa?.cidade,
          empresaEstado: empresa?.estado,
        ),
      ),
    );
  }

  /// Apaga o serviço inteiro: as fotos da galeria, os arquivos no Storage e a
  /// linha do catálogo.
  ///
  /// Até aqui só dava para editar: um item cadastrado errado ficava para
  /// sempre na vitrine da empresa. Só aparece em modo de edição — item que
  /// ainda não foi salvo é só fechar a tela.
  Future<void> _excluirServico() async {
    final servico = widget.servico;
    if (servico == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir do catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Excluir "${servico.nome}" apaga o item, a foto de capa e todas as fotos '
          'da galeria. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Os arquivos saem primeiro, enquanto ainda dá para saber quais são.
      // Falha aqui não impede a exclusão: sobra um arquivo órfão no Storage,
      // que ninguém alcança sem o registro.
      try {
        final caminhos = <String>[];
        final galeria = await supabase
            .from('empresa_servicos_galeria')
            .select('foto_url')
            .eq('servico_id', servico.id);
        for (final linha in (galeria as List)) {
          final caminho = _caminhoNoStorage(linha['foto_url']?.toString());
          if (caminho != null) caminhos.add(caminho);
        }
        final capa = _caminhoNoStorage(servico.fotoPrincipal);
        if (capa != null) caminhos.add(capa);
        if (caminhos.isNotEmpty) await supabase.storage.from('avatars').remove(caminhos);
      } catch (_) {}

      // A galeria antes do serviço: se houver chave estrangeira sem cascata,
      // apagar o serviço primeiro daria erro.
      await supabase.from('empresa_servicos_galeria').delete().eq('servico_id', servico.id);
      await supabase.from('empresa_servicos').delete().eq('id', servico.id);

      ref.invalidate(painelServicosListProvider(widget.empresaId));
      ref.invalidate(servicoGaleriaProvider(servico.id));

      if (!mounted) return;
      mostrarAviso(context, '"${servico.nome}" foi excluído do catálogo.', tipo: TipoAviso.sucesso);
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      if (mounted) mostrarAviso(context, 'Erro no banco ao excluir: ${e.message}', tipo: TipoAviso.erro);
    } catch (e) {
      if (mounted) mostrarAviso(context, 'Erro inesperado ao excluir: $e', tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Caminho do arquivo dentro do bucket, a partir da URL pública.
  static String? _caminhoNoStorage(String? url) {
    if (url == null || url.isEmpty) return null;
    const marca = '/object/public/avatars/';
    final i = url.indexOf(marca);
    if (i < 0) return null;
    return Uri.decodeComponent(url.substring(i + marca.length).split('?').first);
  }

  Future<void> _salvar() async {
    if (_nomeCtrl.text.isEmpty || _categoriaSelecionada == null) {
      mostrarAviso(context, 'Preencha os campos obrigatórios: categoria e nome.', tipo: TipoAviso.erro);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String? fotoPrincipalUrl = widget.servico?.fotoPrincipal;
      String? servicoIdTemp = widget.servico?.id;
      
      // 1. DADOS DO SERVIÇO
      final dadosServico = {
        'empresa_id': widget.empresaId,
        'nome': _nomeCtrl.text.trim(),
        'categoria': _categoriaSelecionada,
        'nome_anexo': _nomeAnexoCtrl.text.trim(),
        'link_anexo': _linkCtrl.text.trim(),
        'objetivo': _objetivoCtrl.text.trim(),
        'descricao': _descricaoCtrl.text.trim(),
      };

      // Inserção ou Atualização Base
      if (servicoIdTemp == null) {
        final resp = await supabase.from('empresa_servicos').insert(dadosServico).select('id').single();
        servicoIdTemp = resp['id'] as String?;
      } else {
        await supabase.from('empresa_servicos').update(dadosServico).eq('id', servicoIdTemp);
      }

      // Validação de segurança para garantir que o ID não é nulo antes de usar no Storage
      if (servicoIdTemp == null) {
        throw Exception('Erro ao gerar o ID do serviço.');
      }
      final String servicoId = servicoIdTemp;

      // 2. UPLOAD FOTO PRINCIPAL
      if (_fotoPrincipalLocal != null) {
        // avatars/empresas/servicos_cad/<servico_id>/...: a política do bucket
        // só deixa o admin da empresa dona do serviço gravar nessa pasta.
        final path = await supabase.storage.from('avatars').enviarArquivoSeguro(
          'empresas/servicos_cad/$servicoId',
          _fotoPrincipalLocal!,
          prefixo: 'capa_',
          fileOptions: const FileOptions(upsert: true),
        );
        fotoPrincipalUrl = supabase.storage.from('avatars').getPublicUrl(path);
        
        await supabase.from('empresa_servicos').update({'foto_principal': fotoPrincipalUrl}).eq('id', servicoId);
      }

      // 3. UPLOAD DA GALERIA
      if (_novasFotosGaleria.isNotEmpty) {
        for (var foto in _novasFotosGaleria) {
          final path = await supabase.storage
              .from('avatars')
              .enviarArquivoSeguro('empresas/servicos_cad/$servicoId', foto, prefixo: 'galeria_');
          final url = supabase.storage.from('avatars').getPublicUrl(path);
          
          await supabase.from('empresa_servicos_galeria').insert({
            'servico_id': servicoId,
            'foto_url': url,
            'criado_por': supabase.auth.currentUser?.id,
          });
        }
      }

      if (mounted) {
        ref.invalidate(painelServicosListProvider(widget.empresaId));
        mostrarAviso(context, 'Salvo com sucesso!', tipo: TipoAviso.sucesso);
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (mounted) mostrarAviso(context, 'Erro no banco: ${e.message}', tipo: TipoAviso.erro);
    } on AuthException catch (e) {
      if (mounted) mostrarAviso(context, 'Erro de autenticação: ${e.message}', tipo: TipoAviso.erro);
    } catch (e) {
      if (mounted) mostrarAviso(context, 'Erro inesperado: $e', tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imgCapa;
    if (_fotoPrincipalLocal != null) {
      imgCapa = FileImage(_fotoPrincipalLocal!);
    } else if (widget.servico?.fotoPrincipal != null) {
      imgCapa = StorageNetworkImage(widget.servico!.fotoPrincipal!);
    }

    // Provider para carregar fotos antigas da galeria (se for modo edição)
    final galeriaAntigaAsync = widget.servico != null ? ref.watch(servicoGaleriaProvider(widget.servico!.id)) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            const Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Edição', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FOTO DE CAPA
            GestureDetector(
              onTap: _capturarFotoPrincipal,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                      image: imgCapa != null ? DecorationImage(image: imgCapa, fit: BoxFit.cover) : null,
                    ),
                    child: imgCapa == null ? const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 40)) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_square, size: 20),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FORMULÁRIO
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Os campos marcados com * são obrigatórios.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const _RotuloCampo('Categoria', obrigatorio: true),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _categoriaSelecionada,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
              ),
              hint: const Text('Selecione'),
              items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _categoriaSelecionada = v),
            ),
            const SizedBox(height: 16),

            _buildTextField('Nome', _nomeCtrl, obrigatorio: true),
            _buildTextField('Nome do anexo', _nomeAnexoCtrl, complemento: '(opcional)'),
            
            // Campo de Link com ícone de anexo customizado
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RotuloCampo('Link', complemento: '(opcional)'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _linkCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://…',
                      hintStyle: const TextStyle(color: Colors.black26),
                      prefixIcon: const Icon(Icons.attach_file, color: Colors.black54),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                    ),
                  ),
                ],
              ),
            ),

            _buildTextField('Objetivo', _objetivoCtrl, maxLength: 80, maxLines: 2),
            _buildTextField('Descrição', _descricaoCtrl, maxLines: 4, maxLength: 500),
            const SizedBox(height: 16),

            // GALERIA
            const Text('Galeria', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fotos que já estão no banco (se modo edição)
                  if (galeriaAntigaAsync != null)
                    galeriaAntigaAsync.when(
                      data: (fotos) => Row(
                        children: fotos.map((f) => _buildGaleriaImg(
                          provider: StorageNetworkImage(f.fotoUrl),
                          onRemove: () => _removerFotoAntigaGaleria(f.id), // Passa a função de remover com o ID correto
                        )).toList(),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),
                  
                  // Novas fotos selecionadas (ainda não salvas) mapeando o índice para remoção
                  ..._novasFotosGaleria.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final File file = entry.value;
                    return _buildGaleriaImg(
                      provider: FileImage(file),
                      onRemove: () => _removerNovaFotoGaleria(index),
                    );
                  }),
                  
                  // Botão Adicionar Foto
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: _adicionarFotoGaleria,
                      child: Container(
                        height: 80, width: 80,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Adicionar foto', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // VER COMO O CLIENTE VÊ
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _preVisualizar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver como o cliente vê', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // BOTÃO SALVAR
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                onPressed: _isLoading ? null : _salvar,
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Salvar Informações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            if (widget.servico != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _excluirServico,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir do catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int? maxLength,
    int maxLines = 1,
    bool obrigatorio = false,
    String? complemento,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RotuloCampo(label, obrigatorio: obrigatorio, complemento: complemento),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // WIDGET ATUALIZADO PARA EXIBIR A IMAGEM COM O BOTÃO DE REMOÇÃO
  // =======================================================================
  Widget _buildGaleriaImg({required ImageProvider provider, required VoidCallback onRemove}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 8), 
          height: 80, width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(image: provider, fit: BoxFit.cover),
          ),
        ),
        // Botão de remoção (X) ancorado no topo direito do container da imagem
        Positioned(
          top: 0,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}


/// Rótulo de campo. Com `obrigatorio`, ganha um asterisco vermelho — é o
/// único aviso de que o campo trava o salvamento.
class _RotuloCampo extends StatelessWidget {
  final String texto;
  final bool obrigatorio;
  final String? complemento;

  const _RotuloCampo(this.texto, {this.obrigatorio = false, this.complemento});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto),
          if (obrigatorio)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold),
            ),
          if (complemento != null)
            TextSpan(
              text: ' $complemento',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
      style: const TextStyle(color: Colors.grey, fontSize: 13),
    );
  }
}
