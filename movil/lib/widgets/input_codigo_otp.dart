import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class InputCodigoOTP extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const InputCodigoOTP({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<InputCodigoOTP> createState() => _InputCodigoOTPState();
}

class _InputCodigoOTPState extends State<InputCodigoOTP> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // If user pasted a full code
      if (value.length > 1) {
        final digits = value.split('');
        for (int i = 0; i < widget.length && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        _checkComplete();
        _focusNodes[widget.length - 1].requestFocus();
        return;
      }

      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _checkComplete();
  }

  void _checkComplete() {
    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 44,
          height: 54,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: CeosTheme.dataMono(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: CeosColors.areaOdontologia,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: CeosColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: CeosColors.areaOdontologia,
                  width: 2,
                ),
              ),
            ),
            onChanged: (val) => _onDigitChanged(index, val),
            onTap: () {
              _controllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _controllers[index].text.length),
              );
            },
          ),
        );
      }),
    );
  }
}
