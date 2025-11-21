import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR AR App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const QRScannerScreen(),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? _controller;
  String? _scannedUrl;
  bool _hasPermission = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    if (_hasPermission) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      setState(() {
        _scannedUrl = barcode.rawValue;
        _isScanning = false;
      });
      _controller?.stop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned: ${barcode.rawValue}')),
      );
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scannedUrl = null;
    });
    _controller?.start();
  }

  Future<void> _launchARViewer() async {
    if (_scannedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a QR code first')),
      );
      return;
    }

    // Build Google Scene Viewer URL
    final sceneViewerUrl = Uri.parse(
      'https://arvr.google.com/scene-viewer/1.0'
    ).replace(queryParameters: {
      'file': _scannedUrl!,
      'mode': 'ar_preferred',
      'title': '3D Model',
    });

    // Try to launch Scene Viewer
    try {
      final intent = Uri.parse(
        'intent://arvr.google.com/scene-viewer/1.0?'
        'file=${Uri.encodeComponent(_scannedUrl!)}'
        '&mode=ar_preferred'
        '&title=3D%20Model'
        '#Intent;scheme=https;'
        'package=com.google.android.googlequicksearchbox;'
        'action=android.intent.action.VIEW;end;'
      );
      
      if (await canLaunchUrl(intent)) {
        await launchUrl(intent);
      } else if (await canLaunchUrl(sceneViewerUrl)) {
        await launchUrl(sceneViewerUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: open URL in browser
        final url = Uri.parse(_scannedUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          _showError('Could not launch AR viewer');
        }
      }
    } catch (e) {
      _showError('Error launching AR: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code AR Scanner'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasPermission ? _startScanning : null,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scannedUrl != null ? _launchARViewer : null,
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('View in AR'),
                  ),
                ),
              ],
            ),
          ),
          
          // Scanner view
          Expanded(
            child: _hasPermission
                ? Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _controller != null
                        ? MobileScanner(
                            controller: _controller!,
                            onDetect: _onDetect,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Camera permission required'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _requestCameraPermission,
                          child: const Text('Grant Permission'),
                        ),
                      ],
                    ),
                  ),
          ),
          
          // Result display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _isScanning
                      ? 'Scanning...'
                      : _scannedUrl != null
                          ? 'Scanned URL:'
                          : 'Scan a QR code with a 3D model URL (.glb or .gltf)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_scannedUrl != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _scannedUrl!,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}