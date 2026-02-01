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

  // Optional “intensity” like the reference UI (not used in DB yet)
  String intensity = 'medium'; // easy|medium|hard

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

  void _submit() {
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
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Live'),
        backgroundColor: const Color(0xFF0B1220),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1220),
              Color(0xFF070B14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safeBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "WHAT'S THE MAIN GOAL?",
                  style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),

                _GlassCard(
                  child: TextField(
                    controller: intentCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Finish the physics problems',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _SectionTitle('TIMER'),
                    ),
                    Expanded(
                      child: _SectionTitle('CATEGORY'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _SelectTile(
                            title: 'POMODORO',
                            subtitle: '25m focus • 5m break',
                            selected: preset == 25 && breakMin == 5,
                            onTap: () => setState(() {
                              preset = 25;
                              breakMin = 5;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'SHORT',
                            subtitle: '50m focus • 10m break',
                            selected: preset == 50 && breakMin == 10,
                            onTap: () => setState(() {
                              preset = 50;
                              breakMin = 10;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'LONG',
                            subtitle: '90m focus • 15m break',
                            selected: preset == 90 && breakMin == 15,
                            onTap: () => setState(() {
                              preset = 90;
                              breakMin = 15;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'CUSTOM',
                            subtitle: 'Choose focus & break',
                            selected: !(preset == 25 && breakMin == 5) &&
                                !(preset == 50 && breakMin == 10) &&
                                !(preset == 90 && breakMin == 15),
                            onTap: () async {
                              await _showCustomPicker();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _SelectTile(
                            title: 'Work',
                            subtitle: 'Deep work',
                            selected: category == 'work',
                            onTap: () => setState(() => category = 'work'),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Study',
                            subtitle: 'Learning mode',
                            selected: category == 'study',
                            onTap: () => setState(() => category = 'study'),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Coding',
                            subtitle: 'Build & ship',
                            selected: category == 'coding',
                            onTap: () => setState(() => category = 'coding'),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Reading',
                            subtitle: 'Focus reading',
                            selected: category == 'reading',
                            onTap: () => setState(() => category = 'reading'),
                          ),
                          const SizedBox(height: 10),
                          _SelectTile(
                            title: 'Other',
                            subtitle: 'Anything',
                            selected: category == 'other',
                            onTap: () => setState(() => category = 'other'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: autoBreak,
                          onChanged: (v) => setState(() => autoBreak = v),
                          title: const Text(
                            'Auto break after focus',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Break: $breakMin min',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'INTENSITY',
                  style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ChipButton(
                        label: 'Easy',
                        selected: intensity == 'easy',
                        onTap: () => setState(() => intensity = 'easy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChipButton(
                        label: 'Medium',
                        selected: intensity == 'medium',
                        onTap: () => setState(() => intensity = 'medium'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChipButton(
                        label: 'Hard',
                        selected: intensity == 'hard',
                        onTap: () => setState(() => intensity = 'hard'),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'GO LIVE • $preset min',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
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

  Future<void> _showCustomPicker() async {
    int tmpPreset = preset;
    int tmpBreak = breakMin;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Custom Timer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GlassCard(
                      child: DropdownButton<int>(
                        value: tmpPreset,
                        dropdownColor: const Color(0xFF0F172A),
                        iconEnabledColor: Colors.white70,
                        underline: const SizedBox.shrink(),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 25, child: Text('25 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 50, child: Text('50 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 90, child: Text('90 min', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) => setState(() => tmpPreset = v ?? 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassCard(
                      child: DropdownButton<int>(
                        value: tmpBreak,
                        dropdownColor: const Color(0xFF0F172A),
                        iconEnabledColor: Colors.white70,
                        underline: const SizedBox.shrink(),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 5, child: Text('5 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 10, child: Text('10 min', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 15, child: Text('15 min', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) => setState(() => tmpBreak = v ?? 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      preset = tmpPreset;
                      breakMin = tmpBreak;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        fontSize: 12,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF1E1B4B) : const Color(0xFF0F172A);
    final border = selected ? const Color(0xFF4F46E5) : Colors.white10;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0B1220) : Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
