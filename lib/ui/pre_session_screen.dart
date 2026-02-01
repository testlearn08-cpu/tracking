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
  // Theme-ish constants (same style as your updated screens)
  static const _bgTop = Color(0xFF0B1220);
  static const _bgBottom = Color(0xFF070B14);
  static const _card = Color(0xFF0F172A);
  static const _selectedCard = Color(0xFF1E1B4B);
  static const _accent = Color(0xFF4F46E5);

  final intentCtrl = TextEditingController();

  int preset = 50;
  int breakMin = 10;
  bool autoBreak = true;
  String category = 'study';

  // Optional “intensity” (UI-only)
  String intensity = 'medium'; // easy|medium|hard

  @override
  void initState() {
    super.initState();
    preset = widget.initialPresetMinutes ?? 50;
    // optional: if user arrives via quick-start, auto align break defaults
    if (preset == 25) breakMin = 5;
    if (preset == 90) breakMin = 15;
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

  bool get _isPomodoro => preset == 25 && breakMin == 5;
  bool get _isShort => preset == 50 && breakMin == 10;
  bool get _isLong => preset == 90 && breakMin == 15;
  bool get _isCustom => !_isPomodoro && !_isShort && !_isLong;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Go Live', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _bgTop,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText: 'e.g., Crush the physics problems',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: const [
                    Expanded(child: _SectionTitle('TIMER')),
                    SizedBox(width: 12),
                    Expanded(child: _SectionTitle('CATEGORY')),
                  ],
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: TIMER
                        Expanded(
                          child: Column(
                            children: [
                              _SelectTile(
                                title: 'POMODORO',
                                subtitle: '25m focus • 5m break',
                                selected: _isPomodoro,
                                onTap: () => setState(() {
                                  preset = 25;
                                  breakMin = 5;
                                }),
                              ),
                              const SizedBox(height: 10),
                              _SelectTile(
                                title: 'SHORT',
                                subtitle: '50m focus • 10m break',
                                selected: _isShort,
                                onTap: () => setState(() {
                                  preset = 50;
                                  breakMin = 10;
                                }),
                              ),
                              const SizedBox(height: 10),
                              _SelectTile(
                                title: 'LONG',
                                subtitle: '90m focus • 15m break',
                                selected: _isLong,
                                onTap: () => setState(() {
                                  preset = 90;
                                  breakMin = 15;
                                }),
                              ),
                              const SizedBox(height: 10),
                              _SelectTile(
                                title: 'CUSTOM',
                                subtitle: _isCustom ? '$preset m focus • $breakMin m break' : 'Choose focus & break',
                                selected: _isCustom,
                                onTap: _showCustomPicker,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // RIGHT: CATEGORY
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
                  ),
                ),

                const SizedBox(height: 14),

                // Auto break panel (reference-like)
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
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Break: $breakMin min',
                            style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
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

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      backgroundColor: _bgTop,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Custom Timer',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _GlassCard(
                          child: DropdownButton<int>(
                            value: tmpPreset,
                            dropdownColor: _card,
                            iconEnabledColor: Colors.white70,
                            underline: const SizedBox.shrink(),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 15, child: Text('15 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 25, child: Text('25 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 50, child: Text('50 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 90, child: Text('90 min', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (v) => setSheetState(() => tmpPreset = v ?? 50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlassCard(
                          child: DropdownButton<int>(
                            value: tmpBreak,
                            dropdownColor: _card,
                            iconEnabledColor: Colors.white70,
                            underline: const SizedBox.shrink(),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('0 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 5, child: Text('5 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 10, child: Text('10 min', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 15, child: Text('15 min', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (v) => setSheetState(() => tmpBreak = v ?? 10),
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
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            );
          },
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
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 10)),
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

  static const _card = Color(0xFF0F172A);
  static const _selectedCard = Color(0xFF1E1B4B);
  static const _accent = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _selectedCard : _card;
    final border = selected ? _accent : Colors.white10;

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
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
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
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
