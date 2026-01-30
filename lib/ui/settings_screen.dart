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
  final goalCtrl = TextEditingController(text: '120');

  @override
  void dispose() {
    goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: goalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Daily goal minutes'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final v = int.tryParse(goalCtrl.text.trim()) ?? 120;
              await userRef.update({'goalMinutes': v, 'updatedAt': FieldValue.serverTimestamp()});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Improve timer reliability'),
            subtitle: const Text('Battery optimization settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BatteryHelpScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
