import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/event.dart';

/// Card widget displaying event information in a list.
class EventCard extends StatelessWidget {
  final EventEntity event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image (if available)
            if (event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    event.coverImageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.electricNavy,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                      child: Center(
                        child: Icon(
                          LucideIcons.imageOff,
                          size: 32,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header row with organizer info and status
              Row(
                children: [
                  // Organizer avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.electricNavy.withValues(alpha: 0.2),
                    backgroundImage: event.organizerAvatar != null
                        ? NetworkImage(event.organizerAvatar!)
                        : null,
                    child: event.organizerAvatar == null
                        ? Text(
                            event.organizerName.isNotEmpty
                                ? event.organizerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.electricNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Organizer name
                  Expanded(
                    child: Text(
                      event.organizerName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Attending badge
                  if (event.isAttending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.electricNavy.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 12,
                            color: AppColors.electricNavy,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Attending',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.electricNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Event title
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                event.description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Event details row
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  // Date
                  _buildInfoChip(
                    icon: LucideIcons.calendar,
                    label: event.formattedDate,
                    isDark: isDark,
                  ),
                  // Time
                  _buildInfoChip(
                    icon: LucideIcons.clock,
                    label: event.formattedTimeRange,
                    isDark: isDark,
                  ),
                  // Location
                  if (event.address != null)
                    _buildInfoChip(
                      icon: LucideIcons.mapPin,
                      label: event.address!,
                      isDark: isDark,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer with attendee count and capacity
              Row(
                children: [
                  // Attendee count
                  Icon(
                    LucideIcons.users,
                    size: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.maxAttendees != null
                        ? '${event.attendeeCount}/${event.maxAttendees} attending'
                        : '${event.attendeeCount} attending',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  // Full indicator
                  if (event.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Full',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ), // Padding
          ],
        ), // Column (outer)
      ), // InkWell
      ), // Material
    ); // Container
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
