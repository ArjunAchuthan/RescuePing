import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const RescueMeshApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
