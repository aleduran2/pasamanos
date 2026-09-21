import 'package:flutter/material.dart';

/// Selector múltiple con la forma de un desplegable (como un
/// DropdownButtonFormField): al tocarlo se abre una hoja con casilleros
/// para elegir varias opciones a la vez, y el campo muestra lo elegido
/// como texto, separado por comas.
class SelectorMultipleDesplegable extends StatelessWidget {
  const SelectorMultipleDesplegable({
    super.key,
    required this.label,
    required this.opciones,
    required this.seleccionados,
    required this.onChanged,
  });

  final String label;
  final List<String> opciones;
  final Set<String> seleccionados;
  final ValueChanged<Set<String>> onChanged;

  Future<void> _abrirSelector(BuildContext context) async {
    final temporal = Set<String>.from(seleccionados);
    final resultado = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(temporal),
                          child: const Text('Listo'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: opciones.map((opcion) {
                        final marcado = temporal.contains(opcion);
                        return CheckboxListTile(
                          value: marcado,
                          title: Text(opcion),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (valor) => setModalState(() {
                            if (valor ?? false) {
                              temporal.add(opcion);
                            } else {
                              temporal.remove(opcion);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (resultado != null) onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final texto = seleccionados.isEmpty
        ? 'Ninguno'
        : seleccionados.join(', ');
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _abrirSelector(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: seleccionados.isEmpty
              ? TextStyle(color: colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}
