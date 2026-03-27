import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSave = true;
  bool _notifications = true;
  bool _analytics = false;
  bool _hapticFeedback = true;
  bool _highQualityPreview = true;
  String _defaultExport = '1080p';
  String _theme = 'Dark';
  bool _cacheCleared = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSave = prefs.getBool('autoSave') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
      _analytics = prefs.getBool('analytics') ?? false;
      _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
      _highQualityPreview = prefs.getBool('highQualityPreview') ?? true;
      _defaultExport = prefs.getString('defaultExport') ?? '1080p';
      _theme = prefs.getString('theme') ?? 'Dark';
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _sectionTitle('General'),
                      _toggleItem('Auto-Save Projects', 'Save changes automatically', Icons.save_rounded, _autoSave, (v) { setState(() => _autoSave = v); _savePref('autoSave', v); }),
                      _toggleItem('Notifications', 'Get notified about collaborations', Icons.notifications_rounded, _notifications, (v) { setState(() => _notifications = v); _savePref('notifications', v); }),
                      _toggleItem('Haptic Feedback', 'Vibration on interactions', Icons.vibration_rounded, _hapticFeedback, (v) { setState(() => _hapticFeedback = v); _savePref('hapticFeedback', v); }),
                      const SizedBox(height: 20),
                      _sectionTitle('Editor'),
                      _toggleItem('High Quality Preview', 'Use full resolution in preview', Icons.hd_rounded, _highQualityPreview, (v) { setState(() => _highQualityPreview = v); _savePref('highQualityPreview', v); }),
                      _dropdownItem('Default Export Quality', Icons.tune_rounded, _defaultExport, ['720p', '1080p', '4K'], (v) { setState(() => _defaultExport = v); _savePref('defaultExport', v); }),
                      _dropdownItem('Theme', Icons.palette_rounded, _theme, ['Dark', 'AMOLED', 'Midnight'], (v) { setState(() => _theme = v); _savePref('theme', v); }),
                      const SizedBox(height: 20),
                      _sectionTitle('Privacy'),
                      _toggleItem('Share Analytics', 'Help improve SmartCut', Icons.analytics_rounded, _analytics, (v) { setState(() => _analytics = v); _savePref('analytics', v); }),
                      const SizedBox(height: 20),
                      _sectionTitle('Storage'),
                      _buildStorageInfo(),
                      const SizedBox(height: 20),
                      _sectionTitle('About'),
                      _infoItem('Version', '1.0.0', Icons.info_outline_rounded),
                      _infoItem('Build', '2024.03.13', Icons.build_rounded),
                      _infoItem('Platform', 'Flutter / Dart', Icons.phone_android_rounded),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'SmartCut v1.0.0\nMade with ❤️ and AI',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Padding(
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
            Expanded(child: Text('Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryPurple)),
    );
  }

  Widget _toggleItem(String title, String desc, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primaryPurple,
              inactiveTrackColor: AppTheme.darkElevated,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownItem(String title, IconData icon, String value, List<String> options, ValueChanged<String> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryPurple.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<String>(
                value: value,
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary)))).toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
                underline: const SizedBox(),
                isDense: true,
                dropdownColor: AppTheme.darkCard,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryPurple, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Storage Used', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Text('2.4 GB / 10 GB', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.24,
              backgroundColor: AppTheme.darkElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _storageChip('Projects', '1.2 GB', AppTheme.primaryPurple),
              const SizedBox(width: 8),
              _storageChip('Cache', '800 MB', AppTheme.accentOrange),
              const SizedBox(width: 8),
              _storageChip('Exports', '400 MB', AppTheme.accentCyan),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _clearCacheDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryPink,
                side: const BorderSide(color: AppTheme.primaryPink),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Clear Cache', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Cache', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('This will clear 800 MB of cached data. Your projects will not be affected.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cacheCleared = true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Cache cleared successfully', style: GoogleFonts.inter(fontSize: 13)),
                backgroundColor: AppTheme.accentCyan, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: Text('Clear', style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _storageChip(String label, String size, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(size, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
