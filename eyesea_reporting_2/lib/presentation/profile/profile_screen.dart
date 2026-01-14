// TODO: [MAINTAINABILITY] This file is 890 lines - consider splitting.
// Candidates for extraction:
// - SettingsTab → settings_tab.dart (already exists but could be separate screen)
// - MyReportsTab → my_reports_tab.dart
// - LegalTab → legal_tab.dart
// - ProfileHeader → profile_header.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/logger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/vessel.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/organization.dart';
import '../../domain/repositories/organization_repository.dart';
import 'widgets/my_reports_tab.dart';
import 'widgets/settings_tab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // Tab State - 0: Overview, 1: My Reports, 2: Settings
  int _selectedTabIndex = 0;

  // Edit Mode State
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _countryController;

  // Role/Org/Vessel editing state
  UserRole? _editingRole;
  OrganizationEntity? _editingOrg;
  VesselEntity? _editingVessel;
  List<OrganizationEntity> _organizations = [];
  List<VesselEntity> _editingVessels = [];
  bool _isLoadingOrgs = false;
  bool _isLoadingEditVessels = false;

  // Image Upload
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _countryController = TextEditingController(text: user?.country ?? '');

    // Load profile data (badges, stats, reports)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  void _loadProfileData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      context.read<ProfileProvider>().loadProfileData(
            user.id,
            streakDays: user.streakDays,
          );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _handleAvatarTap() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;
    if (!mounted) return;

    // Get current avatar URL to clear from cache later
    final oldAvatarUrl = context.read<AuthProvider>().currentUser?.avatarUrl;

    setState(() => _isUploadingImage = true);

    try {
      await context.read<AuthProvider>().uploadAvatar(File(image.path));

      // Clear old avatar from image cache
      if (oldAvatarUrl != null) {
        imageCache.evict(oldAvatarUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Avatar updated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    // Validation for Seafarer role
    if (_editingRole == UserRole.seafarer) {
      if (_editingOrg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an organization'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_editingVessel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a vessel'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    try {
      await context.read<AuthProvider>().updateProfile(
            displayName: _nameController.text.trim(),
            country: _countryController.text.trim(),
            role: _editingRole,
            orgId: _editingOrg?.id,
            currentVesselId:
                _editingRole == UserRole.seafarer ? _editingVessel?.id : null,
          );
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Profile updated successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _startEditing() {
    final user = context.read<AuthProvider>().currentUser;
    setState(() {
      _isEditing = true;
      _editingRole = user?.role;
      _editingOrg = null;
      _editingVessel = null;
      _organizations = [];
      _editingVessels = [];
    });
    _fetchOrganizationsForEdit();
  }

  Future<void> _fetchOrganizationsForEdit() async {
    setState(() => _isLoadingOrgs = true);
    try {
      final repo = context.read<OrganizationRepository>();
      final orgs = _editingRole == UserRole.seafarer
          ? await repo.fetchShippingCompanies()
          : await repo.fetchAllOrganizations();
      if (mounted) {
        setState(() => _organizations = orgs);
      }
    } catch (e) {
      AppLogger.error('Error fetching organizations for edit', e);
    } finally {
      if (mounted) setState(() => _isLoadingOrgs = false);
    }
  }

  Future<void> _fetchVesselsForEdit(String orgId) async {
    setState(() {
      _isLoadingEditVessels = true;
      _editingVessels = [];
      _editingVessel = null;
    });
    try {
      final repo = context.read<OrganizationRepository>();
      final vessels = await repo.fetchVessels(orgId);
      if (mounted) {
        setState(() => _editingVessels = vessels);
      }
    } catch (e) {
      AppLogger.error('Error fetching vessels for edit', e);
    } finally {
      if (mounted) setState(() => _isLoadingEditVessels = false);
    }
  }

  Future<void> _handleRoleChange(UserRole newRole) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final currentRole = user.role;

    // Block switching to Ambassador or EyeseaRep
    if (newRole == UserRole.ambassador || newRole == UserRole.eyeseaRep) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This role is managed by administrators'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Seafarer -> Volunteer: Ask about keeping organization
    if (currentRole == UserRole.seafarer && newRole == UserRole.volunteer) {
      final keepOrg = await _showKeepOrgDialog();

      setState(() {
        _editingRole = newRole;
        _editingVessel = null; // Always clear vessel for volunteers
        if (!keepOrg) {
          _editingOrg = null;
        }
      });

      // Refetch orgs for volunteer (all orgs)
      await _fetchOrganizationsForEdit();
      return;
    }

    // Volunteer -> Seafarer: Will require org + vessel selection
    if ((currentRole == UserRole.volunteer || _editingRole == UserRole.volunteer) &&
        newRole == UserRole.seafarer) {
      setState(() {
        _editingRole = newRole;
        _editingOrg = null; // Must select shipping company
        _editingVessel = null;
        _editingVessels = [];
      });

      // Fetch shipping companies
      await _fetchOrganizationsForEdit();
      return;
    }

    // Same role - just update state
    setState(() {
      _editingRole = newRole;
    });
  }

  Future<bool> _showKeepOrgDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keep Organization?'),
            content: const Text(
              'You are changing from Seafarer to Volunteer. '
              'Do you want to keep your current organization affiliation?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Leave Organization'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keep Organization'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user, primaryColor),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTabSwitcher(context, primaryColor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: 300.ms,
                child: _buildTabContent(context, user, primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
      BuildContext context, UserEntity user, Color primaryColor) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab(context, user, primaryColor);
      case 1:
        return const MyReportsTab();
      case 2:
        return const SettingsTab();
      default:
        return _buildOverviewTab(context, user, primaryColor);
    }
  }

  // --- Header Section ---
  Widget _buildHeader(
      BuildContext context, UserEntity user, Color primaryColor) {
    final level = user.reportsCount < 10
        ? 'Ocean Scout'
        : user.reportsCount < 50
            ? 'Ocean Guardian'
            : 'Ocean Hero';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: Colors.transparent,
      child: Column(
        children: [
          // Top Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (GoRouter.of(context).canPop())
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(LucideIcons.arrowLeft),
                  style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).cardColor.withValues(alpha: 0.5)),
                )
              else
                const SizedBox(width: 48),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: 200.ms,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isEditing ? LucideIcons.check : LucideIcons.pencil,
                    key: ValueKey(_isEditing),
                    color: primaryColor,
                  ),
                ),
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    _startEditing();
                  }
                },
                style: IconButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.1)),
              ),
            ],
          ),

          // Avatar with progress ring
          GestureDetector(
            onTap: _handleAvatarTap,
            child: _buildAvatarWithProgress(context, user, primaryColor),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 16),

          // Name
          AnimatedCrossFade(
            duration: 300.ms,
            firstChild: Text(
              user.displayName ?? 'Ocean Guardian',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            secondChild: SizedBox(
                width: 200,
                child: TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Your Name',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )),
            crossFadeState: _isEditing
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),

          const SizedBox(height: 4),
          Text(user.email,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),

          // Role/Org/Vessel editing (only for Volunteer/Seafarer)
          if (_isEditing &&
              (user.role == UserRole.volunteer ||
                  user.role == UserRole.seafarer)) ...[
            const SizedBox(height: 16),
            _buildRoleOrgVesselEditor(context, user, primaryColor),
          ],

          const SizedBox(height: 12),

          // Pills (Level & Org) - hide when editing
          if (!_isEditing)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPill(context, level, LucideIcons.award, primaryColor),
                if (user.orgName != null)
                  _buildPill(context, user.orgName!, LucideIcons.building2,
                      Colors.indigoAccent),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),

          // Seafarer Information - hide when editing
          if (!_isEditing && user.role == UserRole.seafarer) ...[
            const SizedBox(height: 16),
            _buildVesselCard(context, user, primaryColor)
                .animate()
                .fadeIn(delay: 300.ms)
                .slideY(begin: 0.2),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleOrgVesselEditor(
      BuildContext context, UserEntity user, Color primaryColor) {
    final effectiveRole = _editingRole ?? user.role;

    return Column(
      children: [
        // Role Selection (Volunteer/Seafarer only)
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                value: UserRole.volunteer,
                label: Text('Volunteer'),
                icon: Icon(Icons.favorite, size: 18),
              ),
              ButtonSegment(
                value: UserRole.seafarer,
                label: Text('Seafarer'),
                icon: Icon(Icons.directions_boat, size: 18),
              ),
            ],
            selected: {effectiveRole},
            onSelectionChanged: (newSelection) {
              _handleRoleChange(newSelection.first);
            },
          ),
        ),

        const SizedBox(height: 16),

        // Organization Dropdown
        if (_isLoadingOrgs)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<OrganizationEntity>(
              key: ValueKey('org_edit_${_editingOrg?.id}'),
              decoration: InputDecoration(
                labelText: effectiveRole == UserRole.seafarer
                    ? 'Organization *'
                    : 'Organization (Optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              initialValue: _editingOrg,
              isExpanded: true,
              hint: Text(effectiveRole == UserRole.seafarer
                  ? 'Select shipping company'
                  : 'Select organization'),
              items: _organizations.map((org) {
                return DropdownMenuItem(
                  value: org,
                  child: Text(org.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (org) {
                setState(() {
                  _editingOrg = org;
                  _editingVessel = null;
                  _editingVessels = [];
                });
                if (org != null && effectiveRole == UserRole.seafarer) {
                  _fetchVesselsForEdit(org.id);
                }
              },
            ),
          ),

        // Vessel Dropdown (Seafarer only)
        if (effectiveRole == UserRole.seafarer) ...[
          const SizedBox(height: 12),
          if (_isLoadingEditVessels)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<VesselEntity>(
                key: ValueKey('vessel_edit_${_editingVessel?.id}'),
                decoration: InputDecoration(
                  labelText: 'Vessel *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                initialValue: _editingVessel,
                isExpanded: true,
                hint: const Text('Select vessel'),
                items: _editingVessels.map((vessel) {
                  return DropdownMenuItem(
                    value: vessel,
                    child: Text(
                      '${vessel.name}${vessel.imoNumber != null ? ' (${vessel.imoNumber})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _editingOrg == null
                    ? null
                    : (vessel) => setState(() => _editingVessel = vessel),
                disabledHint: _editingOrg == null
                    ? const Text('Select organization first')
                    : null,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAvatarWithProgress(
      BuildContext context, UserEntity user, Color primaryColor) {
    // Calculate progress to next level
    final progress = (user.reportsCount % 10) / 10;

    // Letter placeholder widget
    Widget letterPlaceholder() => Center(
          child: Text(
            user.displayName?.isNotEmpty == true
                ? user.displayName![0].toUpperCase()
                : '?',
            style: const TextStyle(
                fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        // Progress ring
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
        // Avatar
        Hero(
          tag: 'profile_avatar',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
              border:
                  Border.all(color: Theme.of(context).cardColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : (user.avatarUrl != null
                    ? Image.network(
                        user.avatarUrl!,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                        errorBuilder: (_, error, stackTrace) {
                          AppLogger.warning('Avatar image load error: $error');
                          return letterPlaceholder();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : letterPlaceholder()),
          ),
        ),
        // Camera icon
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                ]),
            child: Icon(LucideIcons.camera, color: primaryColor, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(
      BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVesselCard(BuildContext context, UserEntity user, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.ship, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Vessel',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                Text(
                  user.currentVesselName ?? 'No Vessel Linked',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showVesselSwitcher(context, user),
            child: const Text('Change'),
          )
        ],
      ),
    );
  }

  void _showVesselSwitcher(BuildContext context, UserEntity user) {
    if (user.orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No organization linked. Please contact support.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VesselSwitcherSheet(
          orgId: user.orgId!, currentVesselId: user.currentVesselId),
    );
  }

  // --- Tab Switcher (3 tabs) ---
  Widget _buildTabSwitcher(BuildContext context, Color primaryColor) {
    final tabs = ['Overview', 'My Reports', 'Settings'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
          ]),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          return Expanded(
            child: _buildTabBtn(
              context,
              entry.value,
              _selectedTabIndex == entry.key,
              primaryColor,
              () => setState(() => _selectedTabIndex = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBtn(BuildContext context, String text, bool isActive,
      Color primaryColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- Overview Tab ---
  Widget _buildOverviewTab(
      BuildContext context, UserEntity user, Color primaryColor) {
    final profileProvider = context.watch<ProfileProvider>();
    final stats = profileProvider.stats;
    final badges = profileProvider.badges;
    final isLoadingStats = profileProvider.isLoadingStats;
    final isLoadingBadges = profileProvider.isLoadingBadges;

    return RefreshIndicator(
      onRefresh: () => profileProvider.refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // Stats
          _buildStatsSection(context, user, stats, isLoadingStats, primaryColor),

          const SizedBox(height: 32),

          // Achievements Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Achievements',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (badges.isNotEmpty)
                Text(
                  '${badges.where((b) => b.isEarned).length}/${badges.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Badges
          isLoadingBadges
              ? const Center(child: CircularProgressIndicator())
              : _buildBadgesSection(context, badges),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, UserEntity user,
      UserStats stats, bool isLoading, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            LucideIcons.fileText,
            isLoading ? '...' : '${stats.reportsCount}',
            'Reports',
            Colors.pinkAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            LucideIcons.flame,
            isLoading ? '...' : '${stats.streakDays}',
            'Day Streak',
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            LucideIcons.trophy,
            isLoading ? '...' : '#${stats.rank}',
            'Rank',
            primaryColor,
          ),
        ),
      ],
    ).animate().scale(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String value,
      String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context, List<BadgeEntity> badges) {
    if (badges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(LucideIcons.award,
                  size: 48, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                'No badges yet',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];
          return _buildBadgeItem(context, badge);
        },
      ).animate().slideX(
          begin: 0.2, duration: 400.ms, delay: 200.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildBadgeItem(BuildContext context, BadgeEntity badge) {
    final iconData = _getBadgeIcon(badge.icon);

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: badge.isEarned
                  ? badge.color.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: badge.isEarned
                  ? Border.all(color: badge.color.withValues(alpha: 0.3))
                  : null,
            ),
            child: Icon(
              badge.isEarned ? iconData : LucideIcons.lock,
              color: badge.isEarned ? badge.color : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: badge.isEarned ? null : Colors.grey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  IconData _getBadgeIcon(String iconName) {
    switch (iconName) {
      case 'award':
        return LucideIcons.award;
      case 'compass':
        return LucideIcons.compass;
      case 'shield':
        return LucideIcons.shield;
      case 'trophy':
        return LucideIcons.trophy;
      case 'flame':
        return LucideIcons.flame;
      case 'zap':
        return LucideIcons.zap;
      case 'users':
        return LucideIcons.users;
      case 'recycle':
        return LucideIcons.recycle;
      case 'sunrise':
        return LucideIcons.sunrise;
      default:
        return LucideIcons.award;
    }
  }
}

// --- Vessel Switcher Bottom Sheet ---
class _VesselSwitcherSheet extends StatefulWidget {
  final String orgId;
  final String? currentVesselId;

  const _VesselSwitcherSheet({required this.orgId, this.currentVesselId});

  @override
  State<_VesselSwitcherSheet> createState() => _VesselSwitcherSheetState();
}

class _VesselSwitcherSheetState extends State<_VesselSwitcherSheet> {
  List<VesselEntity> _vessels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVessels();
  }

  Future<void> _fetchVessels() async {
    try {
      final vessels = await context
          .read<OrganizationRepository>()
          .fetchVessels(widget.orgId);
      if (mounted) {
        setState(() {
          _vessels = vessels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectVessel(VesselEntity vessel) async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.updateProfile(
        displayName: auth.currentUser!.displayName ?? '',
        country: auth.currentUser!.country ?? '',
        currentVesselId: vessel.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.ship),
              const SizedBox(width: 12),
              Text('Select Vessel',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const Divider(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_vessels.isEmpty)
            const Expanded(
                child: Center(
                    child: Text('No vessels found in this organization'))),
          if (!_isLoading && _vessels.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _vessels.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vessel = _vessels[index];
                  final isSelected = vessel.id == widget.currentVesselId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(vessel.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: vessel.imoNumber != null
                        ? Text('IMO: ${vessel.imoNumber}',
                            style: const TextStyle(color: Colors.grey))
                        : null,
                    trailing: isSelected
                        ? Icon(LucideIcons.checkCircle,
                            color: Theme.of(context).colorScheme.primary)
                        : const Icon(LucideIcons.circle, color: Colors.grey),
                    onTap: () => _selectVessel(vessel),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
