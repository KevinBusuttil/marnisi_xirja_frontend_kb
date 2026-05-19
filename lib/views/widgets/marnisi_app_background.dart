import 'package:flutter/material.dart';
import 'package:web_admin/helpers/dashboard_background_style.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';

class MarnisiAppBackground extends StatelessWidget {
  const MarnisiAppBackground({
    super.key,
    this.backgroundPath,
  });

  final String? backgroundPath;

  @override
  Widget build(BuildContext context) {
    if (backgroundPath != null) {
      return _buildBackground(backgroundPath!.trim());
    }

    return FutureBuilder<String?>(
      future: MarnisiImageHelper.readAppBackgroundPath(),
      builder: (context, snapshot) {
        final path = (snapshot.data ?? '').trim();
        return _buildBackground(path);
      },
    );
  }

  Widget _buildBackground(String path) {
    Widget fallbackAsset() {
      return Image.asset(
        DashboardBackgroundStyle.imageAssetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: ContainerBackgroundTheme.myGradientDecoration,
        ),
      );
    }

    final imageWidget = MarnisiImageHelper.isNetworkImagePath(path)
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackAsset(),
          )
        : Image.asset(
            path.isNotEmpty ? path : DashboardBackgroundStyle.imageAssetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: ContainerBackgroundTheme.myGradientDecoration,
            ),
          );

    return Stack(
      children: [
        Positioned.fill(child: imageWidget),
        Positioned.fill(
          child: Container(
            color: DashboardBackgroundStyle.overlayColor,
          ),
        ),
      ],
    );
  }
}
