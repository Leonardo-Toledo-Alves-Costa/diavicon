import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/empresa_profile_provider.dart';

class EmpresaInformacoesScreen extends ConsumerStatefulWidget {
  final EmpresaDetalheModel empresa;

  const EmpresaInformacoesScreen({super.key, required this.empresa});

  @override
  ConsumerState<EmpresaInformacoesScreen> createState() => _EmpresaInformacoesScreenState();
}

class _EmpresaInformacoesScreenState extends ConsumerState<EmpresaInformacoesScreen> {
  int _abaAtual = 0; // 0 = Sobre, 1 = Endereço, 2 = Redes Sociais
  bool _isLoading = false;

  // Imagens Locais
  File? _fotoCapaLocal;
  File? _fotoLogoLocal;

  // Categoria (Ramo de Atuação)
  String? _categoriaSelecionada;
  final List<String> _categorias = ['Gestora de ativos','Proprietária de ativos','Inspeção', 'Intervenção', 'Produtos', 'Equipamentos'];

  // Controladores - Aba Sobre
  late TextEditingController _nomeCtrl;
  late TextEditingController _descricaoCtrl;
  late TextEditingController _sobreCtrl;

  // Controladores - Aba Endereço
  final _cepCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ruaCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();

  // Controladores - Aba Redes Sociais
  late TextEditingController _siteCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _youtubeCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.empresa.nome);
    _descricaoCtrl = TextEditingController(text: widget.empresa.descricao);
    _sobreCtrl = TextEditingController(text: widget.empresa.sobre);
    _siteCtrl = TextEditingController(text: widget.empresa.site);
    _emailCtrl = TextEditingController(text: widget.empresa.emailContato);
    _whatsappCtrl = TextEditingController(text: widget.empresa.whatsapp);
    _linkedinCtrl = TextEditingController(text: widget.empresa.linkedin);
    _instagramCtrl = TextEditingController(text: widget.empresa.instagram);
    _youtubeCtrl = TextEditingController(text: widget.empresa.youtube);

    // Carrega a categoria atual salva no banco (mapeada no model)
    // Caso a propriedade se chame diferente no seu model, ajuste aqui
    _categoriaSelecionada = widget.empresa.ramoAtuacao; 

    _carregarEnderecoDaEmpresa();
  }

  Future<void> _carregarEnderecoDaEmpresa() async {
    try {
      final response = await Supabase.instance.client
          .from('empresas')
          .select('endereco_id, enderecos(*)')
          .eq('id', widget.empresa.id)
          .maybeSingle();

      if (response != null && response['enderecos'] != null) {
        final end = response['enderecos'];
        if (mounted) {
          setState(() {
            _cepCtrl.text = end['cep'] ?? '';
            _cidadeCtrl.text = end['cidade'] ?? '';
            _ruaCtrl.text = end['endereco'] ?? ''; 
            _bairroCtrl.text = end['bairro'] ?? '';
            _estadoCtrl.text = end['estado'] ?? '';
            _paisCtrl.text = end['pais'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar endereço: $e');
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    _sobreCtrl.dispose();
    _cepCtrl.dispose();
    _cidadeCtrl.dispose();
    _ruaCtrl.dispose();
    _bairroCtrl.dispose();
    _estadoCtrl.dispose();
    _paisCtrl.dispose();
    _siteCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _linkedinCtrl.dispose();
    _instagramCtrl.dispose();
    _youtubeCtrl.dispose();
    super.dispose();
  }

  // Abre modal para escolher fonte (Câmera ou Galeria)
  Future<void> _escolherFonteFoto(bool isCapa) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Selecionar Imagem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      _processarFoto(isCapa, source);
    }
  }

  // Executa o corte (Cropper)
  Future<void> _processarFoto(bool isCapa, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);

    if (image != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: isCapa ? const CropAspectRatio(ratioX: 16, ratioY: 9) : const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Imagem',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Ajustar Imagem',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped != null) {
        setState(() {
          if (isCapa) {
            _fotoCapaLocal = File(cropped.path);
          } else {
            _fotoLogoLocal = File(cropped.path);
          }
        });
      }
    }
  }

  Future<void> _salvar() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String? novaUrlCapa;
      String? novaUrlLogo;

      // 1. Upload da Foto de Capa
      if (_fotoCapaLocal != null) {
        final ext = _fotoCapaLocal!.path.split('.').last;
        final filePath = '${widget.empresa.id}/capa_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('empresas').upload(filePath, _fotoCapaLocal!, fileOptions: const FileOptions(upsert: true));
        novaUrlCapa = supabase.storage.from('empresas').getPublicUrl(filePath);
      }

      // 2. Upload da Logo
      if (_fotoLogoLocal != null) {
        final ext = _fotoLogoLocal!.path.split('.').last;
        final filePath = '${widget.empresa.id}/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('empresas').upload(filePath, _fotoLogoLocal!, fileOptions: const FileOptions(upsert: true));
        novaUrlLogo = supabase.storage.from('empresas').getPublicUrl(filePath);
      }

      // 3. Atualizar tabela 'empresas'
      final updateData = {
        'nome': _nomeCtrl.text.trim(),
        'ramo_atuacao': _categoriaSelecionada, // 🔥 Salvando a nova categoria
        'descricao': _descricaoCtrl.text.trim(),
        'sobre': _sobreCtrl.text.trim(),
        'site': _siteCtrl.text.trim(),
        'email_contato': _emailCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'linkedin': _linkedinCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'youtube': _youtubeCtrl.text.trim(),
      };

      if (novaUrlCapa != null) updateData['foto_capa'] = novaUrlCapa;
      if (novaUrlLogo != null) updateData['foto_url'] = novaUrlLogo;

      await supabase.from('empresas').update(updateData).eq('id', widget.empresa.id);

      // 4. Atualizar a tabela 'enderecos'
      final empresaResponse = await supabase.from('empresas').select('endereco_id').eq('id', widget.empresa.id).single();
      final enderecoId = empresaResponse['endereco_id'];

      final enderecoData = {
        'cep': _cepCtrl.text.trim(),
        'cidade': _cidadeCtrl.text.trim(),
        'endereco': _ruaCtrl.text.trim(),
        'bairro': _bairroCtrl.text.trim(),
        'estado': _estadoCtrl.text.trim(),
        'pais': _paisCtrl.text.trim(),
      };

      if (enderecoId != null) {
        await supabase.from('enderecos').update(enderecoData).eq('id', enderecoId);
      } else {
        final novoEnd = await supabase.from('enderecos').insert(enderecoData).select('id').single();
        await supabase.from('empresas').update({'endereco_id': novoEnd['id']}).eq('id', widget.empresa.id);
      }

      if (mounted) {
        ref.invalidate(empresaDetalheProvider(widget.empresa.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informações salvas com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no banco de dados: ${e.message}'), backgroundColor: Colors.red));
    } on StorageException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de Storage: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imgCapa;
    if (_fotoCapaLocal != null) {
      imgCapa = FileImage(_fotoCapaLocal!);
    } else if (widget.empresa.fotoCapa != null && widget.empresa.fotoCapa!.isNotEmpty) {
      imgCapa = NetworkImage(widget.empresa.fotoCapa!);
    }

    ImageProvider? imgLogo;
    if (_fotoLogoLocal != null) {
      imgLogo = FileImage(_fotoLogoLocal!);
    } else if (widget.empresa.fotoUrl != null && widget.empresa.fotoUrl!.isNotEmpty) {
      imgLogo = NetworkImage(widget.empresa.fotoUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Painel',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Informações', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÁREA DE IMAGENS 
            SizedBox(
              height: 180, 
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Capa (Fundo)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: 120,
                    child: GestureDetector(
                      onTap: () => _escolherFonteFoto(true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300], 
                          borderRadius: BorderRadius.circular(12),
                          image: imgCapa != null ? DecorationImage(image: imgCapa, fit: BoxFit.cover) : null,
                        ),
                      ),
                    ),
                  ),
                  
                  // Botão Editar Capa
                  Positioned(
                    top: 80, right: 8,
                    child: _buildEditIcon(() => _escolherFonteFoto(true)),
                  ),
                  
                  // Logo / Avatar
                  Positioned(
                    bottom: 0, left: 16,
                    child: GestureDetector(
                      onTap: () => _escolherFonteFoto(false),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44, 
                            backgroundColor: Colors.white, 
                            child: CircleAvatar(
                              radius: 40, 
                              backgroundColor: Colors.grey[200], 
                              backgroundImage: imgLogo,
                              child: imgLogo == null ? const Icon(Icons.business, size: 40, color: Colors.grey) : null,
                            )
                          ),
                          _buildEditIcon(() => _escolherFonteFoto(false)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            _buildTextField('Nome da Empresa', _nomeCtrl),

            // 🔥 Caso queira manter a fidelidade visual do print exibindo o CNPJ, basta descomentar:
            /*
            const SizedBox(height: 4),
            Text('CNPJ 90.336.515/0001-50', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            */
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton(0, 'Sobre'),
                _buildTabButton(1, 'Endereço'),
                _buildTabButton(2, 'Redes Sociais'),
              ],
            ),
            const SizedBox(height: 24),

            if (_abaAtual == 0) ...[
              // 🔥 Dropdown da Categoria 
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ramo de atuação', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                      hint: const Text('Selecione', style: TextStyle(color: Colors.black54)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      items: _categorias.map((String categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria,
                          child: Text(categoria, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _categoriaSelecionada = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),

              _buildTextField('Descrição (Breve)', _descricaoCtrl, maxLength: 80, maxLines: 2),
              _buildTextField('Sobre a Empresa', _sobreCtrl, maxLength: 500, maxLines: 6),
            ] else if (_abaAtual == 1) ...[
              _buildTextField('CEP', _cepCtrl),
              _buildTextField('Cidade', _cidadeCtrl),
              _buildTextField('Rua', _ruaCtrl),
              _buildTextField('Bairro', _bairroCtrl),
              _buildTextField('Estado', _estadoCtrl),
              _buildTextField('País', _paisCtrl),
            ] else if (_abaAtual == 2) ...[
              _buildTextField('Site', _siteCtrl),
              _buildTextField('E-mail', _emailCtrl),
              _buildTextField('Whatsapp', _whatsappCtrl),
              _buildTextField('Linkedin', _linkedinCtrl),
              _buildTextField('Instagram', _instagramCtrl),
              _buildTextField('Youtube', _youtubeCtrl),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
                ),
                onPressed: _isLoading ? null : _salvar,
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Salvar Informações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _abaAtual == index;
    return GestureDetector(
      onTap: () => setState(() => _abaAtual = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent, 
          borderRadius: BorderRadius.circular(20)
        ),
        child: Text(
          title, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
          )
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int? maxLength, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

  Widget _buildEditIcon(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white, 
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          border: Border.all(color: Colors.grey[200]!)
        ),
        child: const Icon(Icons.edit_square, size: 16, color: Color(0xFF3E3E3D)),
      ),
    );
  }
}