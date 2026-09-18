import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bevel.dart';
import 'theme.dart';

/// A sunken single-line text box built on [EditableText].
class Win98TextField extends StatefulWidget {
  const Win98TextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final String? semanticLabel;

  @override
  State<Win98TextField> createState() => _Win98TextFieldState();
}

class _Win98TextFieldState extends State<Win98TextField> {
  FocusNode? _own;
  FocusNode get _focusNode => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Win98Theme.of(context);
    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: _focusNode.requestFocus,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.controlHeight),
          child: Bevel(
            style: BevelStyle.field,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditableText(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                style: theme.textStyle,
                cursorColor: theme.text,
                cursorWidth: 1,
                backgroundCursorColor: theme.shadow,
                selectionColor: theme.selection.withValues(alpha: 0.4),
                maxLines: 1,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                inputFormatters: widget.maxLength == null
                    ? null
                    : [LengthLimitingTextInputFormatter(widget.maxLength)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
