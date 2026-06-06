import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../providers/equipe_provider.dart';

class InviteTeamBody extends ConsumerStatefulWidget {
  final String projetoId;

  const InviteTeamBody({super.key, required this.projetoId});

  @override
  ConsumerState<InviteTeamBody> createState() => _InviteTeamBodyState();
}

class _InviteTeamBodyState extends ConsumerState<InviteTeamBody> {
  final _cnpjController = TextEditingController();
  String _cnpjBusca = '';
  bool _enviandoConvite = false;

  @override
  void dispose() {
    _cnpjController.dispose();
    super.dispose();
  }

  void _dispararBusca() {
    setState(() {
      _cnpjBusca = _cnpjController.text.trim();
    });
  }

  Future<void> _enviarConvite(String empresaId) async {
    setState(() => _enviandoConvite = true);

    try {
      await ref.read(equipeControllerProvider).enviarConvite(
            projetoId: widget.projetoId, // Use widget.projetoId
            empresaConvidadaId: empresaId,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      DiaviconAlerts.show(
        context,
        'Convite Enviado',
        'Empresa convidada com sucesso!',
      );
    } catch (e) {
      if (!mounted) return;
      DiaviconAlerts.show(context, 'Erro', e.toString(), isErro: true);
    } finally {
      if (mounted) setState(() => _enviandoConvite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buscaAsync = ref.watch(buscarEmpresaPorCnpjProvider(_cnpjBusca));

    // 🔥 Removemos a lógica do teclado e deixamos SÓ a barra de navegação nativa
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      // Agora ele vai dar apenas o respiro da barra inferior (nav bar)
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'CNPJ da Empresa',
            hint: '00.000.000/0000-00',
            controller: _cnpjController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          CustomButton(text: 'Buscar Empresa', onPressed: _dispararBusca),

          // TUDO DAQUI PRA BAIXO SÓ APARECE SE TIVER BUSCADO ALGO
          if (_cnpjBusca.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            buscaAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => const Center(
                child: Text(
                  'Erro ao buscar CNPJ',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              data: (empresaEncontrada) {
                if (empresaEncontrada == null) {
                  return const Center(
                    child: Text('Nenhuma empresa encontrada.', style: TextStyle(color: AppColors.hintText)),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Empresa Encontrada:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.inputBorder,
                        backgroundImage: empresaEncontrada['foto_url'] != null
                            ? NetworkImage(empresaEncontrada['foto_url'])
                            : null,
                        child: empresaEncontrada['foto_url'] == null
                            ? const Icon(Icons.business, color: Colors.grey)
                            : null,
                      ),
                      title: Text(empresaEncontrada['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('CNPJ: ${empresaEncontrada['cnpj']}'),
                      trailing: _enviandoConvite
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => _enviarConvite(empresaEncontrada['id']), // 🔥 AQUI ESTÁ A CORREÇÃO
                              child: const Text('Convidar', style: TextStyle(color: Colors.white)),
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
