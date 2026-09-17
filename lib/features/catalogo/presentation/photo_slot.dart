import 'dart:io';

import 'package:flutter/material.dart';

class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    super.key,
    required this.etiqueta,
    required this.archivo,
    required this.onTap,
  });

  final String etiqueta;
  final File? archivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 130,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: archivo == null
                  ? const Icon(Icons.add_a_photo_outlined)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        archivo!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}
