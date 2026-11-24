import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/StorageService.dart';
import 'package:path/path.dart' as path;
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart'; // New package for better image upload UI

class EditProductScreen extends StatefulWidget {
  final Product? product;
  final String storeId;

  const EditProductScreen({super.key, this.product, required this.storeId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>(); // Add form key for validation
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late TextEditingController ratingController;
  late TextEditingController quantityController;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isProcessing = false; // New state for form submission
  String? _uploadedImageUrl;
  bool _imageError = false; // Track image validation
  bool _isAvailable = true; // Owner can hide a product without deleting it

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product?.name ?? '');
    priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    descriptionController = TextEditingController(text: widget.product?.description ?? '');
    ratingController = TextEditingController(text: widget.product?.rating?.toString() ?? '');
    quantityController = TextEditingController(text: widget.product?.quantity.toString() ?? '0');
    _uploadedImageUrl = widget.product?.imageUrl;
    _isAvailable = widget.product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    ratingController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  // Method to pick image with enhanced UX
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image for better upload performance
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _imageError = false; // Clear any image error
        });
      }
    } on PlatformException catch (e) {
      // Handle specific platform exceptions (e.g., permission denied)
      if (e.code == 'photo_access_denied') {
        _showErrorSnackBar('Photo library access was denied. Please enable photo permissions in Settings.');
      } else {
        _showErrorSnackBar('Failed to access gallery: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select image. Please try again.');
    }
  }

  // Method for camera image capture
  Future<void> _captureImageFromCamera() async {
    try {
      final XFile? capturedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (capturedFile != null) {
        setState(() {
          _selectedImage = File(capturedFile.path);
          _imageError = false;
        });
      }
    } on PlatformException catch (e) {
      // Handle specific platform exceptions (e.g., permission denied)
      if (e.code == 'camera_access_denied') {
        _showErrorSnackBar('Camera access was denied. Please enable camera permissions in Settings.');
      } else if (e.code == 'photo_access_denied') {
        _showErrorSnackBar('Photo library access was denied. Please enable photo permissions in Settings.');
      } else {
        _showErrorSnackBar('Failed to access camera: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture image. Please try again.');
    }
  }

  // Show image source picker dialog
  Future<void> _showImageSourceDialog() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final BuildContext currentContext = context; // Store the current context
    await showModalBottomSheet(
      context: currentContext, // Use the stored context
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _captureImageFromCamera();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cs.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced upload method with better error handling
  Future<String> _uploadImage(File image) async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Create a unique filename with timestamp
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileExtension = path.extension(image.path);
      String fileName = 'product_$timestamp$fileExtension';

      final String downloadUrl =
          await StorageService.uploadFile(Buckets.product, 'products/$fileName', image);

      setState(() {
        _isUploading = false;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar('Failed to upload image: ${e.toString()}');
      rethrow;
    }
  }

  void _showErrorSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    final BuildContext currentContext = context; // Store the current context
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onPrimary),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    final BuildContext currentContext = context; // Store the current context
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: cs.onPrimary),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = widget.product != null;
    final actionText = isEditing ? 'Update' : 'Create';

    return SafeArea(
      child: Scaffold(
        backgroundColor: cs.surfaceContainerHighest,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Product' : 'Add New Product',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: cs.surface,
          foregroundColor: cs.primary,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _showDeleteConfirmation(context);
                },
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _isProcessing
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitPulse(color: cs.primary, size: 50),
                  const SizedBox(height: 20),
                  Text(
                    isEditing ? 'Updating Product...' : 'Creating Product...',
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section
                    _buildImageSection(),
                    const SizedBox(height: 24),

                    // Product information card
                    _buildInfoCard(
                      title: "Basic Details",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(
                            controller: nameController,
                            label: 'Product Name',
                            icon: Icons.inventory_2_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Product name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: priceController,
                                  label: 'Price',
                                  icon: Icons.attach_money,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price <= 0) {
                                      return 'Please enter a valid price';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: ratingController,
                                  label: 'Rating (0-5)',
                                  icon: Icons.star_outline,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                                  ],
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final rating = double.tryParse(value);
                                      if (rating == null || rating < 0 || rating > 5) {
                                        return 'Rating must be between 0-5';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: quantityController,
                            label: 'Quantity',
                            icon: Icons.inventory_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Quantity is required';
                              }
                              final quantity = int.tryParse(value);
                              if (quantity == null || quantity < 0) {
                                return 'Please enter a valid quantity';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Available for sale'),
                            subtitle: Text(_isAvailable
                                ? 'Customers can buy this product while stock lasts'
                                : 'Hidden from sale (shown as unavailable)'),
                            value: _isAvailable,
                            onChanged: (value) => setState(() => _isAvailable = value),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Description card
                    _buildInfoCard(
                      title: "Description",
                      child: _buildFormField(
                        controller: descriptionController,
                        label: 'Product Description',
                        icon: Icons.description_outlined,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Description should be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Submit button
                    ElevatedButton(
                      onPressed: _isUploading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isUploading
                            ? 'Uploading Image...'
                            : '$actionText Product',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    // Store the current context to avoid conflicts
    final BuildContext currentContext = context;

    // Get the providers that we'll need
    final storeProvider = Provider.of<StoreProvider>(currentContext, listen: false);
    final userProvider = Provider.of<CustomUserProvider>(currentContext, listen: false);

    // Validate image selection
    final hasImage = _selectedImage != null || (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty);
    setState(() {
      _imageError = !hasImage;
    });

    // Validate form
    if (!_formKey.currentState!.validate() || !hasImage) {
      if (!hasImage) {
        _showErrorSnackBar('Please select a product image');
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Handle image upload if a new image is selected
      if (_selectedImage != null) {
        _uploadedImageUrl = await _uploadImage(_selectedImage!);
      }

      final productName = nameController.text.trim();
      final price = double.tryParse(priceController.text.trim()) ?? 0.0;
      final description = descriptionController.text.trim();
      final rating = double.tryParse(ratingController.text.trim());
      final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

      // Set default placeholder URL if no image is uploaded (shouldn't happen due to validation)
      String imageUrlToUse = _uploadedImageUrl?.isNotEmpty == true
          ? _uploadedImageUrl!
          : '';

      if (widget.product != null) {
        // Edit existing product
        await storeProvider.editProduct(
          widget.storeId,
          Product(
            id: widget.product!.id,
            name: productName,
            price: price,
            description: description,
            rating: rating,
            imageUrl: imageUrlToUse,
            isAvailable: _isAvailable,
            discount: widget.product!.discount, // keep existing discount
            quantity: quantity,
          ),
          userProvider,
        );

        _showSuccessSnackBar('Product updated successfully');
      } else {
        // Add new product
        if (!currentContext.mounted) return;
        await storeProvider.addProduct(
          widget.storeId,
          Product(
            id: '',
            name: productName,
            price: price,
            description: description,
            rating: rating,
            imageUrl: imageUrlToUse,
            isAvailable: _isAvailable,
            quantity: quantity,
          ),
          userProvider,
          currentContext,
        );

        _showSuccessSnackBar('Product added successfully');
      }

      // Short delay to show the success message before closing
      await Future.delayed(const Duration(milliseconds: 800));
      if (!currentContext.mounted) return;
      Navigator.of(currentContext).pop(); // Return to the previous screen
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    }
  }

  Widget _buildImageSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Image',
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: _selectedImage != null
                      ? _buildImagePreview(File(_selectedImage!.path))
                      : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                      ? _buildNetworkImagePreview(_uploadedImageUrl!)
                      : _buildImagePlaceholder(),
                ),
                const SizedBox(height: 8),
                if (_imageError)
                  Text(
                    'Please select an image',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: cs.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(File imageFile) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildImageActionButton(
            icon: Icons.refresh,
            onTap: _showImageSourceDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImagePreview(String imageUrl) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: cs.surfaceContainerHighest,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                _buildImagePlaceholder(isError: true),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildImageActionButton(
            icon: Icons.refresh,
            onTap: _showImageSourceDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder({bool isError = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DottedBorder(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _imageError ? cs.error.withValues(alpha: 0.05) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.add_a_photo,
              size: 36,
              color: _imageError ? cs.error.withValues(alpha: 0.6) : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              isError ? 'Failed to load image' : 'Tap to add image',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: _imageError ? cs.error : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: ZingShadows.soft,
        ),
        child: Icon(
          icon,
          size: 20,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: ZingShadows.soft,
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: theme.textTheme.bodyMedium!.copyWith(
        color: cs.onSurface,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.bodyMedium!.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: cs.primary)
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 16 : 0,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Get the providers inside the method
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ZingColors.warning),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.product?.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              setState(() {
                _isProcessing = true;
              });

              try {
                await storeProvider.deleteProduct(
                  widget.storeId,
                  widget.product!.id,
                  userProvider,
                );

                // Store context before async operation
                final BuildContext currentContext = this.context;
                if (!currentContext.mounted) return;
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );

                if (!currentContext.mounted) return;
                Navigator.pop(currentContext); // Return to product list
              } catch (e) {
                setState(() {
                  _isProcessing = false;
                });
                _showErrorSnackBar('Failed to delete product: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
