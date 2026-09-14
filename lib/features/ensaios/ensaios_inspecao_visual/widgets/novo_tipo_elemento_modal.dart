import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovoTipoElementoModal extends ConsumerStatefulWidget {
  final String? empresaId; 

  const NovoTipoElementoModal({super.key, this.empresaId});

  @override
  ConsumerState<NovoTipoElementoModal> createState() => _NovoTipoElementoModalState();
}

class _NovoTipoElementoModalState extends ConsumerState<NovoTipoElementoModal> {
  final _nomeController = TextEditingController();
  String _formatoSelecionado = 'Retângulo';
  bool _isLoading = false;

  final List<String> _formatos = ['Retângulo', 'Círculo'];

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      // Busca a empresa do usuário ativo
      final userRes = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
      final minhaEmpresaId = userRes?['empresa_id'];

      // Preparando os dados garantindo as colunas do SQL
      Map<String, dynamic> insertData = {
        'nome': nome,
        'formato_marcacao': _formatoSelecionado,
      };

      // Confio que você criou a coluna 'empresa_id' no Supabase!
      if (minhaEmpresaId != null) {
        insertData['empresa_id'] = minhaEmpresaId;
      }

      await supabase.from('tipos_elemento').insert(insertData);
      
      if (mounted) Navigator.of(context).pop(nome); 
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro do banco: ${e.message}'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Novo Tipo de Elemento', 
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome (ex: Parede)', 
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Formato na Planta:', 
              style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[700])
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey), 
                borderRadius: BorderRadius.circular(4)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _formatoSelecionado,
                  isExpanded: true,
                  items: _formatos.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _formatoSelecionado = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                padding: const EdgeInsets.symmetric(vertical: 14)
              ),
              child: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}