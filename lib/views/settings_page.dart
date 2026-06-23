import 'package:flutter/material.dart';
import '../../data/data_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DataManager _dataManager = DataManager();
  String _storageSize = '0 B';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStorageSize();
  }

  Future<void> _loadStorageSize() async {
    final size = await _dataManager.getMediaStorageSize();
    setState(() {
      _storageSize = _dataManager.formatFileSize(size);
    });
  }

  Future<void> _cleanCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清理无用的媒体文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    final deletedCount = await _dataManager.cleanOrphanedMedia();
    await _loadStorageSize();

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 $deletedCount 个无用文件')),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('确定要清除所有数据吗？此操作将删除所有标签、物品和媒体文件，不可恢复！'),
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

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    await _dataManager.clearAllData();
    await _loadStorageSize();

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有数据已清除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildSection(
                  title: '存储管理',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('媒体存储空间'),
                      subtitle: Text(_storageSize),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services),
                      title: const Text('清理无用媒体'),
                      subtitle: const Text('删除未关联的媒体文件'),
                      onTap: _cleanCache,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: '数据管理',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('清除所有数据'),
                      subtitle: const Text('删除所有标签、物品和媒体文件'),
                      onTap: _clearAllData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: '关于',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('收纳小助手'),
                      subtitle: Text('版本 1.0.0'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}
