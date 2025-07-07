

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'auth_client.dart';
import 'checklist_screen.dart';
import 'checklist_data.dart';
import 'package:audioplayers/audioplayers.dart';

// THIS IS THE NEW CODE TO ADD:

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FOR TESTING ONLY: Clear all SharedPreferences on app start
  //SharedPreferences prefs = await SharedPreferences.getInstance();
  //await prefs.clear();
  //print("SharedPreferences cleared for testing.");
  // END TESTING CODE

  runApp(const SoundEnabledMyApp()); // <<<--- MODIFIED: Now runs SoundEnabledMyApp
}

// CLASS TO HOLD THE ACTUAL APP AND ITS SOUND LOGIC
class SoundEnabledMyApp extends StatefulWidget {
  const SoundEnabledMyApp({super.key});

  @override
  State<SoundEnabledMyApp> createState() => _SoundEnabledMyAppState();
}

class _SoundEnabledMyAppState extends State<SoundEnabledMyApp> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playLaunchSound();
  }

  Future<void> _playLaunchSound() async {
    try {
      // CRITICAL: Ensure you have a sound file at 'assets/sounds/launch_sound.mp3'
      // or change this path to your actual sound file.
      // Example: await _audioPlayer.play(AssetSource('sounds/my_chime.wav'));
      // Don't forget to declare your assets folder in pubspec.yaml
      await _audioPlayer.play(AssetSource('sounds/solarcityintro.mp3'));
      debugPrint("Launch sound played successfully.");
    } catch (e) {
      debugPrint("Error playing launch sound: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This is the content from your original MyApp's build method
    return MaterialApp(
      title: 'Site App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const ProjectListScreen(), // This correctly points to your existing screen
    );
  }
}

// END OF NEW CODE TO ADD



class ProjectInfo {
  String id;
  final String name;
  final int rowIndex;
  bool isOffline;

  ProjectInfo(this.id, this.name, this.rowIndex, {this.isOffline = false});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'rowIndex': rowIndex, 'isOffline': isOffline,
  };

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      json['id'], json['name'], json['rowIndex'],
      isOffline: json['isOffline'] ?? false,
    );
  }
}

const String webClientId = "428486523725-7ud0br3iuorbb3qkdubt7la77tl3rbfg.apps.googleusercontent.com"; // <-- USE THIS ONE
const String spreadsheetId = "1iw1teAX7TLRm-239YTPqOIfCUzvF_6OqGK5_Z7aASAU";




class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});
  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  bool _isLoading = true;
  List<ProjectInfo> _projects = [];
  String? _statusMessage;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  sheets.SheetsApi? _sheetsApi;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _handleAppStart();
  }

  Future<void> _handleSignOut() async {
    final googleSignIn = GoogleSignIn();
    bool signedOut = false;
    bool disconnected = false;

    try {
      await googleSignIn.signOut();
      signedOut = true;
      debugPrint("User successfully signed out (googleSignIn.signOut).");

      // Attempt disconnect, but don't let it block the rest of the sign-out flow if it fails
      try {
        await googleSignIn.disconnect();
        disconnected = true;
        debugPrint("User successfully disconnected (googleSignIn.disconnect).");
      } catch (disconnectError) {
        debugPrint(
            "Error during googleSignIn.disconnect(): $disconnectError. Proceeding with sign-out state reset.");
        // Log the error, but don't rethrow or set a user-facing error message specifically for this.
        // The main goal is to allow re-authentication.
      }

      setState(() {
        _currentUser = null;
        _driveApi = null;
        _sheetsApi = null;
        _projects = [];
        _statusMessage = "You have been signed out.";
        if (disconnected) {
          _statusMessage = "You have been signed out and disconnected.";
        }
        _isLoading = false;
      });
    } catch (signOutError) {
      debugPrint("Error during googleSignIn.signOut(): $signOutError");
      if (mounted) {
        setState(() {
          _statusMessage = "Error during sign out process.";
          // Potentially leave _isLoading as is, or set it to false if the user can't proceed.
        });
      }
    }
  }

  Future<void> _syncOfflinePhotos(List<ProjectInfo> currentProjects) async {
    // Ensure Drive API is available
    if (_driveApi == null) {
      debugPrint("Drive API not initialized. Cannot sync offline photos.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingPhotosJson = prefs.getStringList('pendingUploads') ?? [];

    if (pendingPhotosJson.isEmpty) {
      debugPrint("No pending photos to upload.");
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    List<PendingUpload> pendingUploads = pendingPhotosJson
        .map((jsonString) => PendingUpload.fromJson(jsonDecode(jsonString)))
        .toList();
    List<PendingUpload> successfullyUploaded = [];
    List<PendingUpload> failedToFindProject = [];

    // Inside _syncOfflinePhotos()
    // Inside _syncOfflinePhotos()
    // ... after List<PendingUpload> failedToFindProject = [];

    // CORRECTED SECTION:
    List<ProjectInfo> allProjects = List<ProjectInfo>.from(currentProjects);

    if (allProjects.isEmpty) {
      debugPrint(
          "Warning: currentProjects list passed to _syncOfflinePhotos was empty. Cannot determine upload folders for photos.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); // Keep UI consistent
      }
      return;
    }
    // END OF CORRECTED SECTION

     for (var uploadJob in pendingUploads) {
      try {
        ProjectInfo? parentProject;
        debugPrint("--- Processing uploadJob ---");
        debugPrint("uploadJob siteName: ${uploadJob.siteName}");
        debugPrint("uploadJob taskName: ${uploadJob.taskName}");
        debugPrint("--- Current allProjects for matching: ---");
        for (var proj in allProjects) {
          debugPrint("Project: ${proj.name}, ID: ${proj.id}, isOffline: ${proj
              .isOffline}");
        }
        // Then the try-catch for parentProject = allProjects.firstWhere(...)
        try {
          parentProject = allProjects.firstWhere(
                (p) =>
            p.name == uploadJob.siteName && p.id.isNotEmpty &&
                !p.id.startsWith('temp_') && !p.id.startsWith('offline_'),
          );
        } catch (e) {
          parentProject = null;
        }

        if (parentProject == null || parentProject.id.isEmpty) {
          debugPrint(
              "Skipping photo for ${uploadJob.siteName} - ${uploadJob
                  .taskName}: Parent project not found or its Drive folder ID is missing.");
          failedToFindProject.add(uploadJob);
          continue;
        }

        final File photoFile = File(uploadJob.localPath);
        if (!await photoFile.exists()) {
          debugPrint(
              "Skipping photo for ${uploadJob.siteName} - ${uploadJob
                  .taskName}: Local file not found at ${uploadJob
                  .localPath}. Removing from queue.");
          successfullyUploaded.add(uploadJob);
          continue;
        }

        final imageBytes = await photoFile.readAsBytes();
        final media = drive.Media(Stream.value(imageBytes), imageBytes.length);
        final String photoFileName = '${uploadJob.taskName.replaceAll(
            RegExp(r'[^\w\s.-]'), '_')}.jpg';
        final driveFile = drive.File()
          ..name = photoFileName
          ..parents = [parentProject.id];

        debugPrint("Uploading $photoFileName to folder ${parentProject
            .id} for site ${parentProject.name}");

        final drive.File uploadedDriveFile = await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
          $fields: 'id',
        );

        if (uploadedDriveFile.id != null) {
          debugPrint(
              "Successfully uploaded $photoFileName, Drive File ID: ${uploadedDriveFile
                  .id}");
          List<String> jobRoles = ['Roofer', 'Electrician'];
          bool checklistUpdated = false;
          for (String role in jobRoles) {
            final checklistKey = '${parentProject.id}_$role';
            final checklistJsonString = prefs.getString(checklistKey);

            if (checklistJsonString != null) {
              List<dynamic> checklistRaw = jsonDecode(checklistJsonString);
              List<ChecklistItem> items = checklistRaw.map((j) =>
                  checklistItemFromJson(j)).toList();
              int itemIndex = items.indexWhere((item) =>
              item is PhotoTaskItem &&
                  item.label == uploadJob.taskName &&
                  item.status == PhotoTaskStatus.PENDING_UPLOAD);

              if (itemIndex != -1) {
                PhotoTaskItem taskToUpdate = items[itemIndex] as PhotoTaskItem;
                taskToUpdate.status = PhotoTaskStatus.COMPLETE;
                taskToUpdate.fileId = uploadedDriveFile.id;
                taskToUpdate.localFilePath = null;

                items[itemIndex] = taskToUpdate;
                await prefs.setString(checklistKey,
                    jsonEncode(items.map((i) => i.toJson()).toList()));
                debugPrint("Updated checklist item '${uploadJob
                    .taskName}' for role '$role' in project '${parentProject
                    .name}'.");
                checklistUpdated = true;
                break;
              }
            }
          }
          if (!checklistUpdated) {
            debugPrint("Warning: Photo '${uploadJob
                .taskName}' for project '${parentProject
                .name}' uploaded, but corresponding PENDING_UPLOAD checklist item not found or updated.");
          }
          try {
            await photoFile.delete();
            debugPrint("Deleted local file: ${uploadJob.localPath}");
          } catch (e) {
            debugPrint("Error deleting local file ${uploadJob.localPath}: $e.");
          }
          successfullyUploaded.add(uploadJob);
        } else {
          debugPrint(
              "Failed to upload $photoFileName: No ID returned from Drive API. Will retry later.");
        }
      } catch (e, s) {
        debugPrint("Failed to upload pending photo for ${uploadJob
            .siteName} - ${uploadJob.taskName}: $e");
        debugPrint("Stack trace: $s");
      }
    }

    pendingUploads.removeWhere((p) =>
    successfullyUploaded.contains(p) || failedToFindProject.contains(p));

    List<String> remainingQueueJson =
    pendingUploads.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('pendingUploads', remainingQueueJson);

    debugPrint("${successfullyUploaded.length -
        failedToFindProject.length} photos uploaded. ${failedToFindProject
        .length} photos skipped due to missing project data. ${remainingQueueJson
        .length} photos remaining in queue for retry.");

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi);
  }

  Future<void> _handleAppStart() async {
    setState(() { _isLoading = true; _statusMessage = "Initializing..."; });
    await _loadProjectsFromCache();

    if (await _isOnline()) {
      await _signInAndSync();
    } else {
      setState(() { _statusMessage = "You are offline. Showing cached projects."; _isLoading = false; });
    }
  }

  // --- REPLACE YOUR _signInAndSync FUNCTION WITH THIS ---

  Future<void> _signInAndSync() async {
final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveScope, sheets.SheetsApi.spreadsheetsScope]); // clientId parameter REMOVED
    try {
      // First, try to sign in silently without showing a dialog
      // This will work if the user has signed in before
      GoogleSignInAccount? account = await googleSignIn.signInSilently();

      // If silent sign-in fails, show the interactive sign-in dialog
      account ??= await googleSignIn.signIn();

      if (account == null) {
        setState(() { _statusMessage = "Sign-in was cancelled."; _isLoading = false; });
        return;
      }

      final authHeaders = await account.authHeaders;
      final httpClient = GoogleAuthClient(authHeaders);

      setState(() {
        _currentUser = account;
        _sheetsApi = sheets.SheetsApi(httpClient);
        _driveApi = drive.DriveApi(httpClient);
      });

      // Now that we are definitely signed in and have our APIs ready, start the sync
      await _syncAndFetchProjects();

    } catch (e) {
      debugPrint('Error during sign-in: $e');
      setState(() { _statusMessage = "An error occurred during sign-in."; _isLoading = false; });
    }
  }

  Future<void> _syncAndFetchProjects() async {
    if (!mounted) {
      return; // Good practice at the start of async methods in State
    }
    setState(() {
      _isLoading = true;
      _statusMessage = "Syncing online data..."; // More generic message
    });

    try {
      await _syncOfflineProjects(); // This should manage its own status messages if long
      if (!mounted) return;

      await _fetchProjectsFromSheet(); // This sets _isLoading = false on completion/error
      if (!mounted) return;

      // _fetchProjectsFromSheet would have set _isLoading = false.
      // If _syncOfflinePhotos also needs a loading indicator, it should set it true
      // and then false in its own finally block.
      // For now, let's assume _syncOfflinePhotos doesn't need to re-set the main screen's _isLoading.
      // If it does, the logic here needs adjustment.
      // Let _syncOfflinePhotos run. Its internal _isLoading = true/false is for its own progress.
      await _syncOfflinePhotos(_projects);
    } catch (e, s) {
      debugPrint("Error during _syncAndFetchProjects: $e");
      debugPrint("Stack trace for _syncAndFetchProjects: $s");
      if (mounted) {
        setState(() {
          _statusMessage = "An error occurred during sync.";
          _isLoading = false; // <<< --- ADD THIS! ---
        });
      }
    } finally {
      // Ensure isLoading is false if not already set by a sub-function's finally
      // or an error path. This is a final safety net.
      // _fetchProjectsFromSheet and _syncOfflinePhotos should have set it false.
      // This is mainly for the case where _syncOfflineProjects errors out
      // and the catch block above handles it.
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          if (_statusMessage ==
              "Syncing online data...") { // Clear default sync message if no error
            _statusMessage = null;
          }
        });
      }
    }
  }

  Future<void> _fetchProjectsFromSheet() async {
    if (_sheetsApi == null) { setState(() => _statusMessage = "Not authenticated."); return; }
    setState(() { _statusMessage = "Fetching latest projects..."; });

    try {
      final result = await _sheetsApi!.spreadsheets.values.get(spreadsheetId, 'Sheet1!A2:F');
      List<ProjectInfo> onlineProjects = [];
      if (result.values != null) {
        onlineProjects = result.values!
            .asMap().entries
            .where((entry) => entry.value.isNotEmpty && entry.value[0].toString().trim().isNotEmpty)
            .map((entry) => ProjectInfo(
            entry.value.length > 5 && entry.value[5].toString().isNotEmpty ? entry.value[5].toString() : 'temp_${_uuid.v4()}',
            entry.value[0].toString(),
            entry.key + 2,
            isOffline: false)
        ).toList();
      }
      await _saveProjectsToCache(onlineProjects);
      await _loadProjectsFromCache();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      setState(() { _statusMessage = "Failed to fetch projects."; });
    } finally {
      if (mounted) setState(() { _isLoading = false; _statusMessage = null; });
    }
  }

  Future<void> _saveProjectsToCache(List<ProjectInfo> projectsToSave) async {
    debugPrint(
        "--- ENTERING _saveProjectsToCache (Timestamp: ${DateTime.now()}) ---");
    debugPrint("Projects PASSED TO _saveProjectsToCache (count: ${projectsToSave
        .length}):");
    for (var p_in in projectsToSave) {
      debugPrint("  In: ${p_in.name}, ID: ${p_in.id}, isOffline: ${p_in
          .isOffline}, rowIndex: ${p_in.rowIndex}");
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getStringList('cached_projects') ?? [];
    List<ProjectInfo> existingCachedProjects = cachedJson
        .map((p) => ProjectInfo.fromJson(jsonDecode(p)))
        .toList();

    debugPrint(
        "Existing CACHED projects BEFORE merge (count: ${existingCachedProjects
            .length}):");
    for (var p_cache in existingCachedProjects) {
      debugPrint(
          "  Cache: ${p_cache.name}, ID: ${p_cache.id}, isOffline: ${p_cache
              .isOffline}, rowIndex: ${p_cache.rowIndex}");
    }

    // Create a map of the new projects for easier lookup
    Map<String, ProjectInfo> projectsToSaveMap = {
      for (var p in projectsToSave) p.name: p
    };

    List<ProjectInfo> finalProjectList = [];

    // Add or update projects from projectsToSave
    for (var newProject in projectsToSave) {
      finalProjectList.add(newProject);
    }

    // Add any offline projects from cache that weren't in projectsToSave
    // (e.g., a truly new offline project not yet on the sheet)
    for (var cachedProject in existingCachedProjects) {
      if (!projectsToSaveMap.containsKey(cachedProject.name) &&
          cachedProject.isOffline) {
        debugPrint(
            "Adding purely offline project from cache to final list: ${cachedProject
                .name}");
        finalProjectList.add(cachedProject);
      } else if (projectsToSaveMap.containsKey(cachedProject.name) &&
          cachedProject.isOffline &&
          !projectsToSaveMap[cachedProject.name]!.isOffline) {
        debugPrint("Project ${cachedProject
            .name} was in cache as offline, but now in projectsToSave as online. Using online version.");
        // The online version is already added from projectsToSaveMap, so do nothing here.
      } else if (projectsToSaveMap.containsKey(cachedProject.name) &&
          !cachedProject.isOffline &&
          projectsToSaveMap[cachedProject.name]!.isOffline) {
        debugPrint("Warning: Project ${cachedProject
            .name} was in cache as ONLINE, but projectsToSave has it as OFFLINE. This is unusual. Prioritizing projectsToSave version.");
        // The version from projectsToSave is already in finalProjectList.
      }
    }
    // De-duplicate just in case, prioritizing based on isOffline status if names clash after all.
    // This is a bit defensive; the logic above should handle most cases.
    Map<String, ProjectInfo> deduplicatedMap = {};
    for (var project in finalProjectList) {
      // If project already in map:
      // - If current map entry is offline and new one is online, replace.
      // - Otherwise, keep existing (or if both same offline status, first one wins, which is fine)
      if (deduplicatedMap.containsKey(project.name)) {
        if (deduplicatedMap[project.name]!.isOffline && !project.isOffline) {
          deduplicatedMap[project.name] = project; // Online overrides offline
        }
      } else {
        deduplicatedMap[project.name] = project;
      }
    }
    finalProjectList = deduplicatedMap.values.toList();


    debugPrint(
        "FINAL list of projects to be saved to cache (count: ${finalProjectList
            .length}):");
    for (var p_final in finalProjectList) {
      debugPrint(
          "  Final: ${p_final.name}, ID: ${p_final.id}, isOffline: ${p_final
              .isOffline}, rowIndex: ${p_final.rowIndex}");
    }

    List<String> allProjectsJson =
    finalProjectList.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('cached_projects', allProjectsJson);
    debugPrint("--- EXITING _saveProjectsToCache (Projects saved) ---");
  }

  Future<void> _loadProjectsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final projectJsonList = prefs.getStringList('cached_projects');
    if (projectJsonList != null) {
      setState(() {
        _projects = projectJsonList.map((json) => ProjectInfo.fromJson(jsonDecode(json))).toList();
      });
    }
  }

  void _showCreateProjectDialog() {
    final addressController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Create New Site"),
      content: TextField(controller: addressController, decoration: const InputDecoration(hintText: "Enter Site Address")),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            if (addressController.text.isNotEmpty) {
              Navigator.of(context).pop();
              _handleCreateSite(addressController.text);
            }
          },
          child: const Text("Create"),
        ),
      ],
    ));
  }

// --- THE CORRECTED CODE ---
  Future<void> _handleCreateSite(String siteName) async {
    if (await _isOnline() && _sheetsApi != null) {
      setState(() { _isLoading = true; });
      // The corrected line now passes a blank string for the folderId
      await _appendNewRowToSheet(siteName, '');
      await _fetchProjectsFromSheet();
    } else {
      final newProject = ProjectInfo('offline_${_uuid.v4()}', siteName, -1, isOffline: true);
      setState(() { _projects.add(newProject); });
      await _saveProjectsToCache(_projects);
    }
    setState(() { _isLoading = false; });
  }

  // NEW start of _handleProjectTap
Future<void> _handleProjectTap(ProjectInfo project) async {
    debugPrint(
        "--- _handleProjectTap entered. Project: '${project.name}', ID: '${project.id}', isOffline: ${project.isOffline}, Current _isLoading: $_isLoading");

    // Case 1: Project is already fully synced online (has a non-temporary, non-offline, valid Drive ID)
    if (project.id.isNotEmpty &&
        !project.id.startsWith('temp_') &&      // project with 'temp_' ID needs online setup
        !project.id.startsWith('offline_') &&   // project with 'offline_' ID is explicitly offline
        !project.isOffline) {                   // project marked isOffline is explicitly offline
      debugPrint(
          "--- _handleProjectTap: Project '${project.name}' is ALREADY SYNCED and online. Navigating to role selection.");
      _showRoleSelectionDialog(project);
      return; // Exit, already good
    }

    // Case 2: Project was explicitly created offline OR is marked as offline.
    // We allow navigation for offline use.
    // A project with a 'temp_' ID (from sheet, missing Drive ID) should NOT exit here. It needs online setup.
    if (project.isOffline || project.id.startsWith('offline_')) {
      debugPrint(
          "--- _handleProjectTap: Project '${project.name}' is marked for EXPLICIT OFFLINE access (isOffline=${project.isOffline} or ID starts with 'offline_'). Navigating for offline use.");
      _showRoleSelectionDialog(project);
      return; // Exit, allow offline use
    }

    // --- IF WE REACH HERE, the project EITHER:
    // 1. Has a 'temp_' ID (meaning it was fetched from the sheet and its Drive Folder ID in column F was empty).
    //    This project NEEDS to proceed to the online setup logic below.
    // 2. Or some other edge case where it's not fully synced and not explicitly offline.
    debugPrint(
        "--- _handleProjectTap: Project '${project.name}' (ID: ${project.id}, isOffline: ${project.isOffline}) requires online setup/check. Proceeding to online logic...");

    // THE REST OF YOUR _handleProjectTap function (from "bool isCurrentlyOnline;" onwards) REMAINS UNCHANGED.


    // --- IF WE REACH HERE, IT'S A PROJECT THAT *SHOULD* BE ONLINE BUT ISN'T FULLY SET UP ---
    // --- This path is now primarily for projects that were fetched from the sheet but are missing a Drive ID,
    // --- or some other edge case where an "online" project still needs folder creation.
    // --- However, with the changes to how offline projects are handled,
    // --- this block might become less frequently hit for the initial tap.

    debugPrint(
        "--- _handleProjectTap: Project '${project.name}' (ID: ${project
            .id}, isOffline: ${project
            .isOffline}) does not meet direct offline/online criteria. Proceeding to online setup/check logic.");


    bool isCurrentlyOnline;
    try {
      debugPrint(
          "--- _handleProjectTap: About to call _isOnline() for project '${project
              .name}'.");
      isCurrentlyOnline = await _isOnline();
      debugPrint(
          "--- _handleProjectTap: _isOnline() call completed. Result: $isCurrentlyOnline for project '${project
              .name}'.");
    } catch (e, s) {
      debugPrint(
          "--- _handleProjectTap: CRITICAL ERROR during _isOnline() call or await: $e for project '${project
              .name}'.");
      debugPrint("--- _handleProjectTap: Stacktrace for _isOnline() error: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error checking network status.")),
        );
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    // If still not online, and it's a project that we thought needed online setup (but wasn't temp/offline initially)
    if (!isCurrentlyOnline) {
      debugPrint(
          "--- _handleProjectTap: User is OFFLINE. Project '${project
              .name}' requires online setup which cannot be performed. Showing SnackBar.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Cannot complete project setup. You are offline.")),
        );
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    // --- ONLINE PATH CONTINUES (for projects that need Drive folder creation etc.) ---
    debugPrint(
        "--- _handleProjectTap: User is ONLINE. Proceeding with Drive/Sheet setup for '${project
            .name}'.");

    if (_driveApi == null || _sheetsApi == null) {
      debugPrint(
          "--- _handleProjectTap: Drive or Sheets API is NULL. Cannot proceed with online setup for '${project
              .name}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Cannot set up project. Authentication error.")),
        );
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    if (!mounted) {
      debugPrint(
          "--- _handleProjectTap: Online path, but widget NOT MOUNTED before setting _isLoading=true. Returning for '${project
              .name}'.");
      return;
    }

    debugPrint(
        "--- _handleProjectTap: Setting _isLoading = true for online setup of '${project
            .name}'.");
    setState(() {
      _isLoading = true;
      _statusMessage = "Setting up '${project.name}'...";
    });

    try {
      debugPrint(
          "--- _handleProjectTap: Entering TRY block for Drive/Sheet operations for '${project
              .name}'.");
      final parentFolderId = await _getOrCreateParentFolder(_driveApi!);
      if (!mounted) {
        debugPrint(
            "--- _handleProjectTap: NOT MOUNTED after _getOrCreateParentFolder. Returning for '${project
                .name}'.");
        return;
      }
      final newFolderId = await _createSiteFolder(project.name, parentFolderId);
      debugPrint(
          "--- _handleProjectTap: Project '${project
              .name}': Created Drive folder ID: $newFolderId");

      // Important: We need to update the project's ID in our local state _projects
      // AND in the cache after it's successfully created online.

      // Fetch fresh projects to get the correct rowIndex if it was a new project
      // or to confirm details of existing ones.
      await _fetchProjectsFromSheet(); // This will also save to cache and update _projects state
      if (!mounted) {
        debugPrint(
            "--- _handleProjectTap: NOT MOUNTED after _fetchProjectsFromSheet. Returning for '${project
                .name}'.");
        return;
      }

      // Find the project again in the updated _projects list.
      // It's possible the original 'project' object passed to this function
      // is now stale if _fetchProjectsFromSheet modified the list.
      ProjectInfo? updatedProjectOnline = _projects.firstWhere(
              (p) =>
          p.name == project.name && (p.id == newFolderId ||
              (p.rowIndex == project.rowIndex && project.rowIndex != -1)),
          orElse: () {
            // Fallback: if it was a purely offline project, its rowIndex might still be -1
            // and its ID would have been 'offline_...' before.
            // We need to match by name and assume it's the one we just processed.
            return _projects.firstWhere(
                  (p) => p.name == project.name && !p.isOffline,
              // Find the online version by name
              orElse: () => null_project_info, // Should not happen if fetch worked
            );
          }
      );


      if (updatedProjectOnline.id != null_project_info.id) {
        String finalFolderId = newFolderId; // Default to the newly created one

        // If the project fetched from sheet already had a valid Drive ID, use that.
        // This handles the case where the folder existed but the local cache was out of sync.
        if (updatedProjectOnline.id.isNotEmpty &&
            !updatedProjectOnline.id.startsWith('temp_') &&
            !updatedProjectOnline.id.startsWith('offline_')) {
          debugPrint(
              "--- _handleProjectTap: Project '${updatedProjectOnline
                  .name}' ALREADY HAS Drive ID ${updatedProjectOnline
                  .id} from sheet. Using it.");
          finalFolderId = updatedProjectOnline.id;
        } else {
          // If the fetched project from sheet does NOT have a Drive ID (column F was empty),
          // then we need to update the sheet with the newFolderId we just created.
          debugPrint(
              "--- _handleProjectTap: Project '${updatedProjectOnline
                  .name}' needs sheet update with new folder ID $newFolderId for row ${updatedProjectOnline
                  .rowIndex}.");
          await _updateSheetWithFolderId(
              updatedProjectOnline.rowIndex, newFolderId);
          updatedProjectOnline.id = newFolderId; // Update the local object's ID
          debugPrint(
              "--- _handleProjectTap: Project '${updatedProjectOnline
                  .name}': Sheet updated.");
        }

        updatedProjectOnline.isOffline = false; // Mark as online now

        // Update the project in the main _projects list and save to cache again
        int projectIndexInState = _projects.indexWhere((p) =>
        p.name == updatedProjectOnline.name);
        if (projectIndexInState != -1) {
          _projects[projectIndexInState] = updatedProjectOnline;
        } else {
          _projects.add(updatedProjectOnline); // Should ideally be an update
        }

        if (mounted) {
          setState(() {
            // The _projects list is already updated, just need to trigger a rebuild if necessary
            // and clear status message. _isLoading should be false from _fetchProjectsFromSheet.
            _statusMessage = "Project '${project.name}' setup complete.";
          });
        }
        await _saveProjectsToCache(
            List.from(_projects)); // Save the fully updated list
        debugPrint(
            "--- _handleProjectTap: Project '${updatedProjectOnline
                .name}': Saved to cache with ID ${updatedProjectOnline
                .id}, isOffline=false.");

        _showRoleSelectionDialog(updatedProjectOnline);
      } else {
        debugPrint(
            "--- _handleProjectTap: ERROR - Project '${project
                .name}' NOT FOUND or has invalid ID in _projects list after fetching from sheet and attempting online setup.");
        if (mounted) {
          setState(() =>
          _statusMessage =
          "Error finalizing project '${project.name}' after setup attempt.");
          // _isLoading should be false from _fetchProjectsFromSheet
        }
      }
    } catch (e, s) {
      debugPrint(
          "--- _handleProjectTap: ERROR during Drive/Sheet operations for project '${project
              .name}': $e");
      debugPrint("--- _handleProjectTap: Stack trace: $s");
      if (mounted) {
        setState(() {
          _statusMessage = "Failed to set up project '${project.name}'.";
          _isLoading = false; // Explicitly set false in catch
        });
      }
    } finally {
      debugPrint(
          "--- _handleProjectTap: Entering FINALLY block for project '${project
              .name}'. Current _isLoading: $_isLoading.");
      if (mounted && _isLoading) {
        debugPrint(
            "--- _handleProjectTap: FINALLY block - _isLoading is TRUE and mounted. Setting _isLoading = false for '${project
                .name}'.");
        setState(() {
          _isLoading = false;
          if (_statusMessage != null &&
              _statusMessage!.startsWith("Setting up")) {
            _statusMessage = null;
          }
        });
      } else if (mounted && !_isLoading) {
        debugPrint(
            "--- _handleProjectTap: FINALLY block - _isLoading is FALSE and mounted. No change to _isLoading needed for '${project
                .name}'.");
      } else if (!mounted) {
        debugPrint(
            "--- _handleProjectTap: FINALLY block - NOT MOUNTED. Cannot call setState for '${project
                .name}'.");
      }
    }
    debugPrint(
        "--- _handleProjectTap finished for project: '${project
            .name}'. Final _isLoading: $_isLoading");
  }

// Helper for the orElse in firstWhere, to avoid nullable ProjectInfo directly
  final ProjectInfo null_project_info = ProjectInfo(
      "", "", -1); // A dummy non-null project

  void _showRoleSelectionDialog(ProjectInfo project) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Role'),
          content: Text('Select role for:\n${project.name}'),
          actions: <Widget>[
            TextButton(child: const Text('Roofer'), onPressed: () {
              Navigator.of(context).pop();
              _navigateToNextScreen(project, 'Roofer');
            },),
            TextButton(child: const Text('Electrician'), onPressed: () {
              Navigator.of(context).pop();
              _navigateToNextScreen(project, 'Electrician');
            },),
          ],
        );
      },
    );
  }

  void _navigateToNextScreen(ProjectInfo project, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ChecklistScreen(
              siteAddress: project.name,
              folderId: project.id, // Using your correct 'folderId'
              jobRole: role,
              currentUser: _currentUser,
            ),
      ),
    ).then((_) async {
      debugPrint("Popped from ChecklistScreen for project: ${project
          .name}. Refreshing project list UI from cache.");

      if (mounted) {
        // Simply load from cache. If the checklist screen caused changes that were synced
        // AND correctly saved to cache (due to the fixes above), this will reflect them.
        setState(() {
          _isLoading = true;
        }); // Show loading while reloading from cache
        await _loadProjectsFromCache();
        setState(() {
          _isLoading = false;
        }); // Hide loading

        // Optional: If you want to be absolutely sure and network is available,
        // you could trigger a full sync here, but it might be overkill.
        // if (await _isOnline()) {
        //   await _signInAndSync();
        // }
      }
    });
  }

  Future<String> _getOrCreateParentFolder(drive.DriveApi driveApi) async {
        const parentFolderName = "Company Job Photos";
        const query = "mimeType='application/vnd.google-apps.folder' and name='$parentFolderName' and trashed=false";
        debugPrint("[Drive Debug] Querying for parent folder: $query");
        try {
            final result = await driveApi.files.list(q: query, $fields: 'files(id, name)'); // Added name to fields
            if (result.files != null && result.files!.isNotEmpty) {
                final folderId = result.files!.first.id!;
                final folderName = result.files!.first.name ?? "Unknown Name";
                debugPrint("[Drive Debug] Found existing parent folder '$folderName' with ID: $folderId");
                return folderId;
            } else {
                debugPrint("[Drive Debug] Parent folder '$parentFolderName' not found. Creating it...");
                final folderMetadata = drive.File()
                    ..name = parentFolderName
                    ..mimeType = "application/vnd.google-apps.folder";
                final createdFolder = await driveApi.files.create(folderMetadata, $fields: 'id, name'); // Added name to fields
                if (createdFolder.id == null) {
                    debugPrint("[Drive Debug] CRITICAL: Failed to create parent folder. No ID returned.");
                    throw Exception("Failed to create parent folder '$parentFolderName'. Drive API returned no ID.");
                }
                debugPrint("[Drive Debug] Successfully created parent folder '${createdFolder.name}' with ID: ${createdFolder.id!}");
                return createdFolder.id!;
            }
        } catch (e, s) {
            debugPrint("[Drive Debug] CRITICAL ERROR in _getOrCreateParentFolder: $e");
            debugPrint("[Drive Debug] Stack trace for _getOrCreateParentFolder: $s");
            throw Exception("Error in _getOrCreateParentFolder: $e"); // Re-throw to propagate
        }
    }

  Future<String> _createSiteFolder(String name, String parentId) async {
        debugPrint("[Drive Debug] Attempting to create site folder '$name' inside parent ID: $parentId");
        final fileMetadata = drive.File()
            ..name = name
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [parentId];
        try {
            final folder = await _driveApi!.files.create(fileMetadata, $fields: 'id, name'); // Added name to fields
            if (folder.id == null) {
                debugPrint("[Drive Debug] CRITICAL: Failed to create site folder '$name'. No ID returned.");
                throw Exception("Failed to create site folder '$name'. Drive API returned no ID.");
            }
            debugPrint("[Drive Debug] Successfully created site folder '${folder.name}' with ID: ${folder.id!}");
            return folder.id!;
        } catch (e, s) {
            debugPrint("[Drive Debug] CRITICAL ERROR in _createSiteFolder for site '$name': $e");
            debugPrint("[Drive Debug] Stack trace for _createSiteFolder: $s");
            throw Exception("Error creating site folder '$name': $e"); // Re-throw
        }
    }

  Future<void> _updateSheetWithFolderId(int rowIndex, String folderId) async {
    final folderLink = "https://drive.google.com/drive/folders/$folderId";
    final values = [ [folderId, folderLink] ];
    final valueRange = sheets.ValueRange()..values = values;
    await _sheetsApi!.spreadsheets.values.update(valueRange, spreadsheetId, 'Sheet1!F$rowIndex', valueInputOption: 'USER_ENTERED');
  }

// --- REPLACE THIS FUNCTION ---
  Future<void> _appendNewRowToSheet(String siteName, String folderId) async {
    if (_sheetsApi == null) return;
    final folderLink = folderId.isEmpty ? "" : "https://drive.google.com/drive/folders/$folderId";

    // This matches your spreadsheet columns A through G
    final values = [[siteName, "", "New", "", "", folderId, folderLink]];

    final valueRange = sheets.ValueRange()..values = values;
    await _sheetsApi!.spreadsheets.values.append(valueRange, spreadsheetId, 'Sheet1!A1', valueInputOption: 'USER_ENTERED');
  }

  // Inside _ProjectListScreenState class

  Future<void> _syncOfflineProjects() async {
    debugPrint("--- _syncOfflineProjects ENTERED (Timestamp: ${DateTime.now()}) ---");
    debugPrint("Current _projects list BEFORE filtering for offline (at start of _syncOfflineProjects):");
    if (_projects.isEmpty) {
      debugPrint("  _projects list is currently empty.");
    } else {
      for (var p_log in _projects) {
        debugPrint("  Project: ${p_log.name}, ID: ${p_log.id}, isOffline: ${p_log.isOffline}");
      }
    }
    if (_driveApi == null || _sheetsApi == null) {
      debugPrint(
          "Drive or Sheets API not available. Cannot sync offline projects.");
      return;
    }

    // Create a mutable copy to iterate and modify, or carefully update _projects directly.
    // For simplicity here, let's assume we update _projects and then save.
    List<ProjectInfo> offlineProjectsToSync = _projects.where((p) =>
    p.isOffline).toList();
    debugPrint("Found ${offlineProjectsToSync.length} projects where isOffline == true (these will be synced):");
    if (offlineProjectsToSync.isNotEmpty) {
      for (var p_sync_log in offlineProjectsToSync) {
        debugPrint("  Will attempt to sync: ${p_sync_log.name}, ID: ${p_sync_log.id}");
      }
    }

    if (offlineProjectsToSync.isEmpty) {
      debugPrint("No offline projects to sync.");
      return;
    }

    // Let the user know something is happening
    // This status message might be quickly overwritten by _syncOfflinePhotos or _fetchProjectsFromSheet,
    // but it's good for debugging or if those subsequent steps are slow.
    if (mounted) {
      setState(() {
        _statusMessage =
        "Syncing ${offlineProjectsToSync.length} offline project(s)...";
        // _isLoading might already be true from _syncAndFetchProjects
      });
    }

    bool changesMade = false;
    try {
      final String parentDriveFolderId = await _getOrCreateParentFolder(
          _driveApi!);

      for (ProjectInfo projectToSync in offlineProjectsToSync) {
        debugPrint("Syncing offline project: ${projectToSync.name}");
        try {
          // 1. Create the folder in Google Drive
          final String newDriveFolderId = await _createSiteFolder(
              projectToSync.name, parentDriveFolderId);
          debugPrint("Created Drive folder for ${projectToSync
              .name}, ID: $newDriveFolderId");

          // 2. Add the project to the Google Sheet
          //    Your existing _appendNewRowToSheet seems suitable.
          //    It takes siteName and folderId.
          await _appendNewRowToSheet(projectToSync.name, newDriveFolderId);
          debugPrint("Appended ${projectToSync.name} to Google Sheet.");

          // 3. Update the ProjectInfo object in the main _projects list
          //    Find the original project in _projects by its temporary offline ID or name
          //    and update its properties.
          int projectIndex = _projects.indexWhere((p) =>
          p.id == projectToSync.id);
          if (projectIndex != -1) {
            _projects[projectIndex].id = newDriveFolderId;
            _projects[projectIndex].isOffline = false;
            // _projects[projectIndex].rowIndex will be updated by the next _fetchProjectsFromSheet
            changesMade = true;
            debugPrint("Updated local project data for ${projectToSync
                .name}. New ID: $newDriveFolderId");
          } else {
            debugPrint("Error: Could not find project ${projectToSync
                .name} in _projects list to update after sync.");
            // This case should ideally not happen if offlineProjectsToSync is derived from _projects.
          }
        } catch (e, s) {
          debugPrint("Error syncing project ${projectToSync.name}: $e");
          debugPrint("Stack trace: $s");
          // Decide if you want to stop or continue with other projects.
          // For now, it continues. You might add this project to a "failed sync" list.
        }
      }

      if (changesMade) {
        // 4. Save the updated list of projects to SharedPreferences
        await _saveProjectsToCache(
            _projects); // This saves the entire _projects list
        debugPrint(
            "Saved updated projects list to cache after syncing offline projects.");
      }
    } catch (e, s) {
      // This would catch errors from _getOrCreateParentFolder or other top-level issues.
      debugPrint("Critical error during _syncOfflineProjects: $e");
      debugPrint("Stack trace: $s");
      if (mounted) {
        setState(() {
          _statusMessage = "Error syncing offline project data.";
        });
      }
      return; // Early exit if we can't get parent folder or a major issue.
    }

    // The _isLoading and _statusMessage will be managed by the calling function _syncAndFetchProjects
    // and the subsequent _fetchProjectsFromSheet.
    debugPrint("_syncOfflineProjects completed.");
  }
  Future<void> _updateChecklistAfterSync(String folderId, String taskName, String fileId) async { /* ... placeholder ... */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Sites'), actions: [ IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _handleAppStart), if (_currentUser != null) IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign Out', onPressed: _handleSignOut) ],),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateProjectDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_statusMessage != null && _projects.isEmpty) { return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_statusMessage!, textAlign: TextAlign.center))); }
    return Column(
      children: [
        if (_statusMessage != null && _projects.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_statusMessage!, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: _buildProjectList()),
      ],
    );
  }
// --- REPLACE YOUR _buildProjectList FUNCTION WITH THIS ---
// --- REPLACE YOUR _buildProjectList FUNCTION WITH THIS ---

  Widget _buildProjectList() {
    if (_projects.isEmpty) {
      return const Center(child: Text('No projects available.'));
    }

    return ListView.builder(
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        // 'project' is now correctly treated as a ProjectInfo object
        final project = _projects[index];

        return ListTile(
          // We now correctly access the properties of the 'project' object
          title: Text(project.name),
          subtitle: Text(project.isOffline ? 'Saved locally' : (project.id.isEmpty ? 'Awaiting Setup' : 'Synced')),
          leading: Icon(project.isOffline ? Icons.cloud_off : (project.id.isEmpty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined)),
          onTap: () {
            debugPrint("--- Project Tapped ---");
            debugPrint("Project: ${project.name}, ID: ${project.id}, isOffline: ${project.isOffline}");
            debugPrint("Current _isLoading state BEFORE _handleProjectTap: $_isLoading");
                        _handleProjectTap(project);
          },
        );
      },
    );
  }

}