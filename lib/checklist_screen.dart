import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'auth_client.dart';
import 'checklist_data.dart';
import 'camera_screen.dart';
import 'photo_viewer_screen.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class ChecklistScreen extends StatefulWidget {
  final String siteAddress;
  final String jobRole;
  final String folderId;
  final GoogleSignInAccount? currentUser;

  const ChecklistScreen({
    super.key,
    required this.siteAddress,
    required this.jobRole,
    required this.folderId,
    this.currentUser,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late List<ChecklistItem> _items;
  late Map<String, TextEditingController> _textControllers;
  bool _isLoading = true;
  bool _isCompletingJob = false;

  final String _logSpreadsheetId = "1iw1teAX7TLRm-239YTPqOIfCUzvF_6OqGK5_Z7aASAU";
  final String _detailsSpreadsheetId = "1XXcKE5pSa2U0VB_PxyweCXaN1IPr2S_Ikek1PaDLtWQ";

  @override
  void initState() {
    super.initState();
    _textControllers = {};
    _loadChecklistState();
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.folderId}_${widget.jobRole}';
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _items = jsonList.map((json) => checklistItemFromJson(json)).toList();
    } else {
      _items = (widget.jobRole == 'Roofer') ? createRooferTaskList() : createElectricianTaskList();
    }
    _items.whereType<TextTaskItem>().forEach((item) {
      final controller = TextEditingController(text: item.value);
      controller.addListener(() {
        item.value = controller.text;
        _saveChecklistState();
      });
      _textControllers[item.label] = controller;
    });
    setState(() { _isLoading = false; });
  }

  Future<void> _saveChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.folderId}_${widget.jobRole}';
    final jsonString = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(key, jsonString);
  }

  // --- REPLACE YOUR _handlePhotoTaskTap FUNCTION WITH THIS NEW VERSION ---

  Future<void> _handlePhotoTaskTap(PhotoTaskItem item) async {
    // If the task is already complete, we navigate to the viewer.
    if (item.status == PhotoTaskStatus.COMPLETE){
      if (widget.currentUser == null || item.fileId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot view online photos while offline.'), backgroundColor: Colors.orange));
        return;
      }
      final result = await Navigator.of(context).push<Map<String,dynamic>>(
        MaterialPageRoute(
          builder: (context) => PhotoViewerScreen(
            fileId: item.fileId!,
            taskName: item.label,
            currentUser: widget.currentUser!,
          ),
        ),
      );
      if (result != null && result['retake'] == true) {
        setState(() { item.status = PhotoTaskStatus.NOT_STARTED; });
        await _handlePhotoTaskTap(item);
      }
      return;
    }

    // If the task is INCOMPLETE or PENDING, we always open the camera.
    // The CameraScreen itself knows whether to upload or save locally.
    final result = await Navigator.of(context).push<Map<String, String?>>(
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          folderId: widget.folderId,
          taskName: item.label,
          siteAddress: widget.siteAddress,
          currentUser: widget.currentUser, // Pass the nullable user
        ),
      ),
    );

    // When the camera screen returns a result, we update our checklist state
    if (result != null && result['taskName'] != null) {
      final completedTaskName = result['taskName'];
      final newStatus = result['status'];
      final uploadedFileId = result['fileId'];

      final taskToUpdate = _items.firstWhere((task) => task.label == completedTaskName) as PhotoTaskItem;

      setState(() {
        if (newStatus == 'COMPLETE') {
          taskToUpdate.status = PhotoTaskStatus.COMPLETE;
        } else if (newStatus == 'PENDING') {
          taskToUpdate.status = PhotoTaskStatus.PENDING_UPLOAD;
        } else {
          // Default or handle unexpected status string
          taskToUpdate.status =
              PhotoTaskStatus.PENDING_UPLOAD; // Or another appropriate default
        }
        taskToUpdate.fileId = uploadedFileId;
      });

      await _saveChecklistState();
    }
  }

  Future<void> _markJobAsComplete() async {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot complete job while offline.')));
      return;
    }
    setState(() { _isCompletingJob = true; });
    await _saveChecklistState();

    try {
      final authHeaders = await widget.currentUser!.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);
      final sheetsApi = sheets.SheetsApi(httpClient);

      if(widget.jobRole == 'Electrician') {
        await _appendToDetailsSheet(sheetsApi);
      }
      await _updateMasterLog(sheetsApi);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job successfully marked as complete!'), backgroundColor: Colors.green,));
      Navigator.of(context).pop();

    } catch (e) {
      developer.log("Error completing job", error: e, name: "ChecklistScreen");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating spreadsheets: ${e.toString()}'), backgroundColor: Colors.red,));
    } finally {
      if (mounted) setState(() { _isCompletingJob = false; });
    }
  }

  Future<void> _appendToDetailsSheet(sheets.SheetsApi sheetsApi) async {
    if (_detailsSpreadsheetId.contains("YOUR_ID")) {
      throw Exception("Details Spreadsheet ID is not set in the code.");
    }
    final textItems = _items.whereType<TextTaskItem>();
    final detailsMap = { for (var item in textItems) item.label : item.value };
    final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final values = [
      date,
      widget.siteAddress,
      detailsMap['Customer Name'] ?? '',
      detailsMap['Customer phone'] ?? '',
      detailsMap['Customer Email'] ?? '',
      detailsMap['Roof measurements'] ?? '',
      detailsMap['Zs reading'] ?? '',
      detailsMap['Ze reading'] ?? '',
      detailsMap['Inverter serial number'] ?? '',
    ];

    final valueRange = sheets.ValueRange()..values = [values];
    await sheetsApi.spreadsheets.values.append(valueRange, _detailsSpreadsheetId, 'Sheet1!A1', valueInputOption: 'USER_ENTERED');
  }

  Future<void> _updateMasterLog(sheets.SheetsApi sheetsApi) async {
    final findResult = await sheetsApi.spreadsheets.values.get(_logSpreadsheetId, 'Sheet1!A:F');
    int sheetRowToUpdate = -1;
    List<dynamic>? projectRowData;

    if (findResult.values != null) {
      for (int i = 0; i < findResult.values!.length; i++) {
        final row = findResult.values![i];
        if (row.length > 5 && row[5] == widget.folderId) {
          sheetRowToUpdate = i + 1;
          projectRowData = findResult.values![i];
          break;
        }
      }
    }
    if (sheetRowToUpdate == -2) { return; }

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String dateColumn;
    String overallStatus;

    if (widget.jobRole == 'Roofer') {
      dateColumn = 'D';
      bool electricianIsDone = (projectRowData != null && projectRowData.length > 4 && projectRowData[4].toString().isNotEmpty);
      overallStatus = electricianIsDone ? "Complete" : "In Progress";
    } else {
      dateColumn = 'E';
      bool rooferIsDone = (projectRowData != null && projectRowData.length > 3 && projectRowData[3].toString().isNotEmpty);
      overallStatus = rooferIsDone ? "Complete" : "In Progress";
    }

    final List<sheets.ValueRange> updateData = [];

    updateData.add(sheets.ValueRange()
      ..range = 'Sheet1!C$sheetRowToUpdate'
      ..values = [[overallStatus]]);

    updateData.add(sheets.ValueRange()
      ..range = 'Sheet1!$dateColumn$sheetRowToUpdate'
      ..values = [[date]]);

    final batchUpdateBody = sheets.BatchUpdateValuesRequest()..data = updateData..valueInputOption = 'USER_ENTERED';
    await sheetsApi.spreadsheets.values.batchUpdate(batchUpdateBody, _logSpreadsheetId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea( // <<< --- ADD THIS LINE
      child: Scaffold( // <<< This Scaffold is now the child of SafeArea
        appBar: AppBar(title: Text(widget.siteAddress),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(20.0),
            child: Text('${widget.jobRole} Checklist', style: const TextStyle(
                fontSize: 16, color: Colors.white70)),),),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : buildChecklist(),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _isCompletingJob ? null : _markJobAsComplete,
            child: _isCompletingJob ? const CircularProgressIndicator(
              color: Colors.white,) : Text(
                'Mark ${widget.jobRole} Work as Complete'),
          ),
        ),
      ),
    ); // <<< --- ADD THIS CLOSING PARENTHESIS for SafeArea
  }

  ListView buildChecklist() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        if (item is PhotoTaskItem) {
          return ListTile(
            leading: _getIconForItemStatus(item.status),
            title: Text(item.label),
            onTap: () { _handlePhotoTaskTap(item); },
          );
        } else if (item is TextTaskItem) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _textControllers[item.label],
              decoration: InputDecoration(labelText: item.label, border: const OutlineInputBorder()),
            ),
          );
        }
        return Container();
      },
    );
  }

  Widget? _getIconForItemStatus(PhotoTaskStatus status){
    switch (status) {
      case PhotoTaskStatus.COMPLETE:
        return const Icon(Icons.check_circle, color: Colors.green);
      case PhotoTaskStatus.PENDING_UPLOAD:
        return const Icon(Icons.sync, color: Colors.orange);
      default:
        return const Icon(Icons.camera_alt_outlined, color: Colors.grey);
    }
  }
}