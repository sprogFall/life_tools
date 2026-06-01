import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_project_detail.dart';
import '../models/work_photo_project_item.dart';
import '../repository/work_photo_repository.dart';
import '../services/work_photo_camera_service.dart';
import '../services/work_photo_capture_coordinator.dart';
import '../services/work_photo_media_store.dart';
import '../widgets/work_photo_item_bar.dart';

class WorkPhotoCameraPage extends StatefulWidget {
  final int projectId;
  final WorkPhotoRepository? repository;
  final WorkPhotoMediaStore? mediaStore;
  final WorkPhotoCameraService? cameraService;

  const WorkPhotoCameraPage({
    super.key,
    required this.projectId,
    this.repository,
    this.mediaStore,
    this.cameraService,
  });

  @override
  State<WorkPhotoCameraPage> createState() => _WorkPhotoCameraPageState();
}

class _WorkPhotoCameraPageState extends State<WorkPhotoCameraPage> {
  late final WorkPhotoRepository _repository;
  late final WorkPhotoMediaStore _mediaStore;
  late final WorkPhotoCameraService _cameraService;
  late final bool _ownsCameraService;
  bool _loading = true;
  bool _capturing = false;
  String? _error;
  WorkPhotoProjectDetail? _detail;
  int? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _mediaStore = widget.mediaStore ?? WorkPhotoMediaStore();
    _cameraService = widget.cameraService ?? WorkPhotoCameraService();
    _ownsCameraService = widget.cameraService == null;
    _initialize();
  }

  @override
  void dispose() {
    if (_ownsCameraService) {
      _cameraService.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _loading = false;
          _error = l10n.work_photo_camera_permission_content;
        });
        return;
      }

      final detail = await _repository.getProjectDetail(widget.projectId);
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = l10n.work_photo_project_detail_title;
        });
        return;
      }

      await _cameraService.initialize();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _selectedItemId = _pickInitialItem(detail);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(
          context,
        )!.work_photo_camera_error(e.toString());
      });
    }
  }

  int? _pickInitialItem(WorkPhotoProjectDetail detail) {
    final assetsByItem = detail.assetsByItemId;
    for (final item in detail.items) {
      final id = item.id;
      if (id == null) continue;
      final count = assetsByItem[id]?.length ?? 0;
      if (count < item.minCount) return id;
    }
    return detail.items.isEmpty ? null : detail.items.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
            ? _buildError(l10n)
            : _buildCamera(l10n),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Column(
      children: [
        IOS26AppBar(
          title: l10n.work_photo_camera_title,
          showBackButton: true,
          useSafeArea: false,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(IOS26Theme.spacingXl),
              child: Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: IOS26Theme.bodyMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCamera(AppLocalizations l10n) {
    final detail = _detail!;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: IOS26Theme.textPrimary,
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
                  child: _cameraService.buildPreview(),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IOS26AppBar(
            title: detail.project.name,
            showBackButton: true,
            useSafeArea: false,
            actions: [
              IOS26IconButton(
                icon: CupertinoIcons.camera_rotate,
                semanticLabel: l10n.work_photo_switch_camera,
                onPressed: _cameraService.cameraCount < 2
                    ? null
                    : _switchCamera,
                tone: IOS26IconTone.onAccent,
              ),
              IOS26IconButton(
                icon: _flashIcon(),
                semanticLabel: l10n.work_photo_toggle_flash,
                onPressed: _toggleFlash,
                tone: IOS26IconTone.onAccent,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(detail),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(WorkPhotoProjectDetail detail) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(color: IOS26Theme.glassBorderColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WorkPhotoItemBar(
            items: detail.items,
            assetsByItemId: detail.assetsByItemId,
            selectedItemId: _selectedItemId,
            onSelected: (item) => setState(() => _selectedItemId = item.id),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingLg,
              0,
              IOS26Theme.spacingLg,
              IOS26Theme.spacingLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: IOS26Theme.primaryColor,
                        width: 4,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                      child: IOS26Button(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(
                          IOS26Theme.radiusFull,
                        ),
                        onPressed: _capturing || _selectedItemId == null
                            ? null
                            : _capture,
                        variant: IOS26ButtonVariant.primary,
                        child: _capturing
                            ? const IOS26ButtonLoadingIndicator()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _flashIcon() {
    return switch (_cameraService.flashMode) {
      FlashMode.off => CupertinoIcons.bolt_slash,
      FlashMode.auto => CupertinoIcons.bolt_badge_a,
      FlashMode.always => CupertinoIcons.bolt_fill,
      FlashMode.torch => CupertinoIcons.bolt_fill,
    };
  }

  Future<void> _switchCamera() async {
    await _cameraService.switchCamera();
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    await _cameraService.toggleFlash();
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    final itemId = _selectedItemId;
    if (itemId == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final coordinator = WorkPhotoCaptureCoordinator(
        repository: _repository,
        mediaStore: _mediaStore,
        cameraCapture: _cameraService,
      );
      await coordinator.captureToItem(
        projectId: widget.projectId,
        projectItemId: itemId,
      );
      final detail = await _repository.getProjectDetail(widget.projectId);
      if (!mounted || detail == null) return;
      setState(() {
        _detail = detail;
        _selectedItemId = _nextItemAfterCapture(detail, currentItemId: itemId);
      });
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: AppLocalizations.of(context)!.work_photo_capture_failed,
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  int? _nextItemAfterCapture(
    WorkPhotoProjectDetail detail, {
    required int currentItemId,
  }) {
    final current = _findItem(detail.items, currentItemId);
    final currentCount = detail.assetsByItemId[currentItemId]?.length ?? 0;
    if (current != null && currentCount < current.minCount) {
      return currentItemId;
    }
    for (final item in detail.items) {
      final id = item.id;
      if (id == null) continue;
      final count = detail.assetsByItemId[id]?.length ?? 0;
      if (count < item.minCount) return id;
    }
    return currentItemId;
  }

  WorkPhotoProjectItem? _findItem(
    List<WorkPhotoProjectItem> items,
    int itemId,
  ) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}
