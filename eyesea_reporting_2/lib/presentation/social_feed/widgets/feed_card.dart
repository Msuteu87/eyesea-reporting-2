import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/feed_item.dart';
import '../../../domain/entities/report.dart';
import 'thank_you_button.dart';

/// Instagram-style full-width card for displaying a feed item
class FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onThankPressed;
  final bool canThank;

  const FeedCard({
    super.key,
    required this.item,
    this.onThankPressed,
    this.canThank = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, name, location, time
          _buildHeader(context, isDark),

          // Image
          _buildImage(context, isDark),

          // Action row: Thank button
          _buildActionRow(context, isDark),

          // Details: Pollution info, scene labels
          _buildDetails(context, isDark),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.oceanBlue.withValues(alpha: 0.2),
            backgroundImage: item.avatarUrl != null
                ? NetworkImage(item.avatarUrl!)
                : null,
            child: item.avatarUrl == null
                ? const Icon(
                    LucideIcons.user,
                    size: 20,
                    color: AppColors.oceanBlue,
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName ?? 'Anonymous',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.locationString,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Time ago
          Text(
            _formatTimeAgo(item.reportedAt),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isDark) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.oceanBlue,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildImagePlaceholder(isDark),
              )
            : _buildImagePlaceholder(isDark),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Center(
      child: Icon(
        LucideIcons.image,
        size: 48,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ThankYouButton(
            count: item.thanksCount,
            isThanked: item.userHasThanked,
            onPressed: onThankPressed,
            enabled: canThank,
          ),
          const Spacer(),
          // Status badge
          if (item.status == ReportStatus.resolved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    size: 14,
                    color: AppColors.successGreen,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Recovered',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pollution type and metrics row
          Row(
            children: [
              Icon(
                _getPollutionIcon(item.pollutionType),
                size: 18,
                color: AppColors.oceanBlue,
              ),
              const SizedBox(width: 6),
              Text(
                item.pollutionType.displayLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (item.totalWeightKg != null && item.totalWeightKg! > 0) ...[
                const SizedBox(width: 12),
                Icon(
                  LucideIcons.scale,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  item.weightString,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
              if (item.totalItems > 0) ...[
                const SizedBox(width: 12),
                Icon(
                  LucideIcons.hash,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.totalItems} items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),

          // Scene labels
          if (item.sceneLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.sceneLabels
                  .take(4)
                  .map((label) => _buildSceneChip(label, isDark))
                  .toList(),
            ),
          ],

          // Pollution breakdown chips
          if (item.pollutionCounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.pollutionCounts.entries
                  .where((e) => e.value > 0)
                  .take(4)
                  .map((e) => _buildPollutionChip(e.key, e.value, isDark))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSceneChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildPollutionChip(PollutionType type, int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.oceanBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPollutionIcon(type),
            size: 14,
            color: AppColors.oceanBlue,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.oceanBlue,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPollutionIcon(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return LucideIcons.milk;
      case PollutionType.oil:
        return LucideIcons.droplet;
      case PollutionType.debris:
        return LucideIcons.trash2;
      case PollutionType.sewage:
        return LucideIcons.droplets;
      case PollutionType.fishingGear:
        return LucideIcons.anchor;
      case PollutionType.container:
        return LucideIcons.box;
      case PollutionType.other:
        return LucideIcons.helpCircle;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m';
      }
      return '${diff.inHours}h';
    }
    if (diff.inDays == 1) return '1d';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }
}
