import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battery_help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.uid});
  final String uid;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);
  static const _accent = Color(0xFF6C63FF);

  final goalCtrl = TextEditingController(text: '120');
  bool saving = false;

  @override
  void dispose() {
    goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily goal minutes',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: goalCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '120',
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: saving
                          ? null
                          : () async {
                              final v = int.tryParse(goalCtrl.text.trim()) ?? 120;
                              setState(() => saving = true);
                              try {
                                await userRef.update({'goalMinutes': v, 'updatedAt': FieldValue.serverTimestamp()});
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white10),
                          boxShadow: const [
                            BoxShadow(blurRadius: 22, color: Colors.black38, offset: Offset(0, 10)),
                          ],
                        ),
                        child: Text(
                          saving ? 'Saving...' : 'Save',
                          style: const TextStyle(
                            color: Color(0xFFB9B6FF),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  title: const Text(
                    'Improve timer reliability',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Battery optimization settings',
                    style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BatteryHelpScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
