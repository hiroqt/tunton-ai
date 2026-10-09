import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tuntun/main.dart';

void main() {
  patrolTest('counter smoke test with Patrol', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());

    // Verify initial counter value is 0
    expect($('0'), findsOneWidget);

    // Tap the increment floating action button
    await $(Icons.add).tap();

    // Verify counter increments to 1
    expect($('1'), findsOneWidget);
  });
}
