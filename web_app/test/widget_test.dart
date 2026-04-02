import 'package:flutter_test/flutter_test.dart';

import 'package:prof_summary_web/main.dart';

void main() {
  testWidgets('Shows setup when Supabase is not configured', (WidgetTester tester) async {
    await tester.pumpWidget(const ProfSummaryApp());
    expect(find.textContaining('Set Supabase credentials'), findsOneWidget);
  });
}
