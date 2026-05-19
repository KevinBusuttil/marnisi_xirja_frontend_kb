import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
// import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/dimens.dart';
// import 'package:web_admin/generated/l10n.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/theme/theme_extensions/app_color_scheme.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';

class Contact extends StatelessWidget {
  const Contact({super.key});

  @override
  Widget build(BuildContext context) {
    final userDataProvider = context.read<UserDataProvider>();

    if (userDataProvider.isUserLoggedIn()) {
      return PortalMasterLayout(
        body: _content(context),
      );
    } else {
      return PublicMasterLayout(
        body: _content(context),
      );
    }
  }

  Widget _content(BuildContext context) {
    // final lang = Lang.of(context);
    final themeData = Theme.of(context);
    final appColorScheme = Theme.of(context).extension<AppColorScheme>()!;

    return Container(
      decoration: ContainerBackgroundTheme.myGradientDecoration,
      child: ListView(
        padding: const EdgeInsets.all(kDefaultPadding),
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: kDefaultPadding * 5.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: kDefaultPadding),
                  child: Text(
                    'Contact',
                    style: themeData.textTheme.displayMedium!.copyWith(
                      color: appColorScheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
