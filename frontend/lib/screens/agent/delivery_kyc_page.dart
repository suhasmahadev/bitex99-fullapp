import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../utils/responsive.dart';
import 'widgets/kyc_stepper.dart';
import 'widgets/kyc_form_card.dart';
import 'widgets/image_upload_widget.dart';

class DeliveryKYCPage extends StatefulWidget {
  const DeliveryKYCPage({super.key});

  @override
  State<DeliveryKYCPage> createState() => _DeliveryKYCPageState();
}

class _DeliveryKYCPageState extends State<DeliveryKYCPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final bgGrey = const Color(0xFFF5F5F5);

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final prov = context.watch<DeliveryProvider>();
    final step = prov.currentKycStep;

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          // ── HERO SECTION ──
          _buildHeroSection(context),

          // ── STEPPER ──
          KycStepper(
            currentStep: step,
            steps: const ['Basic Info', 'Vehicle Details', 'Documents'],
          ),

          // ── FORM CONTENT ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: R.wp(6.0), vertical: R.hp(1.0)),
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildStepContent(step, prov),
                ),
              ),
            ),
          ),

          // ── STICKY BOTTOM NAV ──
          _buildBottomNav(step, prov),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(R.wp(6.0), R.hp(6.0), R.wp(6.0), R.hp(4.0)),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              final prov = context.read<DeliveryProvider>();
              if (prov.currentKycStep > 0) {
                prov.prevKycStep();
              }
            },
            child: Icon(Icons.arrow_back, color: Colors.white, size: R.wp(7.0)),
          ),
          SizedBox(height: R.hp(2.5)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.wp(3.0), vertical: R.hp(0.8)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Delivery Partner Program',
              style: TextStyle(
                color: Colors.white,
                fontSize: R.sp(3.2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: R.hp(2.0)),
          Text(
            'Partner with Us',
            style: TextStyle(
              color: Colors.white,
              fontSize: R.sp(8.0),
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: R.hp(1.0)),
          Text(
            'Earn by delivering food to customers in your city.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: R.sp(4.0),
              height: 1.3,
            ),
          ),
          SizedBox(height: R.hp(3.5)),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('10,000+', 'Deliveries'),
              _buildStat('₹25,000+', 'Monthly Earnings'),
              _buildStat('Zero', 'Joining Fee'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: R.sp(4.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: R.hp(0.4)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: R.sp(3.0),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(int step, DeliveryProvider prov) {
    switch (step) {
      case 0:
        return _buildStep1(prov);
      case 1:
        return _buildStep2(prov);
      case 2:
        return _buildStep3(prov);
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Basic Info
  Widget _buildStep1(DeliveryProvider prov) {
    return KycFormCard(
      key: const ValueKey(0),
      title: 'Basic Info',
      subtitle: 'Please provide your basic details',
      children: [
        _buildTextField('Full Name', prov.nameController, Icons.person_outline),
        _buildTextField('Phone Number', prov.phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
        _buildTextField('Email Address', prov.emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        _buildTextField('Aadhaar / ID Number', prov.idNumberController, Icons.badge_outlined),
      ],
    );
  }

  // Step 2: Vehicle Details
  Widget _buildStep2(DeliveryProvider prov) {
    return KycFormCard(
      key: const ValueKey(1),
      title: 'Vehicle Details',
      subtitle: 'Information about your delivery vehicle',
      children: [
        _buildDropdown('Vehicle Type', prov.vehicleType, (val) => prov.setVehicleType(val ?? 'Bike'), ['Bike', 'Scooter', 'Cycle']),
        _buildTextField('Vehicle Number', prov.vehicleNumberController, Icons.directions_bike_outlined),
        _buildTextField('Driving License Number', prov.licenseNumberController, Icons.card_membership_outlined),
      ],
    );
  }

  // Step 3: Documents Upload
  Widget _buildStep3(DeliveryProvider prov) {
    return KycFormCard(
      key: const ValueKey(2),
      title: 'Upload Documents',
      subtitle: 'Provide clear photos of your original documents',
      children: [
        ImageUploadWidget(label: 'Profile Photo', imageBytes: prov.profilePhoto, onTap: () => prov.pickImage('profile')),
        ImageUploadWidget(label: 'Aadhaar Card', imageBytes: prov.aadhaarImage, onTap: () => prov.pickImage('aadhaar')),
        ImageUploadWidget(label: 'Driving License', imageBytes: prov.licenseImage, onTap: () => prov.pickImage('license')),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.hp(2.5)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: R.sp(4.2), color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.grey.shade500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(vertical: R.hp(2.0)),
        ),
        validator: (val) => (val == null || val.isEmpty) ? 'Required field' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, ValueChanged<String?> onChanged, List<String> options) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.hp(2.5)),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        style: TextStyle(fontSize: R.sp(4.2), color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.two_wheeler, color: Colors.grey.shade500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBottomNav(int step, DeliveryProvider prov) {
    return Container(
      padding: EdgeInsets.fromLTRB(R.wp(6.0), R.hp(2.0), R.wp(6.0), R.hp(3.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          if (step > 0)
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.only(right: R.wp(3.0)),
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => prov.prevKycStep(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: R.hp(2.0)),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: R.sp(4.2),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _onNext(step, prov),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: R.hp(2.0)),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: R.hp(2.5),
                      width: R.hp(2.5),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      step == 2 ? 'Submit Application' : 'Next',
                      style: TextStyle(
                        fontSize: R.sp(4.2),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNext(int step, DeliveryProvider prov) async {
    if (!_formKey.currentState!.validate()) return;

    if (step < 2) {
      prov.nextKycStep();
    } else {
      // Final step validation for images
      if (prov.profilePhoto == null || prov.aadhaarImage == null || prov.licenseImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please upload all required documents'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      await prov.submitKYC();
      setState(() => _isSubmitting = false);
    }
  }
}
