import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class LocalPackingPhotoThumbnail extends StatelessWidget {
  final PlatformFile file;

  const LocalPackingPhotoThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    if (path == null || path.isEmpty) {
      return const _PackingPhotoThumbnailPlaceholder();
    }

    return _PackingPhotoThumbnail(
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PackingPhotoThumbnailPlaceholder(),
      ),
    );
  }
}

class RemotePackingPhotoThumbnail extends StatelessWidget {
  final String? imageUrl;

  const RemotePackingPhotoThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _PackingPhotoThumbnailPlaceholder();
    }

    return _PackingPhotoThumbnail(
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PackingPhotoThumbnailPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

class _PackingPhotoThumbnail extends StatelessWidget {
  final Widget child;

  const _PackingPhotoThumbnail({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(height: 44, width: 44, child: child),
      );
}

class _PackingPhotoThumbnailPlaceholder extends StatelessWidget {
  const _PackingPhotoThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 20),
      );
}
