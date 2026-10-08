import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A full-screen OpenStreetMap view. The user taps anywhere on the map to
/// drop a marker there, then confirms to send that LatLng back to whichever
/// screen opened this one. No API key needed -- tiles come from the public
/// OpenStreetMap tile server.
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng initialCenter;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialCenter = const LatLng(17.3850, 78.4867), // defaults to Hyderabad
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 12,
              onTap: (tapPosition, point) {
                setState(() => _picked = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.shipeasy',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Color(0xFFE05C50), size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E23),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _picked == null
                    ? 'Tap on the map to drop a pin'
                    : 'Selected: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
        backgroundColor: _picked == null ? Colors.grey : const Color(0xFF3399FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.check),
        label: const Text('Confirm Location'),
      ),
    );
  }
}
