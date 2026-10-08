import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController(text: 'Krishna Reddy');
  final _companyController = TextEditingController(text: 'BudgetBasket');
  final _emailController = TextEditingController(text: 'shipper1@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _phoneController = TextEditingController(text: '9126855092');

  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool? _isServerReachable;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
    _testServerConnection();
  }

  Future<void> _checkExistingToken() async {
    await ApiService().init();
    if (ApiService().token != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  Future<void> _testServerConnection() async {
    final ok = await ApiService().testConnection();
    if (mounted) {
      setState(() => _isServerReachable = ok);
    }
  }

  Future<void> _showServerSettingsDialog() async {
    final ipController = TextEditingController(text: ApiService().baseUrl);
    bool testing = false;
    String? testMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1E23),
          title: const Text('Backend Server Configuration', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select or enter your computer\'s IP address so your phone can reach the backend:',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://10.250.5.120:8000/api',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Wi-Fi (10.250.5.120)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() => ipController.text = 'http://10.250.5.120:8000/api');
                    },
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() => ipController.text = 'http://10.0.2.2:8000/api');
                    },
                  ),
                  ActionChip(
                    label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() => ipController.text = 'http://127.0.0.1:8000/api');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (testMsg != null)
                Text(
                  testMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    color: testMsg!.contains('Success') ? const Color(0xFF1D8A4B) : const Color(0xFFE05C50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() {
                        testing = true;
                        testMsg = 'Testing connection...';
                      });
                      final ok = await ApiService().testConnection(ipController.text.trim());
                      setDialogState(() {
                        testing = false;
                        testMsg = ok ? '✓ Successfully connected to backend!' : '✗ Failed to reach server at this URL.';
                      });
                    },
              child: const Text('Test Connection'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                await ApiService().setCustomBaseUrl(ipController.text.trim());
                navigator.pop();
                _testServerConnection();
              },
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Username/email and password are required.';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> res;
      if (_isRegister) {
        final name = _nameController.text.trim();
        final company = _companyController.text.trim();
        final phone = _phoneController.text.trim();

        if (name.isEmpty) {
          setState(() {
            _errorMessage = 'Full Name is required for registration.';
            _isLoading = false;
          });
          return;
        }

        res = await ApiService().register(
          fullName: name,
          email: email,
          password: password,
          phone: phone.isNotEmpty ? phone : null,
          companyName: company.isNotEmpty ? company : null,
        );
      } else {
        res = await ApiService().login(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Authentication failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: Cannot reach backend server at ${ApiService().baseUrl}. Tap the settings icon above to configure IP.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121417),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showServerSettingsDialog,
            icon: Icon(
              Icons.wifi,
              size: 16,
              color: _isServerReachable == true
                  ? const Color(0xFF1D8A4B)
                  : (_isServerReachable == false ? const Color(0xFFE05C50) : Colors.grey),
            ),
            label: Text(
              _isServerReachable == true ? 'Online' : 'Configure Server',
              style: TextStyle(
                fontSize: 12,
                color: _isServerReachable == true ? const Color(0xFF1D8A4B) : const Color(0xFF3399FF),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3399FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('ShipEasy', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Center(
                child: Text('MySQL + MongoDB Token-Protected Logistics', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF331616),
                    border: Border.all(color: const Color(0xFFB3261E)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE05C50), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFE05C50), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isRegister ? 'Register Database Account' : 'Sign In with Database User',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Creates a new row in MySQL `shippers`'
                            : 'Authenticates username/password in MySQL `shippers`',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      if (_isRegister) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _companyController,
                          decoration: const InputDecoration(labelText: 'Company / Shop Name', prefixIcon: Icon(Icons.storefront_outlined)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Username or Email',
                          hintText: 'e.g. shipper1@example.com or Krishna Reddy',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          hintText: 'Default seed password: password123',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text(_isRegister ? 'Register & Generate Token' : 'Sign In with Token'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _isRegister = !_isRegister;
                          _errorMessage = null;
                        }),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF3399FF)),
                        child: Text(_isRegister ? 'Already have an account? Sign In' : 'New user? Register Account'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Connected to: ${ApiService().baseUrl}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
