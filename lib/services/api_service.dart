import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _customBaseUrl;
  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get customBaseUrl => _customBaseUrl;

  List<String> get candidateUrls {
    final list = <String>[];
    // 1. Direct USB port reverse (via adb reverse tcp:8000 tcp:8000) & Localhost
    list.add('http://127.0.0.1:8000/api');
    list.add('http://localhost:8000/api');
    // 2. Wi-Fi IP
    list.add('http://10.250.5.120:8000/api');
    // 3. Android Emulator host loopback
    list.add('http://10.0.2.2:8000/api');
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty && !list.contains(_customBaseUrl)) {
      list.insert(0, _customBaseUrl!);
    }
    return list;
  }

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    return 'http://127.0.0.1:8000/api';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _customBaseUrl = prefs.getString('custom_base_url');
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = jsonDecode(userJson);
      } catch (_) {}
    }
  }

  Future<void> setCustomBaseUrl(String url) async {
    _customBaseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', _customBaseUrl!);
  }

  Future<bool> testConnection([String? url]) async {
    final target = url ?? baseUrl;
    try {
      final root = target.replaceAll('/api', '');
      final res = await http.get(Uri.parse('$root/health')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers({bool requiresAuth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _token != null) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  /// Sends HTTP request with automatic failover between candidate host IPs
  /// (e.g. 192.168.0.101 <-> 10.0.2.2 <-> 127.0.0.1)
  Future<http.Response> _sendWithFailover(
    Future<http.Response> Function(String url) requestFn,
  ) async {
    final urls = candidateUrls;
    Exception? lastException;

    for (final url in urls) {
      try {
        final res = await requestFn(url).timeout(const Duration(seconds: 5));
        // If succeeded, remember this working URL
        if (_customBaseUrl != url) {
          _customBaseUrl = url;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_base_url', url);
        }
        return res;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastException ?? Exception('Cannot connect to backend server at any address: ${urls.join(', ')}');
  }

  // --- Authentication Endpoints (CO3 Token Authentication) ---

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? companyName,
  }) async {
    final res = await _sendWithFailover((url) => http.post(
      Uri.parse('$url/auth/register'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'phone': phone,
        'company_name': companyName,
      }),
    ));

    final data = jsonDecode(res.body);
    if (res.statusCode == 201 || res.statusCode == 200) {
      _token = data['access_token'];
      _currentUser = data['shipper'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('current_user', jsonEncode(_currentUser));
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Registration failed.'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _sendWithFailover((url) => http.post(
      Uri.parse('$url/auth/login'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({
        'username_or_email': email,
        'email': email,
        'username': email,
        'password': password,
      }),
    ));

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      _token = data['access_token'];
      _currentUser = data['shipper'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('current_user', jsonEncode(_currentUser));
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Login failed.'};
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('current_user');
  }

  // --- Shipments Endpoints (CO1 & CO3) ---

  Future<List<Map<String, dynamic>>> getShipments() async {
    final res = await _sendWithFailover((url) => http.get(
      Uri.parse('$url/shipments'),
      headers: _headers(),
    ));

    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(list);
    } else {
      throw Exception('Failed to fetch shipments (${res.statusCode}): ${res.body}');
    }
  }

  Future<Map<String, dynamic>> bookShipment({
    required String originAddress,
    required String originCity,
    required String destinationAddress,
    required String destinationCity,
    required double weightKg,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  }) async {
    final res = await _sendWithFailover((url) => http.post(
      Uri.parse('$url/shipments'),
      headers: _headers(),
      body: jsonEncode({
        'origin_address': originAddress,
        'origin_city': originCity,
        'destination_address': destinationAddress,
        'destination_city': destinationCity,
        'weight_kg': weightKg,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'destination_lat': destLat,
        'destination_lng': destLng,
      }),
    ));

    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Booking failed.'};
    }
  }

  Future<Map<String, dynamic>> cancelShipment(int shipmentId) async {
    final res = await _sendWithFailover((url) => http.post(
      Uri.parse('$url/shipments/$shipmentId/cancel'),
      headers: _headers(),
    ));

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return {'success': true, 'message': data['message'] ?? 'Shipment cancelled.'};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Unable to cancel shipment.'};
    }
  }

  Future<double> estimateCost({
    required double weightKg,
    required String originCity,
    required String destinationCity,
  }) async {
    try {
      final res = await _sendWithFailover((url) => http.post(
        Uri.parse('$url/shipments/estimate-cost'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({
          'weight_kg': weightKg,
          'origin_city': originCity,
          'destination_city': destinationCity,
        }),
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['estimated_cost'] as num).toDouble();
      }
    } catch (_) {}
    // Fallback formula
    final same = originCity.trim().toLowerCase() == destinationCity.trim().toLowerCase();
    return 50.0 + (weightKg * (same ? 8.0 : 15.0));
  }
}
