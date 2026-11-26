import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:society_connect/features/auth/data/registration_draft.dart';
import 'package:society_connect/features/auth/presentation/register_screen.dart';

void main() {
  testWidgets(
      'keeps selected vacant flat valid when submit refreshes the availability list',
      (tester) async {
    var availabilityChecks = 0;
    RegistrationDraft? submittedDraft;

    await tester.pumpWidget(MaterialApp(
      home: RegisterScreen(
        loadRegistrationFlats: (societyId) async {
          availabilityChecks++;
          expect(societyId, 'ASHOPALAV1');
          return [
            {'id': 'ASHOPALAV1_A103', 'flatNumber': 'A103'},
          ];
        },
        onRegistrationSubmit: (draft) async {
          submittedDraft = draft;
        },
      ),
    ));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'resident@example.com');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.enterText(textFields.at(2), 'password123');
    await tester.enterText(textFields.at(3), 'Resident Name');
    await tester.enterText(textFields.at(4), '9876543210');
    await tester.enterText(textFields.at(5), 'ASHOPALAV1');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A103').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(availabilityChecks, 2);
    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.flatId, 'ASHOPALAV1_A103');
    expect(submittedDraft!.flatNumber, 'A103');
    expect(submittedDraft!.societyId, 'ASHOPALAV1');
    expect(find.text('Select an available flat.'), findsNothing);
  });
}
