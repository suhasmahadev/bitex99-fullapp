import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../utils/responsive.dart';

class KYCPendingPage extends StatefulWidget {
  const KYCPendingPage({super.key});

  @override
  State<KYCPendingPage> createState() => _KYCPendingPageState();
}

class _KYCPendingPageState extends State<KYCPendingPage> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final prov = context.read<DeliveryProvider>();
      if (prov.kycStatus == KYCStatus.pending) {
        prov.refreshKYCStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final prov = context.watch<DeliveryProvider>();
    final isApproved = prov.kycStatus == KYCStatus.approved;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(R.wp(8.0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(R.wp(5.0)),
                decoration: BoxDecoration(
                  color: isApproved ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved ? Icons.verified_user : Icons.timer_outlined,
                  size: R.wp(20.0),
                  color: isApproved ? Theme.of(context).colorScheme.primary : Colors.orange,
                ),
              ),
              SizedBox(height: R.hp(4.0)),
              Text(
                isApproved ? 'Verification Successful!' : 'Verification in Progress',
                style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.hp(2.0)),
              Text(
                isApproved 
                  ? 'Your documents have been verified. You can now start delivering orders.'
                  : 'We are reviewing your documents. This usually takes 5-10 minutes. Please stay tuned!',
                style: TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.hp(6.0)),
              if (!isApproved)
                const CircularProgressIndicator(color: Colors.orange),
              if (isApproved)
                SizedBox(
                  width: double.infinity,
                  height: R.hp(7.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Handled by the Gateway/Wrapper
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Continue to Dashboard', style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
