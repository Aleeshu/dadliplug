import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Business listing editor for Business Admins and Team Admins.
///
/// Gives business owners and the team direct control over:
/// - 1-tap "Closed today" emergency status
/// - Hours and schedule
/// - Landmark directions ("How to find us")
/// - Practical tags (cash only, cards, US$, parking, etc.)
/// - Phone, WhatsApp, and details
class BusinessListingScreen extends ConsumerStatefulWidget {
  const BusinessListingScreen({this.businessId, super.key});

  final String? businessId;

  @override
  ConsumerState<BusinessListingScreen> createState() =>
      _BusinessListingScreenState();
}

class _BusinessListingScreenState extends ConsumerState<BusinessListingScreen> {
  final _formKey = GlobalKey<FormState>();

  Business? _currentBusiness;
  bool _isLoading = true;
  bool _isSaving = false;

  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _howToFindUsController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _addressController;

  BusinessCategory _category = BusinessCategory.food;
  bool _isClosedToday = false;
  final Set<String> _selectedTags = {};
  final Set<int> _selectedDays = {};
  double _opensAt = 9;
  double _closesAt = 17;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _areaController = TextEditingController();
    _descriptionController = TextEditingController();
    _howToFindUsController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();
    _addressController = TextEditingController();
    _loadBusiness();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    _howToFindUsController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    setState(() => _isLoading = true);
    final repo = ref.read(businessRepositoryProvider);

    try {
      Business? b;
      if (widget.businessId != null) {
        b = await repo.getBusinessById(widget.businessId!);
      } else {
        final list = await repo.getBusinesses();
        if (list.isNotEmpty) b = list.first;
      }

      if (b != null && mounted) {
        _currentBusiness = b;
        _nameController.text = b.name;
        _areaController.text = b.area;
        _descriptionController.text = b.description;
        _howToFindUsController.text = b.howToFindUs ?? '';
        _phoneController.text = b.phone ?? '';
        _whatsappController.text = b.whatsapp ?? '';
        _addressController.text = b.address ?? '';
        _category = b.category;
        _isClosedToday = b.isClosedToday;
        _selectedTags
          ..clear()
          ..addAll(b.tags);
        _selectedDays
          ..clear()
          ..addAll(b.hours.days);
        _opensAt = b.hours.opensAt;
        _closesAt = b.hours.closesAt;
      }
    } catch (_) {
      // Keep empty if none found
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleClosedToday(bool value) async {
    final b = _currentBusiness;
    if (b == null) return;

    setState(() => _isClosedToday = value);
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.toggleClosedToday(b.id, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Marked as closed today.' : 'Resumed normal hours.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClosedToday = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: context.palette.bad,
          ),
        );
      }
    }
  }

  Future<void> _saveListing() async {
    final b = _currentBusiness;
    if (b == null || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final updated = b.copyWith(
      name: _nameController.text.trim(),
      category: _category,
      area: _areaController.text.trim(),
      description: _descriptionController.text.trim(),
      howToFindUs: _howToFindUsController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      whatsapp: _whatsappController.text.trim(),
      tags: _selectedTags.toList(),
      isClosedToday: _isClosedToday,
      hours: OpeningHours(
        days: _selectedDays,
        opensAt: _opensAt,
        closesAt: _closesAt,
      ),
      lastVerifiedAt: DateTime.now(),
    );

    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.updateBusiness(updated);
      _currentBusiness = updated;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Listing updated and verified successfully!'),
            backgroundColor: context.palette.good,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save listing: $e'),
            backgroundColor: context.palette.bad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: const Text('Edit Listing')),
        body: Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
      );
    }

    if (_currentBusiness == null) {
      return Scaffold(
        backgroundColor: palette.app,
        appBar: AppBar(title: const Text('Edit Listing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.giant),
            child: Text(
              'No business listing assigned to your account.',
              style: AppText.bodyLarge.copyWith(color: palette.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Manage Listing'),
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveListing,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: palette.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            // 1. One-tap "Closed Today" Emergency Toggle
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: _isClosedToday ? palette.badBg : palette.surface,
                borderRadius: BorderRadius.circular(Corners.md),
                border: Border.all(
                  color: _isClosedToday ? palette.bad : palette.line,
                ),
                boxShadow: Shadows.card,
              ),
              child: SwitchListTile(
                value: _isClosedToday,
                onChanged: _toggleClosedToday,
                activeThumbColor: palette.bad,
                title: Text(
                  'Closed Today (Temporary)',
                  style: AppText.titleSmall.copyWith(
                    color: _isClosedToday ? palette.bad : palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'One-tap closure for hurricane season, public holidays, or Carnival.',
                  style: AppText.caption.copyWith(color: palette.muted),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: Insets.xl),

            // 2. Primary Details
            _buildSectionHeader('General Information', palette),
            const SizedBox(height: Insets.md),
            _buildTextField(
              controller: _nameController,
              label: 'Business Name',
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              palette: palette,
            ),
            const SizedBox(height: Insets.md),

            // Category Selector
            DropdownButtonFormField<BusinessCategory>(
              initialValue: _category,
              decoration: _inputDecoration('Category', palette),
              items: [
                for (final cat in BusinessCategory.values)
                  DropdownMenuItem(
                    value: cat,
                    child: Text(cat.label),
                  ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: Insets.md),

            _buildTextField(
              controller: _areaController,
              label:
                  'Area / Neighbourhood (e.g. Dickenson Bay, English Harbour)',
              palette: palette,
            ),
            const SizedBox(height: Insets.md),

            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 4,
              palette: palette,
            ),
            const SizedBox(height: Insets.xl),

            // 3. Location & Directions
            _buildSectionHeader('Location & Landmark Directions', palette),
            const SizedBox(height: Insets.md),
            _buildTextField(
              controller: _howToFindUsController,
              label: 'How to find us (Landmarks)',
              hint: 'e.g. Past the roundabout, opposite the market',
              maxLines: 2,
              palette: palette,
            ),
            const SizedBox(height: Insets.md),
            _buildTextField(
              controller: _addressController,
              label: 'Street Address (if applicable)',
              palette: palette,
            ),
            const SizedBox(height: Insets.xl),

            // 4. Contact
            _buildSectionHeader('Direct Contact', palette),
            const SizedBox(height: Insets.md),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number (intl e.g. +1 268 555 0100)',
              keyboardType: TextInputType.phone,
              palette: palette,
            ),
            const SizedBox(height: Insets.md),
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number (+1 268 ...)',
              keyboardType: TextInputType.phone,
              palette: palette,
            ),
            const SizedBox(height: Insets.xl),

            // 5. Practical Tags
            _buildSectionHeader('Practical Amenities & Tags', palette),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final tag in KnownBusinessTags.all)
                  FilterChip(
                    label: Text(KnownBusinessTags.labelFor(tag)),
                    selected: _selectedTags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: palette.ink,
                    checkmarkColor: palette.app,
                    labelStyle: TextStyle(
                      color: _selectedTags.contains(tag)
                          ? palette.app
                          : palette.ink,
                      fontWeight: _selectedTags.contains(tag)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            // 6. Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveListing,
              style: FilledButton.styleFrom(
                backgroundColor: palette.ink,
                foregroundColor: palette.app,
                padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Corners.md),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & Verify Listing'),
            ),
            const SizedBox(height: Insets.giant),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppPalette palette) {
    return Text(
      title,
      style: AppText.titleMedium.copyWith(
        color: palette.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required AppPalette palette,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: AppText.bodyMedium.copyWith(color: palette.ink),
      decoration: _inputDecoration(label, palette, hint: hint),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    AppPalette palette, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppText.bodyMedium.copyWith(color: palette.muted),
      hintStyle: AppText.bodyMedium.copyWith(color: palette.muted),
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: palette.blue),
      ),
    );
  }
}
