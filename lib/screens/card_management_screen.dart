import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CardManagementScreen extends StatefulWidget {
  const CardManagementScreen({super.key});

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  final _db = FirebaseDatabase.instance;

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
    final cardCtrl = TextEditingController(
        text: user['cardUID']?.toString() ?? '');
    String selectedRole = user['role']?.toString() ?? 'user';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit: ${user['name'] ?? ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: cardCtrl,
                decoration: const InputDecoration(
                  labelText: 'Card UID',
                  hintText: 'Contoh: F7 51 86 63',
                  border: OutlineInputBorder(),
                  helperText: 'Salin dari Serial Monitor saat tap kartu',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Role:', style: TextStyle(fontSize: 13)),
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
                await _db.ref('presentia/users/${user['uid']}').update({
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
        ),
      ),
    );
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Hapus akun "$name"? Tindakan ini tidak bisa dibatalkan.'),
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
              child: Text('Tidak ada user terdaftar',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final users = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
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
                              // Online indicator
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
                        if (val == 'edit') _editCard(user);
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