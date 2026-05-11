import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color customerColor = Color(0xFFE8593C); // Default/Customer
  static const Color restaurantColor = Color(0xFF00A651); // Restaurant
  static const Color deliveryColor = Color(0xFFFFC107); // Delivery Agent
  
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Color(0xFF1A1A1A); // Dark Charcoal
  static const Color greyColor = Color(0xFF757575);

  static ThemeData get lightTheme => customerTheme; // Alias for default

  static ThemeData _buildTheme(Color primary) {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: backgroundColor,
      ),
    textTheme: GoogleFonts.notoSansTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.notoSans(
        fontSize: 16,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.notoSans(
        fontSize: 14,
        color: textColor,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      iconTheme: const IconThemeData(color: textColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: greyColor,
        backgroundColor: backgroundColor,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData get customerTheme => _buildTheme(customerColor);
  static ThemeData get restaurantTheme => _buildTheme(restaurantColor);
  static ThemeData get deliveryTheme => _buildTheme(deliveryColor);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: customerColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: ColorScheme.fromSeed(
      seedColor: customerColor,
      brightness: Brightness.dark,
      primary: customerColor,
    ),
    // ... define dark text theme if needed
  );
}
