import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class LocationService {
  LocationService._(); // Construtor privado para impedir instâncias

  // Busca o endereço completo através de um CEP usando a ViaCEP
  static Future<Map<String, String>?> buscarEnderecoPorCep(String cepFormatado) async {
    final cep = cepFormatado.replaceAll('-', '');
    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] == null) {
          return {
            'rua': data['logradouro'] ?? '',
            'cidade': data['localidade'] ?? '',
            'uf': data['uf'] ?? '',
            'pais': 'Brasil',
          };
        }
      }
    } catch (e) {
      debugPrint('Erro no LocationService (ViaCEP): $e');
    }
    return null; // Retorna null se der erro ou CEP não existir
  }

  /// Pega num texto (ex: "Rua X, Cidade Y") e devolve a Latitude e Longitude
  static Future<Map<String, double>?> buscarCoordenadasPorEndereco(String textoBusca) async {
    try {
      List<Location> locs = await locationFromAddress(textoBusca);
      if (locs.isNotEmpty) {
        return {
          'lat': locs.first.latitude,
          'lng': locs.first.longitude,
        };
      }
    } catch (e) {
      debugPrint('Erro no LocationService (Geocoding Text): $e');
    }
    return null;
  }

  /// Faz o inverso: Pega na Latitude e Longitude e devolve a Rua, CEP, etc.
  static Future<Map<String, String>?> buscarEnderecoPorCoordenadas(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark lugar = placemarks.first;
        String cidade = lugar.subAdministrativeArea?.isNotEmpty == true 
            ? lugar.subAdministrativeArea! 
            : lugar.locality ?? '';

        return {
          'cep': lugar.postalCode ?? '',
          'rua': lugar.thoroughfare ?? '',
          'numero': lugar.subThoroughfare ?? '',
          'cidade': cidade,
          'uf': lugar.administrativeArea ?? '',
          'pais': lugar.country ?? 'Brasil',
        };
      }
    } catch (e) {
      debugPrint('Erro no LocationService (Reverse Geocoding): $e');
    }
    return null;
  }
}