import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlPattern = RegExp(
  r'((https?:\/\/)|(www\.))[^\s]+',
  caseSensitive: false,
);

/// Plain [Text] with any URLs in [text] (`https://…`, `http://…`, `www…`)
/// turned into tappable, distinctly-colored spans that open in the external
/// browser via `url_launcher`. Trailing punctuation (`.`, `,`, `)`, ...)
/// right after a URL is excluded from the link so a sentence-ending period
/// doesn't get swallowed into it.
class LinkifiedText extends StatelessWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.linkColor,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final matches = _urlPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final color = linkColor ?? Theme.of(context).colorScheme.primary;
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      var end = match.end;
      while (end > match.start && _isTrailingPunctuation(text[end - 1])) {
        end--;
      }
      final rawUrl = text.substring(match.start, end);
      final url = rawUrl.startsWith('www.') ? 'https://$rawUrl' : rawUrl;

      spans.add(
        TextSpan(
          text: rawUrl,
          style: (style ?? const TextStyle()).copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrlSafely(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
        ),
      );

      if (end < match.end) {
        spans.add(TextSpan(text: text.substring(end, match.end)));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  static bool _isTrailingPunctuation(String char) {
    return '.,!?؟،؛;:)]}'.contains(char);
  }
}
