/*
In this file define all the routes for the application.
You need import all the screens and providers that you will use in the routes.
*/

// import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// import 'package:web_admin/views/screens/buttons_screen.dart';
// import 'package:web_admin/views/screens/colors_screen.dart';
// import 'package:web_admin/views/screens/crud_detail_screen.dart';
// import 'package:web_admin/views/screens/crud_screen.dart';
// import 'package:web_admin/views/screens/text_screen.dart';
// import 'package:web_admin/views/screens/dialogs_screen.dart';
// import 'package:web_admin/views/screens/form_screen.dart';
// import 'package:web_admin/views/screens/general_ui_screen.dart';
// import 'package:web_admin/views/screens/iframe_demo_screen.dart';
// import 'package:web_admin/views/screens/register_screen.dart';
// import 'package:web_admin/views/screens/send_reset_password.dart';

//other temp modules
import 'package:web_admin/views/screens/addons_templates/addons_order_track_screen.dart';
import 'package:web_admin/views/screens/addons_templates/addons_rewards_screen.dart';
import 'package:web_admin/views/screens/addons_templates/addons_faq_screen.dart';
import 'package:web_admin/views/screens/addons_templates/addons_help_screen.dart';
import 'package:web_admin/views/screens/addons_templates/addons_contact_screen.dart';
import 'package:web_admin/views/screens/addons_templates/addons_live_chat_screen.dart';

import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/views/screens/general_settings_screen.dart';

import 'package:web_admin/splash.dart';
import 'package:web_admin/views/screens/login_screen.dart';
import 'package:web_admin/views/screens/logout_screen.dart';
import 'package:web_admin/views/screens/my_profile_screen.dart';
import 'package:web_admin/views/screens/error_screen.dart';

/* New screens*/
import 'package:web_admin/views/screens/dashboard_screen.dart';
// sales
import 'package:web_admin/views/screens/sales_history_screen.dart';
import 'package:web_admin/views/screens/sales_report_screen.dart';
//
import 'package:web_admin/views/screens/inventory_screen.dart';
import 'package:web_admin/views/screens/tour_management_screen.dart';
import 'package:web_admin/views/screens/deliveries_screen.dart';
import 'package:web_admin/views/screens/customers_screen.dart';
//settings
import 'package:web_admin/views/screens/addons_templates/addons_password_change_screen.dart';
import 'package:web_admin/views/screens/security_options_screen.dart';
import 'package:web_admin/views/screens/privacy_screen.dart';

import 'views/screens/sales_register_pos_screen 2.dart';

class RouteUri {
  static const String home = '/';
  static const String myProfile = '/my-profile';
  static const String logout = '/logout';
  static const String form = '/form';
  static const String generalUi = '/general-ui';
  static const String colors = '/colors';
  static const String text = '/text';
  static const String buttons = '/buttons';
  static const String dialogs = '/dialogs';
  static const String error404 = '/404';
  static const String login = '/login';
  static const String register = '/register';
  static const String crud = '/crud';
  static const String crudDetail = '/crud-detail';
  static const String iframe = '/iframe';
  static const String orderTrack = '/order-track';

  // new routes pos
  static const String splash = '/splash'; // this is the initial screen
  static const String dashboard = '/dashboard';
  static const String salesRegister = '/sales-register-pos';
  static const String salesHistory = '/sales-history';
  static const String salesReport = '/sales-report';
  static const String inventory = '/inventory';
  static const String tourManagement = '/tour-management';
  static const String deliveries = '/deliveries';
  static const String customers = '/customers';
  static const String generalSettings = '/general-settings';
  static const String passwordChange = '/password-change';
  static const String securityOptions = '/security-options';
  static const String privacy = '/privacy';
  static const String resetPassword = '/reset-password';

  //customer portal
  static const String billing = '/billing';
  static const String rewards = '/rewards';
  static const String faq = '/faq';
  static const String help = '/help';
  static const String contact = '/contact';
  static const String liveChat = '/live-chat';
  static const String products = '/products';
}

// Define the unrestricted and public routes.
const List<String> unrestrictedRoutes = [
  RouteUri.error404,
  RouteUri.logout,
  RouteUri.login,
  RouteUri.register,
  RouteUri.resetPassword,
  RouteUri.splash,
];

const List<String> publicRoutes = [
  RouteUri.login,
  RouteUri.register,
  RouteUri.resetPassword,
  RouteUri.splash,
];

GoRouter appRouter(UserDataProvider userDataProvider) {
  return GoRouter(
    //default screen
    initialLocation: RouteUri.splash,
    //error screen
    errorPageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: const ErrorScreen(),
    ),
    routes: [
      /// new routes
      // ********************
      //     * splash *
      // *********************
      GoRoute(
        path: RouteUri.splash,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SplashWidget(),
        ),
      ),
      // ********************
      /// *Login*
      /// ********************
      GoRoute(
        path: RouteUri.login,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          );
        },
      ),

      // ********************
      //     * Home *
      // ********************

      GoRoute(
        path: RouteUri.home,
        redirect: (context, state) => RouteUri.dashboard,
      ),

      GoRoute(
        path: RouteUri.dashboard,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          );
        },
      ),

      // ******************************
      //     * Sales *
      // ******************************
      GoRoute(
        path: RouteUri.salesRegister,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const PosSystem(),
        ),
      ),
      GoRoute(
        path: RouteUri.salesHistory,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SalesHistory(),
        ),
      ),

      GoRoute(
        path: RouteUri.salesReport,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SalesReport(),
        ),
      ),

      // ******************************
      //     * Inventory *
      // ******************************
      GoRoute(
        path: RouteUri.inventory,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Inventory(),
        ),
      ),

      GoRoute(
        path: RouteUri.tourManagement,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const TourManagementScreen(),
        ),
      ),

      // ******************************
      //     * Deliveries *
      // ******************************

      GoRoute(
        path: RouteUri.deliveries,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Deliveries(),
        ),
      ),

      // ******************************
      //     * Customers *
      // ******************************

      GoRoute(
        path: RouteUri.customers,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Customers(),
        ),
      ),

      // ******************************
      //     * Settings *
      // ******************************
      GoRoute(
        path: RouteUri.generalSettings,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const GeneralSettings(),
        ),
      ),
      GoRoute(
        path: RouteUri.passwordChange,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const PasswordChange(),
        ),
      ),
      GoRoute(
        path: RouteUri.securityOptions,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SecurityOptions(),
        ),
      ),
      GoRoute(
        path: RouteUri.privacy,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Privacy(),
        ),
      ),

      //********************************
      /// extra modules customer portal
      //
      //****************************
      //     * Reset Password *
      //****************************
      // GoRoute(
      //   path: RouteUri.resetPassword,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const SendResetPassword(),
      //   ),
      // ),

      //****************************
      //     * Register new user *
      //****************************

      // GoRoute(
      //   path: RouteUri.register,
      //   pageBuilder: (context, state) {
      //     return NoTransitionPage<void>(
      //       key: state.pageKey,
      //       child: const RegisterScreen(),
      //     );
      //   },
      // ),

      GoRoute(
        path: RouteUri.myProfile,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const MyProfileScreen(),
        ),
      ),
      GoRoute(
        path: RouteUri.logout,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const LogoutScreen(),
        ),
      ),

      GoRoute(
        path: RouteUri.orderTrack,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const OrderTrack(),
        ),
      ),
      // ******************************
      //     * Product and services *
      // ******************************
      GoRoute(
        path: RouteUri.products,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const PosSystem(),
        ),
      ),

      // ******************************
      //     * Rewards *
      // ******************************
      GoRoute(
        path: RouteUri.rewards,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Rewards(),
        ),
      ),
      // ******************************
      //     * Support *
      // ******************************
      GoRoute(
        path: RouteUri.faq,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Faq(),
        ),
      ),

      GoRoute(
        path: RouteUri.help,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Help(),
        ),
      ),

      GoRoute(
        path: RouteUri.contact,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const Contact(),
        ),
      ),

      GoRoute(
        path: RouteUri.liveChat,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const LiveChat(),
        ),
      ),

      // GoRoute(
      //   path: RouteUri.form,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const FormScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteUri.generalUi,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const GeneralUiScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteUri.colors,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const ColorsScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteUri.text,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const TextScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteUri.buttons,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const ButtonsScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteUri.dialogs,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const DialogsScreen(),
      //   ),
      // ),

      // GoRoute(
      //   path: RouteUri.crud,
      //   pageBuilder: (context, state) {
      //     return NoTransitionPage<void>(
      //       key: state.pageKey,
      //       child: const CrudScreen(),
      //     );
      //   },
      // ),
      // GoRoute(
      //   path: RouteUri.crudDetail,
      //   pageBuilder: (context, state) {
      //     return NoTransitionPage<void>(
      //       key: state.pageKey,
      //       child: CrudDetailScreen(id: state.uri.queryParameters['id'] ?? ''),
      //     );
      //   },
      // ),
      // GoRoute(
      //   path: RouteUri.iframe,
      //   pageBuilder: (context, state) => NoTransitionPage<void>(
      //     key: state.pageKey,
      //     child: const IFrameDemoScreen(),
      //   ),
      // ),
    ],
    redirect: (context, state) {
      if (unrestrictedRoutes.contains(state.matchedLocation)) {
        return null;
      } else if (publicRoutes.contains(state.matchedLocation)) {
        // Is public route.
        if (userDataProvider.isUserLoggedIn()) {
          // User is logged in, redirect to home page.
          return RouteUri.home;
        }
      } else {
        // Not public route.
        if (!userDataProvider.isUserLoggedIn()) {
          // User is not logged in, redirect to login page.
          return RouteUri.login;
        }
      }

      return null;
    },
  );
}
