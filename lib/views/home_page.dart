import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../services/nfc_service.dart';
import '../data/data_manager.dart';
import 'item_info_page.dart';
import 'settings_page.dart';
import 'container_list_page.dart';

class HomePage extends StatefulWidget {
  final String? containerId;

  const HomePage({super.key, this.containerId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final DataManager _dataManager = DataManager();
  final NfcService _nfcService = NfcService();

  ValueNotifier<dynamic> result = ValueNotifier(null);
  ValueNotifier<String> status = ValueNotifier('等待操作');
  int? _selectedIndex;
  bool _showTagInfo = false;
  String? _currentTagId;
  String? _currentTagName;
  bool _isNfcAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.containerId != null) {
      _initializeWithContainerId(widget.containerId!);
    } else {
      _checkNfcAndStart();
    }
  }

  Future<void> _initializeWithContainerId(String containerId) async {
    status.value = '加载容器...';

    final existingTag = await _dataManager.getTagByTagId(containerId);

    if (existingTag != null) {
      _currentTagId = containerId;
      _currentTagName = existingTag.tagName;
      await _updateUIWithItems(containerId);
    } else {
      status.value = '容器不存在';
    }
  }

  Future<void> _checkNfcAndStart() async {
    final available = await _nfcService.isNfcAvailable();
    if (!mounted) return;
    setState(() => _isNfcAvailable = available);
    if (_isNfcAvailable) {
      _startNfcSession();
    } else {
      status.value = '请贴近标签';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 注意：这里不能调用 _nfcService.stopSession()。
    // pushAndRemoveUntil 换页时，旧首页的 dispose 会在新首页入场动画
    // 结束后（约 300ms）才执行，那时新首页的 NFC 会话已经启动，
    // 旧 dispose 里的 stopSession 会把新会话一起停掉，导致贴标签时
    // 只剩系统弹窗。会话停止由 didChangeAppLifecycleState（paused/
    // detached）和设置页软重启前显式 await 的 stopNfcSession 负责。
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNfcAndStart();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _nfcService.stopSession();
    }
  }

  void _startNfcSession() async {
    await _nfcService.startSession(
      onTagDiscovered: (tag) {
        _handleTag(tag);
      },
    );
  }

  void _handleTag(NfcTag tag) async {
    status.value = '正在读取...';

    // 使用标签的真实 ID，不立即停止会话
    final tagId = _nfcService.getTagId(tag);

    final existingTag = await _dataManager.getTagByTagId(tagId);

    if (existingTag != null) {
      _currentTagId = tagId;
      _currentTagName = existingTag.tagName;
      await _updateUIWithItems(tagId);
    } else {
      final inputController = TextEditingController();
      final enteredName = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('新标签'),
          content: TextField(
            controller: inputController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '请输入标签名称',
              hintText: '例如：厨房、客厅',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, inputController.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (enteredName != null && enteredName.isNotEmpty) {
        await _dataManager.createTag(tagId, enteredName);
        _currentTagId = tagId;
        _currentTagName = enteredName;
        await _updateUIWithItems(tagId);
      }
    }
  }

  Future<void> _updateUIWithItems(String tagId) async {
    final items = await _dataManager.getItemsByTag(tagId);
    final itemsMap = items.map((item) => _dataManager.itemToMap(item)).toList();

    result.value = {
      'tagId': tagId,
      'tagName': _currentTagName,
      'items': itemsMap,
    };

    if (items.isEmpty) {
      status.value = '没有存放记录';
    } else {
      status.value = '共存放${items.length}件物品';
    }

    setState(() {
      _selectedIndex = null;
    });
  }

  void _showTagInfoToggle() {
    setState(() {
      _showTagInfo = !_showTagInfo;
    });
  }

  void _showMediaPreview(Map<String, dynamic> itemData) {
    final imagePath = itemData['imagePath'] as String?;
    final videoPath = itemData['videoPath'] as String?;

    if (videoPath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _VideoPlayerPage(videoPath: videoPath),
        ),
      );
    } else if (imagePath != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.file(File(imagePath)),
          ),
        ),
      );
    }
  }

  void _onItemTap(int index, Map<String, dynamic> itemData) {
    if (_currentTagId == null) return;

    setState(() {
      _selectedIndex = index;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemInfoPage(
          itemData: itemData,
          initialMode: ItemInfoMode.view,
          tagId: _currentTagId!,
          tagName: _currentTagName ?? '',
        ),
      ),
    ).then((_) {
      _refreshItems();
    });
  }

  Future<void> _refreshItems() async {
    if (_currentTagId == null) return;

    final items = await _dataManager.getItemsByTag(_currentTagId!);
    final itemsMap = items.map((item) => _dataManager.itemToMap(item)).toList();
    result.value = {
      'tagId': _currentTagId,
      'tagName': _currentTagName,
      'items': itemsMap,
    };

    if (items.isEmpty) {
      status.value = '没有存放记录';
    } else {
      status.value = '共存放${items.length}件物品';
    }

    setState(() {
      _selectedIndex = null;
    });
  }

  void _ndefWrite() async {
    if (_currentTagId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先读取标签')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemInfoPage(
          initialMode: ItemInfoMode.add,
          tagId: _currentTagId!,
          tagName: _currentTagName ?? '',
        ),
      ),
    );

    _refreshItems();
  }

  void _showClearConfirmDialog() async {
    if (_currentTagId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空确认'),
        content: const Text('继续操作将清除所有数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dataManager.deleteItemsByTag(_currentTagId!);
      _refreshItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTagName ?? '收纳小助手'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ContainerListPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            GestureDetector(
              onTap: _showTagInfoToggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue.shade50,
                child: Text(
                  status.value,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (_showTagInfo && result.value != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Text(
                  result.value['tagInfo'] ?? '',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
            Expanded(
              child: _buildContentSection(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<dynamic>(
                      valueListenable: result,
                      builder: (context, value, _) {
                        bool hasData = value != null &&
                            value is Map &&
                            value.containsKey('items') &&
                            (value['items'] as List).isNotEmpty;
                        return ElevatedButton.icon(
                          onPressed: hasData ? _showClearConfirmDialog : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                          ),
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label:
                              const Text('清空', style: TextStyle(fontSize: 14)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _ndefWrite,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('存入物品', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return ValueListenableBuilder<dynamic>(
      valueListenable: result,
      builder: (context, value, _) {
        if (value == null || !value.containsKey('items')) {
          // 空态引导：首次启动 / 未贴近任何标签时，提示用户如何使用
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.nfc,
                    size: 64,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isNfcAvailable ? '等待操作' : '设备不支持 NFC',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '将 NFC 标签贴近手机背面即可识别容器',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (_isNfcAvailable) ...[
                    const SizedBox(height: 4),
                    Text(
                      '贴近新标签时可为其命名',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        List items = value['items'] ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  '这个容器还没有存放任何物品',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击下方的"存入物品"按钮开始添加',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final itemData = items[index];
            final isSelected = _selectedIndex == index;

            return GestureDetector(
              onTap: () => _onItemTap(index, itemData),
              child: Container(
                color: isSelected
                    ? Colors.blue.shade100
                    : (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        itemData['itemName'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (itemData['imagePath'] != null ||
                        itemData['videoPath'] != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showMediaPreview(itemData),
                        child: itemData['videoPath'] != null
                            ? const Icon(Icons.videocam, color: Colors.orange)
                            : const Icon(Icons.image, color: Colors.green),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String videoPath;

  const _VideoPlayerPage({required this.videoPath});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _controller.setLooping(true);
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('视频播放'),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
