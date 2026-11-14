import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_palette.dart';

/// Hướng dẫn lần đầu (coach marks): làm tối màn hình, khoét sáng một widget và hiện bong bóng giải thích.
/// Mỗi màn chỉ hiện một lần (cờ trong shared_preferences); "Xem lại hướng dẫn" gọi [replayTutorials].
const tutorialPrefsPrefix = 'tutorial_seen_';

/// Tắt sẵn trong widget test (biến môi trường FLUTTER_TEST) để các test cũ không bị lớp phủ che.
/// Test của chính phần hướng dẫn thì override provider này thành true.
final tutorialEnabledProvider = Provider<bool>(
  (ref) => kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST'),
);

/// Tăng lên mỗi lần người dùng bấm "Xem lại hướng dẫn" để các màn đang mở kiểm tra lại cờ.
final tutorialReplayProvider = StateProvider<int>((ref) => 0);

/// Xoá mọi cờ "đã xem" để hướng dẫn hiện lại ở lần mở màn kế tiếp.
Future<void> replayTutorials(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith(tutorialPrefsPrefix)) await prefs.remove(key);
  }
  ref.read(tutorialReplayProvider.notifier).state++;
}

class TutorialStep {
  const TutorialStep({
    required this.key,
    required this.title,
    required this.text,
  });

  /// GlobalKey gắn trên widget cần chỉ. Widget chưa dựng thì bước này tự bỏ qua.
  final GlobalKey key;
  final String title;
  final String text;
}

/// Bọc quanh nội dung một màn: khi widget của bước đầu tiên đã dựng xong và màn đang ở trên cùng,
/// hiện hướng dẫn một lần duy nhất cho [id].
class TutorialGate extends ConsumerStatefulWidget {
  const TutorialGate({
    super.key,
    required this.id,
    required this.steps,
    required this.child,
  });
  final String id;
  final List<TutorialStep> steps;
  final Widget child;

  @override
  ConsumerState<TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends ConsumerState<TutorialGate> {
  bool _done = false;
  bool _busy = false;
  bool _visible = true;
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Future<void> _maybeShow() async {
    if (_done || _busy || !mounted) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final flag = '$tutorialPrefsPrefix${widget.id}';
      if (prefs.getBool(flag) == true) {
        _done = true;
        return;
      }
      // Màn bị che bởi màn khác hoặc tab đang ẩn: chờ tới khi hiện lại
      if (ModalRoute.of(context)?.isCurrent == false || !_visible) return;
      final steps = widget.steps
          .where((s) => s.key.currentContext != null)
          .toList();
      if (steps.isEmpty) return; // widget chưa dựng, lần build sau thử lại
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _done = true;
      await prefs.setBool(flag, true);
      if (!mounted) return;
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _TutorialOverlay(
          steps: steps,
          onClose: () {
            entry.remove();
            if (_entry == entry) _entry = null;
          },
        ),
      );
      _entry = entry;
      overlay.insert(entry);
    } catch (_) {
      // Lỗi đọc cờ thì bỏ qua hướng dẫn, không chặn màn hình
      _done = true;
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tutorialReplayProvider, (_, _) {
      if (_entry == null) setState(() => _done = false);
    });
    // Tab ẩn trong IndexedStack bị tắt ticker; đổi tab thì widget này build lại
    _visible = TickerMode.valuesOf(context).enabled;
    if (ref.watch(tutorialEnabledProvider) && _visible && !_done && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
    return widget.child;
  }
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({required this.steps, required this.onClose});
  final List<TutorialStep> steps;
  final VoidCallback onClose;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int index = -1;
  Rect? hole;

  /// Màn bên dưới có thể còn đang tải dữ liệu và xê dịch sau khi đo: đo lại định kỳ để khung sáng bám đúng.
  Timer? _follow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
    _follow = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || index < 0) return;
      final rect = _rectOf(widget.steps[index].key);
      if (rect != null && rect != hole) setState(() => hole = rect);
    });
  }

  @override
  void dispose() {
    _follow?.cancel();
    super.dispose();
  }

  Future<void> _go(int next) async {
    var i = next;
    while (i < widget.steps.length) {
      final target = widget.steps[i].key.currentContext;
      if (target != null && target.mounted) {
        try {
          await Scrollable.ensureVisible(
            target,
            alignment: 0.4,
            duration: const Duration(milliseconds: 200),
          );
        } catch (_) {}
        if (!mounted) return;
        final rect = _rectOf(widget.steps[i].key);
        if (rect != null) {
          setState(() {
            index = i;
            hole = rect;
          });
          return;
        }
      }
      i++;
    }
    widget.onClose();
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final mine = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    if (mine is! RenderBox || !mine.attached) return null;
    final origin = box.localToGlobal(Offset.zero, ancestor: mine);
    return (origin & box.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    final rect = hole;
    if (index < 0 || rect == null) {
      // Chặn chạm trong lúc cuộn tới widget đầu tiên
      return const AbsorbPointer(child: SizedBox.expand());
    }
    final step = widget.steps[index];
    final last = index == widget.steps.length - 1;
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final below = size.height - rect.bottom;
        final placeBelow = below >= 190 || below >= rect.top;
        final width = math.min(size.width - 32, 360.0);
        final double left = (rect.center.dx - width / 2)
            .clamp(16.0, math.max(16.0, size.width - width - 16))
            .toDouble();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(painter: _HolePainter(rect)),
              ),
            ),
            Positioned(
              left: left,
              width: width,
              top: placeBelow
                  ? math.min(rect.bottom + 12, size.height - 150)
                  : null,
              bottom: placeBelow
                  ? null
                  : math.min(size.height - rect.top + 12, size.height - 150),
              child: Material(
                color: colors.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${index + 1}/${widget.steps.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (!last)
                            TextButton(
                              onPressed: widget.onClose,
                              child: const Text('Bỏ qua'),
                            ),
                          FilledButton(
                            onPressed: () => _go(index + 1),
                            child: Text(last ? 'Xong' : 'Tiếp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HolePainter extends CustomPainter {
  const _HolePainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(cutout),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
    canvas.drawRRect(
      cutout,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}
