package com.enke.cloudpos

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall

class MainActivity : FlutterActivity() {
    private val CHANNEL = "PLUTUS-API"
    private val PLUTUS_SMART_ACTION = "com.pinelabs.masterapp.SERVER"
    private val PLUTUS_SMART_PACKAGE = "com.pinelabs.masterapp"
    private var isServiceBound = false
    private var mService: IBinder? = null
    private var pendingResult: Result? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d("MainActivity", "Service connected: $name")
            mService = service
            isServiceBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d("MainActivity", "Service disconnected: $name")
            mService = null
            isServiceBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToService" -> bindToService(result)
                "startTransaction" -> {
                    val transactionData = call.argument<String>("transactionData")
                    if (transactionData != null && isServiceBound) {
                        startTransaction(transactionData, result)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "Service not bound or missing transaction data", null)
                    }
                }
                "startPrintJob" -> {
                    val printData = call.argument<String>("printData")
                    if (printData != null && isServiceBound) {
                        startPrintJob(printData, result)
                    } else {
                        result.error("SERVICE_NOT_BOUND", "Service not bound or missing print data", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindToService(result: MethodChannel.Result) {
        try {
            val intent = Intent().apply {
                action = PLUTUS_SMART_ACTION
                setPackage(PLUTUS_SMART_PACKAGE)
            }
            val success = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
            if (success) {
                Log.d("MainActivity", "Service Binding Success")
                result.success("SUCCESS") // Return "SUCCESS" for consistency
            } else {
                Log.e("MainActivity", "Failed to bind to service")
                result.error("FAILED", "Failed to initiate service binding", null)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Exception binding to service", e)
            result.error("BINDING_ERROR", e.localizedMessage, null)
        }
    }

    private fun startTransaction(transactionData: String, result: Result) {
        try {
            Log.d("MainActivity", "Service bound, starting transaction: $transactionData")
            pendingResult = result

            val intent = Intent("com.pinelabs.masterapp.HYBRID_REQUEST").apply {
                setPackage(PLUTUS_SMART_PACKAGE)
                putExtra("REQUEST_DATA", transactionData)
                putExtra("packageName", "com.enke.cloudpos") // Your app package name
            }
            startActivityForResult(intent, 1001)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting transaction", e)
            result.error("TRANSACTION_ERROR", e.localizedMessage, null)
        }
    }

    private fun startPrintJob(printData: String, result: Result) {
        try {
            Log.d("MainActivity", "Service bound, starting print job: $printData")
            pendingResult = result

            val intent = Intent("com.pinelabs.masterapp.HYBRID_REQUEST").apply {
                setPackage(PLUTUS_SMART_PACKAGE)
                putExtra("REQUEST_DATA", printData)
                putExtra("packageName", "com.enke.cloudpos") // Your app package name
            }
            startActivityForResult(intent, 1002)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting print job", e)
            result.error("PRINT_JOB_ERROR", e.localizedMessage, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            1001, 1002 -> handleResult(requestCode, resultCode, data)
        }
    }

    private fun handleResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (pendingResult == null) {
            Log.e("MainActivity", "No pending result to return data")
            return
        }

        try {
            if (resultCode == RESULT_OK && data != null) {
                val responseData = data.getStringExtra("RESPONSE_DATA")
                Log.d("MainActivity", "Response data: $responseData")
                pendingResult?.success(responseData)
            } else {
                val errorMsg = if (requestCode == 1001) "Transaction failed" else "Print job failed"
                pendingResult?.error("FAILED", errorMsg, null)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error handling result", e)
            pendingResult?.error("ERROR", e.localizedMessage, null)
        } finally {
            pendingResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
        }
    }
}
