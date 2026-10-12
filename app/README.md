# App

Flutter app, iOS + Android, one codebase. Phase 2 complete.

```
lib/
  core/
    config/      app_config.dart, map_defaults.dart
    routing/     app_router.dart, app_tabs.dart, stub_scaffold.dart
    theme/       app_colors.dart, app_spacing.dart, app_text.dart, app_theme.dart
  models/        business.dart, business_category.dart, review.dart, user.dart
  services/      auth_service, supabase_auth_service, mock_auth_service,
                 auth_session, auth_factory, error_mapper,
                 ranking_service, opening_hours_service, listing_filter_service
  features/      auth, map, listing, discovery, search, reviews,
                 business_admin, team_admin
test/            auth_test, app_smoke_test, ranking_service_test,
                 opening_hours_service_test
```

## Status

Implemented and tested:
- Design system, light and dark, ported 1:1 from the prototype
- Routing with role-based tabs and route guards
- Auth: email, Google, password reset, roles, session
- Domain models: Business, OpeningHours, MenuItem, Review, Visit, User, Subscription
- Ranking formula, ported from the prototype
- Spotlight rotation, 10 slots, least-recently-featured first
- Opening hours in Antigua time
- Listing filter and sort

Working screens: map placeholder, sign in, sign up, profile.
Still stubs: explore, your places, listing, search, business and team areas.

## Auth

`AuthSession` is the only thing screens talk to. It wraps whichever
`AuthService` is active, so swapping the mock for Supabase changes nothing
above that line.

Without Supabase keys the app uses `MockAuthService` and shows a role switcher,
which is how the team reaches all three tab sets on a device. Release builds
refuse to start without keys rather than ship mock auth.

## Roles

Three roles in one app. Tab sets and route guards derive from the role. Real
enforcement is Row Level Security — see `backend/README.md`.

## Fonts

Gabarito, Hanken Grotesk and IBM Plex Mono are declared by family name but not
bundled. The app falls back to system fonts. Bundle before release.

## Known environment issue

Spaces in `C:\Users\wilheim leeshu` break `flutter test` and `flutter build`.
See `docs/build-environment.md`.