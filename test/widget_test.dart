import 'package:flutter_test/flutter_test.dart';

import 'package:daynamic_flow/app.dart';

void main() {
  testWidgets('Login screen shows the two role buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TurnosApp());

    expect(find.text('Gerente'), findsOneWidget);
    expect(find.text('Empleado'), findsOneWidget);

    await tester.tap(find.text('Gerente'));
    await tester.pumpAndSettle();

    // Manager home screen greets Carlos and shows the working-now stat.
    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(find.textContaining('Trabajando ahora'), findsOneWidget);
  });
}
