import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:intl/intl.dart';

/// What a customer can ask a business for on WhatsApp, by category
/// (plan.md Phase 7: quotes for trades, slots for tours and salons).
enum RequestKind {
  /// "What would this cost?" Trades and car work.
  quote,

  /// "Can I come at this time?" Salons, tours, classes, viewings.
  slot,
}

/// The request a business's category offers, or null when it offers none
/// (a restaurant takes walk-ins; a shop has its prices on the shelf).
RequestKind? requestKindFor(BusinessCategory c) => switch (c) {
  BusinessCategory.services || BusinessCategory.automotive => RequestKind.quote,
  BusinessCategory.healthBeauty ||
  BusinessCategory.entertainment ||
  BusinessCategory.education ||
  BusinessCategory.realEstate => RequestKind.slot,
  _ => null,
};

/// The button label: a viewing for property, a slot for everything else.
String requestLabel(Business b) => switch (requestKindFor(b.category)) {
  RequestKind.quote => 'Request a quote',
  RequestKind.slot when b.category == BusinessCategory.realEstate =>
    'Request a viewing',
  RequestKind.slot => 'Request a slot',
  null => '',
};

/// The WhatsApp message. Says where the customer found the business, so the
/// business can see Dadliplug bringing it work (plan.md section 11).
String requestMessage({
  required Business business,
  required RequestKind kind,
  required String details,
  DateTime? when,
}) {
  final what = details.trim();
  final lines = <String>['Hi ${business.name}, I found you on Dadliplug.'];
  switch (kind) {
    case RequestKind.quote:
      lines.add(
        what.isEmpty
            ? 'Could I get a quote?'
            : 'Could I get a quote for: $what',
      );
    case RequestKind.slot:
      final slot = when == null
          ? null
          : '${DateFormat('EEEE d MMMM').format(when)} at '
                '${DateFormat.jm().format(when).replaceAll(' ', ' ')}';
      final thing = what.isEmpty
          ? (business.category == BusinessCategory.realEstate
                ? 'a viewing'
                : 'an appointment')
          : what;
      lines.add(
        slot == null
            ? 'I would like to book $thing. When do you have a slot?'
            : 'I would like to book $thing on $slot. Is that available?',
      );
  }
  return lines.join('\n');
}
