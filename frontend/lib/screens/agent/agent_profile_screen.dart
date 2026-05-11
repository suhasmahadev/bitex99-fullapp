import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../utils/responsive.dart';
import '../onboarding/login_screen.dart';

class AgentProfileScreen extends StatelessWidget {
  const AgentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final userProv = context.watch<UserProvider>();
    final deliveryProv = context.watch<DeliveryProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.all(R.wp(5.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agent Profile', style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(2.0)),
            _buildDetailCard(
              context: context,
              title: 'Personal Details',
              icon: Icons.person_outline,
              children: [
                _buildRow('Full Name', deliveryProv.agentName.isEmpty ? userProv.name : deliveryProv.agentName),
                _buildRow('Phone', deliveryProv.agentPhone.isEmpty ? userProv.phone : deliveryProv.agentPhone),
                _buildRow('Email', deliveryProv.agentEmail.isEmpty ? 'Not provided' : deliveryProv.agentEmail),
              ],
            ),
            SizedBox(height: R.hp(2.0)),
            _buildDetailCard(
              context: context,
              title: 'KYC Status',
              icon: Icons.verified_user_outlined,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Verification', style: TextStyle(color: Colors.grey.shade600, fontSize: R.sp(3.8))),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(0.5)),
                      decoration: BoxDecoration(
                        color: userProv.agentKycStatus == KycStatus.approved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        userProv.agentKycStatus == KycStatus.approved ? 'Approved' : 'Pending',
                        style: TextStyle(
                          color: userProv.agentKycStatus == KycStatus.approved ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: R.sp(3.2),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildRow('ID Type', 'Aadhaar'),
                _buildRow('ID Number', 'Available in Docs'),
              ],
            ),
            SizedBox(height: R.hp(2.0)),
            _buildDetailCard(
              context: context,
              title: 'Vehicle Details',
              icon: Icons.two_wheeler,
              children: [
                _buildRow('Type', deliveryProv.vehicleType.isEmpty ? 'Bike' : deliveryProv.vehicleType),
                if (deliveryProv.vehicleType != 'Cycle')
                  _buildRow('Vehicle No.', deliveryProv.vehicleNumberController.text.isEmpty ? 'Not Provided' : deliveryProv.vehicleNumberController.text),
              ],
            ),
            SizedBox(height: R.hp(2.0)),
            _buildDetailCard(
              context: context,
              title: 'Bank Details',
              icon: Icons.account_balance,
              children: [
                _buildRow('Account Name', 'Provided'),
                _buildRow('A/C Number', 'XXXX XXXX'),
                _buildRow('IFSC', 'XXXX000000'),
              ],
            ),
          SizedBox(height: R.hp(4.0)),
          SizedBox(
            width: double.infinity,
            height: R.hp(6.0),
            child: OutlinedButton.icon(
              onPressed: () {
                userProv.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen(town: '')),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          SizedBox(height: R.hp(4.0)),
        ],
      ),
    );
  }

  Widget _buildDetailCard({required BuildContext context, required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(R.wp(4.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: R.wp(5.0)),
              SizedBox(width: R.wp(2.0)),
              Text(title, style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: R.hp(1.5)),
          Divider(color: Colors.grey.shade200),
          SizedBox(height: R.hp(1.5)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.hp(1.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: R.sp(3.8))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(3.8))),
        ],
      ),
    );
  }
}

