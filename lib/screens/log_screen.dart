import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class LogScreen extends StatelessWidget {
  LogScreen({super.key});

  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: const Text('Log Aktivitas'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.watchLog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _LogTile(log: log);
            },
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final role    = log['role']?.toString()   ?? 'unknown';
    final action  = log['action']?.toString() ?? '';
    final name    = log['name']?.toString()   ?? '';
    final ts      = log['timestamp'] as int?  ?? 0;

    final isAdmin  = role == 'admin';
    final isMasuk  = action == 'masuk';
    final time     = ts > 0
        ? DateFormat('HH:mm  dd/MM/yyyy')
            .format(DateTime.fromMillisecondsSinceEpoch(ts))
        : log['time']?.toString() ?? '-';

    final actionColor = isMasuk
        ? const Color(0xFF1D9E75)
        : const Color(0xFFE24B4A);

    final roleColor = isAdmin
        ? const Color(0xFF1E3A5F)
        : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMasuk ? Icons.login : Icons.logout,
              color: actionColor,
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
                      name.isEmpty ? role.toUpperCase() : name,
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
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAdmin ? 'Admin' : 'User',
                        style: TextStyle(
                          fontSize: 10,
                          color: roleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isMasuk ? 'Masuk ke rumah' : 'Keluar dari rumah',
                  style: TextStyle(
                    fontSize: 12,
                    color: actionColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Waktu
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}