import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/mqtt_service.dart';

class CardManagementScreen extends StatefulWidget {
  const CardManagementScreen({super.key});

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  final _db   = FirebaseDatabase.instance;
  final _mqtt = MqttService();

  Stream<List<Map<String, dynamic>>> _watchUsers() {
    return _db.ref('presentia/users').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = Map<String, dynamic>.from(data as Map);
      return map.entries.map((e) {
        final user = Map<String, dynamic>.from(e.value as Map);
        user['uid'] = e.key;
        return user;
      }).toList();
    });
  }

  Future<void> _editCard(Map<String, dynamic> user) async {
    final cardCtrl    = TextEditingController(
        text: user['cardUID']?.toString() ?? '');
    String selectedRole = user['role']?.toString() ?? 'user';
    bool   isScanning   = false;
    StreamSubscription? scanSub;

    // Aktifkan scan mode di ESP32
    _mqtt.setScanMode(true);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Subscribe hasil scan → isi ke field otomatis
          scanSub ??= _mqtt.scanStream.listen((uid) {
            // Cek apakah dialog masih mounted sebelum mengubah state
            if (ctx.mounted) {
              setDlgState(() {
                cardCtrl.text = uid;
                isScanning    = false;
              });
            }
            // Gunakan ctx yang sudah dicek mounted untuk menampilkan SnackBar
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('✅ UID terbaca: $uid'),
                  backgroundColor: const Color(0xFF1D9E75),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });

          return AlertDialog(
            title: Text('Edit: ${user['name'] ?? ''}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner instruksi scan
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1D9E75),
                              ),
                            )
                          : const Icon(
                              Icons.nfc,
                              color: Color(0xFF1D9E75),
                              size: 18,
                            ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tap kartu ke reader RFID — UID otomatis terisi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1D9E75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Field UID
                TextField(
                  controller: cardCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Card UID',
                    hintText: 'Tap kartu atau isi manual',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                    helperText: 'Contoh: F7 51 86 63',
                  ),
                ),
                const SizedBox(height: 16),

                // Role selector
                const Text(
                  'Role:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _RoleOption(
                      label: 'Admin',
                      selected: selectedRole == 'admin',
                      onTap: () =>
                          setDlgState(() => selectedRole = 'admin'),
                    ),
                    const SizedBox(width: 8),
                    _RoleOption(
                      label: 'User',
                      selected: selectedRole == 'user',
                      onTap: () =>
                          setDlgState(() => selectedRole = 'user'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _db
                      .ref('presentia/users/${user['uid']}')
                      .update({
                    'cardUID': cardCtrl.text.trim().toUpperCase(),
                    'role': selectedRole,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    // Cleanup saat dialog ditutup
    _mqtt.setScanMode(false);
    scanSub?.cancel();
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text(
            'Hapus akun "$name"? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.ref('presentia/users/$uid').remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text('Manajemen Kartu'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _watchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Tidak ada user terdaftar',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final users = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8), // Perbaikan: (_, _)
            itemBuilder: (context, index) {
              final user     = users[index];
              final role     = user['role']?.toString()    ?? 'user';
              final name     = user['name']?.toString()    ?? '-';
              final email    = user['email']?.toString()   ?? '-';
              final cardUID  = user['cardUID']?.toString() ?? '';
              final isOnline = user['isOnline'] == true;
              final isAdmin  = role == 'admin';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      backgroundColor: isAdmin
                          ? const Color(0xFF1E3A5F).withValues(alpha: 0.1)
                          : const Color(0xFF2563EB).withValues(alpha: 0.1),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                        color: isAdmin
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? const Color(0xFF1E3A5F)
                                          .withValues(alpha: 0.1)
                                      : const Color(0xFF2563EB)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isAdmin ? 'Admin' : 'User',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isAdmin
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFF2563EB),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Dot online indicator
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline
                                      ? const Color(0xFF1D9E75)
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cardUID.isEmpty
                                ? '⚠ Kartu belum didaftarkan'
                                : 'UID: $cardUID',
                            style: TextStyle(
                              fontSize: 11,
                              color: cardUID.isEmpty
                                  ? Colors.orange
                                  : Colors.grey,
                              fontStyle: cardUID.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (val) {
                        if (val == 'edit')   _editCard(user);
                        if (val == 'delete') _deleteUser(user['uid'], name);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit kartu & role'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus akun',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1E3A5F).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF1E3A5F)
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E3A5F) : Colors.grey,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}