import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/mqtt_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _uidCtrl      = TextEditingController();
  final _mqtt         = MqttService();

  bool _loading    = false;
  bool _obscure    = true;
  bool _uidScanned = false;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    // Listen scan result dari ESP32
    _scanSub = _mqtt.scanStream.listen((uid) {
      if (!mounted) return;
      setState(() {
        _uidCtrl.text = uid;
        _uidScanned   = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Kartu terbaca: $uid'),
          backgroundColor: const Color(0xFF1D9E75),
        ),
      );
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _setupAdmin() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _showSnack('Semua field harus diisi', Colors.red);
      return;
    }
    if (_uidCtrl.text.isEmpty) {
      _showSnack('Tap kartu ke reader dulu', Colors.orange);
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showSnack('Password minimal 6 karakter', Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      // Buat akun Firebase Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      // Simpan ke Realtime DB sebagai Admin
      await FirebaseDatabase.instance
          .ref('presentia/users/${cred.user!.uid}')
          .set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': 'admin',
        'cardUID': _uidCtrl.text.trim().toUpperCase(),
        'isOnline': true,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Inisialisasi state awal
      await FirebaseDatabase.instance.ref('presentia/state').set({
        'adminPresent': false,
        'userPresent': false,
        'counter': 0,
        'lampuRumah': false,
        'isMalam': false,
        'kamarAdmin': {'lampu': false, 'kipas': false},
        'kamarUser':  {'lampu': false, 'kipas': false},
      });

      if (mounted) {
        _showSnack('Setup berhasil! Selamat datang.', const Color(0xFF1D9E75));
      }
      // StreamBuilder di main.dart otomatis redirect ke Dashboard
    } catch (e) {
      setState(() => _loading = false);
      _showSnack(e.toString(), Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.door_front_door,
                    size: 56, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'PRESENTIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Setup Awal — Buat Akun Admin',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 32),

                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // Step indicator
                        _StepInfo(
                          step: '1',
                          text: 'Isi data akun admin (pemilik rumah)',
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _StepInfo(
                          step: '2',
                          text: 'Tap kartu RFID ke reader — UID otomatis terisi',
                        ),
                        const SizedBox(height: 12),

                        // UID field dengan status scan
                        TextField(
                          controller: _uidCtrl,
                          decoration: InputDecoration(
                            labelText: 'Card UID',
                            prefixIcon: Icon(
                              _uidScanned
                                  ? Icons.check_circle
                                  : Icons.credit_card,
                              color: _uidScanned
                                  ? const Color(0xFF1D9E75)
                                  : null,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _uidScanned
                                    ? const Color(0xFF1D9E75)
                                    : Colors.grey,
                              ),
                            ),
                            helperText: _uidScanned
                                ? '✅ Kartu berhasil terbaca'
                                : 'Tap kartu ke reader RFID',
                            helperStyle: TextStyle(
                              color: _uidScanned
                                  ? const Color(0xFF1D9E75)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _setupAdmin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Selesaikan Setup & Masuk'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepInfo extends StatelessWidget {
  final String step;
  final String text;

  const _StepInfo({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A5F),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}