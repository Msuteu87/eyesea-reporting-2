import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/report.dart';

/// Read-only screen to view an existing report's details.
class ReportViewScreen extends StatelessWidget {
  final ReportEntity report;

  const ReportViewScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = report.imageUrls.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? Image.network(
                      report.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge and type
                  Row(
                    children: [
                      _buildStatusBadge(context, report.status),
                      const Spacer(),
                      if (report.xpEarned != null && report.xpEarned! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.zap,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${report.xpEarned} XP',
                                style: TextStyle(
                                  color: Colors.amber[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ).animate().fadeIn(duration: 200.ms),
                  const SizedBox(height: 16),

                  // Pollution type
                  Text(
                    _formatPollutionType(report.pollutionType),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 200.ms, delay: 50.ms),
                  const SizedBox(height: 8),

                  // Location
                  if (report.address != null || report.city != null)
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 16,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.address ??
                                [report.city, report.country]
                                    .where((e) => e != null)
                                    .join(', '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 200.ms, delay: 100.ms),
                  const SizedBox(height: 24),

                  // Details card
                  _buildDetailsCard(context).animate().fadeIn(
                        duration: 200.ms,
                        delay: 150.ms,
                      ),
                  const SizedBox(height: 16),

                  // Notes
                  if (report.notes != null && report.notes!.isNotEmpty) ...[
                    _buildNotesCard(context).animate().fadeIn(
                          duration: 200.ms,
                          delay: 200.ms,
                        ),
                    const SizedBox(height: 16),
                  ],

                  // Pollution counts
                  if (report.pollutionCounts.isNotEmpty)
                    _buildPollutionCountsCard(context).animate().fadeIn(
                          duration: 200.ms,
                          delay: 250.ms,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.oceanBlue.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          LucideIcons.image,
          size: 64,
          color: AppColors.oceanBlue.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ReportStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ReportStatus.pending:
        color = Colors.amber;
        label = 'Pending Review';
        icon = LucideIcons.clock;
        break;
      case ReportStatus.verified:
        color = AppColors.oceanBlue;
        label = 'Verified';
        icon = LucideIcons.checkCircle;
        break;
      case ReportStatus.resolved:
        color = AppColors.successGreen;
        label = 'Recovered';
        icon = LucideIcons.checkCircle2;
        break;
      case ReportStatus.rejected:
        color = AppColors.error;
        label = 'Rejected';
        icon = LucideIcons.xCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            icon: LucideIcons.calendar,
            label: 'Reported',
            value: _formatDate(report.reportedAt),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            context,
            icon: LucideIcons.gauge,
            label: 'Severity',
            value: '${report.severity}/5',
            trailing: _buildSeverityIndicator(report.severity),
          ),
          if (report.totalWeightKg != null) ...[
            const Divider(height: 24),
            _buildDetailRow(
              context,
              icon: LucideIcons.scale,
              label: 'Estimated Weight',
              value: '${report.totalWeightKg!.toStringAsFixed(1)} kg',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.oceanBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSeverityIndicator(int severity) {
    return Row(
      children: List.generate(5, (index) {
        final isActive = index < severity;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? _getSeverityColor(severity)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 2) return AppColors.successGreen;
    if (severity <= 3) return Colors.amber;
    return AppColors.error;
  }

  Widget _buildNotesCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText, size: 20, color: AppColors.oceanBlue),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.notes!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPollutionCountsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trash2, size: 20, color: AppColors.oceanBlue),
              const SizedBox(width: 8),
              Text(
                'Items Detected',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: report.pollutionCounts.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.oceanBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.key.displayLabel}: ${entry.value}',
                  style: const TextStyle(
                    color: AppColors.oceanBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatPollutionType(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return 'Plastic Pollution';
      case PollutionType.oil:
        return 'Oil Spill';
      case PollutionType.debris:
        return 'Marine Debris';
      case PollutionType.sewage:
        return 'Sewage';
      case PollutionType.fishingGear:
        return 'Fishing Gear';
      case PollutionType.container:
        return 'Container';
      case PollutionType.other:
        return 'Other Pollution';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
