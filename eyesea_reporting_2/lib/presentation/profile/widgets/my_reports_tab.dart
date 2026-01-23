import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';
import '../../providers/profile_provider.dart';

class MyReportsTab extends StatefulWidget {
  const MyReportsTab({super.key});

  @override
  State<MyReportsTab> createState() => _MyReportsTabState();
}

class _MyReportsTabState extends State<MyReportsTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProfileProvider>().loadMoreReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final reports = provider.userReports;
    final isLoading = provider.isLoadingReports;
    final selectedStatus = provider.selectedStatus;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildFilterChips(context, selectedStatus),
        ),
        const SizedBox(height: 16),

        // Reports list
        Expanded(
          child: isLoading && reports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : reports.isEmpty
                  ? _buildEmptyState(context)
                  : _buildReportsList(context, reports, isLoading),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context, String? selectedStatus) {
    final provider = context.read<ProfileProvider>();
    final theme = Theme.of(context);

    final filters = [
      ('All', null),
      ('Pending', 'pending'),
      ('Recovered', 'resolved'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedStatus == filter.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.$1),
              selected: isSelected,
              onSelected: (_) => provider.filterByStatus(filter.$2),
              backgroundColor: theme.cardColor,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.fileSearch,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No reports yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your pollution reports will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildReportsList(
    BuildContext context,
    List<ReportEntity> reports,
    bool isLoading,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: reports.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == reports.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final report = reports[index];
        return _UserReportCard(report: report)
            .animate()
            .fadeIn(duration: 200.ms, delay: (index * 50).ms)
            .slideX(begin: 0.1);
      },
    );
  }
}

class _UserReportCard extends StatelessWidget {
  final ReportEntity report;

  const _UserReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = report.imageUrls.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () {
          context.push('/report-view', extra: report);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.oceanBlue.withValues(alpha: 0.1),
                  child: hasImage
                      ? Image.network(
                          report.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatPollutionType(report.pollutionType),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildStatusBadge(context, report.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (report.address != null)
                      Text(
                        report.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(report.reportedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        if (report.xpEarned != null && report.xpEarned! > 0) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            LucideIcons.zap,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${report.xpEarned} Credits',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                LucideIcons.chevronRight,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        LucideIcons.image,
        color: AppColors.oceanBlue.withValues(alpha: 0.5),
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
        label = 'Pending';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
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
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
