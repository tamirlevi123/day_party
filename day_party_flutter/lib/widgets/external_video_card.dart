import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/node.dart';

class ExternalVideoCard extends StatelessWidget {
  final VideoAttachment attachment;

  const ExternalVideoCard({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasThumbnail = attachment.thumbnailUrl != null && attachment.thumbnailUrl!.isNotEmpty;
    final providerName = attachment.provider?.toUpperCase() ?? 'VIDEO';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasThumbnail)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    attachment.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                  ),
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_outline, size: 48, color: Colors.black54),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(providerName),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    TextButton.icon(
                      onPressed: () => _openUrl(context, attachment.url ?? attachment.embedHtml),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('פתח'),
                    ),
                  ],
                ),
                if (attachment.title != null && attachment.title!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    attachment.title!,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
                if (attachment.description != null && attachment.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    attachment.description!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String? url) async {
    final target = url ?? attachment.url;
    if (target == null || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הסרטון'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final success = await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הקישור'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

