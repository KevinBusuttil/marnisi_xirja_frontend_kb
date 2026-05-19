// lib/widgets/item_tile.dart

import 'package:flutter/material.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';

class ItemTile extends StatelessWidget {
  final String? image;
  final String title;
  final double price;
  final String unit;
  final String code;
  final Map<String, String> networkImageHeaders;
  // final String category;
  // final String taxGroup;
  // final double taxPct;
  final VoidCallback onTap;

  const ItemTile({
    super.key,
    this.image,
    required this.title,
    required this.price,
    required this.unit,
    required this.code,
    this.networkImageHeaders = const <String, String>{},
    // required this.category,
    // required this.taxGroup,
    // required this.taxPct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCode = code.contains('::') ? code.split('::').last : code;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color.fromARGB(255, 31, 32, 41),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: (MarnisiImageHelper.isNetworkImagePath(
                            (image ?? '').trim()))
                        ? Image.network(
                            image!,
                            headers: networkImageHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.wine_bar_rounded,
                                color: Colors.white70,
                                size: 44,
                              ),
                            ),
                          )
                        : Image.asset(
                            image ?? MarnisiImageHelper.fallbackItemAssetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.wine_bar_rounded,
                                color: Colors.white70,
                                size: 44,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: title,
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                visibleCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '€${price.toString()}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
