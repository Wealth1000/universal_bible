import 'package:flutter/material.dart';

class SearchPageDesktop extends StatelessWidget {
  const SearchPageDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: const Center(
        child: Text('Search Page Desktop'),
      ),
    );
  }
}