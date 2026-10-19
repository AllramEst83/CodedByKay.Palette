import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/app_messenger.dart';
import 'services/blob/blob_store.dart';
import 'state/board_controller.dart';
import 'state/palette_controller.dart';
import 'state/persistence.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PaletteApp(persist: true));
}

class PaletteApp extends StatefulWidget {
  const PaletteApp({
    super.key,
    this.paletteController,
    this.boardController,
    this.persist = false,
  });

  /// Injected in tests; created (and owned) by the app otherwise.
  final PaletteController? paletteController;
  final BoardController? boardController;

  /// Whether to restore and autosave state (off in widget tests).
  final bool persist;

  @override
  State<PaletteApp> createState() => _PaletteAppState();
}

class _PaletteAppState extends State<PaletteApp> {
  late final PaletteController _palette = widget.paletteController ?? PaletteController();
  late final BoardController _board = widget.boardController ?? BoardController();
  AppPersistence? _persistence;
  late bool _ready = !widget.persist;

  @override
  void initState() {
    super.initState();
    if (widget.persist) _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppPersistence persistence = AppPersistence(
        palette: _palette,
        board: _board,
        prefs: prefs,
        blobs: createPlatformBlobStore(),
      );
      final bool restored = await persistence.restore();
      persistence.attach();
      _persistence = persistence;
      if (mounted) setState(() => _ready = true);
      if (!restored) await _palette.loadSample();
    } catch (err) {
      debugPrint('Startup restore failed: $err');
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _persistence?.dispose();
    if (widget.paletteController == null) _palette.dispose();
    if (widget.boardController == null) _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<PaletteController>.value(value: _palette),
        ChangeNotifierProvider<BoardController>.value(value: _board),
      ],
      child: MaterialApp(
        title: 'Palette & MoodBoard',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: AppMessenger.key,
        theme: buildAppTheme(),
        home: _ready
            ? const HomeShell()
            : Scaffold(
                body: Center(
                  child: Semantics(
                    label: 'Loading your saved board',
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
      ),
    );
  }
}
