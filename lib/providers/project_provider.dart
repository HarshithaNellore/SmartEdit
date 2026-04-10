import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ProjectProvider with ChangeNotifier {
  final List<Project> _projects = [];
  Project? _currentProject;
  int _selectedMediaIndex = 0;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  double _zoom = 1.0;
  int _selectedToolIndex = 0;
  String _selectedFilter = 'none';
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  int get selectedMediaIndex => _selectedMediaIndex;
  Duration get currentPosition => _currentPosition;
  bool get isPlaying => _isPlaying;
  double get zoom => _zoom;
  int get selectedToolIndex => _selectedToolIndex;
  String get selectedFilter => _selectedFilter;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Project> get recentProjects {
    final sorted = List<Project>.from(_projects)
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return sorted.take(10).toList();
  }

  // Local persistence
  static const String _prefsKey = 'recent_projects';

  Future<void> saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _projects.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_prefsKey, encoded);
    } catch (e) {
      // Ignore local save errors
    }
  }

  Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_prefsKey);
      if (encoded != null && encoded.isNotEmpty) {
        _projects.clear();
        for (var item in encoded) {
          _projects.add(Project.fromJson(jsonDecode(item)));
        }
        notifyListeners();
      }
    } catch (e) {
      // Ignore local load errors
    }
  }

  // API Syncing
  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await loadFromLocal();

    try {
      final response = await ApiService.get('/api/projects/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _projects.clear();
        for (var item in data) {
          // Map backend simplified schema to Flutter full model
          _projects.add(Project(
            id: item['id'],
            name: item['name'],
            type: _parseProjectType(item['type']),
            createdAt: DateTime.parse(item['created_at']),
            modifiedAt: DateTime.parse(item['updated_at']),
          ));
        }
        await saveToLocal();
      } else {
        _error = 'Failed to load projects: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Connection error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ProjectType _parseProjectType(String type) {
    switch (type) {
      case 'video': return ProjectType.video;
      case 'photo': return ProjectType.photo;
      case 'mixed': return ProjectType.mixed;
      default: return ProjectType.video;
    }
  }

  // Project management
  Future<void> createProject(String name, ProjectType type) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/api/projects/', body: {
        'name': name,
        'type': type.toString().split('.').last,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final project = Project(
          id: data['id'],
          name: data['name'],
          type: type,
          createdAt: DateTime.parse(data['created_at']),
          modifiedAt: DateTime.parse(data['updated_at']),
        );
        _projects.add(project);
        _currentProject = project;
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
      await saveToLocal();
    } catch (e) {
      _error = 'Failed to create project dynamically on server, falling back to local storage: $e';
      final project = Project(
        id: const Uuid().v4(),
        name: name,
        type: type,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      _projects.add(project);
      _currentProject = project;
      await saveToLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void openProject(Project project) {
    _currentProject = project;
    _selectedMediaIndex = 0;
    _currentPosition = Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> deleteProject(String projectId) async {
    try {
      final response = await ApiService.delete('/api/projects/$projectId');
      if (response.statusCode == 200) {
        _projects.removeWhere((p) => p.id == projectId);
        if (_currentProject?.id == projectId) {
          _currentProject = null;
        }
      }
      await saveToLocal();
    } catch (e) {
      _error = 'Failed to delete project: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> renameProject(String projectId, String newName) async {
    try {
      final response = await ApiService.put('/api/projects/$projectId', body: {
        'name': newName,
      });
      if (response.statusCode == 200) {
        final project = _projects.firstWhere((p) => p.id == projectId);
        project.name = newName;
        project.modifiedAt = DateTime.now();
      }
      await saveToLocal();
    } catch (e) {
      _error = 'Failed to rename project: $e';
    } finally {
      notifyListeners();
    }
  }

  // Media management
  void addMediaItem(MediaItem item) {
    _currentProject?.mediaItems.add(item);
    _currentProject?.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  void removeMediaItem(String itemId) {
    _currentProject?.mediaItems.removeWhere((m) => m.id == itemId);
    _currentProject?.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  void reorderMedia(int oldIndex, int newIndex) {
    if (_currentProject == null) return;
    final items = _currentProject!.mediaItems;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _currentProject!.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  // Playback
  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void setPosition(Duration pos) {
    _currentPosition = pos;
    notifyListeners();
  }

  void setSelectedMedia(int index) {
    _selectedMediaIndex = index;
    notifyListeners();
  }

  // Editor tools
  void setSelectedTool(int index) {
    _selectedToolIndex = index;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setZoom(double zoom) {
    _zoom = zoom.clamp(0.5, 3.0);
    notifyListeners();
  }

  // Edit operations
  void trimMedia(String mediaId, Duration start, Duration end) {
    final media = _currentProject?.mediaItems.firstWhere((m) => m.id == mediaId);
    if (media != null) {
      media.startTime = start;
      media.endTime = end;
      _currentProject?.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  void setSpeed(String mediaId, double speed) {
    final media = _currentProject?.mediaItems.firstWhere((m) => m.id == mediaId);
    if (media != null) {
      media.speed = speed;
      _currentProject?.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  void rotateMedia(String mediaId, int degrees) {
    final media = _currentProject?.mediaItems.firstWhere((m) => m.id == mediaId);
    if (media != null) {
      media.rotation = (media.rotation + degrees) % 360;
      _currentProject?.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  void addTextOverlay(String mediaId, TextOverlay overlay) {
    final media = _currentProject?.mediaItems.firstWhere((m) => m.id == mediaId);
    media?.textOverlays.add(overlay);
    _currentProject?.modifiedAt = DateTime.now();
    notifyListeners();
  }

  void addStickerOverlay(String mediaId, StickerOverlay sticker) {
    final media = _currentProject?.mediaItems.firstWhere((m) => m.id == mediaId);
    media?.stickers.add(sticker);
    _currentProject?.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  // Undo/Redo
  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_undoStack.removeLast());
      notifyListeners();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(_redoStack.removeLast());
      notifyListeners();
    }
  }

  // Collaboration
  void addCollaborator(Collaborator collab) {
    _currentProject?.collaborators.add(collab);
    _currentProject?.isShared = true;
    _currentProject?.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  void addComment(Comment comment) {
    _currentProject?.comments.add(comment);
    _currentProject?.modifiedAt = DateTime.now();
    saveToLocal();
    notifyListeners();
  }

  // Demo projects - disabled in favor of real database sync
  void loadDemoProjects() {
    // fetchProjects() should be called instead
    if (_projects.isNotEmpty) return;
  }
}
