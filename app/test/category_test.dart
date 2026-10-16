import 'package:antigua_business_map/features/discovery/categories_screen.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The nine design categories and how they are stored.
void main() {
  test('there are exactly the nine categories from the design', () {
    expect(BusinessCategory.values.map((c) => c.label), [
      'Food & Drink',
      'Shopping',
      'Services',
      'Health & Beauty',
      'Entertainment',
      'Automotive',
      'Real Estate',
      'Education',
      'Other',
    ]);
  });

  test('every category survives a round trip through the database name', () {
    for (final c in BusinessCategory.values) {
      expect(BusinessCategoryX.fromName(c.dbName), c, reason: c.dbName);
    }
  });

  test('database names match the CHECK constraint in the migration', () {
    // supabase/migrations/20261015120000_design_categories.sql
    expect(BusinessCategory.values.map((c) => c.dbName).toSet(), {
      'food',
      'shopping',
      'services',
      'health_beauty',
      'entertainment',
      'automotive',
      'real_estate',
      'education',
      'other',
    });
  });

  test('an unknown category is Other, never a guess at a real one', () {
    expect(BusinessCategoryX.fromName('nonsense'), BusinessCategory.other);
    expect(BusinessCategoryX.fromName(''), BusinessCategory.other);
  });

  testWidgets('the Categories screen lists all nine', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    for (final c in BusinessCategory.values) {
      await tester.scrollUntilVisible(find.text(c.label), 80);
      expect(find.text(c.label), findsOneWidget);
    }
  });
}
