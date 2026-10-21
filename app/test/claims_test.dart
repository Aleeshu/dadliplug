import 'package:antigua_business_map/services/claims.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Map<String, dynamic> row({Map<String, dynamic>? business}) => {
    'id': 'c1',
    'business_id': 'b1',
    'contact_name': 'Shirley Joseph',
    'contact_phone': '+1 268 555 0101',
    'role_at_business': 'Owner',
    'note': null,
    'created_at': '2026-10-21T14:00:00Z',
    'businesses': business,
  };

  test("the team is shown the number on the listing, not the claimant's", () {
    final c = ListingClaim.fromMap(
      row(business: {'name': 'Shirley Plumbing', 'phone': '+1 268 555 0000'}),
    );
    expect(c.businessName, 'Shirley Plumbing');
    expect(c.listedPhone, '+1 268 555 0000');
    expect(c.contactPhone, '+1 268 555 0101');
  });

  test('a listing with only WhatsApp is verified on that', () {
    final c = ListingClaim.fromMap(
      row(business: {'name': 'x', 'phone': null, 'whatsapp': '12685550002'}),
    );
    expect(c.listedPhone, '12685550002');
  });

  test('a claim whose listing cannot be read still shows', () {
    final c = ListingClaim.fromMap(row());
    expect(c.businessName, 'Unknown listing');
    expect(c.listedPhone, isNull);
  });

  test('database refusals are shown in their own words', () {
    expect(
      claimErrorMessage(
        const PostgrestException(
          message: 'Your claim is already with the team',
        ),
      ),
      'Your claim is already with the team',
    );
    expect(claimErrorMessage(Exception('socket')), contains('signal'));
  });
}
