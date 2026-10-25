import 'package:flutter/widgets.dart';
import 'app_state.dart';

/// Makes a single [AppState] instance available to the whole widget tree
/// without pulling in a state-management package.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this context');
    return scope!.notifier!;
  }
}
