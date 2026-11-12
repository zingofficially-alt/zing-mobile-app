import 'package:flutter/material.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserDetailsPage extends StatelessWidget {
  final CustomUser user;

  const UserDetailsPage({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine role-specific color
    Color roleColor;
    switch (user.role.toLowerCase()) {
      case 'admin':
        roleColor = cs.primary;
        break;
      case 'owner':
        roleColor = cs.secondary;
        break;
      default:
        roleColor = ZingColors.success;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Flexible app bar with user avatar
          _buildSliverAppBar(context, roleColor),

          // Main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),

                  // Personal Information Section
                  _buildSectionHeader(context, 'Personal Information', Icons.person),
                  SizedBox(height: 12),
                  _buildPersonalInfoCard(context),
                  SizedBox(height: 24),

                  // Role Information Section
                  _buildSectionHeader(context, 'Role Information', Icons.badge),
                  SizedBox(height: 12),
                  _buildRoleInfoCard(context, roleColor),
                  SizedBox(height: 24),

                  // Store Sections (only for Owners)
                  if (user.role == 'Owner' && user.store != null) ...[
                    _buildSectionHeader(context, 'Store Location', Icons.location_on),
                    SizedBox(height: 12),
                    _buildStoreLocationCard(context),
                    SizedBox(height: 24),

                    _buildSectionHeader(context, 'Store Details', Icons.store),
                    SizedBox(height: 12),
                    _buildStoreDetailsCard(context, roleColor),
                    SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.edit),
        onPressed: () {
          // Action to edit user details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Edit functionality coming soon')),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Color roleColor) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: cs.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: cs.onPrimary,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.3),
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary,
                    cs.primary.withOpacity(0.8),
                  ],
                ),
              ),
            ),

            // Pattern overlay for visual interest
            Opacity(
              opacity: 0.1,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),

            // User information overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: Hero(
                  tag: 'user-avatar-${user.id}',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: cs.onPrimary,
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: CircleAvatar(
                        radius: 47,
                        backgroundColor: roleColor,
                        backgroundImage: user.profileImageUrl.isNotEmpty
                            ? NetworkImage(user.profileImageUrl)
                            : null,
                        child: user.profileImageUrl.isEmpty
                            ? Text(
                          user.name[0].toUpperCase(),
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Role badge
            Positioned(
              right: 16,
              bottom: 80,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: roleColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRoleIcon(user.role),
                      color: cs.onPrimary,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      user.role,
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () {
            // Show more options
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 24),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              context: context,
              icon: Icons.email,
              label: 'Email',
              value: user.email,
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.phone,
              label: 'Phone',
              value: user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not provided',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.location_city,
              label: 'Address',
              value: user.address.isNotEmpty ? user.address : 'No Address Provided',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleInfoCard(BuildContext context, Color roleColor) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              context: context,
              icon: _getRoleIcon(user.role),
              label: 'Role',
              value: user.role,
              iconColor: roleColor,
              valueStyle: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (user.role == 'Owner' && user.store != null) ...[
              SizedBox(height: 16),
              _buildInfoRow(
                context: context,
                icon: Icons.tag,
                label: 'Store ID',
                value: user.store!.id!,
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                context: context,
                icon: Icons.store,
                label: 'Store Name',
                value: user.store!.name,
                valueStyle: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoreLocationCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 250,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(user.store!.location.latitude, user.store!.location.longitude),
                zoom: 14,
              ),
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: {
                Marker(
                  markerId: MarkerId('storeLocation'),
                  position: LatLng(user.store!.location.latitude, user.store!.location.longitude),
                  infoWindow: InfoWindow(
                    title: user.store!.name,
                    snippet: 'Store Location',
                  ),
                ),
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.pin_drop, color: cs.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Store is located at coordinates: ${user.store!.location.latitude.toStringAsFixed(6)}, ${user.store!.location.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.directions, size: 16),
                  label: Text('Directions'),
                  onPressed: () {
                    // Open directions in maps
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Directions functionality coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetailsCard(BuildContext context, Color roleColor) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Calculate average rating
    double avgRating = _calculateAverageRating(user.store!.ratings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store description
            _buildInfoRow(
              context: context,
              icon: Icons.description,
              label: 'Description',
              value: user.store!.description,
            ),
            SizedBox(height: 16),

            // Store category
            _buildInfoRow(
              context: context,
              icon: Icons.category,
              label: 'Category',
              value: user.store!.category,
            ),
            SizedBox(height: 16),

            // Store rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.star, color: ZingColors.warning, size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        // Star rating visualization
                        ...List.generate(5, (index) {
                          return Icon(
                            index < avgRating.floor()
                                ? Icons.star
                                : (index == avgRating.floor() && avgRating % 1 > 0)
                                ? Icons.star_half
                                : Icons.star_border,
                            color: ZingColors.warning,
                            size: 18,
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          '${avgRating.toStringAsFixed(1)} (${user.store!.ratings.length} reviews)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: cs.outlineVariant),
            ),

            // Delivery options
            Text(
              'Delivery Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            SizedBox(height: 12),
            _buildDeliveryOptions(context),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: cs.outlineVariant),
            ),

            // Products
            Text(
              'Products Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            SizedBox(height: 12),
            _buildProductList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    TextStyle? valueStyle,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? cs.primary, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ?? TextStyle(
                  fontSize: 16,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (user.store!.deliveryOptions == null || user.store!.deliveryOptions!.isEmpty) {
      return Text(
        'No delivery options available.',
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: user.store!.deliveryOptions!.map((method) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cs.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getDeliveryIcon(method),
                size: 16,
                color: cs.primary,
              ),
              SizedBox(width: 6),
              Text(
                method,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (user.store!.products.isEmpty) {
      return Text(
        'No products available.',
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return ListView.separated(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: user.store!.products.length,
      separatorBuilder: (context, index) => Divider(color: cs.outlineVariant),
      itemBuilder: (context, index) {
        final product = user.store!.products[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.shopping_bag,
                color: cs.primary,
                size: 20,
              ),
            ),
          ),
          title: Text(
            product.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ZingColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: ZingColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper function to calculate the average rating
  double _calculateAverageRating(List<Rating> ratings) {
    if (ratings.isEmpty) return 0.0;
    double totalScore = ratings.fold(0.0, (sum, rating) => sum + rating.score);
    return totalScore / ratings.length;
  }

  // Get appropriate icon for role
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'owner':
        return Icons.store;
      default:
        return Icons.person;
    }
  }

  // Get appropriate icon for delivery method
  IconData _getDeliveryIcon(String method) {
    if (method.toLowerCase().contains('pickup')) {
      return Icons.store;
    } else if (method.toLowerCase().contains('express')) {
      return Icons.local_shipping;
    } else if (method.toLowerCase().contains('same day')) {
      return Icons.delivery_dining;
    } else {
      return Icons.local_shipping;
    }
  }
}
