import 'package:flutter/widgets.dart';
import 'package:win98_ui/win98_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// A small dialog asking for one line of text. Resolves to the trimmed text,
/// or `null` when cancelled or left empty.
Future<String?> showTextPrompt({
  required BuildContext context,
  required String title,
  required String prompt,
  String initial = '',
}) {
  final l10n = AppLocalizations.of(context);
  return showWin98Dialog<String>(
    context: context,
    title: title,
    builder: (context) => _TextPrompt(prompt: prompt, initial: initial, l10n: l10n),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.prompt, required this.initial, required this.l10n});
  final String prompt;
  final String initial;
  final AppLocalizations l10n;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.prompt),
        const SizedBox(height: 6),
        Win98TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          onSubmitted: (_) => _submit(),
          semanticLabel: widget.prompt,
        ),
        Win98DialogButtons(
          children: [
            Win98Button(isDefault: true, onPressed: _submit, child: Text(widget.l10n.ok)),
            Win98Button(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.l10n.cancel),
            ),
          ],
        ),
      ],
    );
  }
}
