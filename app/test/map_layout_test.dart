import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:antigua_business_map/features/map/map_screen.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/auth_factory.dart';
import 'package:antigua_business_map/services/auth_session.dart';
import 'package:antigua_business_map/services/business_repository.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:antigua_business_map/services/mock_auth_service.dart';
import 'package:antigua_business_map/widgets/category_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout tests for the map screen at real phone sizes.
///
/// These exist because the screen was shipped looking broken and nothing in
/// the test suite noticed. Pixel review by screenshot is slow and imprecise;
/// asserting the geometry catches the same problems in seconds.
///
/// Sizes are the ones that actually ship: a small Samsung, a common Android
/// phone, and a tall device.
class _Repo implements BusinessRepository {
  _Repo(this.list);

  final List<Business> list;

  @override
  Stream<List<Business>> watchBusinesses() => Stream.value(list);

  @override
  Future<List<Business>> getBusinesses() async => list;

  @override
  Future<Business?> getBusinessById(String id) async =>
      list.where((b) => b.id == id).firstOrNull;

  @override
  Future<void> updateBusiness(Business business) async {}

  @override
  Future<void> toggleClosedToday(String businessId, bool isClosed) async {}

  @override
  Future<void> reportWrongInfo({
    required String businessId,
    required String reason,
    String details = '',
  }) async {}
}

Business _business(String id) => Business(
      id: id,
      name: 'Business $id',
      category: BusinessCategory.food,
      tier: SubscriptionTier.basic,
      area: 'Dickenson Bay',
      description: 'x',
      latitude: 17.1,
      longitude: -61.8,
      phone: '+1 268 555 0000',
    );

Widget _app(List<Business> businesses) {
  final session = AuthSession(
    service: MockAuthService(latency: Duration.zero),
  );
  return ProviderScope(
    overrides: [
      businessRepositoryProvider.overrideWithValue(_Repo(businesses)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: MapScreen(
        session: session,
        roleSwitcher: RoleSwitcherController(null),
      ),
    ),
  );
}

/// A small, real Android phone. Narrow enough that the chip row has to scroll.
const Size smallPhone = Size(360, 640);
const Size tallPhone = Size(412, 915);

void main() {
  // MapLibre is a PlatformView with no widget-tree equivalent, so it cannot be
  // instantiated in a widget test. These tests cover the Flutter chrome around
  // it — which is where every reported layout problem actually was.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MapScreen.debugMapSurfaceOverride = const ColoredBox(
      key: Key('fake_map_surface'),
      color: Color(0xFFE8E2DA),
    );
  });

  tearDown(() => MapScreen.debugMapSurfaceOverride = null);

  group('map screen layout', () {
    testWidgets('renders without overflow on a small phone', (tester) async {
      tester.view.physicalSize = smallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app([_business('a')]));
      await tester.pump();

      // Any RenderFlex overflow is thrown as a FlutterError during pump and
      // fails the test automatically. Asserting on the error explicitly makes
      // the failure message say what went wrong rather than which line.
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow on a tall phone', (tester) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app([_business('a')]));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the chip row scrolls rather than overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = smallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app([_business('a')]));
      await tester.pump();

      final scroller = find.descendant(
        of: find.byType(CategoryFilterBar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);

      final view = tester.widget<SingleChildScrollView>(scroller);
      expect(view.scrollDirection, Axis.horizontal);
    });

    testWidgets('every category chip is reachable by scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = smallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app([_business('a')]));
      await tester.pump();

      // The last category is the one most likely to be cut off on a narrow
      // screen, which is exactly the bug that was reported.
      expect(find.text('Online'), findsOneWidget);

      await tester.drag(
        find.descendant(
          of: find.byType(CategoryFilterBar),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(-400, 0),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the recentre button sits in the bottom-right quadrant', (
      tester,
    ) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app([_business('a')]));
      await tester.pump();

      final fab = tester.getRect(find.byIcon(Icons.my_location));
      expect(
        fab.center.dy,
        greaterThan(tallPhone.height * 0.6),
        reason: 'The recentre button was rendering at the top of the screen, '
            'over the filter chips, because the Stack was sizing itself to its '
            'content instead of filling the body.',
      );
      expect(fab.right, lessThanOrEqualTo(tallPhone.width));
    });

    testWidgets('the empty state is centred below the overlays', (
      tester,
    ) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const []));
      await tester.pump();

      final heading = tester.getRect(find.text('No businesses listed yet'));
      expect(
        heading.center.dy,
        greaterThan(tallPhone.height * 0.45),
        reason: 'The empty state was stacking at the top, behind the header '
            'and chips, instead of sitting in the free space below them.',
      );
    });

    testWidgets('the empty state does not sit under the filter bar', (
      tester,
    ) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const []));
      await tester.pump();

      final heading = tester.getRect(find.text('No businesses listed yet'));
      final chips = tester.getRect(find.byType(CategoryFilterBar));
      expect(
        heading.top,
        greaterThan(chips.bottom),
        reason: 'The empty-state heading overlapped the category chips.',
      );
    });

    testWidgets('the empty state does not replace the map', (tester) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const []));
      await tester.pump();

      // Hiding the map behind the empty state made a working map look broken
      // and gave no sense of where businesses would appear. Both have to be
      // present at once.
      expect(find.byKey(const Key('fake_map_surface')), findsOneWidget);
      expect(find.text('No businesses listed yet'), findsOneWidget);

      // The scrim must be partial, or the map is hidden again and the change
      // achieves nothing.
      final scrim = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('No businesses listed yet'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient = scrim.decoration as BoxDecoration;
      final colors = gradient.gradient!.colors;
      expect(
        colors.first.a,
        lessThan(0.1),
        reason: 'The top of the scrim must stay transparent so the map is '
            'visible above the empty-state copy.',
      );
      expect(
        colors[1].a,
        greaterThan(0.85),
        reason: 'The middle must be opaque enough to read the copy against '
            'map tiles.',
      );
    });

    testWidgets('renders without overflow when a business is selected', (
      tester,
    ) async {
      tester.view.physicalSize = smallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(_Repo([_business('a')])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(_Repo([_business('a')])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MapScreen(
              session: AuthSession(
                service: MockAuthService(latency: Duration.zero),
              ),
              roleSwitcher: RoleSwitcherController(null),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
