import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyesea_reporting_2/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EyeseaApp());
    expect(find.text('Eyesea Reporting'), findsWidgets);
    expect(find.text('Welcome to Eyesea Reporting'), findsOneWidget);
  });
}
