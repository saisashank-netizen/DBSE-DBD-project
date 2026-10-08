import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'location_picker_screen.dart';

class BookShipmentScreen extends StatefulWidget {
  const BookShipmentScreen({super.key});
  @override
  State<BookShipmentScreen> createState() => _BookShipmentScreenState();
}

class _BookShipmentScreenState extends State<BookShipmentScreen> {
  final _originAddressController = TextEditingController(text: 'Road No 10, Banjara Hills');
  final _originCityController = TextEditingController(text: 'Hyderabad');
  final _destAddressController = TextEditingController(text: '100 Feet Rd, Indiranagar');
  final _destCityController = TextEditingController(text: 'Bangalore');
  final _weightController = TextEditingController(text: '5.0');

  LatLng? _originLocation = const LatLng(17.4156, 78.4357);
  LatLng? _destLocation = const LatLng(12.9784, 77.6408);

  double? _estimatedCost = 125.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateCost();
  }

  Future<void> _calculateCost() async {
    final weight = double.tryParse(_weightController.text) ?? 0;
    if (weight <= 0) {
      setState(() => _estimatedCost = null);
      return;
    }
    final cost = await ApiService().estimateCost(
      weightKg: weight,
      originCity: _originCityController.text.trim(),
      destinationCity: _destCityController.text.trim(),
    );
    if (mounted) {
      setState(() => _estimatedCost = cost);
    }
  }

  Future<void> _pickOriginLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Pick Pickup Location',
          initialCenter: _originLocation ?? const LatLng(17.3850, 78.4867),
        ),
      ),
    );
    if (result != null) {
      setState(() => _originLocation = result);
    }
  }

  Future<void> _pickDestLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Pick Drop Location',
          initialCenter: _destLocation ?? const LatLng(12.9716, 77.5946),
        ),
      ),
    );
    if (result != null) {
      setState(() => _destLocation = result);
    }
  }

  Future<void> _submitBooking() async {
    final weight = double.tryParse(_weightController.text) ?? 0;
    if (weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in kg.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService().bookShipment(
        originAddress: _originAddressController.text.trim(),
        originCity: _originCityController.text.trim(),
        destinationAddress: _destAddressController.text.trim(),
        destinationCity: _destCityController.text.trim(),
        weightKg: weight,
        originLat: _originLocation?.latitude,
        originLng: _originLocation?.longitude,
        destLat: _destLocation?.latitude,
        destLng: _destLocation?.longitude,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final id = res['data']['id'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D8A4B),
            content: Text('Shipment #$id booked successfully! 5-hour cancellation window started.'),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB3261E),
            content: Text(res['error'] ?? 'Booking failed.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking shipment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Shipment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Pickup Details ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.trip_origin, size: 18, color: Color(0xFF1D8A4B)),
                      SizedBox(width: 8),
                      Text('Pickup Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _originCityController,
                    decoration: const InputDecoration(labelText: 'Pickup City', prefixIcon: Icon(Icons.location_city)),
                    onChanged: (_) => _calculateCost(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _originAddressController,
                    decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.home_outlined)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickOriginLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(_originLocation == null ? 'Pick on Map' : 'Map Pin Set (${_originLocation!.latitude.toStringAsFixed(3)}, ${_originLocation!.longitude.toStringAsFixed(3)})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3399FF),
                      side: const BorderSide(color: Color(0xFF3399FF)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Dropoff Details ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, size: 18, color: Color(0xFFE05C50)),
                      SizedBox(width: 8),
                      Text('Destination Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _destCityController,
                    decoration: const InputDecoration(labelText: 'Destination City', prefixIcon: Icon(Icons.location_city)),
                    onChanged: (_) => _calculateCost(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _destAddressController,
                    decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.apartment_outlined)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDestLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(_destLocation == null ? 'Pick on Map' : 'Map Pin Set (${_destLocation!.latitude.toStringAsFixed(3)}, ${_destLocation!.longitude.toStringAsFixed(3)})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3399FF),
                      side: const BorderSide(color: Color(0xFF3399FF)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Cargo Weight ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Package Weight (kg)',
                  prefixIcon: Icon(Icons.scale_outlined),
                  helperText: 'Rates: Rs. 8/kg within same city, Rs. 15/kg intercity + Rs. 50 base fee',
                ),
                onChanged: (_) => _calculateCost(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Estimated Cost Banner ---
          if (_estimatedCost != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A5C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Estimated Cost (sp_estimate_cost)', style: TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text('Includes carrier transit & GST', style: TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Rs. ${_estimatedCost!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF3399FF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // --- Confirm Booking Button ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitBooking,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm Booking (Issue Invoice & Reserve Carrier)'),
            ),
          ),
        ],
      ),
    );
  }
}
