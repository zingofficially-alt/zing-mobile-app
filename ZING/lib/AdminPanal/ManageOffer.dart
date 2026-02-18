import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Service/OfferProvider.dart';
import '../Service/ThemeProvider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ManageOfferPage extends StatefulWidget {
  @override
  _ManageOfferPageState createState() => _ManageOfferPageState();
}

class _ManageOfferPageState extends State<ManageOfferPage> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  File? _pickedImage;
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar("Error selecting image: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearFields() {
    _textController.clear();
    setState(() {
      _pickedImage = null;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _confirmDelete(OfferProvider offerProvider, String offerId) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Offer'),
        content: Text('Are you sure you want to delete this offer?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              offerProvider.deleteOffer(offerId);
              _showSuccessSnackBar('Offer deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
            ),
            child: Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final offerProvider = Provider.of<OfferProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Offers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh offers',
            onPressed: () {
              // Refresh offers if needed
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Offers list section
                Expanded(
                  child: _buildOffersList(offerProvider),
                ),

                // Add offer button
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: Offset(0, -3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _clearFields();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) {
                                return _buildEnhancedBottomSheet(
                                    context,
                                    offerProvider,
                                    isEditing: false
                                );
                              },
                            );
                          },
                          icon: Icon(Icons.add_circle_outline),
                          label: Text(
                            'ADD NEW OFFER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(OfferProvider offerProvider) {
    if (offerProvider.offers.isEmpty) {
      return _buildEmptyState();
    }

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey<int>(offerProvider.offers.length),
        padding: EdgeInsets.all(16),
        itemCount: offerProvider.offers.length,
        itemBuilder: (context, index) {
          Offer offer = offerProvider.offers[index];
          return _buildOfferCard(offer, offerProvider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            'No offers available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the button below to create your first offer',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Offer offer, OfferProvider offerProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if (offer.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                offer.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 180,
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 60,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),

          // Content section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Offer ID: ${offer.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit button
                    OutlinedButton.icon(
                      onPressed: () {
                        _textController.text = offer.text;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) {
                            return _buildEnhancedBottomSheet(
                              context,
                              offerProvider,
                              isEditing: true,
                              offer: offer,
                            );
                          },
                        );
                      },
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: Text('EDIT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // Delete button
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(offerProvider, offer.id),
                      icon: Icon(Icons.delete_outline, size: 18),
                      label: Text('DELETE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBottomSheet(
      BuildContext context,
      OfferProvider offerProvider,
      {bool isEditing = false, Offer? offer}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // To allow the bottom sheet to resize when keyboard appears
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Offer' : 'Create New Offer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),
                  SizedBox(height: 16),

                  // Image selection
                  Text(
                    'Offer Image',
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.5),
                          width: 2,
                        ),
                        color: cs.surfaceContainerHighest,
                      ),
                      child: _getImageWidget(offer),
                    ),
                  ),
                  if (_pickedImage != null || (offer != null && offer.imageUrl.isNotEmpty))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _pickedImage = null;
                          });
                        },
                        icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                        label: Text(
                          'Remove Image',
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ),
                  SizedBox(height: 20),

                  // Text field
                  Text(
                    'Offer Text',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter offer details here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter offer text';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_textController.text.trim().isEmpty) {
                          _showErrorSnackBar('Please enter offer text');
                          return;
                        }

                        if (isEditing && offer != null) {
                          offer.text = _textController.text.trim();
                          offerProvider.updateOffer(offer);
                          _showSuccessSnackBar('Offer updated successfully');
                        } else {
                          offerProvider.addOffer(_textController.text.trim(), _pickedImage);
                          _showSuccessSnackBar('New offer added successfully');
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        isEditing ? Icons.check_circle_outline : Icons.add_circle_outline,
                      ),
                      label: Text(
                        isEditing ? 'UPDATE OFFER' : 'ADD OFFER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getImageWidget(Offer? offer) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // If there's a newly picked image, show it
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          _pickedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    // If editing and offer has an image, show the existing image
    if (offer != null && offer.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          offer.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 40,
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Otherwise show the placeholder
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: cs.onSurfaceVariant,
        ),
        SizedBox(height: 12),
        Text(
          'Tap to select an image',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Recommended: 16:9 ratio',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
