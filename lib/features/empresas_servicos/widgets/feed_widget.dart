import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/feed_provider.dart';

class EmpresaFeedCard extends StatelessWidget {
  final EmpresaFeedModel empresa;
  final VoidCallback onTap;

  const EmpresaFeedCard({super.key, required this.empresa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = (empresa.cidade != null && empresa.estado != null)
        ? '${empresa.cidade} - ${empresa.estado}' : 'Localização indisponível';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: empresa.fotoCapa != null
                      ? ImagemStorage.network(empresa.fotoCapa!, height: 140, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 140, color: Colors.grey[300]),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: Text('${empresa.qtdServicos} Serviços',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -24,
                  left: 16,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 23,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: empresa.fotoUrl != null ? StorageNetworkImage(empresa.fotoUrl!) : null,
                      child: empresa.fotoUrl == null ? const Icon(Icons.business, color: Colors.grey) : null,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(empresa.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  if (empresa.descricao != null) ...[
                    Text(empresa.descricao!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                    const SizedBox(height: 16),
                  ],
                  if (empresa.ramoAtuacao != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                      child: Text(empresa.ramoAtuacao!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServicoFeedCard extends StatelessWidget {
  final ServicoFeedModel servico;
  final VoidCallback onTap;

  const ServicoFeedCard({super.key, required this.servico, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = (servico.cidade != null && servico.estado != null)
        ? '${servico.cidade} - ${servico.estado}' : 'Localização indisponível';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: servico.fotoPrincipal != null
                      ? ImagemStorage.network(servico.fotoPrincipal!, height: 160, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 160, color: Colors.grey[300]),
                ),
                if (servico.categoria != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                      child: Text(servico.categoria!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: servico.empresaFotoUrl != null ? StorageNetworkImage(servico.empresaFotoUrl!) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(servico.empresaNome, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                            Text(location, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(servico.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  if (servico.objetivo != null) ...[
                    const SizedBox(height: 6),
                    Text(servico.objetivo!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                  ],

              

                  if (servico.linkAnexo != null && servico.linkAnexo!.isNotEmpty)
                                                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(servico.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              )




                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}