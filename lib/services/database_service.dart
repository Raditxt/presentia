import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  // ── Ambil role user yang sedang login ──────────────────
  Future<String> getMyRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'unknown';
    final snap = await _db.ref('presentia/users/$uid/role').get();
    return snap.value?.toString() ?? 'unknown';
  }

  // ── Listen state rumah secara real-time ────────────────
  Stream<Map<String, dynamic>> watchState() {
    return _db.ref('presentia/state').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return _defaultState();
      return Map<String, dynamic>.from(data as Map);
    });
  }

  // ── Update satu field di state ─────────────────────────
  Future<void> updateState(String key, dynamic value) async {
    await _db.ref('presentia/state/$key').set(value);
  }

  // ── Ambil log aktivitas (50 terakhir) ──────────────────
  Stream<List<Map<String, dynamic>>> watchLog() {
    return _db
        .ref('presentia/log')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = Map<String, dynamic>.from(data as Map);
      final list = map.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      list.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      return list;
    });
  }

  // ── Tulis log baru ─────────────────────────────────────
  Future<void> addLog({
    required String role,
    required String action,
    required String name,
  }) async {
    final now = DateTime.now();
    await _db.ref('presentia/log').push().set({
      'role': role,
      'action': action,
      'name': name,
      'timestamp': now.millisecondsSinceEpoch,
      'time': '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')} '
          '${now.day}/${now.month}/${now.year}',
    });
  }

  // ── Inisialisasi state awal jika belum ada ─────────────
  Future<void> initStateIfEmpty() async {
    final snap = await _db.ref('presentia/state').get();
    if (!snap.exists) {
      await _db.ref('presentia/state').set(_defaultState());
    }
  }

  Map<String, dynamic> _defaultState() => {
    'adminPresent': false,
    'userPresent': false,
    'counter': 0,
    'lampuRumah': false,
    'kamarAdmin': {'lampu': false, 'led': false},
    'kamarUser':  {'lampu': false, 'led': false},
    'isMalam': false,
  };
}