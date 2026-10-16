import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet allowing users to report inaccurate information.
///
/// Accuracy is the core promise of IslandAds. When users spot outdated
/// hours, dead numbers, or temporary closures, they can submit corrections
/// directly to the team moderation queue.
class ReportWrongInfoSheet extends ConsumerStatefulWidget {
  const ReportWrongInfoSheet({required this.business, super.key});

  final Business business;

  static Future<bool?> show(BuildContext context, Business business) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportWrongInfoSheet(business: business),
    );
  }

  @override
  ConsumerState<ReportWrongInfoSheet> createState() =>
      _ReportWrongInfoSheetState();
}

class _ReportWrongInfoSheetState extends ConsumerState<ReportWrongInfoSheet> {
  static const List<String> _reasons = [
    'Incorrect opening hours',
    'Phone or WhatsApp number disconnected',
    'Business is permanently closed or moved',
    'Closed today / temporary closure',
    'Wrong location / directions',
    'Outdated prices or menu',
    'Other error',
  ];

  String? _selectedReason = _reasons.first;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.reportWrongInfo(
        businessId: widget.business.id,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit report: $e'),
            backgroundColor: context.palette.bad,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // A `Material` wrapper, not just a painted `Container`.
    //
    // The reason list tiles need one is that they draw an ink splash on tap, and a
    // splash needs a Material to draw into. Painting the background with a
    // DecoratedBox instead leaves the RadioListTiles below with no Material
    // ancestor, which Flutter reports as an assertion and which means the tap
    // feedback silently does nothing on a real device.
    return Material(
      color: palette.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Corners.xl),
      ),
      elevation: 8,
      shadowColor: palette.ink.withValues(alpha: 0.3),
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.xl,
          right: Insets.xl,
          top: Insets.lg,
          bottom: Insets.xl + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  decoration: BoxDecoration(
                    color: palette.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.report_problem_outlined,
                    color: palette.bad,
                    size: 24,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Report wrong info',
                      style: AppText.titleLarge.copyWith(color: palette.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 20),
                    color: palette.muted,
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Help keep ${widget.business.name} up to date for everyone in Antigua.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                'What needs updating?',
                style: AppText.labelLarge.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Insets.sm),
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: (val) => setState(() => _selectedReason = val),
                child: Column(
                  children: [
                    for (final reason in _reasons)
                      RadioListTile<String>(
                        value: reason,
                        title: Text(
                          reason,
                          style: AppText.bodyMedium.copyWith(
                            color: palette.ink,
                          ),
                        ),
                        activeColor: palette.ink,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                style: AppText.bodyMedium.copyWith(color: palette.ink),
                decoration: InputDecoration(
                  hintText:
                      'Add details (optional)... e.g. "Closed on Tuesdays now"',
                  hintStyle: AppText.bodyMedium.copyWith(color: palette.muted),
                  filled: true,
                  fillColor: palette.app,
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
                ),
              ),
              const SizedBox(height: Insets.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.app,
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Corners.md),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
