import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

class RestaurantRegistration extends StatefulWidget {
  const RestaurantRegistration({super.key});

  @override
  State<RestaurantRegistration> createState() => _RestaurantRegistrationState();
}

class _RestaurantRegistrationState extends State<RestaurantRegistration> {
  final _formKey = GlobalKey<FormState>();
  File? _fssaiPhoto;
  File? _kitchenPhoto;
  bool _isSubmitted = false;

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (type == 'fssai') setState(() => _fssaiPhoto = File(pickedFile.path));
      if (type == 'kitchen') setState(() => _kitchenPhoto = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Pending Approval', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Our team is reviewing your application. You will be notified once approved.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Partner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Register your shop', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              _buildTextField('Shop Name', 'Enter shop name'),
              _buildTextField('Owner Name', 'Enter owner name'),
              _buildTextField('UPI ID', 'e.g. shopname@okicici'),
              const SizedBox(height: 24),
              Text('Document Photos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildImagePicker('FSSAI License', _fssaiPhoto, () => _pickImage('fssai')),
              _buildImagePicker('Kitchen Photo', _kitchenPhoto, () => _pickImage('kitchen')),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _isSubmitted = true);
                  }
                },
                child: const Text('Submit for Approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
      ),
    );
  }

  Widget _buildImagePicker(String label, File? image, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, color: AppTheme.greyColor),
                    Text(label, style: const TextStyle(color: AppTheme.greyColor)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}

