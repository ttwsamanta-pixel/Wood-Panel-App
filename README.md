# Wood & Panel App

Premium Flutter news and magazine app for Wood & Panel, with a separate Core PHP + MySQL app API/admin dashboard.

## Current Status

Phase 1 foundation has been created:

- Flutter project configuration
- Riverpod app bootstrap
- Central app config, theme tokens, routing
- Reusable header, bottom navigation, cards, buttons, chips, empty states
- Splash, onboarding, home, explore, feed, magazine, profile, article, search, bookmarks, videos, downloads, wallpapers, subscribe, preferences, contact, grow-with-us, about, group media, clients, events, newsletter screens
- Mock repository isolated from future production WordPress/API repositories
- Starter Core PHP API/admin scaffold with PDO, JSON responses, secure session headers, CSRF helpers, and example endpoints

Phase 2 has started:

- Dio API client for the Wood & Panel WordPress REST API
- WordPress post mapping into app `Article` models
- Hybrid content repository with live WordPress data and isolated mock fallback
- Home, Feed, Article, Magazine, Events, and Search screens wired through repositories
- Debounced Search requests
- Local article bookmarks persisted with SharedPreferences

## Flutter Setup

Install Flutter stable, then run:

```bash
flutter pub get
flutter run
```

The app uses `logo.svg` from the project root as the official Wood & Panel logo asset.

## Architecture

```text
lib/
  app/
  core/
    config/
    theme/
  data/
    models/
    repositories/
  features/
  routing/
  widgets/
backend/
  api/
  admin/
  config/
  database/
```

WordPress content is intended to come through the WordPress REST API. App-specific settings, contact/newsletter submissions, banners, events, wallpapers, and admin controls belong in the Core PHP API.

## Environment

Copy `.env.example` for your backend host and configure real values outside source control. Do not commit secrets, Firebase private keys, database passwords, or WordPress database credentials.

## Backend Setup

Requirements:

- PHP 8.2+
- MySQL 8+
- HTTPS in production

Create a database and import:

```bash
mysql -u root -p wood_panel_app < backend/database/schema.sql
```

Point your web server document root to `backend/public` or route `/api/*` requests to `backend/api/index.php`.

## Next Phases

1. Replace mock repositories with WordPress REST repositories.
2. Add Drift/SQLite cache and bookmark persistence.
3. Integrate Firebase messaging, analytics, crash reporting, and remote config.
4. Expand PHP admin modules for posts, banners, ads, settings, push notifications, clients, events, wallpapers, and newsletters.
5. Add unit/widget/API tests once Flutter is installed locally.
