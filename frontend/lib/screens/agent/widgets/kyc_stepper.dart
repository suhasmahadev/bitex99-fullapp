import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class KycStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const KycStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Colors.grey.shade300;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.wp(6.0), vertical: R.hp(2.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = currentStep > stepIndex;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(top: R.hp(1.8)),
                height: 2,
                color: isCompleted ? primaryColor : inactiveColor,
              ),
            );
          }

          // Step Circle
          final stepIndex = index ~/ 2;
          final isActive = currentStep == stepIndex;
          final isCompleted = currentStep > stepIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: R.wp(8.0),
                height: R.wp(8.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? primaryColor
                      : (isActive ? Colors.white : inactiveColor),
                  border: Border.all(
                    color: (isActive || isCompleted) ? primaryColor : inactiveColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: R.wp(4.5))
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            color: isActive ? primaryColor : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: R.sp(3.5),
                          ),
                        ),
                ),
              ),
              SizedBox(height: R.hp(1.0)),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: R.sp(2.8),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.black87 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }),
      ),
    );
  }
}
