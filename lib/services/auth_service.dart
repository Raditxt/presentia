import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;

  // Register + simpan role ke Realtime DB
  Future<String?> register({
    required String email,
    required String password,
    required String name,
    required String role, // 'admin' atau 'user'
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Simpan data user ke Realtime DB
      await _db.ref('presentia/users/${cred.user!.uid}').set({
        'name': name,
        'email': email,
        'role': role,
        'cardUID': '',       // diisi nanti dari manajemen kartu
        'isOnline': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return null; // null = sukses
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update status online
      if (currentUser != null) {
        await _db
            .ref('presentia/users/${currentUser!.uid}/isOnline')
            .set(true);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Logout
  Future<void> logout() async {
    if (currentUser != null) {
      await _db
          .ref('presentia/users/${currentUser!.uid}/isOnline')
          .set(false);
    }
    await _auth.signOut();
  }

  // Ambil role user yang sedang login
  Future<String> getRole() async {
    if (currentUser == null) return 'unknown';
    final snap = await _db
        .ref('presentia/users/${currentUser!.uid}/role')
        .get();
    return snap.value?.toString() ?? 'unknown';
  }
}