import 'package:uuid/uuid.dart';

enum ProjectType { video, photo, mixed }
enum MediaType { video, photo }

class Project {
  final String id;
  String name;
  final ProjectType type;
  final DateTime createdAt;
  DateTime modifiedAt;
  final List<MediaItem> mediaItems;
  final List<EditLayer> layers;
  final List<Collaborator> collaborators;
  final List<Comment> comments;
  Duration totalDuration;
  String? thumbnailPath;
  bool isShared;

  Project({
    String? id,
    required this.name,
    required this.type,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<MediaItem>? mediaItems,
    List<EditLayer>? layers,
    List<Collaborator>? collaborators,
    List<Comment>? comments,
    this.totalDuration = Duration.zero,
    this.thumbnailPath,
    this.isShared = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now(),
        mediaItems = mediaItems ?? [],
        layers = layers ?? [],
        collaborators = collaborators ?? [],
        comments = comments ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'totalDuration': totalDuration.inMilliseconds,
      'isShared': isShared,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? 'Untitled',
      type: ProjectType.values.firstWhere((e) => e.toString() == 'ProjectType.${json['type']}', orElse: () => ProjectType.video),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      modifiedAt: json['modifiedAt'] != null ? DateTime.parse(json['modifiedAt']) : null,
      totalDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
      isShared: json['isShared'] ?? false,
    );
  }
}

class MediaItem {
  final String id;
  final String path;
  final MediaType type;
  Duration startTime;
  Duration endTime;
  Duration totalDuration;
  double speed;
  int rotation;
  final Map<String, dynamic> filters;
  final List<TextOverlay> textOverlays;
  final List<StickerOverlay> stickers;

  MediaItem({
    String? id,
    required this.path,
    required this.type,
    this.startTime = Duration.zero,
    this.endTime = Duration.zero,
    this.totalDuration = Duration.zero,
    this.speed = 1.0,
    this.rotation = 0,
    Map<String, dynamic>? filters,
    List<TextOverlay>? textOverlays,
    List<StickerOverlay>? stickers,
  })  : id = id ?? const Uuid().v4(),
        filters = filters ?? {},
        textOverlays = textOverlays ?? [],
        stickers = stickers ?? [];
}

class EditLayer {
  final String id;
  final String name;
  final LayerType type;
  Duration startTime;
  Duration endTime;
  Map<String, dynamic> properties;

  EditLayer({
    String? id,
    required this.name,
    required this.type,
    this.startTime = Duration.zero,
    this.endTime = Duration.zero,
    Map<String, dynamic>? properties,
  })  : id = id ?? const Uuid().v4(),
        properties = properties ?? {};
}

enum LayerType { video, audio, text, sticker, effect, transition }

class TextOverlay {
  final String id;
  String text;
  double x;
  double y;
  double fontSize;
  String fontFamily;
  int color;
  int backgroundColor;
  double rotation;
  Duration startTime;
  Duration endTime;

  TextOverlay({
    String? id,
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 24,
    this.fontFamily = 'Inter',
    this.color = 0xFFFFFFFF,
    this.backgroundColor = 0x00000000,
    this.rotation = 0,
    this.startTime = Duration.zero,
    this.endTime = Duration.zero,
  }) : id = id ?? const Uuid().v4();
}

class StickerOverlay {
  final String id;
  String assetPath;
  double x;
  double y;
  double scale;
  double rotation;
  Duration startTime;
  Duration endTime;

  StickerOverlay({
    String? id,
    required this.assetPath,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0,
    this.startTime = Duration.zero,
    this.endTime = Duration.zero,
  }) : id = id ?? const Uuid().v4();
}

class FilterPreset {
  final String id;
  final String name;
  final String iconPath;
  final Map<String, double> adjustments;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.adjustments,
  });
}

class Collaborator {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final CollaboratorRole role;
  final bool isOnline;

  const Collaborator({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.role = CollaboratorRole.viewer,
    this.isOnline = false,
  });
}

enum CollaboratorRole { owner, editor, viewer }

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;
  final Duration? timestamp;

  Comment({
    String? id,
    required this.userId,
    required this.userName,
    required this.text,
    DateTime? createdAt,
    this.timestamp,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

class ExportPreset {
  final String name;
  final String platform;
  final int width;
  final int height;
  final double fps;
  final int bitrate;
  final String format;
  final String aspectRatio;

  const ExportPreset({
    required this.name,
    required this.platform,
    required this.width,
    required this.height,
    this.fps = 30,
    this.bitrate = 8000000,
    this.format = 'mp4',
    required this.aspectRatio,
  });

  static const List<ExportPreset> socialPresets = [
    ExportPreset(name: 'Instagram Reel', platform: 'Instagram', width: 1080, height: 1920, fps: 30, aspectRatio: '9:16'),
    ExportPreset(name: 'Instagram Post', platform: 'Instagram', width: 1080, height: 1080, fps: 30, aspectRatio: '1:1'),
    ExportPreset(name: 'Instagram Story', platform: 'Instagram', width: 1080, height: 1920, fps: 30, aspectRatio: '9:16'),
    ExportPreset(name: 'YouTube Video', platform: 'YouTube', width: 1920, height: 1080, fps: 30, aspectRatio: '16:9'),
    ExportPreset(name: 'YouTube Shorts', platform: 'YouTube', width: 1080, height: 1920, fps: 30, aspectRatio: '9:16'),
    ExportPreset(name: 'TikTok', platform: 'TikTok', width: 1080, height: 1920, fps: 30, aspectRatio: '9:16'),
    ExportPreset(name: 'Twitter/X Post', platform: 'Twitter', width: 1280, height: 720, fps: 30, aspectRatio: '16:9'),
    ExportPreset(name: 'Facebook Post', platform: 'Facebook', width: 1280, height: 720, fps: 30, aspectRatio: '16:9'),
    ExportPreset(name: 'WhatsApp Status', platform: 'WhatsApp', width: 1080, height: 1920, fps: 30, aspectRatio: '9:16'),
    ExportPreset(name: '4K Ultra HD', platform: 'Custom', width: 3840, height: 2160, fps: 60, bitrate: 20000000, aspectRatio: '16:9'),
    ExportPreset(name: '1080p Full HD', platform: 'Custom', width: 1920, height: 1080, fps: 30, aspectRatio: '16:9'),
    ExportPreset(name: '720p HD', platform: 'Custom', width: 1280, height: 720, fps: 30, bitrate: 5000000, aspectRatio: '16:9'),
  ];
}

class AIFeatureResult {
  final String type;
  final Map<String, dynamic> data;
  final double confidence;
  final DateTime processedAt;

  AIFeatureResult({
    required this.type,
    required this.data,
    this.confidence = 0.0,
    DateTime? processedAt,
  }) : processedAt = processedAt ?? DateTime.now();
}
