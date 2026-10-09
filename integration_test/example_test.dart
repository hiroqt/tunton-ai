import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tuntun/app/app.dart';
import 'package:tuntun/features/camera/photo_screen.dart';

void main() {
  patrolTest('Tunton photo entry smoke test', ($) async {
    await $.pumpWidgetAndSettle(const TuntonApp(home: PhotoScreen()));
    expect($('Take a photo'), findsOneWidget);
    expect($('Choose from gallery'), findsOneWidget);
    expect($('Intramuros'), findsOneWidget);
  });
}
