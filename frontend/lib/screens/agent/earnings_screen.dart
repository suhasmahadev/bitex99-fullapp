import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  // Day labels and earnings data
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<double> _earnings = [180, 320, 150, 420, 280, 510, 245];
  static const double _maxEarning = 510;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          title: Text('Earnings', style: TextStyle(fontSize: R.sp(5.0))),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              height: R.hp(18.0),
              width: double.infinity,
              padding: EdgeInsets.all(R.wp(5.0)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(R.wp(4.0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Earnings",
                    style: TextStyle(fontSize: R.sp(4.0), color: Colors.white70),
                  ),
                  Text(
                    '₹ 245.00',
                    style: TextStyle(
                      fontSize: R.sp(8.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(context, 'Deliveries', '8'),
                      Container(width: 1, height: R.hp(3.0), color: Colors.white30),
                      _buildSummaryItem(context, 'Avg/Order', '₹ 31'),
                      Container(width: 1, height: R.hp(3.0), color: Colors.white30),
                      _buildSummaryItem(context, 'Tips', '₹ 40'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: R.hp(2.5)),
            // Bar chart
            Text(
              'Weekly Overview',
              style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: R.hp(2.0)),
            Container(
              height: R.hp(28.0),
              padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(2.0)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(R.wp(3.5)),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_days.length, (i) => _buildBar(context, i)),
              ),
            ),
            SizedBox(height: R.hp(2.5)),
            // History
            Text(
              'Weekly History',
              style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: R.hp(1.5)),
            ...List.generate(_days.length, (i) => _buildHistoryRow(context, i)),
            SizedBox(height: R.hp(2.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    R.init(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: R.sp(3.0), color: Colors.white70)),
        SizedBox(height: R.hp(0.5)),
        Text(
          value,
          style: TextStyle(
            fontSize: R.sp(4.5),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBar(BuildContext context, int index) {
    R.init(context);
    double ratio = _earnings[index] / _maxEarning;
    bool isToday = index == 6;
    double chartHeight = R.hp(28.0) - R.hp(4.0); // subtract padding
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '₹${_earnings[index].toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: R.sp(2.8),
            color: isToday ? Theme.of(context).colorScheme.primary : AppTheme.greyColor,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(height: R.hp(0.5)),
        Container(
          width: R.wp(9.0),
          height: chartHeight * ratio * 0.8,
          decoration: BoxDecoration(
            color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(R.wp(2.0)),
          ),
        ),
        SizedBox(height: R.hp(0.5)),
        Text(
          _days[index],
          style: TextStyle(
            fontSize: R.sp(3.2),
            color: isToday ? Theme.of(context).colorScheme.primary : AppTheme.greyColor,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, int index) {
    R.init(context);
    final dates = [
      '26 April 2026', '25 April 2026', '24 April 2026',
      '23 April 2026', '22 April 2026', '21 April 2026', '20 April 2026',
    ];
    return Container(
      margin: EdgeInsets.only(bottom: R.hp(1.5)),
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.5)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dates[index],
                  style: TextStyle(fontSize: R.sp(4.0), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(8 - index).clamp(3, 10)} Orders completed',
                  style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor),
                ),
              ],
            ),
          ),
          Text(
            '₹ ${_earnings[index].toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: R.sp(4.2),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

