import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import '../../utils/responsive.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String selectedLanguage = 'English';
  String? selectedTown;
  final List<String> towns = ['KR Nagar', 'Hunsur'];
  final List<String> comingSoonTowns = ['Mysuru', 'Periyapatna'];

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          actions: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
              child: DropdownButton<String>(
                value: selectedLanguage,
                underline: const SizedBox(),
                items: ['English', 'Kannada'].map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(lang, style: TextStyle(fontSize: R.sp(4.0))),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedLanguage = val);
                },
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Bitex99',
              style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: R.hp(1.5)),
            Text(
              'Select your town to start ordering delicious local food.',
              style: TextStyle(fontSize: R.sp(4.0), color: AppTheme.greyColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: R.hp(2.5)),
            Text(
              'Choose Town',
              style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: R.hp(2.5)),
            Wrap(
              spacing: R.wp(4.0),
              runSpacing: R.hp(2.0),
              children: [
                ...towns.map((town) => _buildTownCard(town, false)),
                ...comingSoonTowns.map((town) => _buildTownCard(town, true)),
              ],
            ),
            SizedBox(height: R.hp(2.5)),
            SizedBox(
              width: double.infinity,
              height: R.hp(7.0),
              child: ElevatedButton(
                onPressed: selectedTown != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(town: selectedTown!),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(R.wp(3.0)),
                  ),
                ),
                child: Text('Continue', style: TextStyle(fontSize: R.sp(5.0))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTownCard(String town, bool isComingSoon) {
    bool isSelected = selectedTown == town;
    return Opacity(
      opacity: isComingSoon ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isComingSoon ? null : () => setState(() => selectedTown = town),
        child: Container(
          width: R.wp(42.0),
          height: R.hp(16.0),
          padding: EdgeInsets.all(R.wp(3.5)),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(R.wp(3.5)),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on,
                color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.greyColor,
                size: R.wp(8.0),
              ),
              SizedBox(height: R.hp(1.0)),
              Text(
                town,
                style: TextStyle(
                  fontSize: R.sp(5.0),
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (isComingSoon) ...[
                SizedBox(height: R.hp(0.8)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(0.3)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: TextStyle(fontSize: R.sp(3.0), color: Colors.grey),
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

