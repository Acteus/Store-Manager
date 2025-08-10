import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../error/failures.dart';
import 'package:dartz/dartz.dart' hide State;

class ImageService {
  static const int maxImageSize = 1024; // Maximum width/height in pixels
  static const int imageQuality = 85; // JPEG quality (0-100)
  static const double maxFileSizeMB = 5.0;

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Pick image from gallery
  Future<Result<File?>> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxImageSize.toDouble(),
        maxHeight: maxImageSize.toDouble(),
        imageQuality: imageQuality,
      );

      if (image == null) {
        return const Right(null); // User cancelled
      }

      final file = File(image.path);

      // Validate file size
      final sizeInBytes = await file.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB > maxFileSizeMB) {
        return Left(ValidationFailure(
            'Image file is too large. Maximum size is ${maxFileSizeMB}MB'));
      }

      return Right(file);
    } catch (e) {
      return Left(UnknownFailure('Failed to pick image: ${e.toString()}'));
    }
  }

  // Take photo with camera
  Future<Result<File?>> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxImageSize.toDouble(),
        maxHeight: maxImageSize.toDouble(),
        imageQuality: imageQuality,
      );

      if (image == null) {
        return const Right(null); // User cancelled
      }

      final file = File(image.path);

      // Validate file size
      final sizeInBytes = await file.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB > maxFileSizeMB) {
        return Left(ValidationFailure(
            'Image file is too large. Maximum size is ${maxFileSizeMB}MB'));
      }

      return Right(file);
    } catch (e) {
      return Left(UnknownFailure('Failed to take photo: ${e.toString()}'));
    }
  }

  // Process and save image
  Future<Result<String>> processAndSaveImage(File imageFile) async {
    try {
      // Read image file
      final bytes = await imageFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        return const Left(ValidationFailure('Invalid image format'));
      }

      // Resize image if needed
      if (image.width > maxImageSize || image.height > maxImageSize) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? maxImageSize : null,
          height: image.height > image.width ? maxImageSize : null,
        );
      }

      // Convert to JPEG with quality compression
      final compressedBytes = img.encodeJpg(image, quality: imageQuality);

      // Generate unique filename
      final filename = '${_uuid.v4()}.jpg';

      // Save to app directory
      final savedFile =
          await _saveImageToAppDirectory(compressedBytes, filename);

      return Right(savedFile.path);
    } catch (e) {
      return Left(UnknownFailure('Failed to process image: ${e.toString()}'));
    }
  }

  // Save image bytes to app directory
  Future<File> _saveImageToAppDirectory(
      Uint8List bytes, String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'product_images'));

    // Create images directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final file = File(path.join(imagesDir.path, filename));
    await file.writeAsBytes(bytes);

    return file;
  }

  // Delete image file
  Future<Result<void>> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to delete image: ${e.toString()}'));
    }
  }

  // Get image file from path
  Future<Result<File?>> getImageFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return Right(file);
      } else {
        return const Right(null);
      }
    } catch (e) {
      return Left(UnknownFailure('Failed to get image file: ${e.toString()}'));
    }
  }

  // Clear all cached images
  Future<Result<void>> clearImageCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'product_images'));

      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }

      return const Right(null);
    } catch (e) {
      return Left(
          UnknownFailure('Failed to clear image cache: ${e.toString()}'));
    }
  }

  // Get total cache size
  Future<double> getCacheSizeMB() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'product_images'));

      if (!await imagesDir.exists()) {
        return 0.0;
      }

      int totalSize = 0;
      await for (final file in imagesDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
}

// Cached image widget for product images
class ProductImageWidget extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showDefaultIcon;

  const ProductImageWidget({
    Key? key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.showDefaultIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildDefaultWidget();
    }

    // Check if it's a local file path
    if (imagePath!.startsWith('/') || imagePath!.startsWith('file://')) {
      return _buildLocalImage();
    }

    // Assume it's a network URL
    return _buildNetworkImage();
  }

  Widget _buildLocalImage() {
    final file = File(imagePath!);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }

        if (snapshot.data == true) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          );
        } else {
          return _buildDefaultWidget();
        }
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imagePath!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 512,
      maxHeightDiskCache: 512,
    );
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return errorWidget ?? _buildDefaultWidget();
  }

  Widget _buildDefaultWidget() {
    if (!showDefaultIcon) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image_outlined,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.5 : height! * 0.5)
            : 48,
        color: Colors.grey.shade400,
      ),
    );
  }
}

// Image picker dialog
class ImagePickerDialog extends StatelessWidget {
  final Function(File) onImageSelected;

  const ImagePickerDialog({
    Key? key,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Image'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () => _pickFromGallery(context),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () => _takePhoto(context),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _pickFromGallery(BuildContext context) async {
    Navigator.of(context).pop();

    final imageService = ImageService();
    final result = await imageService.pickImageFromGallery();

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (file) {
        if (file != null) {
          onImageSelected(file);
        }
      },
    );
  }

  void _takePhoto(BuildContext context) async {
    Navigator.of(context).pop();

    final imageService = ImageService();
    final result = await imageService.takePhoto();

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (file) {
        if (file != null) {
          onImageSelected(file);
        }
      },
    );
  }
}

// Image crop widget (simplified)
class ImageCropWidget extends StatefulWidget {
  final File imageFile;
  final Function(File) onCropped;

  const ImageCropWidget({
    Key? key,
    required this.imageFile,
    required this.onCropped,
  }) : super(key: key);

  @override
  State<ImageCropWidget> createState() => _ImageCropWidgetState();
}

class _ImageCropWidgetState extends State<ImageCropWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          TextButton(
            onPressed: _cropImage,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Center(
        child: Image.file(widget.imageFile),
      ),
    );
  }

  void _cropImage() {
    // For now, just return the original image
    // In a real implementation, you'd use a cropping library
    widget.onCropped(widget.imageFile);
    Navigator.of(context).pop();
  }
}
