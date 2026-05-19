import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/generated/l10n.dart';
import 'package:web_admin/master_layout_config.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/services/marnisi_api_service.dart';
import 'package:web_admin/theme/theme_extensions/app_sidebar_theme.dart';
import 'package:web_admin/helpers/txn_helper.dart';

class SidebarMenuConfig {
  final String uri;
  final IconData icon;
  final String Function(BuildContext context) title;
  final List<SidebarChildMenuConfig> children;
  final Set<String> visibleForRoles;

  const SidebarMenuConfig({
    required this.uri,
    required this.icon,
    required this.title,
    List<SidebarChildMenuConfig>? children,
    Set<String>? visibleForRoles,
  })  : children = children ?? const [],
        visibleForRoles = visibleForRoles ?? const {};
}

class SidebarChildMenuConfig {
  final String uri;
  final IconData icon;
  final String Function(BuildContext context) title;
  final List<SidebarChildMenuConfig> children;
  final Set<String> visibleForRoles;

  const SidebarChildMenuConfig({
    required this.uri,
    required this.icon,
    required this.title,
    List<SidebarChildMenuConfig>? children,
    Set<String>? visibleForRoles,
  })  : children = children ?? const [],
        visibleForRoles = visibleForRoles ?? const {};
}

class Sidebar extends StatefulWidget {
  final bool autoSelectMenu;
  final String? selectedMenuUri;
  final void Function() onAccountButtonPressed;
  final void Function() onLogoutButtonPressed;
  final List<SidebarMenuConfig> sidebarConfigs;

  const Sidebar({
    super.key,
    this.autoSelectMenu = true,
    this.selectedMenuUri,
    required this.onAccountButtonPressed,
    required this.onLogoutButtonPressed,
    required this.sidebarConfigs,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final _scrollController = ScrollController();
  final _marnisiApi = const MarnisiApiService();
  Set<String> _marnisiRoles = const {};

  @override
  void initState() {
    super.initState();
    _loadMarnisiRoles();
  }

  Future<void> _loadMarnisiRoles() async {
    try {
      final context = await _marnisiApi.getContext();
      if (!mounted) return;
      setState(() {
        _marnisiRoles = context.roles.toSet();
      });
    } catch (_) {
      // Keep sidebar functional even when Marnisi context is unavailable.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final mediaQueryData = MediaQuery.of(context);
    final themeData = Theme.of(context);
    final sidebarTheme = themeData.extension<AppSidebarTheme>()!;

    return Drawer(
      child: Column(
        children: [
          Visibility(
            visible: (mediaQueryData.size.width <= kScreenWidthResponsive),
            child: Container(
              alignment: Alignment.centerLeft,
              height: kToolbarHeight,
              padding: const EdgeInsets.only(left: 0),
              child: IconButton(
                onPressed: () {
                  if (Scaffold.of(context).isDrawerOpen) {
                    Scaffold.of(context).closeDrawer();
                  }
                },
                icon: const Icon(Icons.close_rounded),
                color: sidebarTheme.foregroundColor,
                tooltip: lang.closeNavigationMenu,
              ),
            ),
          ),
          Visibility(
            visible: (mediaQueryData.size.width < kScreenWidthSm),
            child: Container(
              padding: const EdgeInsets.only(
                  right: Checkbox.width, top: kDefaultPadding * 0.7),
              alignment: Alignment.center,
              height: 50.0,
              child: SvgPicture.asset(
                'assets/images/CassarCamilleriLogo.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Theme(
              data: themeData.copyWith(
                scrollbarTheme: themeData.scrollbarTheme.copyWith(
                  thumbColor: WidgetStateProperty.all(
                      sidebarTheme.foregroundColor.withOpacity(0.2)),
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    sidebarTheme.sidebarLeftPadding,
                    sidebarTheme.sidebarTopPadding,
                    sidebarTheme.sidebarRightPadding,
                    sidebarTheme.sidebarBottomPadding,
                  ),
                  children: [
                    SidebarHeader(
                      onAccountButtonPressed: widget.onAccountButtonPressed,
                      onLogoutButtonPressed: widget.onLogoutButtonPressed,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(
                        height: 2.0,
                        thickness: 1.0,
                        color: sidebarTheme.foregroundColor.withOpacity(0.5),
                      ),
                    ),
                    _sidebarMenuList(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarMenuList(BuildContext context) {
    final sidebarTheme = Theme.of(context).extension<AppSidebarTheme>()!;

    var currentLocation = widget.selectedMenuUri ?? '';

    if (currentLocation.isEmpty && widget.autoSelectMenu) {
      currentLocation = GoRouter.of(context)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();
    }

    final visibleMenus = widget.sidebarConfigs
        .where((menu) => _isVisibleForRoles(menu.visibleForRoles))
        .toList();

    return Column(
      children: visibleMenus.map<Widget>((menu) {
        final visibleChildren = menu.children
            .where((child) => _isVisibleForRoles(child.visibleForRoles))
            .toList(growable: false);

        if (menu.children.isNotEmpty && visibleChildren.isEmpty) {
          return const SizedBox.shrink();
        }

        if (menu.children.isEmpty) {
          return _sidebarMenu(
            context,
            EdgeInsets.fromLTRB(
              sidebarTheme.menuLeftPadding,
              sidebarTheme.menuTopPadding,
              sidebarTheme.menuRightPadding,
              sidebarTheme.menuBottomPadding,
            ),
            menu.uri,
            menu.icon,
            menu.title(context),
            (currentLocation.startsWith(menu.uri)),
          );
        } else {
          return _expandableSidebarMenu(
            context,
            EdgeInsets.fromLTRB(
              sidebarTheme.menuLeftPadding,
              sidebarTheme.menuTopPadding,
              sidebarTheme.menuRightPadding,
              sidebarTheme.menuBottomPadding,
            ),
            menu.uri,
            menu.icon,
            menu.title(context),
            visibleChildren,
            currentLocation,
          );
        }
      }).toList(growable: false),
    );
  }

  bool _isVisibleForRoles(Set<String> requiredRoles) {
    if (requiredRoles.isEmpty) return true;
    if (_marnisiRoles.isEmpty) {
      return true;
    }
    for (final role in requiredRoles) {
      if (_marnisiRoles.contains(role)) {
        return true;
      }
    }
    return false;
  }

  Widget _sidebarMenu(
    BuildContext context,
    EdgeInsets padding,
    String uri,
    IconData icon,
    String title,
    bool isSelected,
  ) {
    final sidebarTheme = Theme.of(context).extension<AppSidebarTheme>()!;
    final textColor = (isSelected
        ? sidebarTheme.menuSelectedFontColor
        : sidebarTheme.foregroundColor);

    return Padding(
      padding: padding,
      child: Card(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sidebarTheme.menuBorderRadius)),
        elevation: 0.0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: (sidebarTheme.menuFontSize + 4.0),
                color: textColor,
              ),
              const SizedBox(width: kDefaultPadding * 0.5),
              Text(
                title,
                style: TextStyle(
                  fontSize: sidebarTheme.menuFontSize,
                  color: textColor,
                ),
              ),
            ],
          ),
          // ignore: avoid_print
          onTap: () {
            GoRouter.of(context).go(uri);
          },

          selected: isSelected,
          selectedTileColor: sidebarTheme.menuSelectedBackgroundColor,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(sidebarTheme.menuBorderRadius)),
          textColor: textColor,
          hoverColor: sidebarTheme.menuHoverColor,
        ),
      ),
    );
  }

  Widget _expandableSidebarMenu(
    BuildContext context,
    EdgeInsets padding,
    String uri,
    IconData icon,
    String title,
    List<SidebarChildMenuConfig> children,
    String currentLocation,
  ) {
    final themeData = Theme.of(context);
    final sidebarTheme = Theme.of(context).extension<AppSidebarTheme>()!;
    final hasSelectedChild =
        children.any((e) => currentLocation.startsWith(e.uri));
    final parentTextColor = (hasSelectedChild
        ? sidebarTheme.menuSelectedFontColor
        : sidebarTheme.foregroundColor);

    return Padding(
      padding: padding,
      child: Card(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sidebarTheme.menuBorderRadius)),
        elevation: 0.0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: themeData.copyWith(
            hoverColor: sidebarTheme.menuExpandedHoverColor,
          ),
          child: ExpansionTile(
            key: UniqueKey(),
            shape: const Border(),
            trailing: const Icon(
              Icons.keyboard_arrow_down,
            ),
            textColor: const Color.fromARGB(255, 240, 211, 157),
            collapsedTextColor: parentTextColor,
            iconColor: parentTextColor,
            collapsedIconColor: parentTextColor,
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: (hasSelectedChild
                ? sidebarTheme.menuExpandedBackgroundColor
                : Colors.transparent),
            initiallyExpanded: hasSelectedChild,
            childrenPadding: EdgeInsets.only(
              top: sidebarTheme.menuExpandedChildTopPadding,
              bottom: sidebarTheme.menuExpandedChildBottomPadding,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: (sidebarTheme.menuFontSize + 4.0),
                ),
                const SizedBox(width: kDefaultPadding * 0.5),
                Tooltip(
                  message: title,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: sidebarTheme.menuFontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            children: children.map<Widget>((childMenu) {
              if (childMenu.children.isEmpty) {
                return _sidebarMenu(
                  context,
                  EdgeInsets.fromLTRB(
                    sidebarTheme.menuExpandedChildLeftPadding,
                    sidebarTheme.menuExpandedChildTopPadding,
                    sidebarTheme.menuExpandedChildRightPadding,
                    sidebarTheme.menuExpandedChildBottomPadding,
                  ),
                  childMenu.uri,
                  childMenu.icon,
                  childMenu.title(context),
                  (currentLocation.startsWith(childMenu.uri)),
                );
              } else {
                return _expandableSidebarMenu(
                  context,
                  EdgeInsets.fromLTRB(
                    sidebarTheme.menuExpandedChildLeftPadding,
                    sidebarTheme.menuExpandedChildTopPadding,
                    sidebarTheme.menuExpandedChildRightPadding,
                    sidebarTheme.menuExpandedChildBottomPadding,
                  ),
                  childMenu.uri,
                  childMenu.icon,
                  childMenu.title(context),
                  childMenu.children,
                  currentLocation,
                );
              }
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class SidebarHeader extends StatelessWidget {
  final void Function() onAccountButtonPressed;
  final void Function() onLogoutButtonPressed;

  const SidebarHeader({
    super.key,
    required this.onAccountButtonPressed,
    required this.onLogoutButtonPressed,
  });

  Future<void> _handleLogout() async {
    // PENDING
    // final user = Provider.of<UserDataProvider>(context, listen: false);

    await TxnHelper.saveTxn(
      txnReceiptNum: '',
      txnAmount: 0.0,
      txnType: Event.logOut,
      txnStatus: PostingStatus.pending,
      txnLocalStatus: LocalEvent.pending,
    );
    onLogoutButtonPressed();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final themeData = Theme.of(context);
    final sidebarTheme = themeData.extension<AppSidebarTheme>()!;

    return Column(
      children: [
        Row(
          children: [
            Selector<UserDataProvider, String>(
              selector: (context, provider) => provider.userProfileImageUrl,
              builder: (context, value, child) {
                return CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: NetworkImage(value),
                  radius: 20.0,
                );
              },
            ),
            const SizedBox(width: kDefaultPadding * 0.5),
            Selector<UserDataProvider, String>(
              selector: (context, provider) => provider.username,
              builder: (context, value, child) {
                return SizedBox(
                  width: 200,
                  child: Tooltip(
                    message: value,
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: sidebarTheme.headerUsernameFontSize,
                        color: sidebarTheme.foregroundColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: kDefaultPadding * 0.5),
        Align(
          alignment: Alignment.centerRight,
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textButton(
                    themeData,
                    sidebarTheme,
                    Icons.manage_accounts_rounded,
                    lang.account,
                    onAccountButtonPressed),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: VerticalDivider(
                    width: 2.0,
                    thickness: 1.0,
                    color: sidebarTheme.foregroundColor.withOpacity(0.5),
                    indent: kTextPadding,
                    endIndent: kTextPadding,
                  ),
                ),
                _textButton(themeData, sidebarTheme, Icons.login_rounded,
                    lang.logout, () => _handleLogout()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _textButton(ThemeData themeData, AppSidebarTheme sidebarTheme,
      IconData icon, String text, void Function() onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: sidebarTheme.foregroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: (sidebarTheme.headerUsernameFontSize + 4.0),
          ),
          const SizedBox(width: kDefaultPadding * 0.5),
          Text(
            text,
            style: TextStyle(
              fontSize: sidebarTheme.headerUsernameFontSize,
            ),
          ),
        ],
      ),
    );
  }
}
