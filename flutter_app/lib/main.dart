import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'services/app_messenger.dart';
import 'state/board_controller.dart';
import 'state/palette_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PaletteApp());
}

class PaletteApp extends StatelessWidget {
  const PaletteApp({super.key, this.paletteController, this.boardController});

  /// Injected in tests; created (and owned) by the app otherwise.
  final PaletteController? paletteController;
  final BoardController? boardController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        if (paletteController != null)
          ChangeNotifierProvider<PaletteController>.value(value: paletteController!)
        else
          ChangeNotifierProvider<PaletteController>(create: (_) => PaletteController()),
        if (boardController != null)
          ChangeNotifierProvider<BoardController>.value(value: boardController!)
        else
          ChangeNotifierProvider<BoardController>(create: (_) => BoardController()),
      ],
      child: MaterialApp(
        title: 'Palette & MoodBoard',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: AppMessenger.key,
        theme: buildAppTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
