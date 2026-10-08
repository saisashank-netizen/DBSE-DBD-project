import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'home_screen.dart' show statusBadge, statusColor;

class TrackShipmentScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;
  const TrackShipmentScreen({super.key, required this.shipment});

  @override
  State<TrackShipmentScreen> createState() => _TrackShipmentScreenState();
}

class _TrackShipmentScreenState extends State<TrackShipmentScreen> {
  late Map<String, dynamic> _shipment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shipment = Map<String, dynamic>.from(widget.shipment);
  }

  bool get _isBooked => _shipment['status'] == 'booked';
  bool get _isPickedUpOrBeyond => [
        'picked_up',
        'in_transit',
        'out_for_delivery',
        'delivered'
      ].contains(_shipment['status']);
  bool get _canCancel => _isBooked && (_shipment['can_cancel'] == true);

  LatLng _getCoordinates(String? city, double? lat, double? lng) {
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      return LatLng(lat, lng);
    }
    final c = (city ?? '').toLowerCase();
    if (c.contains('bangalore')) return const LatLng(12.9716, 77.5946);
    if (c.contains('chennai')) return const LatLng(13.0827, 80.2707);
    if (c.contains('vijayawada')) return const LatLng(16.5062, 80.6480);
    if (c.contains('warangal')) return const LatLng(17.9689, 79.5941);
    if (c.contains('kurnool')) return const LatLng(15.8281, 78.0373);
    if (c.contains('nellore')) return const LatLng(14.4426, 79.9865);
    return const LatLng(17.3850, 78.4867); // Hyderabad fallback
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1E23),
        title: const Text('Cancel Shipment?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel shipment #${_shipment['id']}? '
          'Under the 5-hour cancellation policy, any associated charges will be refunded.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Shipment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE05C50)),
            child: const Text('Confirm Cancellation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService().cancelShipment(_shipment['id']);
      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _shipment['status'] = 'cancelled';
          _shipment['can_cancel'] = false;
          final List tl = List.from(_shipment['timeline'] ?? []);
          tl.add({
            'status': 'Cancelled',
            'location': '${_shipment['origin']} Hub',
            'time': 'Just now',
            'notes': 'Cancelled by shipper within 5-hour window',
            'lat': _shipment['latest_lat'] ?? 17.3850,
            'lng': _shipment['latest_lng'] ?? 78.4867,
          });
          _shipment['timeline'] = tl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D8A4B),
            content: Text(res['message'] ?? 'Shipment successfully cancelled.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB3261E),
            content: Text(res['error'] ?? 'Cancellation rejected.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB3261E),
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List timeline = _shipment['timeline'] ?? [];
    final latest = timeline.isNotEmpty ? timeline.last : null;

    final originCoord = _getCoordinates(_shipment['origin'], null, null);
    final destCoord = _getCoordinates(_shipment['destination'], null, null);
    final currentCoord = latest != null
        ? _getCoordinates(null, (latest['lat'] as num?)?.toDouble(), (latest['lng'] as num?)?.toDouble())
        : originCoord;

    final routePoints = [originCoord, currentCoord, destCoord];

    return Scaffold(
      appBar: AppBar(
        title: Text('Shipment #${_shipment['id']}'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Interactive Route & Live Tracking Map ---
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: currentCoord,
                  initialZoom: 7.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.shipeasycode',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color(0xFF3399FF),
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Origin Marker (Green)
                      Marker(
                        point: originCoord,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.trip_origin, color: Color(0xFF1D8A4B), size: 28),
                      ),
                      // Current Location Marker (Blue Moving Truck)
                      Marker(
                        point: currentCoord,
                        width: 38,
                        height: 38,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3399FF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF3399FF).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                            ],
                          ),
                          child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                        ),
                      ),
                      // Destination Marker (Red Flag)
                      Marker(
                        point: destCoord,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.location_on, color: Color(0xFFE05C50), size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Shipment Summary Card ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${_shipment['origin']}  ➔  ${_shipment['destination']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      statusBadge(_shipment['status']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Carrier: ${_shipment['carrier'] ?? 'Logistics Fleet'}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_shipment['weight']} kg',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Booked on: ${_shipment['date'] ?? 'Recent'}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Rs. ${((_shipment['cost'] ?? 0) as num).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3399FF)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- 5-Hour Cancellation Policy & Action Button Section ---
          if (_canCancel) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2A1E),
                border: Border.all(color: const Color(0xFF1D8A4B).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF1D8A4B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '5-Hour Cancellation Window Active: Eligible for immediate refund '
                      '(${_shipment['time_remaining_for_cancellation'] ?? 'Active'}).',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Shipment (Full Refund)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE05C50),
                  side: const BorderSide(color: Color(0xFFE05C50)),
                ),
              ),
            ),
          ] else if (_isPickedUpOrBeyond) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2016),
                border: Border.all(color: const Color(0xFFB35A00).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_clock, color: Color(0xFFB35A00), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This shipment has already been picked up by the carrier and cannot be cancelled.',
                      style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isBooked && !_canCancel) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1D1D),
                border: Border.all(color: const Color(0xFFB3261E).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.timer_off, color: Color(0xFFE05C50), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The 5-hour cancellation window has expired. Shipment is locked for carrier dispatch.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_shipment['status'] == 'cancelled') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1D1D),
                border: Border.all(color: const Color(0xFFB3261E).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFFE05C50), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This shipment was cancelled. Invoiced payment status has been refunded.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),

          // --- Tracking Timeline ---
          const Text('Tracking Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          if (timeline.isEmpty)
            Text('No tracking events logged yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
          else
            ...List.generate(timeline.length, (i) {
              final event = timeline[i];
              final isLast = i == timeline.length - 1;
              final color = statusColor(_shipment['status']);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLast ? color : const Color(0xFF3399FF),
                          ),
                        ),
                        if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade800)),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['status'] ?? 'Update',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${event['location'] ?? 'In transit'} '
                              '${event['lat'] != null ? '(${event['lat']}, ${event['lng']})' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            ),
                            if (event['notes'] != null && (event['notes'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  event['notes'],
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ),
                            Text(
                              event['time'] ?? (event['event_time'] != null ? event['event_time'].toString() : ''),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
