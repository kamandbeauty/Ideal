import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/permission_providers.dart';
import '../../services/permission_service.dart';
import '../../services/voice/native_speech_recognizer.dart';
import '../../services/voice/speech_recognizer.dart';

/// A multi-line text field with a built-in Persian dictation button.
///
/// Used by the note editor so «با میکروفون بگو» works wherever the user types.
/// The recogniser is created per field and disposed with it.
class VoiceDictationField extends ConsumerStatefulWidget {
  const VoiceDictationField({
    super.key,
    required this.controller,
    this.hintText = 'متن یادداشت…',
    this.minLines = 6,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final int minLines;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<VoiceDictationField> createState() => _VoiceDictationFieldState();
}

class _VoiceDictationFieldState extends ConsumerState<VoiceDictationField> {
  late final SpeechRecognizer _recognizer = NativeSpeechRecognizer();
  bool _listening = false;
  String _baseText = '';

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _recognizer.stop();
      setState(() => _listening = false);
      return;
    }
    final outcome =
        await ref.read(permissionServiceProvider).request(JavidPermission.microphone);
    if (!mounted) return;
    if (outcome != PermissionOutcome.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای دیکته به مجوز میکروفون نیاز است.')),
      );
      return;
    }
    _baseText = widget.controller.text;
    final started = await _recognizer.start(
      onPartial: (text) {
        if (!mounted) return;
        final combined = _baseText.isEmpty ? text : '$_baseText $text';
        widget.controller.text = combined;
        widget.onChanged?.call(combined);
      },
      onFinal: (text) {
        if (!mounted) return;
        final combined = _baseText.isEmpty ? text : '$_baseText $text';
        widget.controller.text = combined;
        widget.controller.selection =
            TextSelection.collapsed(offset: combined.length);
        widget.onChanged?.call(combined);
        setState(() => _listening = false);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
    if (!mounted) return;
    setState(() => _listening = started);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          minLines: widget.minLines,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _toggle,
          style: FilledButton.styleFrom(
            backgroundColor: _listening
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
                : null,
          ),
          icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(_listening ? 'پایان دیکته' : 'دیکته با میکروفون'),
        ),
      ],
    );
  }
}
