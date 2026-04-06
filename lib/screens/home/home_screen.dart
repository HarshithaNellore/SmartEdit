import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/project_model.dart';
import '../../widgets/glass_card.dart';
import '../../services/stats_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentNavIndex = 0;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().fetchProjects();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: IndexedStack(
            index: _currentNavIndex,
            children: [
              _buildHomeTab(),
              _buildProjectsTab(),
              const SizedBox(), // placeholder for center FAB
              _buildProfileTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 28),
            _buildQuickActions(),
            const SizedBox(height: 28),
            _buildAIFeaturesBanner(),
            const SizedBox(height: 28),
            _buildRecentProjects(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name ?? 'User';
    final userInitial = auth.user?.initials ?? '?';

    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName 👋',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    'SmartCut Studio',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          GlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            child: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary, size: 22),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file != null && mounted) {
      Navigator.pushNamed(context, '/photo-editor');
    }
  }

  Widget _buildQuickActions() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Start', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickActionItem(Icons.videocam_rounded, 'Video', AppTheme.primaryPurple, () {
                Navigator.pushNamed(context, '/video-editor');
              }),
              _quickActionItem(Icons.photo_rounded, 'Photo', AppTheme.primaryPink, () => Navigator.pushNamed(context, '/photo-editor')),
              _quickActionItem(Icons.grid_view_rounded, 'Collage', const Color(0xFFFF9800), () => Navigator.pushNamed(context, '/collage-editor')),
              _quickActionItem(Icons.auto_awesome, 'AI Edit', const Color(0xFFE040FB), () => Navigator.pushNamed(context, '/ai-features')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickActionItem(Icons.file_download_rounded, 'Import', AppTheme.accentCyan, _importMedia),
              _quickActionItem(Icons.people_alt_rounded, 'Share', const Color(0xFF4CAF50), () {
                final provider = context.read<ProjectProvider>();
                final pid = provider.currentProject?.id ?? (provider.projects.isNotEmpty ? provider.projects.first.id : '');
                Navigator.pushNamed(context, '/collaboration', arguments: {'projectId': pid});
              }),
              _quickActionItem(Icons.settings_rounded, 'Settings', const Color(0xFF9E9E9E), () => Navigator.pushNamed(context, '/settings')),
              const SizedBox(width: 64), // Keep layout balanced
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withAlpha(30), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(60), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAIFeaturesBanner() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/ai-features'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9C27B0), Color(0xFFFF6B9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppTheme.primaryPurple.withAlpha(60), blurRadius: 25, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('✨ AI Powered', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    Text('Practical Local\nAI Tools', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                    const SizedBox(height: 8),
                    Text('Auto-highlights, captions, filters, and thumbnails. 100% offline.', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProjects() {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final projects = provider.recentProjects;
        return FadeInUp(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Projects', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  TextButton(
                    onPressed: () => setState(() => _currentNavIndex = 1),
                    child: Text('See All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.movie_creation_outlined, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text('No projects yet', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                        const SizedBox(height: 4),
                        Text('Tap + to create your first project', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: projects.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return _buildProjectCard(project, index);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectCard(Project project, int index) {
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF9C27B0)],
      [const Color(0xFFFF6B9D), const Color(0xFFFF8A50)],
      [const Color(0xFF00D4AA), const Color(0xFF00B4D8)],
      [const Color(0xFFFF8A50), const Color(0xFFFFB347)],
      [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
    ];

    final gradient = colors[index % colors.length];
    final icon = project.type == ProjectType.video
        ? Icons.play_arrow_rounded
        : project.type == ProjectType.photo
            ? Icons.photo_rounded
            : Icons.dashboard_rounded;

    return GestureDetector(
      onTap: () {
        context.read<ProjectProvider>().openProject(project);
        if (project.type == ProjectType.photo) {
          Navigator.pushNamed(context, '/photo-editor');
        } else {
          Navigator.pushNamed(context, '/video-editor');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 150,
        decoration: BoxDecoration(
          color: AppTheme.darkElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(10), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Abstract background wash
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
              ),
              // Glassmorphism overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.darkSurface.withAlpha(200),
                      AppTheme.darkSurface.withAlpha(170),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: gradient[0].withAlpha(80), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        if (project.isShared)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
                            child: const Icon(Icons.group, color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(project.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      project.type == ProjectType.video
                          ? 'Video • ${project.totalDuration.inMinutes}:${(project.totalDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                          : project.type.name.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProjectsTab() {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('My Projects', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('${provider.projects.length} projects', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              Expanded(
                child: provider.projects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textMuted),
                            const SizedBox(height: 16),
                            Text('No projects yet', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: provider.projects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final project = provider.projects[index];
                          return _buildProjectListItem(project);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectListItem(Project project) {
    final icon = project.type == ProjectType.video
        ? Icons.videocam_rounded
        : project.type == ProjectType.photo
            ? Icons.photo_rounded
            : Icons.dashboard_rounded;
    final color = project.type == ProjectType.video
        ? AppTheme.primaryPurple
        : project.type == ProjectType.photo
            ? AppTheme.primaryPink
            : AppTheme.accentCyan;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          context.read<ProjectProvider>().openProject(project);
          if (project.type == ProjectType.photo) {
            Navigator.pushNamed(context, '/photo-editor');
          } else {
            Navigator.pushNamed(context, '/video-editor');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    '${project.type.name.toUpperCase()} • Edited just now',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (project.isShared)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.group_rounded, size: 18, color: AppTheme.accentCyan),
              ),
            GestureDetector(
              onTap: () => _showDeleteDialog(project),
              child: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildProfileTab() {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name ?? 'User';
    final userInitial = auth.user?.initials ?? '?';
    final userEmail = auth.user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Profile header
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(child: Text(userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32))),
            ),
            const SizedBox(height: 12),
            Text(userName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(userEmail.isNotEmpty ? userEmail : 'Free Plan', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            // Stats — real counts
            Consumer<ProjectProvider>(
              builder: (context, projectProvider, _) {
                final projectCount = projectProvider.projects.length;
                return FutureBuilder(
                  future: Future.wait([StatsService.getExportCount(), StatsService.getShareCount()]),
                  builder: (context, snapshot) {
                    final exportCount = snapshot.hasData ? (snapshot.data as List)[0] as int : 0;
                    final shareCount = snapshot.hasData ? (snapshot.data as List)[1] as int : 0;
                    return GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('$projectCount', 'Projects'),
                          Container(width: 1, height: 40, color: AppTheme.darkElevated),
                          _statItem('$exportCount', 'Exports'),
                          Container(width: 1, height: 40, color: AppTheme.darkElevated),
                          _statItem('$shareCount', 'Shared'),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            // Settings options
            ...[
              ['Settings', Icons.settings_rounded, '/settings'],
              ['Export History', Icons.history_rounded, '/export'],
              ['Upgrade to Pro', Icons.diamond_rounded, ''],
              ['Help & Feedback', Icons.help_outline_rounded, ''],
              ['About SmartCut', Icons.info_outline_rounded, ''],
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: InkWell(
                      onTap: () {
                        if ((item[2] as String).isNotEmpty) {
                          Navigator.pushNamed(context, item[2] as String);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(item[1] as IconData, color: AppTheme.textSecondary, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(item[0] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                )),
            // Logout button
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: InkWell(
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent.withAlpha(200), size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Log Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.redAccent)),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  void _showDeleteDialog(Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Project', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${project.name}"? This cannot be undone.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              context.read<ProjectProvider>().deleteProject(project.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"${project.name}" deleted', style: GoogleFonts.inter(fontSize: 13)),
                backgroundColor: AppTheme.darkCard, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppTheme.primaryPurple.withAlpha(100), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: () => _showCreateDialog(),
        child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
      ),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.darkElevated, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Create New Project', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 24),
            _createOption(
              icon: Icons.videocam_rounded,
              title: 'Video Project',
              desc: 'Edit videos with timeline, effects & more',
              color: AppTheme.primaryPurple,
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.any);
                if (result == null || result.files.single.path == null) return;

                Navigator.pop(context);
                final fileName = result.files.single.name;
                final filePath = result.files.single.path!;
                await context.read<ProjectProvider>().createProject(fileName, ProjectType.video);
                if (!mounted) return;
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pushNamed(context, '/video-editor', arguments: {
                    'initialVideoPath': filePath,
                    'initialVideoName': fileName,
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            _createOption(
              icon: Icons.photo_rounded,
              title: 'Photo Project',
              desc: 'Edit photos with filters, AI tools & more',
              color: AppTheme.primaryPink,
              onTap: () async {
                await context.read<ProjectProvider>().createProject('Untitled Photo', ProjectType.photo);
                if (!mounted) return;
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pushNamed(context, '/photo-editor');
                }
              },
            ),
            const SizedBox(height: 12),
            _createOption(
              icon: Icons.dashboard_rounded,
              title: 'Mixed Project',
              desc: 'Combine photos and videos in one project',
              color: AppTheme.accentCyan,
              onTap: () async {
                await context.read<ProjectProvider>().createProject('Untitled Project', ProjectType.mixed);
                if (!mounted) return;
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pushNamed(context, '/mixed-editor');
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _createOption({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: BottomAppBar(
        color: AppTheme.darkSurface,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.folder_rounded, 'Projects'),
              const SizedBox(width: 48),
              _collabNavItem(),
              _navItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collabNavItem() {
    return InkWell(
      onTap: () {
        final provider = context.read<ProjectProvider>();
        final pid = provider.currentProject?.id ?? (provider.projects.isNotEmpty ? provider.projects.first.id : '');
        Navigator.pushNamed(context, '/collaboration', arguments: {'projectId': pid});
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded, color: AppTheme.textMuted, size: 24),
            const SizedBox(height: 2),
            Text('Collab', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
