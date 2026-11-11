import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import 'wellness.dart';

Future<void> showMealPhoto(
  BuildContext context,
  String uid,
  String reference,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Wellness.paper,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              const Expanded(child: Text('Ảnh bữa ăn', style: Wellness.title)),
              IconButton(
                tooltip: 'Đóng ảnh',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: MealPhotoView(
                  key: ValueKey('$uid:$reference:large'),
                  uid: uid,
                  reference: reference,
                  large: true,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

/// Reads through the owner-checked service; never renders a raw filesystem path.
class MealPhotoView extends StatefulWidget {
  const MealPhotoView({
    super.key,
    required this.uid,
    required this.reference,
    this.large = false,
    this.compact = false,
  });
  final String uid;
  final String reference;
  final bool large;
  final bool compact;

  @override
  State<MealPhotoView> createState() => _MealPhotoViewState();
}

class _MealPhotoViewState extends State<MealPhotoView> {
  late Future<Uint8List?> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _bytes = context.read<AppServices>().photos.read(
    widget.uid,
    widget.reference,
  );
  @override
  void didUpdateWidget(MealPhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.reference != widget.reference) {
      _load();
    }
  }

  Widget _missing() => ColoredBox(
    color: Wellness.sage.withValues(alpha: .35),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hide_image_outlined,
              color: Wellness.muted,
              semanticLabel: 'Không đọc được ảnh bữa ăn',
            ),
            if (!widget.compact) ...[
              const SizedBox(height: 8),
              const Text(
                'Không đọc được ảnh. Thông tin bữa ăn vẫn được giữ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Wellness.muted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
    child: FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Wellness.sage,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) return _missing();
        return Image.memory(
          snapshot.data!,
          width: double.infinity,
          fit: widget.large ? BoxFit.contain : BoxFit.cover,
          cacheWidth: widget.large ? 1600 : 480,
          gaplessPlayback: false,
          semanticLabel: 'Ảnh bữa ăn',
          errorBuilder: (_, _, _) => _missing(),
        );
      },
    ),
  );
}
