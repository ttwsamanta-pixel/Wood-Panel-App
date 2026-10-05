import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/article/article_detail_screen.dart';
import '../features/common/simple_screens.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../data/repositories/download_repository.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/explore', builder: (context, state) => const ExploreScreen()),
      GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
      GoRoute(
          path: '/magazine',
          builder: (context, state) => const MagazineScreen()),
      GoRoute(
          path: '/magazine/archive/:year',
          builder: (context, state) => MagazineArchiveScreen(
                year: int.tryParse(state.pathParameters['year'] ?? '') ??
                    DateTime.now().year,
              )),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/article/:id',
        builder: (context, state) => ArticleDetailScreen(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
          path: '/interview/:id',
          builder: (context, state) => const InterviewDetailScreen()),
      GoRoute(
        path: '/legacy-interview',
        builder: (context, state) => LegacyInterviewDetailScreen(
          url: state.uri.queryParameters['url'] ?? '',
        ),
      ),
      GoRoute(
          path: '/videos', builder: (context, state) => const VideosScreen()),
      GoRoute(
          path: '/video/:id',
          builder: (context, state) =>
              VideoPlayerScreen(videoId: state.pathParameters['id'] ?? '')),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) => CategoryNewsScreen(
          categoryId: int.tryParse(state.pathParameters['id'] ?? '') ?? 30036,
        ),
      ),
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarksScreen()),
      GoRoute(
          path: '/magazine/:id',
          builder: (context, state) => MagazineDetailScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              )),
      GoRoute(
          path: '/magazine/:id/read',
          builder: (context, state) => MagazineReaderScreen(
                id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              )),
      GoRoute(
          path: '/downloads',
          builder: (context, state) => const DownloadsScreen()),
      GoRoute(
        path: '/downloaded-pdf',
        builder: (context, state) {
          final file = state.extra;
          if (file is DownloadedFile) {
            return DownloadedPdfScreen(file: file);
          }
          return const DownloadsScreen();
        },
      ),
      GoRoute(
          path: '/wallpapers',
          builder: (context, state) => const WallpapersScreen()),
      GoRoute(
          path: '/subscribe',
          builder: (context, state) => const SubscribeScreen()),
      GoRoute(
          path: '/preferences',
          builder: (context, state) => const PreferencesScreen()),
      GoRoute(
          path: '/contact', builder: (context, state) => const ContactScreen()),
      GoRoute(
          path: '/grow-with-us',
          builder: (context, state) => const GrowWithUsScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
          path: '/group-media',
          builder: (context, state) => const GroupMediaScreen()),
      GoRoute(
          path: '/clients', builder: (context, state) => const ClientsScreen()),
      GoRoute(
          path: '/events', builder: (context, state) => const EventsScreen()),
      GoRoute(
          path: '/newsletter',
          builder: (context, state) => const NewsletterScreen()),
    ],
  );
});
