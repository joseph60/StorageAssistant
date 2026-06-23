import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/media_record.dart';

enum MediaSource { camera, gallery }

enum CameraMode { photo, video }

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  GlobalKey<NavigatorState>? navigatorKey;

  Future<String> get _mediaDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  Future<String> _getImageDirectory() async {
    final mediaDir = await _mediaDirectory;
    final imageDir = Directory('$mediaDir/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  Future<String> _getVideoDirectory() async {
    final mediaDir = await _mediaDirectory;
    final videoDir = Directory('$mediaDir/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir.path;
  }

  Future<String> _getThumbnailDirectory() async {
    final mediaDir = await _mediaDirectory;
    final thumbDir = Directory('$mediaDir/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir.path;
  }

  Future<String> _generateUuidFileName(String extension) async {
    return '${_uuid.v4()}.$extension';
  }

  Future<MediaRecord?> pickImage(MediaSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source == MediaSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile == null) return null;

      return await saveImage(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  Future<MediaRecord?> pickVideo(MediaSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: source == MediaSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (pickedFile == null) return null;

      return await saveVideo(pickedFile.path);
    } catch (e) {
      return null;
    }
  }

  Future<({String? imagePath, String? videoPath})?> pickMedia() async {
    if (navigatorKey?.currentContext == null) return null;

    final result = await showDialog<_MediaPickResult>(
      context: navigatorKey!.currentContext!,
      builder: (context) => const _MediaPickDialog(),
    );

    if (result == null) return null;

    String? imagePath;
    String? videoPath;

    if (result.source == _MediaSource.galleryImage) {
      final media = await pickImage(MediaSource.gallery);
      imagePath = media?.filePath;
    } else if (result.source == _MediaSource.galleryVideo) {
      final media = await pickVideo(MediaSource.gallery);
      videoPath = media?.filePath;
    } else if (result.source == _MediaSource.cameraPhoto) {
      final media = await pickImage(MediaSource.camera);
      imagePath = media?.filePath;
    } else if (result.source == _MediaSource.cameraVideo) {
      final media = await pickVideo(MediaSource.camera);
      videoPath = media?.filePath;
    }

    if (imagePath == null && videoPath == null) return null;

    return (imagePath: imagePath, videoPath: videoPath);
  }

  Future<MediaRecord?> saveImage(String sourcePath) async {
    try {
      final imageDir = await _getImageDirectory();
      final uuidFileName = await _generateUuidFileName('jpg');
      final destPath = '$imageDir/$uuidFileName';

      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();

      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: 1024);
      final compressed = img.encodeJpg(resized, quality: 80);

      await File(destPath).writeAsBytes(compressed);

      return MediaRecord(
        id: uuidFileName.split('.').first,
        filePath: destPath,
        type: MediaType.image,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<MediaRecord?> saveVideo(String sourcePath) async {
    try {
      final videoDir = await _getVideoDirectory();
      final uuidFileName = await _generateUuidFileName('mp4');
      final destPath = '$videoDir/$uuidFileName';

      final info = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info == null || info.file == null) return null;

      await info.file!.copy(destPath);

      String? thumbnailPath;
      final thumbnailDir = await _getThumbnailDirectory();
      final thumbFileName = await _generateUuidFileName('jpg');
      thumbnailPath = '$thumbnailDir/$thumbFileName';

      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: destPath,
        thumbnailPath: thumbnailDir,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );

      if (thumbnail != null) {
        await File(thumbnail).copy(thumbnailPath);
        await File(thumbnail).delete();
      }

      return MediaRecord(
        id: uuidFileName.split('.').first,
        filePath: destPath,
        type: MediaType.video,
        thumbnailPath: thumbnailPath,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteMediaFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMediaWithThumbnail(MediaRecord media) async {
    try {
      await deleteMediaFile(media.filePath);
      if (media.thumbnailPath != null) {
        await deleteMediaFile(media.thumbnailPath!);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> cleanOrphanedMedia(List<String> usedPaths) async {
    try {
      int deletedCount = 0;

      final imageDir = await _getImageDirectory();
      final imageDirectory = Directory(imageDir);
      if (await imageDirectory.exists()) {
        await for (var entity in imageDirectory.list()) {
          if (entity is File && !usedPaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      final videoDir = await _getVideoDirectory();
      final videoDirectory = Directory(videoDir);
      if (await videoDirectory.exists()) {
        await for (var entity in videoDirectory.list()) {
          if (entity is File && !usedPaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      final thumbDir = await _getThumbnailDirectory();
      final thumbDirectory = Directory(thumbDir);
      if (await thumbDirectory.exists()) {
        await for (var entity in thumbDirectory.list()) {
          if (entity is File && !usedPaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      return deletedCount;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getMediaStorageSize() async {
    try {
      int totalSize = 0;

      final dirs = [
        await _getImageDirectory(),
        await _getVideoDirectory(),
        await _getThumbnailDirectory(),
      ];

      for (var dirPath in dirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (var entity in dir.list()) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum _MediaSource { galleryImage, galleryVideo, cameraPhoto, cameraVideo }

class _MediaPickResult {
  final _MediaSource source;
  _MediaPickResult(this.source);
}

class _MediaPickDialog extends StatefulWidget {
  const _MediaPickDialog();

  @override
  State<_MediaPickDialog> createState() => _MediaPickDialogState();
}

class _MediaPickDialogState extends State<_MediaPickDialog> {
  CameraMode _cameraMode = CameraMode.photo;

  void _toggleCameraMode() {
    setState(() {
      _cameraMode =
          _cameraMode == CameraMode.photo ? CameraMode.video : CameraMode.photo;
    });
  }

  void _takePhoto() async {
    final result = _MediaPickResult(_MediaSource.cameraPhoto);
    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  void _startVideoRecording() async {
    final result = _MediaPickResult(_MediaSource.cameraVideo);
    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('请选择'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('从相册选择'),
            onTap: () async {
              final source = await showDialog<_MediaPickResult>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('请选择'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('图片'),
                        onTap: () => Navigator.pop(context,
                            _MediaPickResult(_MediaSource.galleryImage)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.videocam),
                        title: const Text('视频'),
                        onTap: () => Navigator.pop(context,
                            _MediaPickResult(_MediaSource.galleryVideo)),
                      ),
                    ],
                  ),
                ),
              );
              if (source != null && mounted) {
                Navigator.pop(context, source);
              }
            },
          ),
          const Divider(),
          Column(
            children: [
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.blue,
                color: Colors.grey,
                onPressed: (index) {
                  setState(() {
                    _cameraMode =
                        index == 0 ? CameraMode.photo : CameraMode.video;
                  });
                },
                isSelected: [
                  _cameraMode == CameraMode.photo,
                  _cameraMode == CameraMode.video,
                ],
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt, size: 18),
                        SizedBox(width: 4),
                        Text('拍照'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.videocam, size: 18),
                        SizedBox(width: 4),
                        Text('录像'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_cameraMode == CameraMode.photo) {
                    _takePhoto();
                  } else {
                    _startVideoRecording();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: _cameraMode == CameraMode.photo
                        ? Colors.orange
                        : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _cameraMode == CameraMode.photo
                            ? Icons.camera_alt
                            : Icons.videocam,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _cameraMode == CameraMode.photo ? '点击拍照' : '点击录像',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
