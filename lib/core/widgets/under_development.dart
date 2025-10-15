import 'package:flutter/material.dart';

class UnderDevelopment extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onPrimary;
  final String primaryLabel;

  /// Path to your asset image. Ex: 'assets/images/under_development.png'
  final String imageAsset;
  final double imageSize;

  const UnderDevelopment({
    super.key,
    this.title = 'Under Development',
    this.message = 'This feature is being built. Check back soon!',
    this.onPrimary,
    this.primaryLabel = 'Go back',
    this.imageAsset = 'assets/images/under_development.png',
    this.imageSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    height: imageSize,
                    width: imageSize,
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                      // fallback to icon if asset missing
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.construction,
                        size: imageSize,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (message != null)
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      onPrimary ?? () => Navigator.of(context).maybePop(),
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
