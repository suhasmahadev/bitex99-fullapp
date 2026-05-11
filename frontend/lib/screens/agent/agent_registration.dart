import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agent_kyc_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import 'agent_kyc_status.dart';

class AgentRegistrationScreen extends StatelessWidget {
  const AgentRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent KYC Registration'),
        elevation: 0,
      ),
      body: Consumer<AgentKycProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildProgressHeader(context, provider.currentStep),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(R.wp(5.0)),
                  child: _buildCurrentStep(context, provider),
                ),
              ),
              _buildBottomNav(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context, int currentStep) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: R.hp(2.0), horizontal: R.wp(5.0)),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          final isActive = index <= currentStep;
          return Expanded(
            child: Container(
              height: R.hp(0.8),
              margin: EdgeInsets.symmetric(horizontal: R.wp(1.0)),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(R.wp(1.0)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, AgentKycProvider provider) {
    switch (provider.currentStep) {
      case 0:
        return _Step1Personal(provider: provider);
      case 1:
        return _Step2Identity(provider: provider);
      case 2:
        return _Step3Vehicle(provider: provider);
      case 3:
        return _Step4Bank(provider: provider);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNav(BuildContext context, AgentKycProvider provider) {
    return Container(
      padding: EdgeInsets.all(R.wp(5.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          if (provider.currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: provider.previousStep,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: R.hp(1.8)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (provider.currentStep > 0) SizedBox(width: R.wp(4.0)),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (provider.currentStep < 3) {
                  provider.nextStep();
                } else {
                  if (provider.formKey4.currentState!.validate()) {
                    // Submit
                    context
                        .read<UserProvider>()
                        .updateAgentKycStatus(KycStatus.pending);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentKycStatusScreen()),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: R.hp(1.8)),
              ),
              child:
                  Text(provider.currentStep == 3 ? 'Submit KYC' : 'Next Step'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Personal Details
// ─────────────────────────────────────────────────────────────────────────────
class _Step1Personal extends StatelessWidget {
  final AgentKycProvider provider;
  const _Step1Personal({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: provider.formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Details',
              style:
                  TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(1.0)),
          Text('Enter your basic information.',
              style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(height: R.hp(3.0)),
          _buildTextField('Full Name', provider.nameCtrl,
              icon: Icons.person_outline),
          _buildTextField('Phone Number', provider.phoneCtrl,
              icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          _buildTextField('Email Address (Optional)', provider.emailCtrl,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isRequired: false),
          _buildTextField('Date of Birth', provider.dobCtrl,
              icon: Icons.calendar_today_outlined, hint: 'DD/MM/YYYY'),
          _buildTextField('Full Address with Pincode', provider.addressCtrl,
              icon: Icons.home_outlined, maxLines: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Identity Verification
// ─────────────────────────────────────────────────────────────────────────────
class _Step2Identity extends StatelessWidget {
  final AgentKycProvider provider;
  const _Step2Identity({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: provider.formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identity Verification',
              style:
                  TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(1.0)),
          Text('Upload a valid Government ID.',
              style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(height: R.hp(3.0)),
          DropdownButtonFormField<String>(
            initialValue: provider.idType,
            decoration: const InputDecoration(
              labelText: 'Government ID Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: ['Aadhaar', 'PAN', 'Driving License']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) provider.setIdType(val);
            },
          ),
          SizedBox(height: R.hp(2.5)),
          _buildTextField('ID Number', provider.idNumberCtrl,
              icon: Icons.numbers_outlined),
          SizedBox(height: R.hp(2.0)),
          Text('Upload ID Proof (Front)',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(4.0))),
          SizedBox(height: R.hp(1.0)),
          _ImageUploadBox(
            imageBytes: provider.idProofBytes,
            imageName: provider.idProofName,
            onPick: provider.pickIdProof,
            onClear: provider.clearIdProof,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Vehicle Details
// ─────────────────────────────────────────────────────────────────────────────
class _Step3Vehicle extends StatelessWidget {
  final AgentKycProvider provider;
  const _Step3Vehicle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: provider.formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vehicle Details',
              style:
                  TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(1.0)),
          Text('How will you deliver orders?',
              style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(height: R.hp(3.0)),
          DropdownButtonFormField<String>(
            initialValue: provider.vehicleType,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.two_wheeler_outlined),
            ),
            items: ['Bike', 'Scooter', 'Cycle']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) provider.setVehicleType(val);
            },
          ),
          SizedBox(height: R.hp(2.5)),
          if (provider.vehicleType != 'Cycle')
            _buildTextField('Vehicle Number', provider.vehicleNumberCtrl,
                icon: Icons.pin_outlined),
          SizedBox(height: R.hp(2.0)),
          Text('Upload RC (Optional)',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(4.0))),
          SizedBox(height: R.hp(1.0)),
          _ImageUploadBox(
            imageBytes: provider.rcProofBytes,
            imageName: provider.rcProofName,
            onPick: provider.pickRcProof,
            onClear: provider.clearRcProof,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4: Bank Details
// ─────────────────────────────────────────────────────────────────────────────
class _Step4Bank extends StatelessWidget {
  final AgentKycProvider provider;
  const _Step4Bank({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: provider.formKey4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank Details',
              style:
                  TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold)),
          SizedBox(height: R.hp(1.0)),
          Text('Where should we send your earnings?',
              style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(height: R.hp(3.0)),
          _buildTextField('Account Holder Name', provider.accountNameCtrl,
              icon: Icons.person_outline),
          _buildTextField('Account Number', provider.accountNumberCtrl,
              icon: Icons.account_balance_outlined,
              keyboardType: TextInputType.number),
          _buildTextField('IFSC Code', provider.ifscCtrl,
              icon: Icons.account_balance_wallet_outlined),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildTextField(
  String label,
  TextEditingController controller, {
  IconData? icon,
  TextInputType? keyboardType,
  int maxLines = 1,
  String? hint,
  bool isRequired = true,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: R.hp(2.5)),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (val) {
        if (!isRequired) return null;
        if (val == null || val.trim().isEmpty) return 'This field is required';
        return null;
      },
    ),
  );
}

class _ImageUploadBox extends StatelessWidget {
  final dynamic imageBytes;
  final String? imageName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ImageUploadBox({
    this.imageBytes,
    this.imageName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Container(
        height: R.hp(20.0),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: R.hp(20.0),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: R.wp(12.0), color: Colors.grey.shade400),
            SizedBox(height: R.hp(1.0)),
            Text('Tap to upload image',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: R.sp(3.8))),
            Text('JPG, PNG format only (Max 5MB)',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: R.sp(3.0))),
          ],
        ),
      ),
    );
  }
}

