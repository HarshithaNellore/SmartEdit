import 'dart:convert';
import 'api_service.dart';
import 'debug_logger.dart';

class CollaborationService {
  // ─── Collaborators ───

  static Future<List<Map<String, dynamic>>> getCollaborators(String projectId) async {
    DebugLogger.log('COLLAB', '→ GET collaborators for project=$projectId');
    final response = await ApiService.get('/api/projects/$projectId/collaborators');
    DebugLogger.apiResponse('/collaborators', response.statusCode, body: response.body);
    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Loaded ${list.length} collaborators');
      return list;
    }
    DebugLogger.error('COLLAB', 'Failed to load collaborators: ${response.statusCode}');
    throw Exception('Failed to load collaborators: ${response.statusCode} — ${response.body}');
  }

  static Future<Map<String, dynamic>> addCollaborator(String projectId, String email, String role) async {
    DebugLogger.log('COLLAB', '→ POST add collaborator email=$email role=$role project=$projectId');
    final response = await ApiService.post(
      '/api/projects/$projectId/collaborators',
      body: {'email': email, 'role': role},
    );
    DebugLogger.apiResponse('/collaborators', response.statusCode, body: response.body);
    if (response.statusCode == 201) {
      final result = Map<String, dynamic>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Collaborator added: ${result['name']} (${result['email']})');
      return result;
    }
    final errorBody = jsonDecode(response.body);
    final detail = errorBody['detail'] ?? 'Failed to add collaborator (${response.statusCode})';
    DebugLogger.error('COLLAB', 'Add collaborator failed: $detail');
    throw Exception(detail);
  }

  static Future<void> removeCollaborator(String projectId, String userId) async {
    DebugLogger.log('COLLAB', '→ DELETE collaborator userId=$userId project=$projectId');
    final response = await ApiService.delete('/api/projects/$projectId/collaborators/$userId');
    DebugLogger.apiResponse('/collaborators/$userId', response.statusCode);
    if (response.statusCode != 204) {
      DebugLogger.error('COLLAB', 'Remove failed: ${response.statusCode}');
      throw Exception('Failed to remove collaborator: ${response.statusCode}');
    }
    DebugLogger.log('COLLAB', '✅ Collaborator removed');
  }

  // ─── Comments ───

  static Future<List<Map<String, dynamic>>> getComments(String projectId) async {
    DebugLogger.log('COLLAB', '→ GET comments for project=$projectId');
    final response = await ApiService.get('/api/projects/$projectId/comments');
    DebugLogger.apiResponse('/comments', response.statusCode);
    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Loaded ${list.length} comments');
      return list;
    }
    throw Exception('Failed to load comments: ${response.statusCode} — ${response.body}');
  }

  static Future<Map<String, dynamic>> addComment(String projectId, String text, {String? attachment}) async {
    DebugLogger.log('COLLAB', '→ POST comment project=$projectId text="${text.length > 50 ? '${text.substring(0, 50)}...' : text}"');
    final body = <String, dynamic>{'text': text};
    if (attachment != null) body['attachment'] = attachment;
    final response = await ApiService.post('/api/projects/$projectId/comments', body: body);
    DebugLogger.apiResponse('/comments', response.statusCode, body: response.body);
    if (response.statusCode == 201) {
      DebugLogger.log('COLLAB', '✅ Comment added');
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to add comment: ${response.statusCode} — ${response.body}');
  }

  static Future<void> deleteComment(String projectId, String commentId) async {
    DebugLogger.log('COLLAB', '→ DELETE comment=$commentId project=$projectId');
    final response = await ApiService.delete('/api/projects/$projectId/comments/$commentId');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete comment: ${response.statusCode}');
    }
    DebugLogger.log('COLLAB', '✅ Comment deleted');
  }

  static Future<void> clearComments(String projectId) async {
    DebugLogger.log('COLLAB', '→ DELETE all comments project=$projectId');
    final response = await ApiService.delete('/api/projects/$projectId/comments');
    if (response.statusCode != 204) {
      throw Exception('Failed to clear comments: ${response.statusCode}');
    }
    DebugLogger.log('COLLAB', '✅ All comments cleared');
  }

  // ─── Versions ───

  static Future<List<Map<String, dynamic>>> getVersions(String projectId) async {
    DebugLogger.log('COLLAB', '→ GET versions for project=$projectId');
    final response = await ApiService.get('/api/projects/$projectId/versions');
    DebugLogger.apiResponse('/versions', response.statusCode);
    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Loaded ${list.length} versions');
      return list;
    }
    throw Exception('Failed to load versions: ${response.statusCode} — ${response.body}');
  }

  static Future<Map<String, dynamic>> saveVersion(String projectId, {String notes = ''}) async {
    DebugLogger.log('COLLAB', '→ POST save version project=$projectId');
    final response = await ApiService.post('/api/projects/$projectId/versions', body: {'notes': notes});
    DebugLogger.apiResponse('/versions', response.statusCode, body: response.body);
    if (response.statusCode == 201) {
      final result = Map<String, dynamic>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Version saved: ${result['name']}');
      return result;
    }
    throw Exception('Failed to save version: ${response.statusCode} — ${response.body}');
  }

  static Future<void> restoreVersion(String projectId, String versionId) async {
    DebugLogger.log('COLLAB', '→ POST restore version=$versionId project=$projectId');
    final response = await ApiService.post('/api/projects/$projectId/versions/$versionId/restore');
    DebugLogger.apiResponse('/versions/$versionId/restore', response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to restore version: ${response.statusCode} — ${response.body}');
    }
    DebugLogger.log('COLLAB', '✅ Version restored');
  }

  // ─── Activities ───

  static Future<List<Map<String, dynamic>>> getActivities(String projectId) async {
    DebugLogger.log('COLLAB', '→ GET activities for project=$projectId');
    final response = await ApiService.get('/api/projects/$projectId/activities');
    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      DebugLogger.log('COLLAB', '✅ Loaded ${list.length} activities');
      return list;
    }
    throw Exception('Failed to load activities: ${response.statusCode} — ${response.body}');
  }

  // ─── Email Invite (for non-registered users) ───

  static Future<bool> sendInviteEmail(String email, String projectName, String inviterName, String role) async {
    DebugLogger.log('COLLAB', '→ POST email invite to=$email project=$projectName');
    try {
      final response = await ApiService.post('/api/email/invite', body: {
        'email': email,
        'project_name': projectName,
        'inviter_name': inviterName,
        'role': role,
      });
      DebugLogger.apiResponse('/email/invite', response.statusCode, body: response.body);
      return response.statusCode == 200;
    } catch (e) {
      DebugLogger.error('COLLAB', 'Email invite failed', error: e);
      return false;
    }
  }
}
