import 'package:flutter/material.dart';

import 'ui/app_theme.dart';

void main() {
  runApp(const PaletteApp());
}

class PaletteApp extends StatelessWidget {
  const PaletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palette & MoodBoard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(body: Center(child: Text('Palette & MoodBoard'))),
    );
  }
}
