import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';

class MapaPreviewWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;

  const MapaPreviewWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    bool temCoordenadas = latitude != null && longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Indicação no mapa',
          style: TextStyle(fontSize: 14, color: AppColors.hintText),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: temCoordenadas
                ? AbsorbPointer(
                    child: GoogleMap(
                      key: ValueKey('${latitude}_$longitude'),
                      initialCameraPosition: CameraPosition(
                        target: LatLng(latitude!, longitude!),
                        zoom: 16.0,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('preview'),
                          position: LatLng(latitude!, longitude!),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                        ),
                      },
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 40, color: AppColors.hintText),
                      SizedBox(height: 8),
                      Text('Aguardando localização...', style: TextStyle(color: AppColors.hintText)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}