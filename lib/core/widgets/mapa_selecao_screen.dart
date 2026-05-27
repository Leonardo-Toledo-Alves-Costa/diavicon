import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/compact_button.dart'; 
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class MapaSelecaoScreen extends StatefulWidget {
  const MapaSelecaoScreen({super.key});

  @override
  State<MapaSelecaoScreen> createState() => _MapaSelecaoScreenState();
}

class _MapaSelecaoScreenState extends State<MapaSelecaoScreen> {
  // Posição inicial padrão (Centro do Brasil)
  LatLng _posicaoSelecionada = const LatLng(-15.793889, -47.882778);
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _recuperarLocalizacaoAtual(); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _recuperarLocalizacaoAtual() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; 
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; 
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return; 
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final localAtual = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _posicaoSelecionada = localAtual;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(localAtual, 16.0),
      );
    } catch (e) {
      debugPrint("Erro ao obter localização: $e");
    }
  }

  Future<void> _buscarEndereco() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPosition = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _posicaoSelecionada = newPosition;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 16.0),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endereço não encontrado. Tente ser mais específico.'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula o espaço do topo dinamicamente para a barra flutuante não sumir atrás da AppBar
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 16;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: const CustomAppBar(
        title: 'Selecione o Local',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _posicaoSelecionada,
              zoom: 4, 
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_posicaoSelecionada.latitude != -15.793889) {
                _mapController?.moveCamera(
                  CameraUpdate.newLatLngZoom(_posicaoSelecionada, 16.0),
                );
              }
            },
            onTap: (latLng) {
              setState(() {
                _posicaoSelecionada = latLng;
              });
            },
            zoomControlsEnabled: false, 
            markers: {
              Marker(
                markerId: const MarkerId('selecao'),
                position: _posicaoSelecionada,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              ),
            },
          ),
          
          // Barra de Pesquisa Flutuante
          Positioned(
            top: topPadding, 
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarEndereco(),
                decoration: InputDecoration(
                  hintText: 'Digite a rua, cidade ou CEP...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, color: AppColors.primary),
                          onPressed: _buscarEndereco,
                        ),
                ),
              ),
            ),
          ),
          
          // Botão Confirmar
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Center(
              child: SizedBox(
                width: double.infinity, 
                child: CompactButton(
                  text: 'Confirmar Localização',
                  onPressed: () {
                    Navigator.pop(context, _posicaoSelecionada);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}