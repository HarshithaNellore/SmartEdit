import 'dart:async';
import 'dart:convert';
import 'api_service.dart';

/// HTTP Polling implementation of Collaboration Service to local FastAPI backend.
class CollaborationService {

  // ─── Collaborators ───

  static Stream<List<Map<String, dynamic>>> getCollaboratorsStream(String projectId) {
    StreamController<List<Map<String, dynamic>>> controller = StreamController();
    Timer timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/collaborators');
        if (res.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(res.body);
          if (!controller.isClosed) {
            controller.add(jsonList.cast<Map<String, dynamic>>());
          }
        }
      } catch (e) {
        // Silent ignore for continuous polling
      }
    });
    controller.onCancel = () => timer.cancel();
    // Do initial fetch immediately
    Future.microtask(() async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/collaborators');
        if (res.statusCode == 200 && !controller.isClosed) {
          controller.add(jsonDecode(res.body).cast<Map<String, dynamic>>());
        }
      } catch (e) {}
    });
    return controller.stream;
  }

  static Future<Map<String, dynamic>> addCollaborator(String projectId, String email, String role) async {
    final res = await ApiService.post('/api/projects/$projectId/collaborators', body: {
      'email': email,
      'role': role,
    });
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to add collaborator');
  }

  static Future<void> removeCollaborator(String projectId, String userId) async {
    final res = await ApiService.delete('/api/projects/$projectId/collaborators/$userId');
    if (res.statusCode != 204 && res.statusCode != 200) throw Exception('Failed to remove collaborator');
  }

  // ─── Comments ───

  static Stream<List<Map<String, dynamic>>> getCommentsStream(String projectId) {
    StreamController<List<Map<String, dynamic>>> controller = StreamController();
    Timer timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/comments');
        if (res.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(res.body);
          if (!controller.isClosed) {
            controller.add(jsonList.cast<Map<String, dynamic>>());
          }
        }
      } catch (e) {}
    });
    controller.onCancel = () => timer.cancel();
    Future.microtask(() async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/comments');
        if (res.statusCode == 200 && !controller.isClosed) {
          controller.add(jsonDecode(res.body).cast<Map<String, dynamic>>());
        }
      } catch (e) {}
    });
    return controller.stream;
  }

  static Future<Map<String, dynamic>> addComment(String projectId, String text, {String? attachment}) async {
    final res = await ApiService.post('/api/projects/$projectId/comments', body: {
      'text': text,
      'attachment': attachment,
    });
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to add comment');
  }

  static Future<void> deleteComment(String projectId, String commentId) async {
    final res = await ApiService.delete('/api/projects/$projectId/comments/$commentId');
    if (res.statusCode != 204 && res.statusCode != 200) throw Exception('Failed to delete comment');
  }

  static Future<void> clearComments(String projectId) async {
    final res = await ApiService.delete('/api/projects/$projectId/comments');
    if (res.statusCode != 204 && res.statusCode != 200) throw Exception('Failed to clear comments');
  }

  // ─── Versions ───

  static Stream<List<Map<String, dynamic>>> getVersionsStream(String projectId) {
    StreamController<List<Map<String, dynamic>>> controller = StreamController();
    Timer timer = Timer.periodic(const Duration(seconds: 5), (t) async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/versions');
        if (res.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(res.body);
          if (!controller.isClosed) {
            controller.add(jsonList.cast<Map<String, dynamic>>());
          }
        }
      } catch (e) {}
    });
    controller.onCancel = () => timer.cancel();
    Future.microtask(() async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/versions');
        if (res.statusCode == 200 && !controller.isClosed) {
          controller.add(jsonDecode(res.body).cast<Map<String, dynamic>>());
        }
      } catch (e) {}
    });
    return controller.stream;
  }

  static Future<Map<String, dynamic>> saveVersion(String projectId, {String notes = ''}) async {
    final res = await ApiService.post('/api/projects/$projectId/versions', body: {
      'notes': notes,
    });
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to save version');
  }

  static Future<void> restoreVersion(String projectId, String versionId) async {
    final res = await ApiService.post('/api/projects/$projectId/versions/$versionId/restore', body: {});
    if (res.statusCode != 200) throw Exception('Failed to restore version');
  }

  // ─── Activities ───

  static Stream<List<Map<String, dynamic>>> getActivitiesStream(String projectId) {
    StreamController<List<Map<String, dynamic>>> controller = StreamController();
    Timer timer = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/activities');
        if (res.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(res.body);
          if (!controller.isClosed) {
            controller.add(jsonList.cast<Map<String, dynamic>>());
          }
        }
      } catch (e) {}
    });
    controller.onCancel = () => timer.cancel();
    Future.microtask(() async {
      try {
        final res = await ApiService.get('/api/projects/$projectId/activities');
        if (res.statusCode == 200 && !controller.isClosed) {
          controller.add(jsonDecode(res.body).cast<Map<String, dynamic>>());
        }
      } catch (e) {}
    });
    return controller.stream;
  }
}
