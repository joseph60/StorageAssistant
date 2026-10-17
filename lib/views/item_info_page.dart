import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../data/data_manager.dart';
import '../models/item_record.dart';
import '../services/media_service.dart';

enum ItemInfoMode { add, view, edit, remove }

class ItemInfoPage extends StatefulWidget {
  final Map<String, dynamic>? itemData;
  final ItemInfoMode initialMode;
  final String tagId;
  final String tagName;
  const ItemInfoPage({
    super.key,
    this.itemData,
    required this.initialMode,
    required this.tagId,
    required this.tagName,
  });
  @override
  State<ItemInfoPage> createState() => _ItemInfoPageState();
}

class _ItemInfoPageState extends State<ItemInfoPage> {
  late ItemInfoMode _mode;
  final DataManager _dataManager = DataManager();
  final MediaService _mediaService = MediaService();
  late TextEditingController _nameController;
  late TextEditingController _remarkController;
  ValueNotifier<String?> status = ValueNotifier(null);
  bool _isOperating = false;
  String? _imagePath;
  String? _videoPath;

  // 新增：物品列表和当前索引
  List<Map<String, dynamic>> _items = [];
  int _currentIndex = 0;

  // 当前展示的物品数据（滑动后会更新，用于编辑/删除操作）
  Map<String, dynamic>? _currentItemData;

  // 新增：滑动动画相关
  double _slideOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _nameController =
        TextEditingController(text: widget.itemData?['itemName'] ?? '');
    _remarkController =
        TextEditingController(text: widget.itemData?['remark'] ?? '');
    _imagePath = widget.itemData?['imagePath'];
    _videoPath = widget.itemData?['videoPath'];
    _currentItemData = widget.itemData;

    // 加载物品列表并设置当前索引
    _loadItemsAndSetIndex();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _loadItemsAndSetIndex() async {
    if (_mode == ItemInfoMode.view && widget.itemData != null) {
      // 获取当前标签下的所有物品
      final itemRecords = await _dataManager.getItemsByTag(widget.tagId);
      _items = itemRecords.map((record) => record.toMap()).toList();

      // 找到当前物品在列表中的索引
      final currentItemId = widget.itemData!['id'];
      for (int i = 0; i < _items.length; i++) {
        if (_items[i]['id'] == currentItemId) {
          _currentIndex = i;
          break;
        }
      }
    }
  }

  // 带滑动动画的切换到下一个物品
  void _nextItem() {
    if (_currentIndex < _items.length - 1) {
      _slideOffset = 1.0; // 从右侧开始
      setState(() {
        _currentIndex++;
        _updateUIWithItem(_items[_currentIndex]);
      });
      _animateSlide();
    }
  }

  // 带滑动动画的切换到上一个物品
  void _previousItem() {
    if (_currentIndex > 0) {
      _slideOffset = -1.0; // 从左侧开始
      setState(() {
        _currentIndex--;
        _updateUIWithItem(_items[_currentIndex]);
      });
      _animateSlide();
    }
  }

  // 执行滑动动画
  void _animateSlide() {
    const duration = Duration(milliseconds: 300);

    // 创建动画控制器
    final controller = AnimationController(
      duration: duration,
      vsync: Navigator.of(context),
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    animation.addListener(() {
      setState(() {
        // 从起始位置滑动到中心位置
        _slideOffset = _slideOffset * (1 - animation.value);
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _slideOffset = 0.0;
        });
        controller.dispose();
      }
    });

    controller.forward();
  }

  // 更新UI显示指定物品
  void _updateUIWithItem(Map<String, dynamic> item) {
    _currentItemData = item;
    _nameController.text = item['itemName'] ?? '';
    _remarkController.text = item['remark'] ?? '';
    _imagePath = item['imagePath'];
    _videoPath = item['videoPath'];
  }

  void _onCancel() => Navigator.pop(context, null);

  void _onDelete() async {
    if (_isOperating) return;
    String? itemId;
    if (_currentItemData != null && _currentItemData!.containsKey('id')) {
      itemId = _currentItemData!['id'];
    }
    if (itemId != null) {
      _isOperating = true;
      status.value = '正在删除...';
      await _dataManager.deleteItem(itemId);
      _isOperating = false;
      if (mounted) Navigator.pop(context, true);
      return;
    }
    _isOperating = false;
    if (mounted) Navigator.pop(context, false);
  }

  void _pickImage() async {
    // 在新增模式下，如果已经有媒体文件，先保存当前数据
    if (_mode == ItemInfoMode.add &&
        (_imagePath != null || _videoPath != null)) {
      await _onSave(fromPickImage: true);
    }

    final result = await _mediaService.pickMedia();
    if (result != null) {
      setState(() {
        _imagePath = result.imagePath;
        _videoPath = result.videoPath;
      });
    }
  }

  void _showImageViewer(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenImagePage(imagePath: imagePath),
    );
  }

  void _openFullScreenVideo(String videoPath) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenVideoPage(videoPath: videoPath),
    );
  }

  Future<void> _onSave({bool fromPickImage = false}) async {
    if (_isOperating) return;

    String itemName = _nameController.text.trim();
    bool hasMedia = _imagePath != null || _videoPath != null;

    // 如果物品名称为空且没有媒体文件，弹出警告并中止保存
    if (itemName.isEmpty && !hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写物品名称或拍摄图片')),
      );
      return;
    }

    _isOperating = true;
    status.value = '正在保存...';

    try {
      print(
          '开始保存物品：itemName=$itemName, tagId=${widget.tagId}, hasMedia=$hasMedia');
      // 如果物品名称为空但有媒体文件，使用当前日期作为名称，格式为yyyyMMddHHmmss
      if (itemName.isEmpty && hasMedia) {
        final now = DateTime.now();
        final formatter = DateFormat('yyyyMMddHHmmss');
        itemName = formatter.format(now);
        print('自动生成名称：$itemName');
      }

      if (_mode == ItemInfoMode.add) {
        print('创建新物品');
        await _dataManager.createItem(
          itemName: itemName,
          remark: _remarkController.text.trim(),
          imagePath: _imagePath,
          videoPath: _videoPath,
          tagId: widget.tagId,
        );
        print('创建物品成功');
      } else if (_mode == ItemInfoMode.edit) {
        print('编辑物品');
        if (_currentItemData != null && _currentItemData!.containsKey('id')) {
          // 将字符串转换为DateTime
          final createdAt = _currentItemData!['createdAt'] is String
              ? DateTime.parse(_currentItemData!['createdAt'])
              : _currentItemData!['createdAt'];

          final itemRecord = ItemRecord(
            id: _currentItemData!['id'],
            itemName: itemName,
            remark: _remarkController.text.trim(),
            imagePath: _imagePath,
            videoPath: _videoPath,
            tagId: widget.tagId,
            createdAt: createdAt,
            updatedAt: DateTime.now(),
          );
          await _dataManager.updateItem(itemRecord);
          print('更新物品成功');
        }
      }

      if (mounted) {
        status.value = '保存成功';
        // 如果不是从拍照/选择按钮触发的保存，则跳转回主画面
        if (!fromPickImage) {
          Navigator.pop(context, true);
        } else {
          // 重置表单，准备添加下一个物品
          _nameController.clear();
          _remarkController.clear();
          setState(() {
            _imagePath = null;
            _videoPath = null;
          });
        }
      }
    } catch (e) {
      print('保存失败错误：$e');
      if (mounted) {
        status.value = '保存失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：${e.toString()}')),
        );
      }
    } finally {
      _isOperating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;
    switch (_mode) {
      case ItemInfoMode.add:
        title = '新增物品';
        break;
      case ItemInfoMode.view:
        title = '物品详情';
        break;
      case ItemInfoMode.remove:
        title = '取出物品';
        break;
      case ItemInfoMode.edit:
        title = '修改物品';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(title),
            if (_mode == ItemInfoMode.view && _items.isNotEmpty)
              Text('${_currentIndex + 1}/${_items.length}',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // 检测左右划动（primaryVelocity 可能为 null，需兜底；
            // 加速度阈值避免轻触误触发）
            final velocity = details.primaryVelocity ?? 0.0;
            if (velocity < -50) {
              // 左划：切换到下一个物品
              _nextItem();
            } else if (velocity > 50) {
              // 右划：切换到上一个物品
              _previousItem();
            }
          },
          child: Transform.translate(
            offset: Offset(_slideOffset * MediaQuery.of(context).size.width, 0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('物品名称',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            readOnly: _mode == ItemInfoMode.remove ||
                                _mode == ItemInfoMode.view,
                            decoration: InputDecoration(
                              hintText: '请输入物品名称',
                              border: const OutlineInputBorder(),
                              filled: _mode == ItemInfoMode.remove ||
                                  _mode == ItemInfoMode.view,
                              fillColor: _mode == ItemInfoMode.remove ||
                                      _mode == ItemInfoMode.view
                                  ? Colors.grey.shade200
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('物品图像',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_mode == ItemInfoMode.add ||
                              _mode == ItemInfoMode.edit) ...[
                            if (_imagePath != null) ...[
                              Image.file(File(_imagePath!),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                              const SizedBox(height: 8)
                            ],
                            if (_videoPath != null) ...[
                              Container(
                                height: 150,
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(Icons.videocam,
                                      color: Colors.white, size: 48),
                                ),
                              ),
                              const SizedBox(height: 8)
                            ],
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add_photo_alternate,
                                      size: 18),
                                  label: const Text('拍照/选择',
                                      style: TextStyle(fontSize: 14)),
                                ),
                                if (_imagePath != null ||
                                    _videoPath != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => setState(() {
                                      _imagePath = null;
                                      _videoPath = null;
                                    }),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (_mode == ItemInfoMode.view ||
                              _mode == ItemInfoMode.remove) ...[
                            if (_imagePath != null || _videoPath != null) ...[
                              Row(
                                children: [
                                  if (_imagePath != null &&
                                      _videoPath != null) ...[
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showImageViewer(_imagePath!),
                                        child: Image.file(File(_imagePath!),
                                            height: 150, fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _openFullScreenVideo(_videoPath!),
                                        child: Container(
                                          height: 150,
                                          color: Colors.black,
                                          child: const Center(
                                            child: Icon(Icons.play_circle_fill,
                                                color: Colors.white, size: 48),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else if (_imagePath != null) ...[
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showImageViewer(_imagePath!),
                                        child: Center(
                                          child: Image.file(File(_imagePath!),
                                              height: 150, fit: BoxFit.cover),
                                        ),
                                      ),
                                    ),
                                  ] else if (_videoPath != null) ...[
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _openFullScreenVideo(_videoPath!),
                                        child: Container(
                                          height: 150,
                                          color: Colors.black,
                                          child: const Center(
                                            child: Icon(Icons.play_circle_fill,
                                                color: Colors.white, size: 48),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          if (_mode == ItemInfoMode.view ||
                              _mode == ItemInfoMode.remove) ...[
                            if (_remarkController.text.isNotEmpty) ...[
                              const Text('备注',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_remarkController.text),
                              ),
                            ],
                          ] else ...[
                            const Text('备注',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _remarkController,
                              readOnly: _mode == ItemInfoMode.remove ||
                                  _mode == ItemInfoMode.view,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: '请输入备注信息',
                                border: const OutlineInputBorder(),
                                filled: _mode == ItemInfoMode.remove ||
                                    _mode == ItemInfoMode.view,
                                fillColor: _mode == ItemInfoMode.remove ||
                                        _mode == ItemInfoMode.view
                                    ? Colors.grey.shade200
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: status,
                    builder: (context, value, child) {
                      if (value != null) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(value,
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.center),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Row(
                    children: [
                      if (_mode == ItemInfoMode.add ||
                          _mode == ItemInfoMode.view ||
                          _mode == ItemInfoMode.edit ||
                          _mode == ItemInfoMode.remove) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isOperating ? null : _onCancel,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.grey,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                            ),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('取消',
                                style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                      if (_mode == ItemInfoMode.view) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _mode = ItemInfoMode.edit),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('修改',
                                style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                      if (_mode == ItemInfoMode.view ||
                          _mode == ItemInfoMode.remove) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isOperating ? null : _onDelete,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                            ),
                            icon: Icon(
                              _mode == ItemInfoMode.remove
                                  ? Icons.remove_shopping_cart
                                  : Icons.delete,
                              size: 18,
                            ),
                            label: Text(
                              _mode == ItemInfoMode.remove ? '取出' : '取出',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      if (_mode == ItemInfoMode.add ||
                          _mode == ItemInfoMode.edit) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isOperating ? null : _onSave,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                            ),
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('保存',
                                style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 其他辅助类保持不变...

class _FullScreenImagePage extends StatelessWidget {
  final String imagePath;
  const _FullScreenImagePage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final String videoPath;
  const _FullScreenVideoPage({required this.videoPath});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late VideoPlayerController _controller;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (_showControls)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: Center(
                              child: IconButton(
                                onPressed: () {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                  setState(() {});
                                },
                                icon: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
