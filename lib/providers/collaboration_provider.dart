import 'dart:async';
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

  StreamSubscription? _collabSub;
  StreamSubscription? _commentSub;
  StreamSubscription? _versionSub;
  StreamSubscription? _activitySub;

  List<Map<String, dynamic>> get collaborators => _collaborators;
  List<Map<String, dynamic>> get comments => _comments;
  List<Map<String, dynamic>> get versions => _versions;
  List<Map<String, dynamic>> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentProjectId => _currentProjectId;

  int get onlineCount => _collaborators.where((c) => c['is_online'] == true).length;

  /// Subscribe to all real-time data for a project.
  void loadAll(String projectId) {
    if (projectId.isEmpty) {
      _error = 'No project selected.';
      notifyListeners();
      return;
    }

    if (_currentProjectId == projectId) return;

    _disposeSubscriptions();
    _currentProjectId = projectId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    DebugLogger.log('COLLAB', '── Subscribing to Firestore data for project=$projectId ──');

    try {
      _collabSub = CollaborationService.getCollaboratorsStream(projectId).listen((data) {
        _collaborators = data;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = 'Failed to load team data';
        notifyListeners();
      });

      _commentSub = CollaborationService.getCommentsStream(projectId).listen((data) {
        _comments = data;
        notifyListeners();
      });

      _versionSub = CollaborationService.getVersionsStream(projectId).listen((data) {
        _versions = data;
        notifyListeners();
      });

      _activitySub = CollaborationService.getActivitiesStream(projectId).listen((data) {
        _activities = data;
        notifyListeners();
      });
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'loadAll FAILED', error: e, stack: stack);
      _isLoading = false;
      notifyListeners();
    }
  }

  void _disposeSubscriptions() {
    _collabSub?.cancel();
    _commentSub?.cancel();
    _versionSub?.cancel();
    _activitySub?.cancel();
  }

  @override
  void dispose() {
    _disposeSubscriptions();
    super.dispose();
  }

  // ─── Collaborators ───

  Future<bool> addCollaborator(String email, String role) async {
    if (_currentProjectId == null || _currentProjectId!.isEmpty) return false;
    try {
      await CollaborationService.addCollaborator(_currentProjectId!, email, role);
      _error = null;
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
    try {
      await CollaborationService.removeCollaborator(_currentProjectId!, userId);
      _error = null;
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
    try {
      await CollaborationService.addComment(_currentProjectId!, text, attachment: attachment);
      _error = null;
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
      _error = null;
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
      _error = null;
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
    try {
      await CollaborationService.saveVersion(_currentProjectId!, notes: notes);
      _error = null;
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
    try {
      await CollaborationService.restoreVersion(_currentProjectId!, versionId);
      _error = null;
      return true;
    } catch (e, stack) {
      _error = e.toString().replaceAll('Exception: ', '');
      DebugLogger.error('COLLAB', 'restoreVersion FAILED', error: e, stack: stack);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
