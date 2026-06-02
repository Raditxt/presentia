import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'log_screen.dart';
import 'card_management_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db       = DatabaseService();
  final _auth     = AuthService();
  String _role    = 'user';
  String _name    = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _db.initStateIfEmpty();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseDatabase.instance
        .ref('presentia/users/$uid')
        .get();
    if (snap.exists && mounted) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      setState(() {
        _role = data['role'] ?? 'user';
        _name = data['name'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PRESENTIA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              'Halo, $_name · ${_role == 'admin' ? 'Admin' : 'User'}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.credit_card),
              tooltip: 'Manajemen Kartu',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CardManagementScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Log Aktivitas',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => LogScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await _auth.logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _db.watchState(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final state = snapshot.data!;
          final adminPresent = state['adminPresent'] ?? false;
          final userPresent  = state['userPresent']  ?? false;
          final counter      = state['counter']      ?? 0;
          final lampuRumah   = state['lampuRumah']   ?? false;
          final isMalam      = state['isMalam']      ?? false;
          
          // 🔧 Perubahan: gunakan 'kipas' bukan 'led'
          final kamarAdmin = Map<String, dynamic>.from(
              state['kamarAdmin'] ?? {'lampu': false, 'kipas': false});
          final kamarUser = Map<String, dynamic>.from(
              state['kamarUser']  ?? {'lampu': false, 'kipas': false});

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Status hunian ──────────────────────────
                const _SectionTitle('Status Rumah'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _StatusChip(
                      label: 'Admin',
                      active: adminPresent,
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusChip(
                      label: 'User',
                      active: userPresent,
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusChip(
                      label: isMalam ? 'Malam' : 'Siang',
                      active: isMalam,
                      icon: isMalam ? Icons.nights_stay : Icons.wb_sunny,
                      activeColor: const Color(0xFF534AB7),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  '$counter orang di dalam rumah',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // ── Output rumah ───────────────────────────
                const _SectionTitle('Output Rumah'),
                const SizedBox(height: 8),
                _OutputTile(
                  label: 'Lampu Rumah',
                  icon: Icons.lightbulb_outline,
                  active: lampuRumah,
                  canControl: _role == 'admin',
                  onToggle: (val) async {
                    await _db.updateState('lampuRumah', val);
                  },
                ),
                const SizedBox(height: 20),

                // ── Kamar Admin ────────────────────────────
                const _SectionTitle('Kamar Admin'),
                const SizedBox(height: 8),
                _OutputTile(
                  label: 'Lampu Kamar Admin',
                  icon: Icons.lightbulb_outline,
                  active: kamarAdmin['lampu'] ?? false,
                  canControl: _role == 'admin',
                  onToggle: _role == 'admin'
                      ? (val) async {
                          await _db.updateState('kamarAdmin/lampu', val);
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                // 🔧 Perubahan: gunakan 'kipas' bukan 'led'
                _OutputTile(
                  label: 'Kipas Kamar Admin',
                  icon: Icons.wind_power,
                  active: kamarAdmin['kipas'] ?? false,
                  canControl: _role == 'admin',
                  onToggle: _role == 'admin'
                      ? (val) async {
                          await _db.updateState('kamarAdmin/kipas', val);
                        }
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Kamar User ─────────────────────────────
                const _SectionTitle('Kamar User'),
                const SizedBox(height: 8),
                _OutputTile(
                  label: 'Lampu Kamar User',
                  icon: Icons.lightbulb_outline,
                  active: kamarUser['lampu'] ?? false,
                  canControl: true,
                  onToggle: (val) async {
                    await _db.updateState('kamarUser/lampu', val);
                  },
                ),
                const SizedBox(height: 8),
                // 🔧 Perubahan: gunakan 'kipas' bukan 'led'
                _OutputTile(
                  label: 'Kipas Kamar User',
                  icon: Icons.wind_power,
                  active: kamarUser['kipas'] ?? false,
                  canControl: true,
                  onToggle: (val) async {
                    await _db.updateState('kamarUser/kipas', val);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Reusable widgets (tidak berubah) ─────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Color(0xFF1E3A5F),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  final Color? activeColor;

  const _StatusChip({
    required this.label,
    required this.active,
    required this.icon,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? const Color(0xFF1D9E75)) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            active ? 'Ada' : 'Tidak',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _OutputTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool canControl;
  final ValueChanged<bool>? onToggle;

  const _OutputTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.canControl,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? const Color(0xFF1D9E75).withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF1D9E75) : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  active ? 'Menyala' : 'Mati',
                  style: TextStyle(
                    fontSize: 12,
                    color: active
                        ? const Color(0xFF1D9E75)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (canControl && onToggle != null)
            Switch(
              value: active,
              onChanged: onToggle,
              activeThumbColor: const Color(0xFF1D9E75),
              activeTrackColor: const Color(0xFF1D9E75).withValues(alpha: 0.4),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Auto',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}