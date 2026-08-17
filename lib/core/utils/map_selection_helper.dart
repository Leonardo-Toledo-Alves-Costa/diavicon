import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/mapa_selecao_screen.dart';

class MapSelectionHelper {
  MapSelectionHelper._(); // Construtor privado

  /// Abre a tela do mapa, permite ao utilizador selecionar um ponto e
  /// devolve um Map contendo as coordenadas e os dados de endereço preenchidos.
  static Future<Map<String, dynamic>?> selecionarNoMapa(BuildContext context) async {
    // 1. Abre a tela e espera o retorno (LatLng)
    final LatLng? locationSelecionada = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapaSelecaoScreen()),
    );

    // Se o utilizador fechou o mapa sem escolher nada, retornamos null
    if (locationSelecionada == null) return null;

    // 2. Transforma as coordenadas num endereço legível usando o nosso LocationService
    final endereco = await LocationService.buscarEnderecoPorCoordenadas(
      locationSelecionada.latitude,
      locationSelecionada.longitude,
    );

    // 3. Devolve um pacote completo pronto a usar em qualquer formulário da aplicação!
    return {
      'latitude': locationSelecionada.latitude.toString(),
      'longitude': locationSelecionada.longitude.toString(),
      'endereco': endereco, // Atenção: o endereço pode ser null se o clique for num local sem rua (ex: oceano)
    };
  }
}