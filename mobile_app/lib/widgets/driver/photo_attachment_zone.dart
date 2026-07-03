import 'dart:io';
import 'package:flutter/material.dart';

/// A dashed-border drop zone for attaching photos with a preview strip.
///
/// Displays a professional upload area with a dashed border when no images
/// are selected, and a horizontal scrollable thumbnail strip with remove
/// buttons when images are present.
class PhotoAttachmentZone extends StatelessWidget {
  final List<File> images;
  final int maxImages;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const PhotoAttachmentZone({
    super.key,
    required this.images,
    this.maxImages = 3,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail strip
        if (images.isNotEmpty) ...[
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _ImageThumbnail(
                  image: images[index],
                  onRemove: () => onRemovePhoto(index),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Upload zone / Add more button
        if (images.length < maxImages)
          GestureDetector(
            onTap: onAddPhoto,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    images.isEmpty
                        ? 'Tap to attach photos'
                        : 'Add more photos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${images.length}/$maxImages attached',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A single image thumbnail with a remove button overlay.
class _ImageThumbnail extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;

  const _ImageThumbnail({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            image,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
