import 'package:flutter/material.dart';
import 'available_orders.dart';
import 'earnings_screen.dart';
import '../../utils/responsive.dart';

class AgentMain extends StatefulWidget {
  const AgentMain({super.key});

  @override
  State<AgentMain> createState() => _AgentMainState();
}

class _AgentMainState extends State<AgentMain> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const AvailableOrders(),
    const EarningsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SizedBox(
        height: R.hp(9.0),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          iconSize: R.wp(7.0),
          selectedFontSize: R.sp(3.0),
          unselectedFontSize: R.sp(3.0),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: 'Deliveries'),
            BottomNavigationBarItem(icon: Icon(Icons.currency_rupee), label: 'Earnings'),
          ],
        ),
      ),
    );
  }
}
