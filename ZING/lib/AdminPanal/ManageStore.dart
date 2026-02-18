import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/screen/StoreManagement/EditStoreScreen.dart';
import '../Modal/CoustomUser.dart';
import '../Service/ThemeProvider.dart';

class ManageStoresPage extends StatefulWidget {
  const ManageStoresPage({super.key});

  @override
  State<ManageStoresPage> createState() => _ManageStoresPageState();
}

class _ManageStoresPageState extends State<ManageStoresPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();

    // Add listener to search controller
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context);
    final filteredStores = storeProvider.stores.where((store) =>
    store.name.toLowerCase().contains(_searchQuery) ||
        store.category.toLowerCase().contains(_searchQuery)
    ).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Manage Stores',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search stores...',
                  prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: storeProvider.isLoading
          ? _buildLoadingState()
          : storeProvider.stores.isEmpty
          ? _buildEmptyState()
          : _buildStoresList(filteredStores, storeProvider),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: cs.primary,
            size: 60.0,
          ),
          SizedBox(height: 20),
          Text(
            'Loading stores...',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 100,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(height: 20),
            Text(
              'No Stores Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Add your first store by tapping the button below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _addStore(context),
              icon: Icon(Icons.add_circle_outline),
              label: Text(
                'Add New Store',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresList(List<Store> stores, StoreProvider storeProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        itemCount: stores.length,
        padding: EdgeInsets.symmetric(vertical: 16),
        itemBuilder: (context, index) {
          final store = stores[index];
          return _buildStoreCard(store, storeProvider);
        },
      ),
    );
  }

  Widget _buildStoreCard(Store store, StoreProvider storeProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: () => _editStore(store, context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store image or placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: store.imageUrl.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        store.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.broken_image,
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    )
                        : Center(
                      child: Icon(
                        Icons.store,
                        size: 40,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Store details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            store.category,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Owner: ${store.owner.name}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editStore(store, context),
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text('EDIT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteStore(store.id!, storeProvider, context),
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('DELETE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _addStore(context),
      icon: Icon(Icons.add),
      label: Text('ADD STORE'),
      elevation: 4,
    );
  }

  // Function to add a new store - preserved original functionality
  void _addStore(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AddEditStoreDialog(
        refreshStoreData: () {},
      ),
    );
  }

  // Function to edit a store - preserved original functionality
  void _editStore(Store store, BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AddEditStoreDialog(
        store: store,
        refreshStoreData: () {},
      ),
    );
  }

  // Function to delete a store - preserved original functionality
  void _deleteStore(String storeId, StoreProvider storeProvider, BuildContext context) async {
    final confirm = await _showDeleteConfirmation(context);
    if (confirm) {
      await storeProvider.deleteStore(storeId, Provider.of(context, listen: false));
      _showSuccessSnackBar(context, 'Store deleted successfully');
    }
  }

  // Enhanced delete confirmation dialog
  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            SizedBox(width: 10),
            Text('Delete Store'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this store? This action cannot be undone and all related data will be permanently removed.',
          style: TextStyle(fontSize: 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.delete_outline),
            label: Text('DELETE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  // Show a success snackbar with better styling
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
