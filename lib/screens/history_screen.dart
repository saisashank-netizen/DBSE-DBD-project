import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart' show statusBadge;
import 'track_shipment_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';
  List<Map<String, dynamic>> _shipments = [];
  bool _isLoading = true;

  final _filters = const {
    'all': 'All',
    'delivered': 'Delivered',
    'in_transit': 'In Transit',
    'booked': 'Booked',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService().getShipments();
      if (mounted) {
        setState(() {
          _shipments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _shipments
        : _shipments.where((s) => s['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shipment History')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _filters.entries.map((e) {
                final selected = _filter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = e.key),
                    selectedColor: const Color(0xFF3399FF),
                    backgroundColor: const Color(0xFF23262C),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadShipments,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No shipments found in this category.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TrackShipmentScreen(shipment: s)),
                                  );
                                  _loadShipments();
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  '${s['origin']} ➔ ${s['destination']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Carrier: ${s['carrier'] ?? 'Fleet'}  •  ${s['date'] ?? ''}',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rs. ${((s['cost'] ?? 0) as num).toStringAsFixed(2)}  •  ${s['weight']} kg',
                                      style: const TextStyle(color: Color(0xFF3399FF), fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                                trailing: statusBadge(s['status']),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
