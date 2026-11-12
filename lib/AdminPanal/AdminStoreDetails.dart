import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AdminStoreDetailScreen extends StatefulWidget {
  final Store store;

  const AdminStoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  State<AdminStoreDetailScreen> createState() => _AdminStoreDetailScreenState();
}

class _AdminStoreDetailScreenState extends State<AdminStoreDetailScreen> with TickerProviderStateMixin {
  List<YoutubePlayerController> _youtubeControllers = [];
  Store? _store;
  bool _isLoadingVideos = true;
  bool _isAddingVideo = false; // Add loading state for video operations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Tab controller for organizing content
  late TabController _tabController;

  // Scroll controller for custom scrolling effects
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchStoreData();

    // Defer fetchOrdersByStore until after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false)
          .fetchOrdersByStore(context, widget.store.id!);
    });

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );

    _animationController.forward();

    // Initialize tab controller
    _tabController = TabController(length: 5, vsync: this);
  }

  Future<void> _fetchStoreData() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    Store? fetchedStore = await storeProvider.fetchStore(widget.store.id!);

    if (fetchedStore != null && mounted) {
      setState(() {
        _store = fetchedStore;
        _initializeVideoControllers();
        _isLoadingVideos = false;
      });
    }
  }

  void _initializeVideoControllers() {
    // Dispose existing controllers
    for (var controller in _youtubeControllers) {
      controller.dispose();
    }

    // Initialize new controllers
    _youtubeControllers = _store?.videos?.map((video) {
      final videoId = YoutubePlayer.convertUrlToId(video.url);
      return YoutubePlayerController(
        initialVideoId: videoId ?? '',
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
    }).toList() ?? [];
  }

  @override
  void dispose() {
    if (_youtubeControllers.isNotEmpty) {
      for (var controller in _youtubeControllers) {
        controller.dispose();
      }
    }
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Validate YouTube URL
  bool _isValidYouTubeUrl(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    return videoId != null && videoId.isNotEmpty;
  }

  // Show success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Show error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.teal,
          surface: Colors.white,
          background: Colors.grey[50]!,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black26,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [_buildAppBar()];
          },
          body: _store != null ? _buildStoreDetails() : _buildLoading(),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      title: Text(
        '${_store?.name ?? 'Store'} Details',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _store?.imageUrl != null
            ? Stack(
          fit: StackFit.expand,
          children: [
            // Store image as background
            Image.network(
              _store!.imageUrl,
              fit: BoxFit.cover,
            ),
            // Gradient overlay for better text visibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            // Store info overlay
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _store?.name ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _store?.category ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
            : Container(
          color: Colors.indigo,
          child: const Center(
            child: Icon(
              Icons.store,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.info), text: "Info"),
          Tab(icon: Icon(Icons.shopping_cart), text: "Orders"),
          Tab(icon: Icon(Icons.payment), text: "Payments"),
          Tab(icon: Icon(Icons.location_on), text: "Location"),
          Tab(icon: Icon(Icons.video_library), text: "Videos"),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading store details...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetails() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildOrdersTab(),
          _buildPaymentsTab(),
          _buildLocationTab(),
          _buildVideosTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStoreInfoCard(),
        const SizedBox(height: 16),
        _buildDeliveryMethodsCard(),
      ],
    );
  }

  Widget _buildStoreInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Store Details', Icons.store),
            const SizedBox(height: 16),
            _buildDetailItem('Name', _store?.name ?? '', Icons.shopping_bag),
            const Divider(),
            _buildDetailItem('Category', _store?.category ?? '', Icons.category),
            // Add more details as needed
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Orders', Icons.shopping_cart),
              const SizedBox(height: 16),
              Expanded(
                child: _buildOrdersSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersSection() {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (orderProvider.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No orders available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        } else {
          return ListView.separated(
            itemCount: orderProvider.orders.length,
            separatorBuilder: (context, index) => const Divider(),
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              return _buildOrderCard(order);
            },
          );
        }
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to order details
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getStatusColorLight(order.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$${order.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColorLight(order.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColorLight(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.withOpacity(0.2);
      case 'Processed':
        return Colors.blue.withOpacity(0.2);
      case 'Shipped':
        return Colors.purple.withOpacity(0.2);
      case 'Delivered':
        return Colors.green.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.access_time;
      case 'Processed':
        return Icons.inventory;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processed':
        return Colors.blue;
      case 'Shipped':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPaymentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Payments to Zing', Icons.payment),
              const SizedBox(height: 16),
              Expanded(
                child: _buildPaymentsSection(widget.store.owner.id, widget.store.id!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsSection(String userId, String storeId) {
    return FutureBuilder<List<Payment>>(
      future: Provider.of<StoreProvider>(context, listen: false)
          .fetchPaymentsForStoreByOwner(userId, storeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final payment = snapshot.data![index];
              return _buildPaymentCard(payment);
            },
          );
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No payments available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: payment.paymentStatus == 'Paid'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                payment.paymentStatus == 'Paid' ? Icons.check_circle : Icons.pending,
                color: payment.paymentStatus == 'Paid' ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment ID: ${payment.paymentId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${payment.amount} ${payment.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.indigo,
                    ),
                  ),
                  Text(
                    '${payment.paymentDate.toDate()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: payment.paymentStatus == 'Paid'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                payment.paymentStatus,
                style: TextStyle(
                  color: payment.paymentStatus == 'Paid' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSectionTitle('Store Location', Icons.location_on),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_store?.location.latitude ?? 0, _store?.location.longitude ?? 0),
                    zoom: 14.0,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(_store?.id ?? ''),
                      position: LatLng(_store?.location.latitude ?? 0, _store?.location.longitude ?? 0),
                      infoWindow: InfoWindow(title: _store?.name ?? ''),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.directions, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    'Get Directions',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMethodsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Delivery Options', Icons.local_shipping),
            const SizedBox(height: 16),
            if (_store?.deliveryOptions != null && _store!.deliveryOptions!.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _store!.deliveryOptions!.length,
                itemBuilder: (context, index) {
                  final method = _store!.deliveryOptions![index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getDeliveryIcon(method),
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          method,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              Center(
                child: Column(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No delivery methods available',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDeliveryIcon(String method) {
    if (method.toLowerCase().contains('pickup')) {
      return Icons.store;
    } else if (method.toLowerCase().contains('express')) {
      return Icons.delivery_dining;
    } else if (method.toLowerCase().contains('standard')) {
      return Icons.local_shipping;
    } else {
      return Icons.local_shipping;
    }
  }

  Widget _buildVideosTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('YouTube Videos', Icons.video_library),
              const SizedBox(height: 16),
              Expanded(child: _buildYouTubePlayers()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubePlayers() {
    if (_isLoadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_youtubeControllers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No YouTube videos available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isAddingVideo ? null : _showAddVideoDialog,
              icon: _isAddingVideo
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)
              )
                  : const Icon(Icons.add),
              label: Text(_isAddingVideo ? 'Adding...' : 'Add Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _youtubeControllers.length,
      itemBuilder: (context, index) {
        return _buildVideoCard(index);
      },
    );
  }

  Widget _buildVideoCard(int index) {
    final videoId = YoutubePlayer.convertUrlToId(_store?.videos?[index].url ?? '');
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with play button overlay
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
                // Play button overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 24,
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditVideoDialog(index),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteVideo(index),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _isAddingVideo ? null : _showAddVideoDialog,
      icon: _isAddingVideo
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
      )
          : const Icon(Icons.add),
      label: Text(_isAddingVideo ? 'Adding...' : 'Add Video'),
      backgroundColor: _isAddingVideo ? Colors.grey : Colors.indigo,
      elevation: 4,
    );
  }

  void _showAddVideoDialog() {
    final videoUrlController = TextEditingController();
    bool isValidUrl = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.video_library, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Add YouTube Video'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: videoUrlController,
                    onChanged: (value) {
                      setDialogState(() {
                        isValidUrl = _isValidYouTubeUrl(value);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter YouTube Video URL',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: isValidUrl
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : videoUrlController.text.isNotEmpty
                          ? const Icon(Icons.error, color: Colors.red)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.indigo, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                  if (videoUrlController.text.isNotEmpty && !isValidUrl)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Please enter a valid YouTube URL',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isValidUrl ? () => _addVideo(videoUrlController.text) : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValidUrl ? Colors.indigo : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addVideo(String videoUrl) async {
    Navigator.pop(context); // Close dialog

    setState(() {
      _isAddingVideo = true;
    });

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      await storeProvider.addVideo(widget.store.id ?? '', videoUrl);

      // Refresh store data to get updated videos
      await _fetchStoreData();

      _showSuccessSnackBar('Video added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add video: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isAddingVideo = false;
        });
      }
    }
  }

  void _showEditVideoDialog(int index) {
    final videoUrlController = TextEditingController(text: _store?.videos?[index].url);
    bool isValidUrl = _isValidYouTubeUrl(videoUrlController.text);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Edit YouTube Video'),
                ],
              ),
              content: TextField(
                controller: videoUrlController,
                onChanged: (value) {
                  setDialogState(() {
                    isValidUrl = _isValidYouTubeUrl(value);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Edit YouTube Video URL',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: isValidUrl
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.error, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isValidUrl ? () => _editVideo(index, videoUrlController.text) : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValidUrl ? Colors.blue : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editVideo(int index, String videoUrl) async {
    Navigator.pop(context); // Close dialog

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      await storeProvider.editVideo(widget.store.id ?? '', _store!.videos![index].id, videoUrl);

      // Refresh store data
      await _fetchStoreData();

      _showSuccessSnackBar('Video updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update video: ${e.toString()}');
    }
  }

  void _deleteVideo(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Delete Video'),
            ],
          ),
          content: const Text('Are you sure you want to delete this video?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _confirmDeleteVideo(index),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteVideo(int index) async {
    Navigator.pop(context); // Close dialog

    try {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      await storeProvider.deleteVideo(widget.store.id ?? '', _store!.videos![index]);

      // Refresh store data
      await _fetchStoreData();

      _showSuccessSnackBar('Video deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to delete video: ${e.toString()}');
    }
  }
}

// Custom Clipper for AppBar - not used in the new design but kept for reference
class CustomAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}