import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/orders/presentation/order_create_screen.dart';
import '../../features/orders/presentation/order_list_screen.dart';
import '../../features/services/presentation/service_list_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, _) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isAuth = authState.isAuthenticated;
    final path = state.uri.path;

    final isAuthRoute = path == '/login' || path == '/register';
    final isPublicRoute = isAuthRoute || path == '/health' || path.startsWith('/track/');

    // Unauthenticated trying to access protected route -> redirect to login
    if (!isAuth && !isPublicRoute) {
      return '/login';
    }

    // Authenticated trying to access login/register -> redirect to dashboard
    if (isAuth && isAuthRoute) {
      return '/dashboard';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) => const CustomerListScreen(),
      ),
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) => const ServiceListScreen(),
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => const OrderListScreen(),
      ),
      GoRoute(
        path: '/orders/create',
        name: 'orders_create',
        builder: (context, state) => const OrderCreateScreen(),
      ),
      GoRoute(
        path: '/health',
        name: 'health',
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(
        path: '/track/:token',
        name: 'track',
        builder: (context, state) => TrackingScreen(
          token: state.pathParameters['token'] ?? '',
        ),
      ),
    ],
  );
});
