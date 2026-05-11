import 'package:flutter/material.dart';

class CartConflictDialog extends StatelessWidget {
  final String existingRestaurant;
  final String newRestaurant;
  final Future<void> Function() onReplace;

  const CartConflictDialog({
    super.key,
    required this.existingRestaurant,
    required this.newRestaurant,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start fresh?'),
      content: Text(
        'Your cart has items from $existingRestaurant\n'
        'Start fresh to order from $newRestaurant?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No, keep current'),
        ),
        FilledButton(
          onPressed: () async {
            await onReplace();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Yes, start fresh'),
        ),
      ],
    );
  }
}
