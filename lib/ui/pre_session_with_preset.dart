import 'package:flutter/material.dart';
import 'pre_session_screen.dart';

class PreSessionScreenWithPreset extends StatelessWidget {
  const PreSessionScreenWithPreset({super.key, required this.presetMinutes});
  final int presetMinutes;

  @override
  Widget build(BuildContext context) {
    return PreSessionScreen(initialPresetMinutes: presetMinutes);
  }
}
