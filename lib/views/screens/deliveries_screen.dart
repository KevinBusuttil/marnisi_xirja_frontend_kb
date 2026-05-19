import 'package:flutter/material.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';

class Deliveries extends StatefulWidget {
  const Deliveries({super.key});

  @override
  State<Deliveries> createState() => _DeliveriesState();
}

class _DeliveriesState extends State<Deliveries> {
  @override
  Widget build(BuildContext context) {
    // final themeData = Theme.of(context);
    // final appColorScheme = Theme.of(context).extension<AppColorScheme>()!;
    // final size = MediaQuery.of(context).size;
    // final summaryCardCrossAxisCount = (size.width >= kScreenWidthLg ? 3 : 1);

    return PortalMasterLayout(
      body: Container(
        decoration: ContainerBackgroundTheme.myGradientDecoration,
      ),
    );
  }
}
