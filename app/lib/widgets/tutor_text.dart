import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/zws_theme.dart';

class TutorText extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const TutorText({
    super.key,
    required this.text,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final rawLines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .toList();
    final lines = rawLines.where((line) => line.trim().isNotEmpty).isEmpty
        ? [text]
        : rawLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (lines[i].trim().isEmpty)
            SizedBox(height: compact ? 3 : 5)
          else
            _TutorLine(line: lines[i].trim(), color: color, seal: t.seal),
          if (i != lines.length - 1 && lines[i].trim().isNotEmpty)
            SizedBox(height: compact ? 4 : 6),
        ],
      ],
    );
  }
}

class _TutorLine extends StatelessWidget {
  final String line;
  final Color color;
  final Color seal;

  const _TutorLine({
    required this.line,
    required this.color,
    required this.seal,
  });

  @override
  Widget build(BuildContext context) {
    final bullet = _bulletPrefix(line);
    final body = bullet == null ? line : line.substring(bullet.length).trim();
    final label = _labelPrefix(body);
    final base = ZwsFonts.sans(size: 14, color: color, height: 1.45);

    final text = SelectableText.rich(
      TextSpan(
        style: base,
        children: [
          if (label != null) ...[
            TextSpan(
              text: label,
              style: base.copyWith(fontWeight: FontWeight.w800, color: seal),
            ),
            TextSpan(text: body.substring(label.length)),
          ] else
            TextSpan(text: body),
        ],
      ),
    );

    if (bullet == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Text(
            bullet.trim(),
            style: ZwsFonts.sans(
              size: 13,
              weight: FontWeight.w800,
              color: seal,
              height: 1.45,
            ),
          ),
        ),
        Expanded(child: text),
      ],
    );
  }

  String? _bulletPrefix(String value) {
    if (value.startsWith('- ')) return '- ';
    final match = RegExp(r'^\d+[.)]\s+').firstMatch(value);
    return match?.group(0);
  }

  String? _labelPrefix(String value) {
    final match = RegExp(r'^[A-Za-z ]{3,18}:\s*').firstMatch(value);
    return match?.group(0);
  }
}
