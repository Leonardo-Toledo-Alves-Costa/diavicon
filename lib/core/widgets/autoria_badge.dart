import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/autor_exibicao.dart';

/// Selo de rastreio no canto de um cartão: logo da empresa que registrou e,
/// ao lado, a foto do autor — esta só para quem é da mesma empresa dele.
///
/// Quem decide se o autor aparece é o banco, não este widget: a função
/// `autores_para_exibicao` devolve nome e foto nulos para observadores de
/// fora da empresa (ver [AutorExibicao]). Aqui só se desenha o que veio.
///
/// Some por completo quando não há autoria conhecida — é o caso dos
/// elementos criados antes da coluna `criado_por` existir, que precisam
/// continuar abrindo normalmente.
class AutoriaBadge extends StatelessWidget {
  const AutoriaBadge({super.key, required this.autor, this.raioEmpresa = 12});

  final AutorExibicao? autor;

  /// Raio do logo da empresa. O avatar do autor acompanha, menor.
  final double raioEmpresa;

  @override
  Widget build(BuildContext context) {
    final autor = this.autor;
    if (autor == null || (!autor.temLogoEmpresa && !autor.temAutorVisivel)) {
      return const SizedBox.shrink();
    }

    final raioAutor = raioEmpresa * 0.75;

    return Tooltip(
      message: _descricao(autor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (autor.temLogoEmpresa)
            _Circulo(
              url: autor.empresaLogoUrl,
              raio: raioEmpresa,
              iconeVazio: Icons.business,
            ),
          if (autor.temAutorVisivel) ...[
            // Sobreposição leve: os dois leem como um selo só, em vez de
            // dois avatares soltos disputando o canto.
            if (autor.temLogoEmpresa) SizedBox(width: raioAutor * 0.4),
            _Circulo(
              url: autor.fotoUrl,
              raio: raioAutor,
              iconeVazio: Icons.person,
              comBorda: true,
            ),
          ],
        ],
      ),
    );
  }

  String _descricao(AutorExibicao autor) {
    final empresa = autor.empresaNome;
    final nome = autor.nome;
    if (nome != null && empresa != null) return 'Registrado por $nome — $empresa';
    if (nome != null) return 'Registrado por $nome';
    if (empresa != null) return 'Registrado por $empresa';
    return 'Autoria não informada';
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.url, required this.raio, required this.iconeVazio, this.comBorda = false});

  final String? url;
  final double raio;
  final IconData iconeVazio;
  final bool comBorda;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: raio,
      backgroundColor: AppColors.greyLight.withValues(alpha: 0.25),
      // onBackgroundImageError evita que uma URL quebrada (arquivo removido
      // do Storage) derrube a tela inteira com exceção de imagem.
      backgroundImage: url != null ? StorageNetworkImage(url!) : null,
      onBackgroundImageError: url != null ? (_, _) {} : null,
      child: url == null ? Icon(iconeVazio, size: raio, color: AppColors.greyMedium) : null,
    );

    if (!comBorda) return avatar;
    return Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white),
      padding: const EdgeInsets.all(1.5),
      child: avatar,
    );
  }
}
