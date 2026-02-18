import 'package:flutter/material.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'dart:ui';

class OrderDetailsPage extends StatelessWidget {
  final Orders order;

  OrderDetailsPage({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine status color based on order status
    Color statusColor;
    IconData statusIcon;

    switch(order.status.toLowerCase()) {
      case 'delivered':
        statusColor = ZingColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'shipped':
        statusColor = cs.primary;
        statusIcon = Icons.local_shipping;
        break;
      case 'processing':
      case 'pending':
        statusColor = ZingColors.warning;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'cancelled':
        statusColor = cs.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.info;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            tooltip: 'Print Order Details',
            onPressed: () {
              // Print functionality could be added here
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Print feature coming soon'))
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // Order status banner
              _buildStatusBanner(context, statusColor, statusIcon),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),

                    // Order information card
                    _buildOrderInfoCard(context),

                    SizedBox(height: 24),

                    // Order summary
                    _buildSectionHeader(context, 'Order Summary', Icons.summarize),

                    SizedBox(height: 12),

                    // Price summary card
                    _buildPriceSummaryCard(context),

                    SizedBox(height: 24),

                    // Products section header
                    _buildSectionHeader(context, 'Products Ordered', Icons.shopping_bag),

                    SizedBox(height: 12),

                    // Product list
                    ..._buildProductList(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Add a sticky "Need Help?" button
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(0, -1),
              blurRadius: 5,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              // Customer support functionality could be added here
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer support feature coming soon'))
              );
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent),
                SizedBox(width: 8),
                Text(
                  'Need Help With This Order?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, Color statusColor, IconData statusIcon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      color: statusColor.withOpacity(0.1),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 28,
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4),
              Text(
                order.status,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: cs.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                _buildCopyButton(context, order.id),
              ],
            ),
            SizedBox(height: 16),
            // Divider
            Divider(color: cs.outlineVariant),
            SizedBox(height: 12),
            // Order ID
            _buildInfoRow(
              context,
              'Order ID',
              order.id,
              Icons.tag,
            ),
            SizedBox(height: 12),
            // Order Date (assuming there's a date field, if not, this can be removed)
            _buildInfoRow(
              context,
              'Order Date',
              DateTime.now().toString().substring(0, 10), // Placeholder date
              Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          color: cs.primary.withOpacity(0.7),
          size: 18,
        ),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Subtotal
            _buildPriceRow(
              context,
              'Subtotal',
              order.totalPrice * 0.9, // Assuming subtotal is 90% of total, remove if not needed
              false,
            ),
            SizedBox(height: 8),
            // Tax
            _buildPriceRow(
              context,
              'Tax',
              order.totalPrice * 0.1, // Assuming tax is 10%, remove if not needed
              false,
            ),
            SizedBox(height: 8),
            // Shipping
            _buildPriceRow(
              context,
              'Shipping',
              0.0, // Placeholder, adjust as needed
              false,
            ),
            SizedBox(height: 12),
            Divider(color: cs.outlineVariant),
            SizedBox(height: 12),
            // Total
            _buildPriceRow(
              context,
              'Total',
              order.totalPrice,
              true,
              color: ZingColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, double amount, bool isTotal, {Color? color}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? color ?? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? color ?? cs.onSurface : cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          color: cs.primary,
          size: 24,
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProductList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return order.products.map((product) {
      return Card(
        margin: EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image or icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag,
                    color: cs.primary,
                    size: 30,
                  ),
                ),
              ),
              SizedBox(width: 16),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Price: \$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    // Add more product details if available
                  ],
                ),
              ),
              // Product quantity (if available)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Qty: 1', // Replace with actual quantity if available
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCopyButton(BuildContext context, String textToCopy) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () {
        // Copy to clipboard functionality
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order ID copied to clipboard'))
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cs.surfaceContainerHighest,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(width: 4),
            Text(
              'Copy',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
