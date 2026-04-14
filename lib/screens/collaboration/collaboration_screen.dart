import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/collaboration_provider.dart';
import '../../services/debug_logger.dart';

class CollaborationScreen extends StatefulWidget {
  final String projectId;
  const CollaborationScreen({super.key, required this.projectId});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    DebugLogger.log('COLLAB', 'CollaborationScreen opened with projectId="${widget.projectId}"');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.projectId.isNotEmpty) {
        context.read<CollaborationProvider>().loadAll(widget.projectId);
      } else {
        DebugLogger.error('COLLAB', 'Empty projectId passed to CollaborationScreen!');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard: Empty projectId → show helpful error
    if (widget.projectId.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, gradient: AppTheme.getBackgroundGradient(context)),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.redAccent.withAlpha(180)),
                        const SizedBox(height: 16),
                        Text('No Project Selected',
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Please create or select a project from the Home screen before accessing Collaboration.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        GradientButton(text: 'Go Back', icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, gradient: AppTheme.getBackgroundGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              // Error banner
              Consumer<CollaborationProvider>(
                builder: (context, provider, _) {
                  if (provider.error != null) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withAlpha(60)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(provider.error!,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: () => provider.clearError(),
                          child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                        ),
                      ]),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildProjectsTab(),
                    _buildTeamTab(),
                    _buildCommentsTab(),
                    _buildVersionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Consumer<CollaborationProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Collaboration', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text('${provider.collaborators.length + 1} members • ${provider.comments.length} comments',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ),
              GestureDetector(
                onTap: _showInviteDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_add, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Invite', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelColor: AppTheme.textMuted,
        labelColor: Colors.white,
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Projects'),
          Tab(text: 'Team'),
          Tab(text: 'Comments'),
          Tab(text: 'Versions'),
        ],
      ),
    );
  }

  // ─── Projects Tab ───
  Widget _buildProjectsTab() {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final projects = provider.projects;
        if (projects.isEmpty) {
          return _emptyState(Icons.folder_outlined, 'No Shared Projects', 'Create a project and share it to collaborate with your team.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16), physics: const BouncingScrollPhysics(),
          itemCount: projects.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = projects[index];
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 60),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppTheme.primaryPurple.withAlpha(80),
                        AppTheme.primaryPink.withAlpha(60),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.folder_shared, color: AppTheme.primaryPurple, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Consumer<CollaborationProvider>(
                      builder: (context, collabProvider, _) {
                        return Row(children: [
                          Icon(Icons.people_outline, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('${collabProvider.collaborators.length + 1} members', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('Active', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                        ]);
                      },
                    ),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentCyan.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                    child: Text('Live', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentCyan)),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Team Tab ───
  Widget _buildTeamTab() {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;

    return Consumer<CollaborationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Online status header
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text('${provider.onlineCount + 1} online now',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('${provider.collaborators.length + 1} total', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
              ]),
            ),
            const SizedBox(height: 12),
            // Current user (owner)
            if (currentUser != null) _memberCard(
              currentUser.name, currentUser.email, 'Owner',
              AppTheme.primaryPurple, true,
            ),
            // Dynamic team members from backend
            Expanded(
              child: provider.collaborators.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.group_add_rounded, size: 56, color: Colors.white.withAlpha(40)),
                      const SizedBox(height: 12),
                      Text('No team members yet', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Tap "Invite" to add collaborators', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                    ]))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: provider.collaborators.length,
                      itemBuilder: (context, index) {
                        final m = provider.collaborators[index];
                        return Dismissible(
                          key: ValueKey('${m['user_id']}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.person_remove, color: Colors.redAccent),
                          ),
                          confirmDismiss: (_) => _confirmRemoveMember(m['name'] ?? 'Unknown'),
                          onDismissed: (_) {
                            provider.removeCollaborator(m['user_id']);
                          },
                          child: _memberCard(
                            m['name'] ?? 'Unknown',
                            m['email'] ?? '',
                            m['role'] ?? 'viewer',
                            _roleColor(m['role'] ?? 'viewer'),
                            m['is_online'] ?? false,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GradientButton(text: 'Invite Member', icon: Icons.person_add, onPressed: _showInviteDialog),
            ),
          ]),
        );
      },
    );
  }

  Future<bool> _confirmRemoveMember(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Member', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('Remove $name from the team?', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600))),
        ],
      ),
    ) ?? false;
  }

  Widget _memberCard(String name, String email, String role, Color roleColor, bool isOnline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF00E676) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: roleColor.withAlpha(30), borderRadius: BorderRadius.circular(8)),
            child: Text(role, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor)),
          ),
        ]),
      ),
    );
  }

  // ─── Comments Tab ───
  Widget _buildCommentsTab() {
    return Consumer<CollaborationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(children: [
          // Comment stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Text('${provider.comments.length} comments', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const Spacer(),
              if (provider.comments.isNotEmpty) GestureDetector(
                onTap: _clearAllComments,
                child: Text('Clear all', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
              ),
            ]),
          ),
          Expanded(
            child: provider.comments.isEmpty
                ? _emptyState(Icons.chat_bubble_outline, 'No Comments Yet', 'Start a conversation about this project.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16), physics: const BouncingScrollPhysics(),
                    itemCount: provider.comments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = provider.comments[index];
                      final timestamp = DateTime.tryParse(c['created_at'] ?? '') ?? DateTime.now();
                      return Dismissible(
                        key: ValueKey('comment_${c['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete, color: Colors.redAccent),
                        ),
                        onDismissed: (_) => provider.deleteComment(c['id']),
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 200),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      _commentColors[index % _commentColors.length],
                                      _commentColors[(index + 1) % _commentColors.length],
                                    ]),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(child: Text(
                                    (c['author_name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                  )),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c['author_name'] ?? 'Unknown', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  Text(_timeAgo(timestamp), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                ])),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz, color: AppTheme.textMuted, size: 18),
                                  color: AppTheme.getCardColor(context),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (v) {
                                    if (v == 'delete') provider.deleteComment(c['id']);
                                    if (v == 'reply') {
                                      _commentController.text = '@${c['author_name']} ';
                                      FocusScope.of(context).requestFocus(FocusNode());
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(value: 'reply', child: Text('Reply', style: GoogleFonts.inter(color: AppTheme.textPrimary))),
                                    PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent))),
                                  ],
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Text(c['text'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                              if (c['attachment'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppTheme.accentCyan.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.attach_file, size: 14, color: AppTheme.accentCyan),
                                    const SizedBox(width: 6),
                                    Text(c['attachment'], style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan, fontWeight: FontWeight.w500)),
                                  ]),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.white.withAlpha(10))),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Write a comment...', hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                    filled: true, fillColor: Colors.white.withAlpha(8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: GestureDetector(
                      onTap: () => _showFeedback('Attachments coming soon'),
                      child: const Icon(Icons.attach_file, color: AppTheme.textMuted, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  // ─── Versions Tab ───
  Widget _buildVersionsTab() {
    return Consumer<CollaborationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(children: [
          // Save version button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Save Current Version',
                icon: Icons.save_rounded,
                onPressed: _saveVersion,
              ),
            ),
          ),
          Expanded(
            child: provider.versions.isEmpty
                ? _emptyState(Icons.history_rounded, 'No Versions Saved', 'Save versions to track your project history and restore previous states.')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16), physics: const BouncingScrollPhysics(),
                    itemCount: provider.versions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final v = provider.versions[index];
                      final isLatest = index == 0;
                      final timestamp = DateTime.tryParse(v['created_at'] ?? '') ?? DateTime.now();
                      return FadeInUp(
                        duration: const Duration(milliseconds: 200),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: (isLatest ? AppTheme.accentCyan : AppTheme.primaryPurple).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isLatest ? Icons.star_rounded : Icons.history,
                                color: isLatest ? AppTheme.accentCyan : AppTheme.primaryPurple, size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(v['name'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                if (isLatest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.accentCyan.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                                    child: Text('Latest', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.accentCyan)),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 4),
                              Text('${_timeAgo(timestamp)} • by ${v['author_name'] ?? 'Unknown'}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                              if ((v['notes'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(v['notes'], style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ])),
                            if (!isLatest) GestureDetector(
                              onTap: () => _restoreVersion(v),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryPurple.withAlpha(60)),
                                ),
                                child: Text('Restore', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          // Activity log
          if (provider.activities.isNotEmpty) Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Recent Activity', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...provider.activities.take(5).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a['text'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(_timeAgo(DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now()), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                  ]),
                )),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  // ─── Actions ───

  void _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final provider = context.read<CollaborationProvider>();
    final success = await provider.addComment(_commentController.text.trim());
    if (success) {
      _commentController.clear();
    } else {
      _showFeedback(provider.error ?? 'Failed to add comment');
    }
  }

  void _clearAllComments() {
    final provider = context.read<CollaborationProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Comments', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('Delete all ${provider.comments.length} comments? This cannot be undone.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearComments();
            },
            child: Text('Clear All', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _saveVersion() {
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Save Version', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: notesController,
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Version notes (optional)', hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              filled: true, fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final provider = context.read<CollaborationProvider>();
              final success = await provider.saveVersion(notes: notesController.text.trim());
              if (!mounted) return;
              Navigator.pop(ctx);
              _showFeedback(success ? 'Version saved!' : (provider.error ?? 'Failed'));
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  void _restoreVersion(Map<String, dynamic> v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Restore Version', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('Restore "${v['name']}"? Your current work will be saved as a new version first.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<CollaborationProvider>();
              final success = await provider.restoreVersion(v['id'], v['name']);
              _showFeedback(success ? 'Restored to ${v['name']}' : (provider.error ?? 'Failed'));
            },
            child: Text('Restore', style: GoogleFonts.inter(color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'editor';

    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Invite Collaborator', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Name (for display)', hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.person, color: AppTheme.textMuted),
              filled: true, fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            style: GoogleFonts.inter(color: AppTheme.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email address (must be registered)', hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.email, color: AppTheme.textMuted),
              filled: true, fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Role: ', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            ...<String>['editor', 'viewer', 'admin'].map((role) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setBS(() => selectedRole = role),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedRole == role ? _roleColor(role).withAlpha(30) : Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selectedRole == role ? _roleColor(role) : Colors.white.withAlpha(20)),
                      ),
                      child: Text(role[0].toUpperCase() + role.substring(1), style: GoogleFonts.inter(fontSize: 13,
                          color: selectedRole == role ? _roleColor(role) : AppTheme.textMuted,
                          fontWeight: selectedRole == role ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  ),
                )),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (emailCtrl.text.trim().isEmpty) {
                _showFeedback('Please enter an email address');
                return;
              }
              if (!emailCtrl.text.contains('@')) {
                _showFeedback('Please enter a valid email');
                return;
              }
              final provider = context.read<CollaborationProvider>();
              final success = await provider.addCollaborator(emailCtrl.text.trim(), selectedRole);
              if (!mounted) return;
              Navigator.pop(ctx);
              if (success) {
                _showFeedback('Collaborator invited as $selectedRole');
              } else {
                _showFeedback(provider.error ?? 'Failed to invite');
              }
            },
            child: Text('Send Invite', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ]),
      )),
    );
  }

  // ─── Helpers ───

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner': return AppTheme.primaryPurple;
      case 'admin': return const Color(0xFFE040FB);
      case 'editor': return AppTheme.accentCyan;
      case 'viewer': return AppTheme.accentOrange;
      default: return AppTheme.primaryPurple;
    }
  }

  final _commentColors = [AppTheme.primaryPurple, AppTheme.primaryPink, AppTheme.accentCyan, AppTheme.accentOrange, const Color(0xFFE040FB), const Color(0xFF00E676)];

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: AppTheme.getCardColor(context), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.white.withAlpha(40)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
