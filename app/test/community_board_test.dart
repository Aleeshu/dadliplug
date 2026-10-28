import 'package:antigua_business_map/services/community_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommunityPost post(String id, {bool featured = false, int daysAgo = 0}) =>
      CommunityPost.fromMap({
        'id': id,
        'kind': 'for_sale',
        'title': 'Fridge',
        'body': 'Works fine, collect in town',
        'price_ec': 250,
        'area': 'St. Johns',
        'contact': '+1 (268) 555-0100',
        'image_url': null,
        'author_id': 'u',
        'status': 'live',
        'status_note': null,
        'featured': featured,
        'created_at': DateTime.utc(
          2026,
          10,
          28,
        ).subtract(Duration(days: daysAgo)).toIso8601String(),
        'expires_at': '2026-11-27T00:00:00Z',
      });

  test('featured posts first, then newest', () {
    final ordered = orderBoard([
      post('old', daysAgo: 5),
      post('paid', featured: true, daysAgo: 9),
      post('new'),
    ]);
    expect(ordered.map((p) => p.id), ['paid', 'new', 'old']);
  });

  test('every section survives a round trip through its stored name', () {
    for (final k in PostKind.values) {
      expect(PostKind.fromDb(k.dbName), k);
    }
  });

  test('a contact number becomes digits for WhatsApp and calls', () {
    expect(post('a').contactDigits, '12685550100');
  });
}
