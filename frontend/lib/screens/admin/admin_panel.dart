import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/restaurant_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  late Future<List<RestaurantModel>> _pendingRestaurants;

  @override
  void initState() {
    super.initState();
    _pendingRestaurants = RestaurantService().getPendingRestaurants();
  }

  void _reloadRestaurants() {
    setState(() {
      _pendingRestaurants = RestaurantService().getPendingRestaurants();
    });
  }

  Future<void> _approveRestaurant(RestaurantModel restaurant) async {
    await RestaurantService().updateRestaurantStatus(restaurant.id, 'active');
    _reloadRestaurants();
  }

  Future<void> _rejectRestaurant(RestaurantModel restaurant) async {
    final reason = await _askRejectReason();
    if (reason == null) return;
    await RestaurantService().updateRestaurantStatus(
      restaurant.id,
      'rejected',
      rejectionReason: reason,
    );
    _reloadRestaurants();
  }

  Future<String?> _askRejectReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject restaurant'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Enter reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              ctrl.text.trim().isEmpty ? 'Application rejected.' : ctrl.text.trim(),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bitex99 Admin'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Restaurants'),
              Tab(text: 'Agents'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildRestaurantApprovalList(),
            _buildAgentApprovalList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantApprovalList() {
    return FutureBuilder<List<RestaurantModel>>(
      future: _pendingRestaurants,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load restaurant requests: ${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reloadRestaurants,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final restaurants = snapshot.data ?? [];
        if (restaurants.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => _reloadRestaurants(),
            child: ListView(
              children: const [
                SizedBox(height: 220),
                Center(child: Text('No pending restaurant applications.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reloadRestaurants(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return _RestaurantApprovalCard(
                restaurant: restaurant,
                onApprove: () => _approveRestaurant(restaurant),
                onReject: () => _rejectRestaurant(restaurant),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAgentApprovalList(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final status = userProvider.agentKycStatus;

    if (status == KycStatus.none) {
      return const Center(child: Text('No pending agent applications.'));
    }

    Color statusColor = Colors.orange;
    String statusText = 'Pending';
    if (status == KycStatus.approved) {
      statusColor = Colors.green;
      statusText = 'Approved';
    } else if (status == KycStatus.rejected) {
      statusColor = Colors.red;
      statusText = 'Rejected';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    userProvider.name.isEmpty ? 'John Doe (Agent)' : userProvider.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text('Phone: ${userProvider.phone}'),
              const Text('Vehicle: Bike (KA 09 AB 1234)'),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPhotoThumbnail('Aadhaar'),
                  const SizedBox(width: 8),
                  _buildPhotoThumbnail('RC Book'),
                ],
              ),
              const SizedBox(height: 16),
              if (status == KycStatus.pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRejectDialog(context, userProvider),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          userProvider.updateAgentKycStatus(KycStatus.approved);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRejectDialog(BuildContext context, UserProvider provider) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject KYC'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason (e.g. Blurry ID proof)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.updateAgentKycStatus(
                KycStatus.rejected,
                reason: reasonCtrl.text.trim().isEmpty ? 'Documents unclear.' : reasonCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 10))),
    );
  }
}

class _RestaurantApprovalCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _RestaurantApprovalCard({
    required this.restaurant,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  restaurant.shopName.isEmpty ? 'Unnamed Restaurant' : restaurant.shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Owner: ${restaurant.ownerName.isEmpty ? '-' : restaurant.ownerName}'),
          Text('Phone: ${restaurant.phone.isEmpty ? '-' : restaurant.phone}'),
          Text('Town: ${restaurant.town.isEmpty ? '-' : restaurant.town}'),
          Text('Address: ${restaurant.address.isEmpty ? '-' : restaurant.address}'),
          Text('Cuisine: ${restaurant.cuisineType.isEmpty ? '-' : restaurant.cuisineType}'),
          Text('FSSAI: ${restaurant.fssaiNumber.isEmpty ? '-' : restaurant.fssaiNumber}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
