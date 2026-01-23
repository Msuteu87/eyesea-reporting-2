import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/unified_feed_item.dart';

/// Instagram-style card for displaying cleanup events in the feed
class EventFeedCard extends StatelessWidget {
  final EventFeedItem item;
  final VoidCallback? onJoinPressed;
  final bool canJoin;

  const EventFeedCard({
    super.key,
    required this.item,
    this.onJoinPressed,
    this.canJoin = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.lightSeaGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image (if available)
          if (item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty)
            _buildCoverImage(isDark),

          // Event badge header
          _buildEventBadge(isDark),

          // Header: Avatar, organizer name, time
          _buildHeader(context, isDark),

          // Event content
          _buildEventContent(context, isDark),

          // Action row: Join button and attendee count
          _buildActionRow(context, isDark),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEventBadge(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightSeaGreen.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.calendar,
            size: 16,
            color: AppColors.lightSeaGreen,
          ),
          const SizedBox(width: 6),
          const Text(
            'Cleanup Event',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lightSeaGreen,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Status badge
          _buildStatusChip(),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    IconData icon;

    switch (item.status) {
      case 'active':
        color = AppColors.emerald;
        label = 'Happening now';
        icon = LucideIcons.radio;
        break;
      case 'completed':
        color = AppColors.coolGray;
        label = 'Completed';
        icon = LucideIcons.checkCircle;
        break;
      case 'cancelled':
        color = AppColors.punchRed;
        label = 'Cancelled';
        icon = LucideIcons.xCircle;
        break;
      case 'planned':
      default:
        color = AppColors.electricNavy;
        label = 'Upcoming';
        icon = LucideIcons.clock;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
            backgroundColor: AppColors.lightSeaGreen.withValues(alpha: 0.2),
            backgroundImage: item.avatarUrl != null
                ? NetworkImage(item.avatarUrl!)
                : null,
            child: item.avatarUrl == null
                ? const Icon(
                    LucideIcons.user,
                    size: 20,
                    color: AppColors.lightSeaGreen,
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Organizer info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.displayName ?? 'Anonymous',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Organizer',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Created ${_formatTimeAgo(item.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event title
          Text(
            item.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.darkGunmetal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Date and time
          _buildInfoRow(
            icon: LucideIcons.clock,
            text: item.formattedDateTime,
            isDark: isDark,
            color: AppColors.electricNavy,
          ),

          const SizedBox(height: 8),

          // Location
          if (item.address != null && item.address!.isNotEmpty)
            _buildInfoRow(
              icon: LucideIcons.mapPin,
              text: item.address!,
              isDark: isDark,
            ),

          // Description (truncated)
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required bool isDark,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
              color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Attendee count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.users,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.attendeeCount} ${item.attendeeCount == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Spots remaining
          if (item.maxAttendees != null) ...[
            const SizedBox(width: 8),
            Text(
              item.spotsRemainingText,
              style: TextStyle(
                fontSize: 12,
                color: item.isFull 
                    ? AppColors.punchRed 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: item.isFull ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],

          const Spacer(),

          // Join button
          _buildJoinButton(isDark),
        ],
      ),
    );
  }

  Widget _buildJoinButton(bool isDark) {
    final isDisabled = !canJoin || item.isFull || item.status == 'cancelled' || item.status == 'completed';
    final isJoined = item.userHasJoined;

    return FilledButton(
      onPressed: isDisabled ? null : onJoinPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isJoined 
            ? AppColors.emerald 
            : AppColors.lightSeaGreen,
        disabledBackgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isJoined ? LucideIcons.check : LucideIcons.userPlus,
            size: 16,
            color: isDisabled 
                ? (isDark ? Colors.grey[500] : Colors.grey[500])
                : Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isJoined ? 'Joined' : 'Join',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDisabled 
                  ? (isDark ? Colors.grey[500] : Colors.grey[500])
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(bool isDark) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[200],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          item.coverImageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.lightSeaGreen,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              LucideIcons.imageOff,
              size: 32,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return '1d ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
