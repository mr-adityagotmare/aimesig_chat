import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/udp_chat_service.dart';

import '../../providers/theme_provider.dart';

import '../devices/nearby_devices_screen.dart';
import '../settings/theme_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final UdpChatService udp;

  final String username;

  final VoidCallback onProfileTap;

  const HomeScreen({
    super.key,
    required this.udp,
    required this.username,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        context.watch<ThemeProvider>();

    final isDark = themeProvider.isDark;

    final accent =
        themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFF2F2F7),

      appBar: AppBar(
        elevation: 0.5,

        backgroundColor:
            isDark ? Colors.black : Colors.white,

        foregroundColor:
            isDark ? Colors.white : Colors.black,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "Aimesig Chat",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              username,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ThemeSettingsScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.palette,
              color: accent,
            ),
          ),

          IconButton(
            onPressed: onProfileTap,
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: accent,
              child: Text(
                username.isNotEmpty
                    ? username[0]
                        .toUpperCase()
                    : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),

      body: NearbyDevicesScreen(
        udp: udp,
        myName: username,
      ),
    );
  }
}