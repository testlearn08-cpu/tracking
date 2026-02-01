import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.uid, required this.sessionId});
  final String uid;
  final String sessionId;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // Map UI buttons to your backend strings
  // done | partial | not_done
  String result = 'done';
  int distraction = 2;

  final notesCtrl = TextEditingController();

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SessionService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        backgroundColor: const Color(0xFF0B1220),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1220), Color(0xFF070B14)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5).withOpacity(0.18),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.45)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF8B82FF)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Session Complete!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DISTRACTION LEVEL',
                        style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (i) {
                          final v = i + 1;
                          final selected = distraction == v;
                          return _CirclePick(
                            label: '$v',
                            selected: selected,
                            onTap: () => setState(() => distraction = v),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ZEN', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w800, fontSize: 11)),
                          Text('CHAOTIC', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),

                      const SizedBox(height: 18),
                      const Text(
                        'COMPLETION STATUS',
                        style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PillButton(
                              label: '100% Done',
                              selected: result == 'done',
                              onTap: () => setState(() => result = 'done'),
                              selectedColor: const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PillButton(
                              label: 'Incomplete',
                              selected: result != 'done',
                              onTap: () => setState(() => result = 'partial'),
                              selectedColor: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (result != 'done')
                        Row(
                          children: [
                            Expanded(
                              child: _PillButton(
                                label: 'Partial',
                                selected: result == 'partial',
                                onTap: () => setState(() => result = 'partial'),
                                selectedColor: const Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PillButton(
                                label: 'Not done',
                                selected: result == 'not_done',
                                onTap: () => setState(() => result = 'not_done'),
                                selectedColor: const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _GlassCard(
                  child: TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      await service.submitFeedbackAndUpdateStats(
                        uid: widget.uid,
                        sessionId: widget.sessionId,
                        result: result,
                        distractionLevel: distraction,
                        notes: notesCtrl.text.trim(),
                      );

                      if (!mounted) return;
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B1220),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('FINALIZE RESULTS', style: TextStyle(fontWeight: FontWeight.w900)),
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 22, offset: Offset(0, 14)),
        ],
      ),
      child: child,
    );
  }
}

class _CirclePick extends StatelessWidget {
  const _CirclePick({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : const Color(0xFF111827),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? selectedColor : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
