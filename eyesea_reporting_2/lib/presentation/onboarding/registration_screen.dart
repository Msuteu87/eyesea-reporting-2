import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/vessel.dart';
import '../../domain/repositories/organization_repository.dart';
import '../providers/auth_provider.dart';

import '../../core/utils/countries_list.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const RegistrationScreen({super.key, required this.onCompleted});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCountry;

  // Seafarer specific
  UserRole _selectedRole = UserRole.volunteer;
  OrganizationEntity? _selectedOrg;
  VesselEntity? _selectedVessel;

  List<OrganizationEntity> _shippingCompanies = [];
  List<VesselEntity> _vessels = [];
  bool _isLoadingVessels = false;

  bool _isDataConsentGiven = false;
  bool _isMarketingOptIn = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrganizations() async {
    try {
      final repo = context.read<OrganizationRepository>();
      final orgs = await repo.fetchShippingCompanies();
      if (mounted) {
        setState(() => _shippingCompanies = orgs);
      }
    } catch (e) {
      debugPrint('Error fetching organizations: $e');
    } finally {
      if (mounted) {}
    }
  }

  Future<void> _fetchVessels(String orgId) async {
    setState(() {
      _isLoadingVessels = true;
      _vessels = [];
      _selectedVessel = null;
    });
    try {
      final repo = context.read<OrganizationRepository>();
      final vessels = await repo.fetchVessels(orgId);
      if (mounted) {
        setState(() => _vessels = vessels);
      }
    } catch (e) {
      debugPrint('Error fetching vessels: $e');
    } finally {
      if (mounted) setState(() => _isLoadingVessels = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isDataConsentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please accept the data processing agreement to continue'),
          backgroundColor: AppColors.punchRed,
        ),
      );
      return;
    }

    // Additional validation for Seafarers
    if (_selectedRole == UserRole.seafarer) {
      if (_selectedOrg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your Organization')),
        );
        return;
      }
      if (_selectedVessel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your Vessel')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<AuthProvider>().updateProfile(
            displayName: _nameController.text.trim(),
            country: _selectedCountry!,
            role: _selectedRole,
            currentVesselId: _selectedVessel?.id,
            orgId: _selectedOrg?.id,
            gdprConsentAt: DateTime.now(), // Record consent timestamp
            marketingOptIn: _isMarketingOptIn,
          );

      widget.onCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.punchRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Added scroll view for potentially longer form
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us about you',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),

              const SizedBox(height: 8),

              Text(
                'Help us personalize your experience.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Full Name', Icons.person),
                style: TextStyle(color: textColor),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 16),

              // Country Dropdown
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedCountry ?? 'country'),
                decoration: _inputDecoration('Country', Icons.public),
                initialValue: _selectedCountry,
                isExpanded: true,
                menuMaxHeight: 300,
                hint: const Text('Select your country'),
                items: CountriesList.all.map((country) {
                  return DropdownMenuItem(
                    value: country,
                    child: Text(country, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCountry = val);
                },
                validator: (val) => val == null || val.isEmpty
                    ? 'Please select your country'
                    : null,
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 24),

              // Role Selection
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.volunteer,
                      label: Text('Volunteer'),
                      icon: Icon(Icons.favorite),
                    ),
                    ButtonSegment(
                      value: UserRole.seafarer,
                      label: Text('Seafarer'),
                      icon: Icon(Icons.directions_boat),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedRole = newSelection.first;
                    });
                  },
                ),
              ).animate().fadeIn(delay: 500.ms),

              // Seafarer Fields
              if (_selectedRole == UserRole.seafarer) ...[
                const SizedBox(height: 24),

                // Org Dropdown
                DropdownButtonFormField<OrganizationEntity>(
                  key: ValueKey(_selectedOrg?.id ?? 'org_selector'),
                  decoration: _inputDecoration('Organization', Icons.business),
                  initialValue: _selectedOrg,
                  isExpanded: true,
                  items: _shippingCompanies.map((org) {
                    return DropdownMenuItem(
                      value: org,
                      child: Text(org.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (org) {
                    setState(() {
                      _selectedOrg = org;
                      _selectedVessel = null; // Reset vessel
                    });
                    if (org != null) {
                      _fetchVessels(org.id);
                    }
                  },
                  validator: (val) =>
                      val == null && _selectedRole == UserRole.seafarer
                          ? 'Required'
                          : null,
                ).animate().fadeIn(),

                const SizedBox(height: 16),

                // Vessel Dropdown
                DropdownButtonFormField<VesselEntity>(
                  key: ValueKey(_selectedVessel?.id ??
                      'vessel_${_selectedOrg?.id}'), // Force rebuild on org change to reset
                  decoration: _inputDecoration('Vessel', Icons.anchor),
                  initialValue: _selectedVessel,
                  isExpanded: true,
                  items: _vessels.map((vessel) {
                    return DropdownMenuItem(
                      value: vessel,
                      child: Text(
                          vessel.name +
                              (vessel.imoNumber != null
                                  ? ' (${vessel.imoNumber})'
                                  : ''),
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _selectedOrg == null
                      ? null
                      : (vessel) {
                          setState(() => _selectedVessel = vessel);
                        },
                  validator: (val) =>
                      val == null && _selectedRole == UserRole.seafarer
                          ? 'Required'
                          : null,
                  // Disable if no org selected or loading
                  disabledHint: _isLoadingVessels
                      ? const Text('Loading vessels...')
                      : (_selectedOrg == null
                          ? const Text('Select Organization first')
                          : null),
                ).animate().fadeIn(),
              ],

              const SizedBox(height: 24),

              // GDPR Checkbox
              CheckboxListTile(
                value: _isDataConsentGiven,
                onChanged: (val) =>
                    setState(() => _isDataConsentGiven = val == true),
                title: Text(
                  'I agree to the processing of my personal data for account creation and feature personalization, in compliance with GDPR.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: theme.colorScheme.primary,
              ).animate().fadeIn(delay: 550.ms),

              // Marketing Opt-In Checkbox (Optional)
              CheckboxListTile(
                value: _isMarketingOptIn,
                onChanged: (val) =>
                    setState(() => _isMarketingOptIn = val == true),
                title: Text(
                  'I would like to receive updates, news, and promotional communications from Eyesea.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: theme.colorScheme.primary,
              ).animate().fadeIn(delay: 580.ms),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.05),
    );
  }
}
