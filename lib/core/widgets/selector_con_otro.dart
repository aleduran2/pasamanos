import 'package:flutter/material.dart';

/// Desplegable con una lista fija de opciones más "Otro" para escribir
/// cualquier valor que no esté en la lista. Se usa para colegio y barrio:
/// la mayoría elige de la lista (así los valores calzan exacto al buscar),
/// pero nadie queda afuera si el suyo no está.
class SelectorConOtro extends StatefulWidget {
  const SelectorConOtro({
    super.key,
    required this.valorInicial,
    required this.onChanged,
    required this.label,
    required this.labelOtro,
    required this.opciones,
    required this.valorOtro,
  });

  final String? valorInicial;
  final String label;

  /// Label del campo de texto que aparece al elegir "Otro".
  final String labelOtro;
  final List<String> opciones;

  /// Valor centinela para la opción "Otro" (distinto por cada uso, para no
  /// colisionar si en algún momento conviven dos selectores en la misma
  /// pantalla).
  final String valorOtro;
  final ValueChanged<String?> onChanged;

  @override
  State<SelectorConOtro> createState() => _SelectorConOtroState();
}

class _SelectorConOtroState extends State<SelectorConOtro> {
  late bool _mostrarOtro;
  late final TextEditingController _otroController;

  @override
  void initState() {
    super.initState();
    final valor = widget.valorInicial;
    _mostrarOtro = valor != null && !widget.opciones.contains(valor);
    _otroController = TextEditingController(text: _mostrarOtro ? valor : '');
  }

  @override
  void didUpdateWidget(covariant SelectorConOtro oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el valor cambia desde afuera (ej. un botón "Limpiar filtros" que
    // resetea el estado del padre), hay que resincronizar — si no, este
    // selector se queda mostrando la elección vieja aunque el filtro real
    // ya se haya borrado.
    if (widget.valorInicial != oldWidget.valorInicial) {
      final valor = widget.valorInicial;
      final debeMostrarOtro = valor != null && !widget.opciones.contains(valor);
      setState(() {
        _mostrarOtro = debeMostrarOtro;
        _otroController.text = debeMostrarOtro ? valor : '';
      });
    }
  }

  @override
  void dispose() {
    _otroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valorDropdown = _mostrarOtro ? widget.valorOtro : widget.valorInicial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              (valorDropdown != null &&
                  (valorDropdown == widget.valorOtro ||
                      widget.opciones.contains(valorDropdown)))
              ? valorDropdown
              : null,
          decoration: InputDecoration(labelText: widget.label),
          isExpanded: true,
          items: [
            for (final opcion in widget.opciones)
              DropdownMenuItem(
                value: opcion,
                child: Text(opcion, overflow: TextOverflow.ellipsis),
              ),
            DropdownMenuItem(
              value: widget.valorOtro,
              child: const Text('Otro (escribir)'),
            ),
          ],
          onChanged: (valor) {
            setState(() => _mostrarOtro = valor == widget.valorOtro);
            if (valor == widget.valorOtro) {
              widget.onChanged(
                _otroController.text.trim().isEmpty
                    ? null
                    : _otroController.text.trim(),
              );
            } else {
              widget.onChanged(valor);
            }
          },
        ),
        if (_mostrarOtro) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otroController,
            decoration: InputDecoration(labelText: widget.labelOtro),
            textCapitalization: TextCapitalization.words,
            onChanged: (texto) =>
                widget.onChanged(texto.trim().isEmpty ? null : texto.trim()),
          ),
        ],
      ],
    );
  }
}
