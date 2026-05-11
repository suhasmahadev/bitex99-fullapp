import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import 'agent_registration.dart';

class AgentKycStatusScreen extends StatelessWidget {
  const AgentKycStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final userProvider = context.watch<UserProvider>();
    final status = userProvider.agentKycStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Status'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Usually handled by routing back to Login
              userProvider.logout();
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(R.wp(6.0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == KycStatus.pending) ...[
                Icon(Icons.hourglass_empty, size: R.wp(20.0), color: Colors.orange),
                SizedBox(height: R.hp(3.0)),
                Text('Verification in Progress', style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
                SizedBox(height: R.hp(2.0)),
                Text(
                  'Your KYC details have been submitted successfully. Our admin team will review them shortly. Please check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: R.sp(4.0)),
                ),
              ] else if (status == KycStatus.rejected) ...[
                Icon(Icons.error_outline, size: R.wp(20.0), color: Colors.red),
                SizedBox(height: R.hp(3.0)),
                Text('KYC Rejected', style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold, color: Colors.red)),
                SizedBox(height: R.hp(2.0)),
                Container(
                  padding: EdgeInsets.all(R.wp(4.0)),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                      SizedBox(height: R.hp(1.0)),
                      Text(
                        userProvider.agentKycRejectionReason ?? 'Unclear documents. Please upload again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: R.hp(4.0)),
                SizedBox(
                  width: double.infinity,
                  height: R.hp(6.5),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                    child: const Text('Re-upload / Edit KYC'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

