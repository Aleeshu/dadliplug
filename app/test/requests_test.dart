import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business(BusinessCategory category) => Business(
    id: 'b',
    name: 'Shirley Plumbing',
    category: category,
    tier: SubscriptionTier.basic,
    area: 'x',
    description: 'x',
  );

  test('trades get quotes, appointments get slots, shops get neither', () {
    expect(requestKindFor(BusinessCategory.services), RequestKind.quote);
    expect(requestKindFor(BusinessCategory.automotive), RequestKind.quote);
    expect(requestKindFor(BusinessCategory.healthBeauty), RequestKind.slot);
    expect(requestKindFor(BusinessCategory.realEstate), RequestKind.slot);
    expect(requestKindFor(BusinessCategory.food), isNull);
    expect(requestKindFor(BusinessCategory.shopping), isNull);
  });

  test('property asks for a viewing', () {
    expect(
      requestLabel(business(BusinessCategory.realEstate)),
      'Request a viewing',
    );
    expect(
      requestLabel(business(BusinessCategory.services)),
      'Request a quote',
    );
    expect(
      requestLabel(business(BusinessCategory.education)),
      'Request a slot',
    );
  });

  test('every message says it came from Dadliplug', () {
    for (final kind in RequestKind.values) {
      final text = requestMessage(
        business: business(BusinessCategory.services),
        kind: kind,
        details: '',
      );
      expect(
        text,
        startsWith('Hi Shirley Plumbing, I found you on Dadliplug.'),
      );
    }
  });

  test('a quote carries what the customer needs, trimmed', () {
    final text = requestMessage(
      business: business(BusinessCategory.services),
      kind: RequestKind.quote,
      details: '  Leaking tap  ',
    );
    expect(text, endsWith('Could I get a quote for: Leaking tap'));
  });

  test('a slot names the day and time asked for', () {
    final text = requestMessage(
      business: business(BusinessCategory.healthBeauty),
      kind: RequestKind.slot,
      details: 'Box braids',
      when: DateTime(2026, 10, 23, 14, 30),
    );
    expect(text, contains('book Box braids on Friday 23 October at 2:30'));
    expect(text, endsWith('Is that available?'));
  });

  test('a viewing with no details or time still reads naturally', () {
    final text = requestMessage(
      business: business(BusinessCategory.realEstate),
      kind: RequestKind.slot,
      details: ' ',
    );
    expect(
      text,
      endsWith('I would like to book a viewing. When do you have a slot?'),
    );
  });
}
