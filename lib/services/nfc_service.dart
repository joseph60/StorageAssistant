import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/platform_tags/ndef_formatable.dart';
import 'dart:convert';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  bool _isSessionStarted = false;
  NfcTag? _lastTag;
  String? _lastErrorMessage;
  String? _lastAlertMessage;

  factory NfcService() {
    return _instance;
  }

  NfcService._internal();

  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  Future<void> startSession({
    required Function(NfcTag) onTagDiscovered,
    String? alertMessage,
    String? errorMessage,
  }) async {
    if (_isSessionStarted) return;

    _lastAlertMessage = alertMessage;
    _lastErrorMessage = errorMessage;

    bool isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      return;
    }

    _isSessionStarted = true;
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          _lastTag = tag;
          onTagDiscovered(tag);
        },
        invalidateAfterFirstRead: true,
      );
    } catch (e) {
      // 不能静默吞掉：原生开启失败时读卡器模式未开启，
      // 贴标签只会弹系统提示，必须留日志便于定位。
      debugPrint('[NFC] startSession 失败: $e');
      _isSessionStarted = false;
      _lastTag = null;
    }
  }

  Future<void> stopSession({String? alertMessage, String? errorMessage}) async {
    if (_isSessionStarted) {
      try {
        await NfcManager.instance.stopSession(
          alertMessage: alertMessage,
          errorMessage: errorMessage,
        );
      } catch (e) {
        debugPrint('[NFC] stopSession 失败: $e');
      }
      _isSessionStarted = false;
    }
  }

  String _getTagType(NfcTag tag) {
    if (tag.data.containsKey('nfca')) {
      return tag.data['nfca']?['type'] ?? 'NFC-A';
    }
    if (tag.data.containsKey('nfcb')) {
      return tag.data['nfcb']?['type'] ?? 'NFC-B';
    }
    if (tag.data.containsKey('nfcf')) {
      return tag.data['nfcf']?['type'] ?? 'NFC-F';
    }
    if (tag.data.containsKey('nfcv')) {
      return 'NFC-V';
    }
    if (tag.data.containsKey('iso15693')) {
      return tag.data['iso15693']?['type'] ?? 'ISO 15693';
    }
    if (tag.data.containsKey('iso7816')) {
      return tag.data['iso7816']?['type'] ?? 'ISO 7816';
    }
    if (tag.data.containsKey('ndef')) {
      return 'NDEF';
    }
    return '未知';
  }

  int _getTagCapacity(NfcTag tag) {
    if (tag.data.containsKey('nfca')) {
      final nfcaData = tag.data['nfca'];
      if (nfcaData != null) {
        return nfcaData['maxTransceiveLength'] ??
            nfcaData['maxSize'] ??
            nfcaData['capacity'] ??
            nfcaData['size'] ??
            nfcaData['memorySize'] ??
            0;
      }
    }
    if (tag.data.containsKey('nfcb')) {
      return tag.data['nfcb']?['maxTransceiveLength'] ??
          tag.data['nfcb']?['maxSize'] ??
          tag.data['nfcb']?['capacity'] ??
          0;
    }
    if (tag.data.containsKey('nfcf')) {
      return tag.data['nfcf']?['maxTransceiveLength'] ??
          tag.data['nfcf']?['maxSize'] ??
          tag.data['nfcf']?['capacity'] ??
          0;
    }
    if (tag.data.containsKey('nfcv')) {
      return tag.data['nfcv']?['maxTransceiveLength'] ??
          tag.data['nfcv']?['maxSize'] ??
          tag.data['nfcv']?['capacity'] ??
          0;
    }
    if (tag.data.containsKey('iso15693')) {
      return tag.data['iso15693']?['maxTransceiveLength'] ??
          tag.data['iso15693']?['maxSize'] ??
          tag.data['iso15693']?['capacity'] ??
          0;
    }
    if (tag.data.containsKey('ndef')) {
      final ndef = Ndef.from(tag);
      if (ndef != null) {
        return ndef.maxSize ?? 0;
      }
    }
    if (tag.data.containsKey('maxSize')) {
      return tag.data['maxSize'] ?? 0;
    }
    if (tag.data.containsKey('capacity')) {
      return tag.data['capacity'] ?? 0;
    }
    return 0;
  }

  int _getNdefCapacity(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef != null) {
      return ndef.maxSize ?? 0;
    }
    return 0;
  }

  String _getTagId(NfcTag tag) {
    final id = tag.data['nfca']?['identifier'] ??
        tag.data['nfcb']?['identifier'] ??
        tag.data['nfcf']?['identifier'] ??
        tag.data['nfcv']?['identifier'];

    if (id != null) {
      return (id as List<int>)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':')
          .toUpperCase();
    }
    return '未知';
  }

  String getTagId(NfcTag tag) {
    return _getTagId(tag);
  }

  NfcTag? get lastTag => _lastTag;

  void resetSession() {
    _isSessionStarted = false;
  }

  bool get isSessionStarted => _isSessionStarted;

  void resetSessionState() {
    _isSessionStarted = false;
  }

  Future<Map<String, dynamic>> readTag(NfcTag tag) async {
    try {
      final ndef = Ndef.from(tag);
      String tagType = _getTagType(tag);
      int tagCapacity = _getTagCapacity(tag);
      int ndefCapacity = _getNdefCapacity(tag);

      if (ndef == null) {
        String rawInfo = '标签类型: $tagType\n';
        rawInfo += '标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}\n\n';
        rawInfo += 'ID: ${_getTagId(tag)}\n';

        return {
          'status': '发现非 NDEF 标签',
          'message': '该标签未格式化为 NDEF 或不兼容。\n\n$rawInfo',
          'tagInfo':
              '标签类型: $tagType\n标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}\nID: ${_getTagId(tag)}',
          'contentData': rawInfo,
          'isNdef': false,
          'itemList': <String>[],
        };
      }

      final cachedMessage = ndef.cachedMessage;

      if (cachedMessage == null || cachedMessage.records.isEmpty) {
        return {
          'status': '没有存放记录',
          'message': '这是一个已格式化为 NDEF 的空标签。\n\n你可以尝试使用 "写入信息" 写入内容。',
          'tagInfo':
              '标签类型: $tagType\n标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}\n数据长度: 0 字节\nID: ${_getTagId(tag)}',
          'contentData': '空标签',
          'isNdef': true,
          'is_empty': true,
          'itemList': <String>[],
          'tagId': _getTagId(tag),
          'tagName': '',
        };
      }

      String tagName = '';
      for (var record in cachedMessage.records) {
        try {
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.isNotEmpty &&
              record.type.first == 0x54) {
            int statusByte = record.payload.first;
            int languageCodeLength = statusByte & 0x3F;

            if (record.payload.length > 1 + languageCodeLength) {
              List<int> textBytes =
                  record.payload.sublist(1 + languageCodeLength);
              try {
                tagName = utf8.decode(textBytes);
              } catch (_) {
                tagName = String.fromCharCodes(textBytes);
              }
            }
          }
        } catch (_) {}
      }

      String tagInfo =
          'ID: ${_getTagId(tag)}\n类型: $tagType\n标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}';

      return {
        'status': '读取完成',
        'message': 'NFC 标签已识别!\n\n$tagInfo\n\n标签名称: $tagName',
        'tagInfo': tagInfo,
        'contentData': tagName,
        'isNdef': true,
        'is_empty': tagName.isEmpty,
        'identifier': _getTagId(tag),
        'tagId': _getTagId(tag),
        'tagName': tagName,
        'itemList': <String>[],
      };
    } catch (e) {
      String tagType = _getTagType(tag);
      int tagCapacity = _getTagCapacity(tag);
      return {
        'status': '读取异常',
        'message':
            '读取失败: $e\n\n标签类型: $tagType\n标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}',
        'tagInfo':
            '标签类型: $tagType\n标签容量: ${tagCapacity > 0 ? '$tagCapacity 字节' : '未知'}',
        'contentData': '读取失败: $e',
        'isNdef': false,
        'itemList': <String>[],
      };
    }
  }

  Future<Map<String, dynamic>> writeTextToTag(NfcTag tag, String text) async {
    int retryCount = 0;
    const int maxRetries = 3;

    try {
      final ndef = Ndef.from(tag);
      if (ndef == null) {
        return {
          'success': false,
          'message': '写入失败：标签不支持 NDEF',
        };
      }

      if (!ndef.isWritable) {
        return {
          'success': false,
          'message': '写入失败：标签已锁定，无法写入',
        };
      }

      final estimatedSize = text.length * 2 + 30;
      if (estimatedSize > ndef.maxSize) {
        return {
          'success': false,
          'message': '保存失败，标签已满',
        };
      }

      while (retryCount < maxRetries) {
        try {
          final record = NdefRecord.createText(text);
          final message = NdefMessage([record]);
          await ndef.write(message);
          return {
            'success': true,
            'message': '写入成功！',
          };
        } catch (e) {
          String errorMessage = '写入异常: $e';

          if (e.toString().contains('Tag is not found') ||
              e.toString().contains('Tag was lost') ||
              e.toString().contains('tag was lost') ||
              e.toString().contains('标签已移开') ||
              e.toString().contains('Tag removed')) {
            errorMessage = '写入失败：标签已移开，请保持标签靠近设备';
            return {
              'success': false,
              'message': errorMessage,
            };
          } else if (e.toString().contains('io_exception') ||
              e.toString().contains('IOException')) {
            retryCount++;
            if (retryCount < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 500));
              continue;
            } else {
              errorMessage = '写入失败：多次尝试后仍然失败，请检查标签是否正确放置';
            }
          } else if (e.toString().contains('Write failed') ||
              e.toString().contains('write failed')) {
            errorMessage = '写入失败：标签写入操作失败';
          } else if (e.toString().contains('Capacity exceeded') ||
              e.toString().contains('capacity exceeded') ||
              e.toString().contains('超出容量') ||
              e.toString().contains('capacity')) {
            errorMessage = '保存失败，标签已满';
          } else if (e.toString().contains('Tag is locked') ||
              e.toString().contains('tag is locked')) {
            errorMessage = '写入失败：标签已锁定，无法写入';
          }

          return {
            'success': false,
            'message': errorMessage,
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': '写入失败：未知错误: $e',
      };
    }

    return {
      'success': false,
      'message': '写入失败：未知错误',
    };
  }

  Future<Map<String, dynamic>> formatTagToNdef(NfcTag tag) async {
    try {
      final formatable = NdefFormatable.from(tag);

      if (formatable == null) {
        return {
          'success': false,
          'message': '格式化失败：标签不支持 NDEF 格式化或已锁定',
        };
      }

      final emptyRecord = NdefRecord.createText('');
      final message = NdefMessage([emptyRecord]);

      await formatable.format(message);

      return {
        'success': true,
        'message': '格式化成功！',
      };
    } catch (e) {
      if (e.toString().contains('Tag is not found')) {
        return {
          'success': false,
          'message': '格式化失败：标签已移开，请保持标签靠近设备',
        };
      }
      return {
        'success': false,
        'message': '格式化失败: $e',
      };
    }
  }
}
