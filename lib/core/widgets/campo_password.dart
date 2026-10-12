import 'package:flutter/material.dart';

/// Campo de contraseña con botón para mostrar/ocultar el texto — un
/// patrón tan estándar que su ausencia resalta. Antes faltaba en los tres
/// lugares donde se pide una contraseña (login, registro, cambiarla desde
/// el perfil), dejando a quien escribe sin forma de confirmar que no se
/// equivocó de letra antes de enviar.
class CampoPassword extends StatefulWidget {
  const CampoPassword({
    super.key,
    required this.controller,
    required this.labelText,
    this.autofillHints,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculta,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(
            _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}
