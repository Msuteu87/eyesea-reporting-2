import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/event.dart';
import '../../providers/events_provider.dart';

/// Modal bottom sheet displaying full event details with attendee list and RSVP button.
class EventDetailModal extends StatefulWidget {
  final EventEntity event;

  const EventDetailModal({super.key, required this.event});

  static Future<void> show(BuildContext context, EventEntity event) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailModal(event: event),
    );
  }

  @override
  State<EventDetailModal> createState() => _EventDetailModalState();
}

class _EventDetailModalState extends State<EventDetailModal> {
  List<EventAttendee> _attendees = [];
  bool _isLoadingAttendees = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _isLoadingAttendees = true);
    final provider = context.read<EventsProvider>();
    final attendees = await provider.fetchEventAttendees(widget.event.id);
    if (mounted) {
      setState(() {
        _attendees = attendees;
        _isLoadingAttendees = false;
      });
    }
  }

  Future<void> _handleJoinLeave() async {
    setState(() => _isJoining = true);
    final provider = context.read<EventsProvider>();

    final success = widget.event.isAttending
        ? await provider.leaveEvent(widget.event.id)
        : await provider.joinEvent(widget.event.id);

    if (mounted) {
      setState(() => _isJoining = false);

      if (success) {
        // Refresh attendee list
        _loadAttendees();

        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event.isAttending
                  ? 'Successfully left event'
                  : 'Successfully joined event!',
            ),
            backgroundColor: widget.event.isAttending ? Colors.grey : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update attendance'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.inkBlack : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Cover image (if available)
                    if (widget.event.coverImageUrl != null &&
                        widget.event.coverImageUrl!.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          widget.event.coverImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDark ? Colors.grey[850] : Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.oceanBlue,
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
                                size: 48,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Content with padding
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    const SizedBox(height: 16),

                    // Event title
                    Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Organizer info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppColors.oceanBlue.withValues(alpha: 0.2),
                          backgroundImage: widget.event.organizerAvatar != null
                              ? NetworkImage(widget.event.organizerAvatar!)
                              : null,
                          child: widget.event.organizerAvatar == null
                              ? Text(
                                  widget.event.organizerName.isNotEmpty
                                      ? widget.event.organizerName[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.oceanBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Organized by',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              widget.event.organizerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Event details
                    _buildDetailRow(
                      icon: LucideIcons.calendar,
                      label: 'Date',
                      value: widget.event.formattedDate,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: LucideIcons.clock,
                      label: 'Time',
                      value: widget.event.formattedTimeRange,
                      isDark: isDark,
                    ),
                    if (widget.event.address != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: LucideIcons.mapPin,
                        label: 'Location',
                        value: widget.event.address!,
                        isDark: isDark,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Description
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Attendees section
                    Row(
                      children: [
                        const Text(
                          'Attendees',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.oceanBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.event.maxAttendees != null
                                ? '${widget.event.attendeeCount}/${widget.event.maxAttendees}'
                                : '${widget.event.attendeeCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.oceanBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Attendee list
                    if (_isLoadingAttendees)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_attendees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No attendees yet. Be the first to join!',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._attendees.map((attendee) => _buildAttendeeItem(
                            attendee,
                            isDark,
                          )),

                    const SizedBox(height: 100), // Space for button
                        ],
                      ),
                    ), // Padding
                  ],
                ),
              ),

              // Join/Leave button (fixed at bottom)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inkBlack : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (widget.event.isFull && !widget.event.isAttending) ||
                              _isJoining ||
                              widget.event.isPast
                          ? null
                          : _handleJoinLeave,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: widget.event.isAttending
                            ? Colors.grey
                            : AppColors.oceanBlue,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.event.isAttending
                                      ? LucideIcons.x
                                      : LucideIcons.check,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.event.isPast
                                      ? 'Event Ended'
                                      : widget.event.isFull &&
                                              !widget.event.isAttending
                                          ? 'Event Full'
                                          : widget.event.isAttending
                                              ? 'Leave Event'
                                              : 'Join Event',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.oceanBlue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendeeItem(EventAttendee attendee, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.oceanBlue.withValues(alpha: 0.2),
            backgroundImage: attendee.avatarUrl != null
                ? NetworkImage(attendee.avatarUrl!)
                : null,
            child: attendee.avatarUrl == null
                ? Text(
                    attendee.displayName.isNotEmpty
                        ? attendee.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.oceanBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attendee.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
