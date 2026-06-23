package com.example.storage_assistant

import android.content.Intent
import android.nfc.NfcAdapter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private var nfcAdapter: NfcAdapter? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        val action = intent.action
        if (action != null && action.startsWith("android.nfc.action")) {
            // 完全消费掉 NFC 意图，防止系统传递给其他应用
            intent.setAction(null)
            intent.setData(null)
            intent.setType(null)
            intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            // 清除所有 extras
            intent.replaceExtras(android.os.Bundle())
            
            // 如果是 Android 10+，清除剪贴板数据
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                intent.clipData = null
            }
        }
        
        setIntent(intent)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        val intent = intent
        val action = intent.action
        if (action != null && action.startsWith("android.nfc.action")) {
            intent.setAction(null)
            intent.setData(null)
            intent.setType(null)
        }
    }

    override fun onResume() {
        super.onResume()
        
        val intent = intent
        val action = intent.action
        if (action != null && action.startsWith("android.nfc.action")) {
            intent.setAction(null)
            intent.setData(null)
            intent.setType(null)
        }
    }

    override fun onPause() {
        super.onPause()
        // 在应用暂停时，确保 NFC 意图被清除
        val intent = intent
        val action = intent.action
        if (action != null && action.startsWith("android.nfc.action")) {
            intent.setAction(null)
            intent.setData(null)
            intent.setType(null)
        }
    }
}
