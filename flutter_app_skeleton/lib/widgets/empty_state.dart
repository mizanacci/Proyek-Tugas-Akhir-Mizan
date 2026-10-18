import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String? message;

  const EmptyState({
    super.key,
    required this.imageAsset,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  cacheWidth: 900,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
