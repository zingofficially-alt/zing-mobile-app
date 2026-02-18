import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Modal/CoustomUser.dart';
import '../Service/CoustomUserProvider.dart';

class FilterOrdersScreen extends StatefulWidget {
  final String storeId;
  final String selectedFilter;
  final String? selectedUser;

  FilterOrdersScreen({
    required this.storeId,
    required this.selectedFilter,
    this.selectedUser,
  });

  @override
  _FilterOrdersScreenState createState() => _FilterOrdersScreenState();
}

class _FilterOrdersScreenState extends State<FilterOrdersScreen> with SingleTickerProviderStateMixin {
  String _status = 'All';
  String? _selectedUser;

  // Animation controller for interactive elements
  late AnimationController _animationController;
  late Animation<double> _applyButtonAnimation;

  // Track if filters have changed from initial values
  bool _filtersChanged = false;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedFilter;
    _selectedUser = widget.selectedUser;

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _applyButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Check if filters have changed from initial values
  void _checkFiltersChanged() {
    setState(() {
      _filtersChanged = _status != widget.selectedFilter || _selectedUser != widget.selectedUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<CustomUserProvider>(context);

    // Theme colors
    final primaryColor = Theme.of(context).primaryColor;
    final primaryColorLight = primaryColor.withOpacity(0.1);
    final secondaryColor = Colors.teal;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          secondary: secondaryColor,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _filtersChanged ? secondaryColor : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Filter Orders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            if (_filtersChanged)
              IconButton(
                icon: Icon(Icons.restore),
                tooltip: 'Reset filters',
                onPressed: () {
                  setState(() {
                    _status = widget.selectedFilter;
                    _selectedUser = widget.selectedUser;
                    _checkFiltersChanged();
                  });
                },
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  SizedBox(height: 24),

                  // Status filter
                  _buildFilterSection(
                    title: 'Order Status',
                    icon: Icons.local_shipping,
                    child: _buildStatusFilter(primaryColor, primaryColorLight),
                  ),
                  SizedBox(height: 16),

                  // User filter
                  _buildFilterSection(
                    title: 'Customer',
                    icon: Icons.person,
                    child: _buildUserFilter(userProvider, primaryColor, primaryColorLight),
                  ),

                  // Spacer to push button to bottom
                  Spacer(),

                  // Summary of selected filters
                  if (_filtersChanged)
                    _buildFilterSummary(),

                  // Apply button
                  _buildApplyButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Customize Your View',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter(Color primaryColor, Color primaryColorLight) {
    final statuses = ['All', 'Pending', 'Shipped', 'Delivered'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final isSelected = _status == status;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          child: InkWell(
            onTap: () {
              setState(() {
                _status = status;
                _checkFiltersChanged();
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : primaryColorLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 18,
                    color: isSelected ? Colors.white : primaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserFilter(CustomUserProvider userProvider, Color primaryColor, Color primaryColorLight) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedUser,
          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
          hint: Text('Select a customer'),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All Customers'),
            ),
            ...userProvider.users.map((user) {
              return DropdownMenuItem<String>(
                value: user.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: primaryColorLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(user.name),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (newValue) {
            setState(() {
              _selectedUser = newValue;
              _checkFiltersChanged();
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterSummary() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _getStatusIcon(_status),
                size: 16,
                color: Colors.teal,
              ),
              SizedBox(width: 8),
              Text('Status: $_status'),
            ],
          ),
          if (_selectedUser != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.teal,
                  ),
                  SizedBox(width: 8),
                  Text('Customer: ${_getUserName(_selectedUser)}'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _filtersChanged ? _applyButtonAnimation.value : 1.0,
          child: ElevatedButton(
            onPressed: () {
              if (_filtersChanged) {
                _animationController.forward().then((_) {
                  _animationController.reverse();

                  // Return filter values
                  Navigator.pop(context, {
                    'status': _status,
                    'user': _selectedUser,
                  });
                });
              } else {
                // Just go back if no changes
                Navigator.pop(context);
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_filtersChanged ? Icons.check_circle : Icons.filter_list),
                SizedBox(width: 12),
                Text(
                  _filtersChanged ? 'APPLY FILTERS' : 'CLOSE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get icon for status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.filter_list;
    }
  }

  // Helper method to get user name from ID
  String _getUserName(String? userId) {
    if (userId == null) return 'All Customers';

    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    final user = userProvider.users.firstWhere(
          (user) => user.id == userId,
      orElse: () => CustomUser(id: '', name: 'Unknown', email: '', phoneNumber: ''),
    );

    return user.name;
  }
}