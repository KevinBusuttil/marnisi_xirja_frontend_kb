import 'package:flutter/material.dart';

class SearchWidget extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Function() onSubmitted;
  final FocusNode searchFocusNode;

  const SearchWidget({
    super.key,
    required this.searchController,
    required this.onChanged,
    required this.onSubmitted,
    required this.hintText,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[800],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onChanged,
              onSubmitted: (value) => onSubmitted(),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                suffixIcon: IconButton(
                  padding: const EdgeInsets.only(right: 8.0),
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear();
                    onChanged('');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
