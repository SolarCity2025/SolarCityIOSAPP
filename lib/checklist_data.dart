// MOVED TO THE TOP

// All other class/enum definitions come AFTER imports.

enum PhotoTaskStatus {
  NOT_STARTED, // Task hasn't been interacted with
  PENDING_UPLOAD, // Photo taken, saved locally, waiting for upload
  UPLOADING, // (Optional) Photo is currently being uploaded
  COMPLETE, // Photo successfully uploaded to Drive
  FAILED // (Optional) Upload failed after retries
}

ChecklistItem checklistItemFromJson(Map<String, dynamic> json) {
  if (json['type'] == 'photo') {
    return PhotoTaskItem.fromJson(json);
  } else {
    return TextTaskItem.fromJson(json);
  }
}

abstract class ChecklistItem {
  final String label;

  String get type;

  ChecklistItem({required this.label});

  Map<String, dynamic> toJson();
}

class PhotoTaskItem extends ChecklistItem {
  @override
  String get type => 'photo';

  String? localFilePath;
  PhotoTaskStatus status;
  String? fileId;

  PhotoTaskItem({
    required super.label,
    this.localFilePath,
    this.status = PhotoTaskStatus.NOT_STARTED,
    this.fileId,
  });

  factory PhotoTaskItem.fromJson(Map<String, dynamic> json) {
    return PhotoTaskItem(
      label: json['label'] as String,
      localFilePath: json['localFilePath'] as String?,
      status: PhotoTaskStatus.values.firstWhere(
            (e) => e.name == (json['status'] as String?),
        orElse: () => PhotoTaskStatus.NOT_STARTED,
      ),
      fileId: json['fileId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() =>
      {
        'type': type,
        'label': label,
        'localFilePath': localFilePath,
        'status': status.name,
        'fileId': fileId,
      };
}

class TextTaskItem extends ChecklistItem {
  @override
  String get type => 'text';
  String value;

  TextTaskItem({required super.label, this.value = ''});

  factory TextTaskItem.fromJson(Map<String, dynamic> json) {
    return TextTaskItem(
      label: json['label'],
      value: json['value'],
    );
  }

  @override
  Map<String, dynamic> toJson() =>
      {
        'type': type,
        'label': label,
        'value': value,
      };
}

// THIS IS THE CORRECT PendingUpload CLASS WE DEFINED IN STEP 1
// The other version that included 'driveFolderId' has been removed.
class PendingUpload {
  final String localPath;
  final String siteName;
  final String taskName;

  PendingUpload({
    required this.localPath,
    required this.siteName,
    required this.taskName,
  });

  Map<String, dynamic> toJson() =>
      {
        'localPath': localPath,
        'siteName': siteName,
        'taskName': taskName,
      };

  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    return PendingUpload(
      localPath: json['localPath'] as String,
      siteName: json['siteName'] as String,
      taskName: json['taskName'] as String,
    );
  }
}

List<ChecklistItem> createRooferTaskList() {
  return [
    PhotoTaskItem(label: "Pre-install photo 1"),
    PhotoTaskItem(label: "Pre-install photo 2"),
    PhotoTaskItem(label: "Pre-install photo 3"),
    PhotoTaskItem(label: "Pre-install photo 4"),
    PhotoTaskItem(label: "Pre-install photo 5"),
    PhotoTaskItem(label: "Mid-install hook 1"),
    PhotoTaskItem(label: "Mid-install hook 2"),
    PhotoTaskItem(label: "Mid-install rails 3"),
    PhotoTaskItem(label: "Mid-install rails 4"),
    PhotoTaskItem(label: "Mid-install cable entry 5"),
    PhotoTaskItem(label: "Post-install photo 1"),
    PhotoTaskItem(label: "Post-install photo 2"),
    PhotoTaskItem(label: "Post-install photo 3"),
    PhotoTaskItem(label: "Post-install photo 4"),
    PhotoTaskItem(label: "Post-install photo 5"),
  ];
}

List<ChecklistItem> createElectricianTaskList() {
  return [
    PhotoTaskItem(label: "Photo of consumer unit"),
    PhotoTaskItem(label: "Photo of cable run 1"),
    PhotoTaskItem(label: "Photo of cable run 2"),
    PhotoTaskItem(label: "Photo of cut out"),
    PhotoTaskItem(label: "Photo of roof structure"),
    PhotoTaskItem(label: "Photo of install 1"),
    PhotoTaskItem(label: "Photo of install 2"),
    PhotoTaskItem(label: "Photo of install 3"),
    PhotoTaskItem(label: "Photo of inverter"),
    PhotoTaskItem(label: "Photo of inverter label"),
    TextTaskItem(label: "Customer Name"),
    TextTaskItem(label: "Customer Email"),
    TextTaskItem(label: "Customer phone"),
    TextTaskItem(label: "Zs reading"),
    TextTaskItem(label: "Ze reading"),
    TextTaskItem(label: "Roof measurements"),
    TextTaskItem(label: "Inverter serial number"),
  ];
}

// The extra comment "In lib/checklist_data.dart (or a new file like lib/photo_task_status.dart)"
// at the very end of your previous file has also been removed as it's not needed here.