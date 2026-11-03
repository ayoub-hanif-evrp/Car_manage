import 'package:flutter_test/flutter_test.dart';
import 'package:my_logan/app.dart';
import 'package:my_logan/core/app_state.dart';

class _FakeState extends AppState {
  _FakeState() : super();

  @override
  Future<void> load() async {
    loading = false;
    error = null;
    notifyListeners();
  }
}

void main() {
  testWidgets('shell shows Dashboard tab', (tester) async {
    final state = _FakeState();
    await state.load();
    await tester.pumpWidget(MyLoganApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Fuel'), findsWidgets);
    expect(find.text('Garage'), findsWidgets);
    expect(find.text('Navigation'), findsWidgets);
  });
}
