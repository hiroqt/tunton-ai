import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'features/camera/photo_screen.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/Inter-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
  runApp(const TuntonApp(home: PhotoScreen()));
}
