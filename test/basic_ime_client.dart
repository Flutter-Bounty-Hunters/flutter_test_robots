import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'test_logging.dart';

/// A bare-bones implementation of a [DeltaTextInputClient] to help test IME simulation.
class BareBonesTextFieldWithInputClient extends StatefulWidget {
  const BareBonesTextFieldWithInputClient({
    Key? key,
    this.initialValue,
  }) : super(key: key);

  final TextEditingValue? initialValue;

  @override
  State createState() => _BareBonesTextFieldWithInputClientState();
}

class _BareBonesTextFieldWithInputClientState extends State<BareBonesTextFieldWithInputClient>
    implements DeltaTextInputClient {
  late FocusNode _focusNode;
  TextInputConnection? _textInputConnection;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..unfocus()
      ..addListener(_onFocusChange);

    _currentTextEditingValue = widget.initialValue ??
        const TextEditingValue(
          text: "",
          selection: TextSelection.collapsed(offset: -1),
        );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextFieldTapUp(TapUpDetails details) {
    setState(() {
      if (_currentTextEditingValue.selection.extentOffset == -1) {
        // Only set the text selection if one doesn't already exist. This way, tests can pass
        // an initial selection value and then tap on the field to give it focus.
        _currentTextEditingValue = _currentTextEditingValue.copyWith(
          selection: TextSelection.collapsed(offset: _currentTextEditingValue.text.length),
        );
      }

      if (_textInputConnection != null) {
        _textInputConnection!.setEditingState(currentTextEditingValue!);
      }

      _focusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // ignore: prefer_conditional_assignment
      if (_textInputConnection == null) {
        setState(() {
          _textInputConnection = TextInput.attach(this, const TextInputConfiguration());
          _textInputConnection!
            ..show()
            ..setEditingState(currentTextEditingValue!);
        });
      }
    } else {
      setState(() {
        _textInputConnection?.close();
        _textInputConnection = null;
      });
    }
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => _currentTextEditingValue;
  late TextEditingValue _currentTextEditingValue;

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    setState(() {
      for (final delta in textEditingDeltas) {
        imeTestClientLog.info("Handling delta: $delta");
        imeTestClientLog.fine(_deltaSummary(delta));

        _currentTextEditingValue = delta.apply(_currentTextEditingValue);

        imeTestClientLog.info("New text: ${_currentTextEditingValue.text}");
        imeTestClientLog.info("New selection: ${_currentTextEditingValue.selection}");
      }
      _textInputConnection!.setEditingState(_currentTextEditingValue);
    });
  }

  @override
  void updateEditingValue(TextEditingValue value) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showToolbar() {}

  @override
  void connectionClosed() {
    _textInputConnection = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
        ),
        child: GestureDetector(
          onTapUp: _onTextFieldTapUp,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300, minHeight: 56),
            child: Text(
              _currentTextEditingValue.text,
            ),
          ),
        ),
      ),
    );
  }
}

String _deltaSummary(TextEditingDelta delta) {
  if (delta is TextEditingDeltaInsertion) {
    return "TextEditingDeltaInsertion:\n"
        " - old text: ${delta.oldText}\n"
        " - inserted text: ${delta.textInserted}\n"
        " - inserted at: ${delta.insertionOffset}\n"
        " - new selection: ${delta.selection}";
  } else if (delta is TextEditingDeltaReplacement) {
    return "TextEditingDeltaInsertion:\n"
        " - old text: ${delta.oldText}\n"
        " - text being replaced: ${delta.textReplaced}\n"
        " - replaced with: ${delta.replacementText}\n"
        " - new selection: ${delta.selection}";
  } else if (delta is TextEditingDeltaDeletion) {
    return "TextEditingDeltaDeletion:\n"
        " - deletion range: ${delta.deletedRange}\n"
        " - text deleted: ${delta.textDeleted}\n"
        " - new selection: ${delta.selection}";
  } else if (delta is TextEditingDeltaNonTextUpdate) {
    return "TextEditingDeltaNonTextUpdate";
  }

  throw Exception("Invalid delta: $delta");
}
