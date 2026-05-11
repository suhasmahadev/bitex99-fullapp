import 'package:flutter/material.dart';

class PhoneFrameWrapper extends StatefulWidget {
  final Widget child;
  const PhoneFrameWrapper({super.key, required this.child});

  @override
  State<PhoneFrameWrapper> createState() => _PhoneFrameWrapperState();
}

class _PhoneFrameWrapperState extends State<PhoneFrameWrapper> {
  String selectedDevice = 'Android';
  bool isLandscape = false;

  final Map<String, Size> deviceSizes = {
    'Android': const Size(412, 915),   // Samsung Galaxy S23 Ultra / Pixel 7 Pro
    'iOS': const Size(430, 932),        // iPhone 14 Pro Max / iPhone 15 Plus
  };

  @override
  Widget build(BuildContext context) {
    Size currentSize = deviceSizes[selectedDevice]!;
    if (isLandscape) {
      currentSize = Size(currentSize.height, currentSize.width);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhoneFrame(currentSize),
                const SizedBox(height: 30),
                _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneFrame(Size size) {
    double framePadding = 12.0;
    double cornerRadius = 40.0;
    double screenRadius = 30.0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer Frame
        Container(
          width: size.width + (framePadding * 2),
          height: size.height + (framePadding * 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(color: Colors.grey.shade800, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        // Volume Buttons (Left)
        if (!isLandscape)
          Positioned(
            left: -4,
            top: 150,
            child: Column(
              children: [
                _buildSideButton(40),
                const SizedBox(height: 10),
                _buildSideButton(40),
              ],
            ),
          ),

        // Power Button (Right)
        if (!isLandscape)
          Positioned(
            right: -4,
            top: 200,
            child: _buildSideButton(60),
          ),

        // Inner Screen Area
        Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(screenRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(screenRadius),
            child: Stack(
              children: [
                // App Content
                Positioned.fill(
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      padding: const EdgeInsets.only(top: 32, bottom: 20),
                      devicePixelRatio: 1.0,
                    ),
                    child: widget.child,
                  ),
                ),
                
                // Status Bar
                _buildStatusBar(),

                // Notch / Punch Hole
                _buildNotch(),

                // Home Indicator
                _buildHomeIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideButton(double height) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '9:41 AM',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.signal_cellular_4_bar, size: 12, color: Colors.black),
                const SizedBox(width: 4),
                const Icon(Icons.wifi, size: 12, color: Colors.black),
                const SizedBox(width: 4),
                Transform.rotate(
                  angle: 1.57,
                  child: const Icon(Icons.battery_full, size: 16, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotch() {
    if (selectedDevice == 'Android') {
      return Positioned(
        top: 8,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else { // iOS
      return Positioned(
        top: 8,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            width: 90,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildHomeIndicator() {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...deviceSizes.keys.map((name) {
          bool isActive = selectedDevice == name;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: () => setState(() => selectedDevice = name),
              style: OutlinedButton.styleFrom(
                backgroundColor: isActive ? const Color(0xFFE8593C) : Colors.transparent,
                foregroundColor: isActive ? Colors.white : Colors.grey,
                side: BorderSide(color: isActive ? Colors.transparent : Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(name),
            ),
          );
        }).toList(),
        const SizedBox(width: 20),
        IconButton(
          onPressed: () => setState(() => isLandscape = !isLandscape),
          icon: Icon(
            isLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape,
            color: Colors.white,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
