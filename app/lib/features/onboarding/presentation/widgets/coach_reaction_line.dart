import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../domain/coach_reactions.dart';

/// Dòng coach phản hồi ngay theo lựa chọn: biểu tượng lấp lánh + một câu,
/// phần đầu in đậm. Đổi câu thì mờ dần sang câu mới; chưa có câu thì trống.
class CoachReactionLine extends StatelessWidget {
  const CoachReactionLine(this.line, {super.key});

  final CoachLine? line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = line;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        layoutBuilder: (currentChild, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?currentChild],
        ),
        child: current == null
            ? const SizedBox(width: double.infinity, key: ValueKey('none'))
            : Padding(
                key: ValueKey(current.text),
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: c.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${current.lead} ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: current.rest),
                          ],
                        ),
                        key: const ValueKey('coach-reaction-text'),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: c.textPrimary,
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
