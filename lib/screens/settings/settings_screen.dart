import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/network_mode_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final Future<void> Function()? onNetworkModeChanged;
  const SettingsScreen({super.key, this.onNetworkModeChanged});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final networkMode = context.watch<NetworkModeProvider>();
    final isDark = themeProvider.isDark;
    final accent = themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary(isDark)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          _SectionLabel(label: 'APPEARANCE', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              _ToggleTile(
                icon: Icons.dark_mode_rounded,
                label: 'Dark Mode',
                subtitle: isDark ? 'Currently dark' : 'Currently light',
                value: isDark,
                isDark: isDark,
                accent: accent,
                onChanged: (v) => themeProvider.setDark(v),
              ),
              _Divider(isDark: isDark),
              _ToggleTile(
                icon: Icons.view_compact_rounded,
                label: 'Compact Mode',
                subtitle: 'Reduce spacing in chat list',
                value: themeProvider.compactMode,
                isDark: isDark,
                accent: accent,
                onChanged: (v) => themeProvider.setCompactMode(v),
              ),
              _Divider(isDark: isDark),
              _ToggleTile(
                icon: Icons.access_time_rounded,
                label: 'Show Timestamps',
                subtitle: 'Display time on messages',
                value: themeProvider.showTimestamps,
                isDark: isDark,
                accent: accent,
                onChanged: (v) => themeProvider.setShowTimestamps(v),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Accent color section
          _SectionLabel(label: 'ACCENT COLOR', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your accent color',
                      style: TextStyle(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: themeProvider.availableColors.map((color) {
                        final isSelected = themeProvider.primaryColor == color;
                        return GestureDetector(
                          onTap: () => themeProvider.setPrimaryColor(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Chat settings
          _SectionLabel(label: 'CHAT', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.text_fields_rounded,
                          color: accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message font size',
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${themeProvider.chatFontSize.toInt()}px',
                            style: TextStyle(
                              color: AppColors.textSecondary(isDark),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Text('A',
                        style: TextStyle(
                            color: AppColors.textMuted(isDark),
                            fontSize: 12)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          thumbColor: accent,
                          inactiveTrackColor: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          overlayColor: accent.withOpacity(0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          min: 12,
                          max: 22,
                          divisions: 5,
                          value: themeProvider.chatFontSize,
                          onChanged: (v) => themeProvider.setChatFontSize(v),
                        ),
                      ),
                    ),
                    Text('A',
                        style: TextStyle(
                            color: AppColors.textMuted(isDark),
                            fontSize: 20)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Connection Mode section
          _SectionLabel(label: 'CONNECTION MODE', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose how Aimesig connects to other users',
                      style: TextStyle(
                        color: AppColors.textSecondary(isDark),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeCard(
                            icon: Icons.wifi_rounded,
                            title: 'LAN / Wi-Fi',
                            subtitle: 'Same network only\nNo internet needed',
                            selected: networkMode.isLan,
                            accent: accent,
                            isDark: isDark,
                            onTap: () async {
                              await networkMode.setMode(NetworkMode.lan);
                              await onNetworkModeChanged?.call();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ModeCard(
                            icon: Icons.public_rounded,
                            title: 'Internet',
                            subtitle: 'Chat with anyone\nAnywhere online',
                            selected: networkMode.isInternet,
                            accent: accent,
                            isDark: isDark,
                            onTap: () async {
                              await networkMode.setMode(NetworkMode.internet);
                              await onNetworkModeChanged?.call();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (networkMode.isInternet) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accent.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Internet mode relays messages via the Aimesig server. '
                                'You can chat with users on different networks.',
                                style: TextStyle(
                                  color: AppColors.textSecondary(isDark),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Network info
          _SectionLabel(label: 'NETWORK', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              if (networkMode.isLan) ...[
                _InfoTile(
                  icon: Icons.router_outlined,
                  label: 'Discovery Port',
                  value: '8888',
                  isDark: isDark,
                  accent: accent,
                ),
                _Divider(isDark: isDark),
                _InfoTile(
                  icon: Icons.message_outlined,
                  label: 'Message Port',
                  value: '4040',
                  isDark: isDark,
                  accent: accent,
                ),
                _Divider(isDark: isDark),
                _InfoTile(
                  icon: Icons.broadcast_on_personal_outlined,
                  label: 'Protocol',
                  value: 'UDP Broadcast',
                  isDark: isDark,
                  accent: accent,
                ),
              ] else ...[
                _InfoTile(
                  icon: Icons.cloud_outlined,
                  label: 'Server',
                  value: 'aimapp-server.onrender.com',
                  isDark: isDark,
                  accent: accent,
                ),
                _Divider(isDark: isDark),
                _InfoTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Protocol',
                  value: 'WebSocket (Socket.IO)',
                  isDark: isDark,
                  accent: accent,
                ),
                _Divider(isDark: isDark),
                _InfoTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Privacy',
                  value: 'Relay · Encrypted in transit',
                  isDark: isDark,
                  accent: accent,
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // About
          _SectionLabel(label: 'ABOUT', isDark: isDark),
          const SizedBox(height: 8),

          _SettingsCard(
            isDark: isDark,
            children: [
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                value: '2.0.0',
                isDark: isDark,
                accent: accent,
              ),
              _Divider(isDark: isDark),
              _InfoTile(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy',
                value: networkMode.isLan ? 'LAN only · No cloud' : 'Internet · Relay server',
                isDark: isDark,
                accent: accent,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // App footer
          Center(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.wifi_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  'Aimesig Chat',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instant LAN messaging',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textMuted(isDark),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _SettingsCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final Color accent;
  final Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color accent;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevated : AppColors.lightCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: AppColors.textSecondary(isDark), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.12)
              : (isDark ? AppColors.darkElevated : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? accent : AppColors.textSecondary(isDark), size: 20),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: selected ? accent : AppColors.textPrimary(isDark),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textMuted(isDark),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 16,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}
