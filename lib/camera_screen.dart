import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_client.dart';
import 'checklist_data.dart';

// --- THE CORRECTED CODE ---
class CameraScreen extends StatefulWidget {
  final String folderId;
  final String taskName;
  final String siteAddress; // <-- ADD THIS LINE
  final GoogleSignInAccount? currentUser;
//...

  const CameraScreen({
    super.key,
    required this.folderId,
    required this.taskName,
    required this.siteAddress,
    this.currentUser,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isBusy = false;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    if (await _checkAndRequestPermissions()) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          _showError('No cameras found.');
          return;
        }
        _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
        await _controller!.initialize();
      } catch (e) {
        debugPrint('Error setting up camera: $e');
        _showError('Failed to start camera.');
      }
    }
    if (!mounted) return;
    setState(() { _isCameraReady = true; });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isBusy) return;
    setState(() { _isBusy = true; });

    try {
      final imageFile = await _controller!.takePicture();

      Position? position = await _getCurrentLocation();
      String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      String gpsStamp = "GPS: Not Available";
      String addressStamp = "Address: Not Available";

      if (position != null) {
        gpsStamp = "GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks[0];
            addressStamp = "Address: ${p.street}, ${p.locality}, ${p.postalCode}";
          }
        } catch (e) { debugPrint("Could not get address: $e"); }
      }

      final imageBytes = await File(imageFile.path).readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Could not decode image");

      final font = img.arial24;
      img.drawString(originalImage, timestamp, font: font, x: 20, y: 30, color: img.ColorRgb8(255, 255, 255));
      img.drawString(originalImage, gpsStamp, font: font, x: 20, y: 60, color: img.ColorRgb8(255, 255, 255));
      img.drawString(originalImage, addressStamp, font: font, x: 20, y: 90, color: img.ColorRgb8(255, 255, 255));

      final List<int> stampedImageBytes = img.encodeJpg(originalImage, quality: 95);

      if (await _isOnline() && widget.currentUser != null) {
        await _uploadToDrive(stampedImageBytes);
      } else {
        await _saveForLater(stampedImageBytes);
      }

    } catch (e) {
      debugPrint("Error during capture/process: $e");
      _showError("An error occurred. See debug console.");
      if (mounted) setState(() { _isBusy = false; });
    }
  }

  Future<void> _uploadToDrive(List<int> imageBytes) async {
    try {
      final authHeaders = await widget.currentUser!.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(httpClient);

      final media = drive.Media(Stream.value(imageBytes), imageBytes.length);
      var driveFile = drive.File()..name = '${widget.taskName}.jpg'..parents = [widget.folderId];
      final result = await driveApi.files.create(driveFile, uploadMedia: media, $fields: 'id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload Successful!'), backgroundColor: Colors.green));
      Navigator.of(context).pop({'status': 'COMPLETE', 'fileId': result.id, 'taskName': widget.taskName});
    } catch(e) {
      debugPrint("Error uploading to drive: $e");
      _showError("Upload Failed. Saving locally instead.");
      await _saveForLater(imageBytes);
    }
  }

  Future<void> _saveForLater(List<int> imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${_uuid.v4()}.jpg';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(imageBytes);

      final prefs = await SharedPreferences.getInstance();
      // --- THE CORRECTED CODE ---
      final pendingUpload = PendingUpload(
        localPath: filePath,
        taskName: widget.taskName,
        siteName: widget.siteAddress, // <-- ADD THIS LINE
      );

      final queueJson = prefs.getStringList('pendingUploads') ?? [];
      queueJson.add(jsonEncode(pendingUpload.toJson()));
      await prefs.setStringList('pendingUploads', queueJson);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: Photo saved locally.'), backgroundColor: Colors.orange));
      Navigator.of(context).pop({'status': 'PENDING', 'taskName': widget.taskName});
    } catch (e) {
      debugPrint("Error saving for later: $e");
      _showError("Could not save photo locally.");
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { return null; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { return null; }
      }
      if (permission == LocationPermission.deniedForever) { return null; }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Could not get location: $e");
      return null;
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var locationStatus = await Permission.location.request();

    if (cameraStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
      openAppSettings();
    }
    return cameraStatus.isGranted && locationStatus.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _controller == null || !_controller!.value.isInitialized) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Initializing Camera...")));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        Center(child: CameraPreview(_controller!)),
        if (_isBusy)
          Container(
            color: Colors.black54,
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing...', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],),),),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 120, color: Colors.black45, alignment: Alignment.center,
            child: IconButton(
              onPressed: _isBusy ? null : _captureAndProcess,
              icon: const Icon(Icons.camera, color: Colors.white, size: 72),
              iconSize: 72,
            ),),),
      ],),);
  }
}