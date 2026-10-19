import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../services/app_messenger.dart';
import '../../services/picker_service.dart';
import '../app_theme.dart';

const Set<String> _imageExtensions = <String>{'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

bool _isImage(XFile file) {
  final String? mime = file.mimeType;
  if (mime != null && mime.startsWith('image/')) return true;
  final String name = file.name.toLowerCase();
  final int dot = name.lastIndexOf('.');
  return dot >= 0 && _imageExtensions.contains(name.substring(dot + 1));
}

/// Accepts dropped image files (web drag-and-drop) and highlights while
/// dragging. A no-op on devices without drag-and-drop.
class ImageDropZone extends StatefulWidget {
  const ImageDropZone({required this.child, required this.onImages, this.single = false, super.key});

  final Widget child;
  final bool single;
  final Future<void> Function(List<PickedImage> images) onImages;

  @override
  State<ImageDropZone> createState() => _ImageDropZoneState();
}

class _ImageDropZoneState extends State<ImageDropZone> {
  bool _dragging = false;

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    final List<XFile> files = details.files.where(_isImage).toList();
    if (files.isEmpty) {
      AppMessenger.show('Please provide valid image files', isError: true);
      return;
    }
    final List<XFile> chosen = widget.single ? files.take(1).toList() : files;
    final List<PickedImage> images = <PickedImage>[
      for (final XFile f in chosen) PickedImage(f.name, await f.readAsBytes()),
    ];
    await widget.onImages(images);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: widget.child),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.indigo500.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.indigo500, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Drop images here', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
