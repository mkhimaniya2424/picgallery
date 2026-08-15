import 'package:flutter/material.dart';

class AlbumCoverPlaceholder extends StatelessWidget {
  const AlbumCoverPlaceholder({super.key, required this.gradient});

  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(Icons.photo_library_rounded, size: 34, color: Colors.white),
      ),
    );
  }
}
