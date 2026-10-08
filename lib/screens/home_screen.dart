import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'book_shipment_screen.dart';
import 'track_shipment_screen.dart';

Color statusColor(String status) {
  switch (status) {
    case 'booked':
      return const Color(0xFF9A7B00);
    case 'picked_up':
      return const Color(0xFF3399FF);
    case 'in_transit':
      return const Color(0xFF7A3FC2);
    case 'out_for_delivery':
      return const Color(0xFFB35A00);
    case 'delivered':
      return const Color(0xFF1D8A4B);
    case 'cancelled':
      return const Color(0xFFB3261E);
    default:
      return Colors.grey;
  }
}

Widget statusBadge(String status) {
  final color = statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _shipments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService().getShipments();
      if (mounted) {
        setState(() {
          _shipments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not fetch shipments. Is backend running? ($e)';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _shipments.where((s) => ['booked', 'picked_up', 'in_transit', 'out_for_delivery'].contains(s['status'])).length;
    final deliveredCount = _shipments.where((s) => s['status'] == 'delivered').length;
    final totalSpend = _shipments.fold<double>(0.0, (acc, s) => acc + (((s['cost'] ?? 0) as num).toDouble()));

    final user = ApiService().currentUser;
    final displayName = user?['full_name'] ?? 'Shipper';
    final companyName = user?['company_name'] ?? 'ShipEasy Partner';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $displayName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(companyName, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShipments,
            tooltip: 'Refresh Shipments',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadShipments,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Metric Stat Cards ---
            Row(
              children: [
                Expanded(
                  child: _statCard('Active', '$activeCount', const Color(0xFF3399FF), Icons.local_shipping_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('Delivered', '$deliveredCount', const Color(0xFF1D8A4B), Icons.check_circle_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('Product Cost', 'Rs.${totalSpend.toStringAsFixed(0)}', const Color(0xFF7A3FC2), Icons.account_balance_wallet_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Quick Action Banner ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B3A5C), Color(0xFF14243B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Need to send a package?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Book instantly with live map picking and carrier assignment.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookShipmentScreen()),
                      );
                      _loadShipments();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Book'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Shipments Section Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Shipments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_shipments.length} total', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Card(
                color: const Color(0xFF2B1D1D),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off, color: Color(0xFFE05C50), size: 36),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Color(0xFFE05C50), fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadShipments, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_shipments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No shipments booked yet. Tap "Book" to create one!'),
                ),
              )
            else
              ..._shipments.map((s) => _shipmentCard(s)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _shipmentCard(Map<String, dynamic> s) {
    final status = s['status'] ?? 'booked';
    final canCancel = s['can_cancel'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrackShipmentScreen(shipment: s)),
          );
          _loadShipments();
        },
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
                      'Shipment #${s['id']}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${s['origin']}  ➔  ${s['destination']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Carrier: ${s['carrier'] ?? 'Logistics Fleet'}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
                        '${s['weight']} kg  •  Rs. ${((s['cost'] ?? 0) as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3399FF), fontSize: 13),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF1D8A4B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Cancelable within 5h window (${s['time_remaining_for_cancellation'] ?? 'Active'})',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1D8A4B)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
