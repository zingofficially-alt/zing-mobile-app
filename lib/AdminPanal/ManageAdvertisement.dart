import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../Service/AdvertisementProvider.dart';
import '../Service/ThemeProvider.dart';

class ManageAdvertisementsPage extends StatefulWidget {
  @override
  _ManageAdvertisementsPageState createState() => _ManageAdvertisementsPageState();
}

class _ManageAdvertisementsPageState extends State<ManageAdvertisementsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _submitAdvertisement(AdvertisementProvider provider) async {
    if (_formKey.currentState!.validate() && _selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        await provider.addAdvertisement(_descriptionController.text, _selectedImage!);

        // Reset form after successful upload
        _descriptionController.clear();
        setState(() {
          _selectedImage = null;
          _isUploading = false;
        });

        _showSuccessMessage('Advertisement added successfully!');
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        _showErrorMessage('Failed to add advertisement: ${e.toString()}');
      }
    } else if (_selectedImage == null) {
      _showErrorMessage('Please select an image');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmDeleteAdvertisement(AdvertisementProvider provider, String imageUrl) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Advertisement'),
        content: Text('Are you sure you want to delete this advertisement?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              'Delete',
              style: TextStyle(color: cs.error),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteAdvertisement(imageUrl);
              _showSuccessMessage('Advertisement deleted!');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final advertisementProvider = Provider.of<AdvertisementProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Advertisements',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog or information about advertisements
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
              cs.primary.withOpacity(0.05),
              cs.surface,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _buildAddAdvertisementForm(advertisementProvider),
                    ),
                    SliverToBoxAdapter(
                      child: _buildAdvertisementListHeader(),
                    ),
                  ];
                },
                body: _buildAdvertisementList(advertisementProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAdvertisementForm(AdvertisementProvider provider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: cs.primary,
                  size: 28,
                ),
                SizedBox(width: 16),
                Text(
                  'Create New Advertisement',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildImageSelector(),
            SizedBox(height: 24),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Advertisement Description',
                hintText: 'Enter a compelling description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            _buildSubmitButton(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advertisement Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedImage != null
                    ? cs.primary
                    : cs.outlineVariant,
                width: _selectedImage != null ? 2 : 1,
              ),
            ),
            child: _selectedImage != null
                ? _buildSelectedImagePreview()
                : _buildImagePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImagePreview() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: cs.error),
              onPressed: _removeSelectedImage,
              iconSize: 20,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: cs.onSurfaceVariant,
        ),
        SizedBox(height: 8),
        Text(
          'Tap to select an image',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Recommended size: 1200 × 628 pixels',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AdvertisementProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : () => _submitAdvertisement(provider),
        icon: _isUploading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Icon(Icons.add_circle_outline),
        label: Text(
          _isUploading ? 'UPLOADING...' : 'ADD ADVERTISEMENT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvertisementListHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.list_alt,
            color: cs.primary,
          ),
          SizedBox(width: 8),
          Text(
            'Current Advertisements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvertisementList(AdvertisementProvider provider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (provider.advertisements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(height: 16),
            Text(
              'No advertisements available',
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first advertisement above',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: provider.advertisements.length,
      itemBuilder: (context, index) {
        final ad = provider.advertisements[index];
        return _buildAdvertisementCard(ad, provider);
      },
    );
  }

  Widget _buildAdvertisementCard(Advertisement ad, AdvertisementProvider provider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              ad.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 160,
                  width: double.infinity,
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  width: double.infinity,
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: cs.onSurfaceVariant,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ad ID: ${ad.imageUrl.hashCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  onPressed: () => _confirmDeleteAdvertisement(provider, ad.imageUrl),
                  tooltip: 'Delete advertisement',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
