import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/portal_header_time_helper.dart';
import 'package:web_admin/master_layout_config.dart';
import 'package:web_admin/theme/theme_extensions/app_sidebar_theme.dart';
// import 'package:web_admin/utils/database_helper.dart';
import 'package:web_admin/views/widgets/portal_master_layout/sidebar.dart';

class LocaleMenuConfig {
  final String languageCode;
  final String? scriptCode;
  final String name;

  const LocaleMenuConfig({
    required this.languageCode,
    this.scriptCode,
    required this.name,
  });
}

class PortalMasterLayout extends StatefulWidget {
  final Widget body;
  final bool autoSelectMenu;
  final String? selectedMenuUri;
  final void Function(bool isOpened)? onDrawerChanged;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;

  const PortalMasterLayout({
    super.key,
    required this.body,
    this.autoSelectMenu = true,
    this.selectedMenuUri,
    this.onDrawerChanged,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
  });

  @override
  PortalMasterLayoutState createState() => PortalMasterLayoutState();
}

class PortalMasterLayoutState extends State<PortalMasterLayout> {
  String? _userName;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _getUserName();
    _startTime = DateTime.now();
    _loadStartTime();
  }

  Future<void> _getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(StorageKeys.userName) ?? '';
  }

// load the time saved
  Future<void> _loadStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeMillis = prefs.getInt('startTime');

    if (startTimeMillis == null) {
      // if is null, set the time
      // _startTime = DateTime.now();
      // await prefs.setInt('startTime', _startTime.millisecondsSinceEpoch);
    } else {
      _startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    }

    setState(() {}); // update the screen
  }

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final drawer = (mediaQueryData.size.width <= kScreenWidthResponsive
        ? _sidebar(context)
        : null);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(42.0),
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 52, 1, 1),
          automaticallyImplyLeading: (drawer != null),
          flexibleSpace: Stack(
            children: [
              Positioned(
                left: 60,
                top: 11,
                child: _buildClock(),
              ),
              Positioned(
                right: 150,
                top: 11,
                child: _buildDateTimeClock(),
              ),
              Center(
                child: Text(
                  "~ Welcome, ${_userName ?? 'Guest'} ~",
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: drawer,
      drawerEnableOpenDragGesture: false,
      onDrawerChanged: widget.onDrawerChanged,
      body: _responsiveBody(context),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      floatingActionButtonAnimator: widget.floatingActionButtonAnimator,
      persistentFooterButtons: widget.persistentFooterButtons,
    );
  }

  Widget _responsiveBody(BuildContext context) {
    if (MediaQuery.of(context).size.width <= kScreenWidthResponsive) {
      return widget.body;
    } else {
      return Row(
        children: [
          SizedBox(
            width: Theme.of(context).extension<AppSidebarTheme>()!.sidebarWidth,
            child: _sidebar(context),
          ),
          Expanded(child: widget.body),
        ],
      );
    }
  }

  Widget _sidebar(BuildContext context) {
    final goRouter = GoRouter.of(context);

    return Sidebar(
      autoSelectMenu: widget.autoSelectMenu,
      selectedMenuUri: widget.selectedMenuUri,
      onAccountButtonPressed: () => goRouter.go(RouteUri.myProfile),
      onLogoutButtonPressed: () => goRouter.go(RouteUri.logout),
      sidebarConfigs: sidebarMenuConfigs,
    );
  }

  Widget _buildClock() {
    return StreamBuilder<int>(
      stream:
          Stream<int>.periodic(const Duration(seconds: 30), (count) => count),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final elapsed = DateTime.now().difference(_startTime);
          final formattedTime = PortalHeaderTimeHelper.formatElapsed(elapsed);
          return Text(
            formattedTime,
            style: const TextStyle(fontSize: 13),
          );
        } else {
          return const Text(
            '00:00',
            style: TextStyle(fontSize: 13),
          );
        }
      },
    );
  }

  Widget _buildDateTimeClock() {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
          const Duration(seconds: 30), (_) => DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final time = snapshot.data!;
          final formattedDateTime =
              PortalHeaderTimeHelper.formatDateTimeWithoutSeconds(time);
          return Text(
            formattedDateTime,
            style: const TextStyle(fontSize: 13),
          );
        } else {
          return const Text(
            '',
            style: TextStyle(fontSize: 13),
          );
        }
      },
    );
  }
}
