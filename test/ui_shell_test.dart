import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:society_connect/core/widgets/dialog_text_controller_owner.dart';
import 'package:society_connect/core/widgets/floating_navigation_bar.dart';

void main() {
  testWidgets('floating navigation changes the selected destination',
      (tester) async {
    var selectedIndex = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Center(child: Text('Page $selectedIndex')),
          bottomNavigationBar: FloatingNavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.apartment_outlined),
                selectedIcon: Icon(Icons.apartment),
                label: 'Flats',
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Flats'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('dialog text controller remains safe through cancel animation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => DialogTextControllerOwner(
                count: 1,
                builder: (context, controllers) => AlertDialog(
                  content: TextField(controller: controllers.first),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('Open form'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Temporary input');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });
}
