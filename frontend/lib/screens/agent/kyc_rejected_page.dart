import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../utils/responsive.dart';

class KYCRejectedPage extends StatelessWidget {
  const KYCRejectedPage({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final prov = context.read<DeliveryProvider>();

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
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: R.wp(20.0),
                  color: Colors.red,
                ),
              ),
              SizedBox(height: R.hp(4.0)),
              Text(
                'Application Rejected',
                style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.hp(2.0)),
              Text(
                'Your KYC application was not approved due to unclear document images. Please re-upload clear photos of your ID and License.',
                style: TextStyle(fontSize: R.sp(4.0), color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.hp(6.0)),
              SizedBox(
                width: double.infinity,
                height: R.hp(7.0),
                child: ElevatedButton(
                  onPressed: () => prov.resetKYC(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Resubmit Application', style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
