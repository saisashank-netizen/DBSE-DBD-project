import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final name = user?['full_name'] ?? 'Shipper';
    final email = user?['email'] ?? 'Not set';
    final phone = user?['phone'] ?? '+91 98499 26829';
    final company = user?['company_name'] ?? 'ShipEasy Enterprise';
    final shipperId = user?['shipper_id']?.toString() ?? '1';

    return Scaffold(
      appBar: AppBar(title: const Text('Shipper Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3399FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(company, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D8A4B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Shipper ID: #$shipperId (Authenticated via JWT)',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF1D8A4B), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Color(0xFF3399FF)),
                  title: const Text('Email Address'),
                  subtitle: Text(email),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: Color(0xFF3399FF)),
                  title: const Text('Phone Number'),
                  subtitle: Text(phone),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: Color(0xFF3399FF)),
                  title: const Text('Company / Enterprise'),
                  subtitle: Text(company),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined, color: Color(0xFF1D8A4B)),
                  title: const Text('Token Security'),
                  subtitle: const Text('HMAC-SHA256 Bearer Token Active'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Logout Button ---
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ApiService().logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out (Clear Token)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE05C50),
                side: const BorderSide(color: Color(0xFFE05C50)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
