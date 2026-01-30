import 'package:flutter/material.dart';

class PreSessionResult {
  final String intent;
  final int presetMinutes;
  final int breakMinutes;
  final bool autoBreak;
  final String category;

  PreSessionResult({
    required this.intent,
    required this.presetMinutes,
    required this.breakMinutes,
    required this.autoBreak,
    required this.category,
  });
}

class PreSessionScreen extends StatefulWidget {
  const PreSessionScreen({super.key, this.initialPresetMinutes});
  final int? initialPresetMinutes;

  @override
  State<PreSessionScreen> createState() => _PreSessionScreenState();
}

class _PreSessionScreenState extends State<PreSessionScreen> {
  final intentCtrl = TextEditingController();
  int preset = 50;
  int breakMin = 10;
  bool autoBreak = true;
  String category = 'study';

  @override
  void initState() {
    super.initState();
    preset = widget.initialPresetMinutes ?? 50;
  }

  @override
  void dispose() {
    intentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a Focus Session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: intentCtrl,
              decoration: const InputDecoration(
                labelText: 'What are you working on? (required)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Preset:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: preset,
                  items: const [
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 90, child: Text('90')),
                  ],
                  onChanged: (v) => setState(() => preset = v ?? 50),
                ),
                const SizedBox(width: 16),
                const Text('Break:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: breakMin,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 15, child: Text('15')),
                  ],
                  onChanged: (v) => setState(() => breakMin = v ?? 10),
                ),
              ],
            ),
            SwitchListTile(
              value: autoBreak,
              onChanged: (v) => setState(() => autoBreak = v),
              title: const Text('Auto break after focus'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Category:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: 'study', child: Text('Study')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                  ],
                  onChanged: (v) => setState(() => category = v ?? 'study'),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                final intent = intentCtrl.text.trim();
                if (intent.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter what you will work on')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  PreSessionResult(
                    intent: intent,
                    presetMinutes: preset,
                    breakMinutes: breakMin,
                    autoBreak: autoBreak,
                    category: category,
                  ),
                );
              },
              child: const Text('Start'),
            )
          ],
        ),
      ),
    );
  }
}
