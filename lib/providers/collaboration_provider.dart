import 'package:flutter/material.dart';
import '../services/collaboration_service.dart';
import '../services/debug_logger.dart';

class CollaborationProvider with ChangeNotifier {
  List<Map<String, dynamic>> _collaborators = [];
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = false;
  String? _error;
  String? _currentProjectId;

  List<Map<String, dynamic>> get collaborators => _collaborators;
  List<Map<String, dynamic>> get comments => _comments;
  List<Map<String, dynamic>> get versions => _versions;
  List<Map<String, dynamic>> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentProjectId => _currentProjectId;

  int get onlineCount => _collaborators.where((c) => c['is_online'] == true).length;

  /// Load all collaboration data for a project.
  Future<void> loadAll(String projectId) async {
    // Guard: empty projectId
    if (projectId.isEmpty) {
      DebugLogger.error('COLLAB', 'loadAll called with EMPTY projectId — aborting');
      _error = 'No project selected. Please select a project first.';
      notifyListeners();
      return;
    }

    _currentProjectId = projectId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    DebugLogger.log('COLLAB', '── Loading ALL collaboration data for project=$projectId ──');

    try {
      final results = await Future.wait([
        CollaborationService.getCollaborators(projectId),
        CollaborationService.getComments(projectId),
        CollaborationService.getVersions(projectId),
        CollaborationService.getActivities(projectId),
      ]);
      _collaborators = results[0];
      _comments = results[1];
      _versions = results[2];
      _activities = results[3];
      DebugLogger.log('COLLAB', '✅ All data loaded: ${_collaborators.length} collabs, '
          '${_comments.length} comments, ${_versions.length} versions, ${_activities.length} activities');
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'loadAll FAILED', error: e, stack: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Collaborators ───

  Future<bool> addCollaborator(String email, String role) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) {
      _error = 'No project selected';
      DebugLogger.error('COLLAB', 'addCollaborator: no project selected');
      notifyListeners();
      return false;
    }
    DebugLogger.log('COLLAB', 'Adding collaborator: email=$email role=$role');
    try {
      final result = await CollaborationService.addCollaborator(_currentProjectId!, email, role);
      _collaborators.add(result);
      _error = null;
      await _refreshActivities();
      notifyListeners();
      DebugLogger.log('COLLAB', '✅ Collaborator added successfully');
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'addCollaborator FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeCollaborator(String userId) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    DebugLogger.log('COLLAB', 'Removing collaborator: userId=$userId');
    try {
      await CollaborationService.removeCollaborator(_currentProjectId!, userId);
      _collaborators.removeWhere((c) => c['user_id'] == userId);
      _error = null;
      await _refreshActivities();
      notifyListeners();
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'removeCollaborator FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  // ─── Comments ───

  Future<bool> addComment(String text, {String? attachment}) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    DebugLogger.log('COLLAB', 'Adding comment: "${text.length > 30 ? '${text.substring(0, 30)}...' : text}"');
    try {
      final result = await CollaborationService.addComment(_currentProjectId!, text, attachment: attachment);
      _comments.add(result);
      _error = null;
      await _refreshActivities();
      notifyListeners();
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'addComment FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    try {
      await CollaborationService.deleteComment(_currentProjectId!, commentId);
      _comments.removeWhere((c) => c['id'] == commentId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearComments() async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    try {
      await CollaborationService.clearComments(_currentProjectId!);
      _comments.clear();
      _error = null;
      await _refreshActivities();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ─── Versions ───

  Future<bool> saveVersion({String notes = ''}) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    DebugLogger.log('COLLAB', 'Saving version with notes="${notes.isEmpty ? "(none)" : notes}"');
    try {
      final result = await CollaborationService.saveVersion(_currentProjectId!, notes: notes);
      _versions.insert(0, result);
      _error = null;
      await _refreshActivities();
      notifyListeners();
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'saveVersion FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreVersion(String versionId, String versionName) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    DebugLogger.log('COLLAB', 'Restoring version=$versionName ($versionId)');
    try {
      await CollaborationService.restoreVersion(_currentProjectId!, versionId);
      _error = null;
      await _refreshActivities();
      notifyListeners();
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'restoreVersion FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  // ─── Helpers ───

  Future<void> _refreshActivities() async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return;
    try {
      _activities = await CollaborationService.getActivities(_currentProjectId!);
    } catch (e) {
      DebugLogger.error('COLLAB', 'Activity refresh failed (non-critical)', error: e);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
