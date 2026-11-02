import 'package:flutter_test/flutter_test.dart';

import 'package:my_logan/main.dart';

void main() {
  testWidgets('Milestone 0 placeholder shows app name', (tester) async {
    await tester.pumpWidget(const MyLoganApp());

    expect(find.text('My Logan'), findsOneWidget);
    expect(find.textContaining('Milestone 0'), findsOneWidget);
    expect(find.textContaining('not implemented yet'), findsOneWidget);
  });
}
