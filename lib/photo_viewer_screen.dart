import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'auth_client.dart';

class PhotoViewerScreen extends StatefulWidget {
  final String fileId;
  final String taskName;
  final GoogleSignInAccount currentUser;

  const PhotoViewerScreen({
    super.key,
    required this.fileId,
    required this.taskName,
    required this.currentUser,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloadPhoto();
  }

  Future<void> _downloadPhoto() async {
    try {
      final authHeaders = await widget.currentUser.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(httpClient);

      final media = await driveApi.files.get(widget.fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final List<int> dataStore = [];
      await for (var data in media.stream) {
        dataStore.addAll(data);
      }

      final imageBytes = Uint8List.fromList(dataStore);

      setState(() {
        _imageData = imageBytes;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error downloading image: $e");
      setState(() { _error = "Failed to download image."; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.taskName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _buildBody(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.orange.shade700,
          ),
          onPressed: () {
            Navigator.of(context).pop({'retake': true});
          },
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Retake Photo'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Text('Error: $_error', style: const TextStyle(color: Colors.white));
    }
    if (_imageData != null) {
      return InteractiveViewer(
        child: Image.memory(_imageData!),
      );
    }
    return const Text('No image to display.', style: TextStyle(color: Colors.white));
  }
}