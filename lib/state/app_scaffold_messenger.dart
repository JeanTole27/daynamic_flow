import 'package:flutter/material.dart';

/// Global key so `AppState` can show the themed toast from anywhere
/// (business-logic methods don't carry a [BuildContext]), mirroring the
/// `flash()` helper in the original design prototype.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
