import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<void> _backupDatabase() async {
    try {
      final dbPath = await _dataManager.getDatabasePath();
      final bytes = await File(dbPath).readAsBytes();
      final fileName =
          'storage_assistant_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
      final result = await FilePicker.saveFile(
        dialogTitle: '选择备份保存位置',
        fileName: fileName,
        bytes: bytes,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据库备份成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：$e')),
        );
      }
    }
  }

  Future<void> _restoreDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据库恢复'),
        content: const Text('恢复将用备份文件覆盖当前所有数据，且不可撤销。建议先备份当前数据库。\n\n确定要继续吗？'),
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

    final picked = await FilePicker.pickFile(
      dialogTitle: '选择数据库备份文件',
      type: FileType.any,
    );
    if (!mounted) return;
    final path = picked?.path;
    if (path == null) return;

    if (!path.toLowerCase().endsWith('.db')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择 .db 数据库备份文件')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _dataManager.restoreDatabase(path);
      await _loadStorageSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据库恢复成功，建议重启应用以完全刷新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                      leading: const Icon(Icons.backup),
                      title: const Text('数据库备份'),
                      subtitle: const Text('导出数据库到本地文件'),
                      onTap: _backupDatabase,
                    ),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('数据库恢复'),
                      subtitle: const Text('导入备份文件，覆盖当前数据'),
                      onTap: _restoreDatabase,
                    ),
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
