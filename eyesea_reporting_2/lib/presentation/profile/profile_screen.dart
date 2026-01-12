import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/vessel.dart';
import '../../domain/repositories/organization_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Tab State
  bool _showOverview = true; // true = Overview, false = Competitions

  // Edit Mode State - Animated using AnimatedCrossFade or similar
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _countryController;

  // Image Upload
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _countryController = TextEditingController(text: user?.country ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _handleAvatarTap() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      await context.read<AuthProvider>().uploadAvatar(File(image.path));
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
    try {
      await context.read<AuthProvider>().updateProfile(
            displayName: _nameController.text.trim(),
            country: _countryController.text.trim(),
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
      // No app bar, custom header
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user, primaryColor),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTabSwitcher(context, primaryColor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: 300.ms,
                child: _showOverview
                    ? _buildOverviewTab(context, user, primaryColor)
                    : _buildCompetitionsTab(context, primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Header Section ---
  Widget _buildHeader(
      BuildContext context, UserEntity user, Color primaryColor) {
    // Determine Level based on reports
    final level = user.reportsCount < 10 ? 'Ocean Scout' : 'Ocean Guardian';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: Colors.transparent, // Clean, no gradient
      child: Column(
        children: [
          // Top Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button (if can pop)
              if (GoRouter.of(context).canPop())
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).cardColor.withValues(alpha: 0.5)),
                )
              else
                // Spacer to keep Edit button aligned right if no back button
                const SizedBox(width: 48),

              IconButton(
                icon: AnimatedSwitcher(
                  duration: 200.ms,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isEditing ? Icons.check : Icons.edit_outlined,
                    key: ValueKey(_isEditing),
                    color: primaryColor,
                  ),
                ),
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                style: IconButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.1)),
              ),
            ],
          ),

          // Avatar
          GestureDetector(
            onTap: _handleAvatarTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor,
                      border: Border.all(
                          color: Theme.of(context).cardColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                      image: user.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(user.avatarUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _isUploadingImage
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : (user.avatarUrl == null
                            ? Center(
                                child: Text(
                                  user.displayName?.isNotEmpty == true
                                      ? user.displayName![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 40,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4),
                      ]),
                  child: Icon(Icons.camera_alt, color: primaryColor, size: 16),
                ),
              ],
            ),
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

          const SizedBox(height: 8),
          Text(user.email,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),

          const SizedBox(height: 16),

          // Pills (Level & Org)
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPill(
                  context, level, Icons.verified_user_outlined, primaryColor),
              if (user.orgName != null)
                _buildPill(context, user.orgName!, Icons.business,
                    Colors.indigoAccent),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5),

          // Seafarer Information
          if (user.role == UserRole.seafarer) ...[
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
            child: Icon(Icons.directions_boat_outlined, color: color),
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

  // --- Tab Switcher ---
  Widget _buildTabSwitcher(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // Solid card color
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
          ]),
      child: Row(
        children: [
          Expanded(
              child: _buildTabBtn(
                  context, 'Overview', _showOverview, primaryColor)),
          Expanded(
              child: _buildTabBtn(
                  context, 'Competitions', !_showOverview, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTabBtn(
      BuildContext context, String text, bool isActive, Color primaryColor) {
    return GestureDetector(
      onTap: () => setState(() => _showOverview = text == 'Overview'),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 12),
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
          ),
        ),
      ),
    );
  }

  // --- Overview Tab ---
  Widget _buildOverviewTab(
      BuildContext context, UserEntity user, Color primaryColor) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Stats
        Row(
          children: [
            Expanded(
                child: _buildStatCard(context, Icons.delete_outline,
                    '${user.reportsCount}', 'Collected', Colors.pinkAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(context, Icons.location_on_outlined,
                    '${user.reportsCount}', 'Events', primaryColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    context,
                    Icons.water_drop_outlined,
                    '${user.reportsCount * 10}',
                    'Impact',
                    Colors.lightBlueAccent)),
          ],
        ).animate().scale(duration: 300.ms, delay: 100.ms),

        const SizedBox(height: 32),
        Text('Achievements',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildBadge(context, 'Early Bird', Icons.wb_sunny, Colors.orange),
              _buildBadge(
                  context, 'Team Player', Icons.handshake, Colors.amber),
              _buildBadge(
                  context, 'Plastic Free', Icons.recycling, Colors.green),
              _buildBadge(
                  context, 'Next Level', Icons.lock_outline, Colors.grey,
                  isLocked: true),
            ],
          ).animate().slideX(
              begin: 0.2,
              duration: 400.ms,
              delay: 200.ms,
              curve: Curves.easeOut),
        ),

        const SizedBox(height: 48),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().signOut(),
          icon: const Icon(Icons.logout, color: AppColors.error),
          label: const Text('Log Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 40),
      ],
    );
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
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

  Widget _buildBadge(
      BuildContext context, String name, IconData icon, Color color,
      {bool isLocked = false}) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.grey.withValues(alpha: 0.1)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isLocked ? Colors.grey : color),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  // --- Competitions Tab (Placeholder) ---
  Widget _buildCompetitionsTab(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Competitions Coming Soon',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    ).animate().fadeIn();
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
              const Icon(Icons.directions_boat_filled),
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
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
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
