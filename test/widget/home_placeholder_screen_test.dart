import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/core/widgets/home_placeholder_screen.dart';

void main() {
  testWidgets('HomePlaceholderScreen muestra el título Pasamanos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomePlaceholderScreen()),
      ),
    );

    expect(find.text('Pasamanos'), findsOneWidget);
  });
}
