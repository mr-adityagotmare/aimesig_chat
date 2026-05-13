import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final Function(String) onNameChanged;

  const ProfileScreen({
    super.key,
    required this.onNameChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController controller =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    loadName();
  }

  Future<void> loadName() async {
    final prefs = await SharedPreferences.getInstance();

    controller.text =
        prefs.getString("username") ?? "";
  }

  Future<void> saveName() async {
    final name = controller.text.trim();

    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("username", name);

    widget.onNameChanged(name);

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),

      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text("Profile"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 30),

            CircleAvatar(
              radius: 45,
              backgroundColor:
                  const Color(0xFF075E54),

              child: Text(
                controller.text.isNotEmpty
                    ? controller.text[0]
                        .toUpperCase()
                    : "?",
                style: const TextStyle(
                  fontSize: 34,
                ),
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: controller,

              style: const TextStyle(
                color: Colors.white,
              ),

              decoration: InputDecoration(
                labelText: "Device Name",

                labelStyle: const TextStyle(
                  color: Colors.grey,
                ),

                filled: true,
                fillColor: const Color(0xFF202C33),

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF25D366),
                ),

                onPressed: saveName,

                child: const Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}