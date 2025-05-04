import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final narrow = MediaQuery.of(context).size.width < 320;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment:
        narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline,
              color: scheme.onSecondaryContainer,
              size: narrow ? 20 : 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: tt.bodyMedium?.copyWith(
                fontSize : narrow ? 12 : 16,
                fontWeight: FontWeight.w700,
                color     : scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
