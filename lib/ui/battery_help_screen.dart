import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';

class BatteryHelpScreen extends StatelessWidget {
  const BatteryHelpScreen({super.key});

  void _openBatteryOptimizationSettings() {
    const intent = AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
    intent.launch();
  }

  void _openAppDetails() {
    // IMPORTANT: change this to your real package name (android/app/build.gradle applicationId)
    const intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:com.example.tracking',
    );
    intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Improve Timer Reliability')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Some phones (Xiaomi, Oppo, Vivo, Realme, OnePlus) may stop timers or delay notifications.\n\n'
              'Do these steps to keep FocusFlow reliable:',
            ),
            const SizedBox(height: 16),
            _stepCard(
              title: '1) Disable battery optimization for FocusFlow',
              bullets: const [
                'Open Battery optimization settings',
                'Find FocusFlow',
                'Set to “Don’t optimize” / “No restrictions”',
              ],
              buttonText: 'Open Battery Optimization',
              onTap: _openBatteryOptimizationSettings,
            ),
            _stepCard(
              title: '2) Allow background activity / autostart',
              bullets: const [
                'Open App info for FocusFlow',
                'Battery → Background activity ON',
                'Autostart ON (if available)',
              ],
              buttonText: 'Open App Info',
              onTap: _openAppDetails,
            ),
            _stepCard(
              title: '3) Keep notifications allowed',
              bullets: const [
                'Settings → Notifications → FocusFlow',
                'Allow notifications',
                'Lock screen notifications ON',
              ],
              buttonText: null,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String title,
    required List<String> bullets,
    required String? buttonText,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $b'),
                )),
            if (buttonText != null && onTap != null) ...[
              const SizedBox(height: 8),
              ElevatedButton(onPressed: onTap, child: Text(buttonText)),
            ]
          ],
        ),
      ),
    );
  }
}
