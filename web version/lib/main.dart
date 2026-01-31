import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'createapi.dart';
import 'migration_screen.dart';
import 'merchant_storefront.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MigrationAgentApp());
}

class MigrationAgentApp extends StatelessWidget {
  const MigrationAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Migration Sim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// --- 1. THE SPLIT SCREEN ENTRY POINT (Animated & Polished) ---
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 📝 STATE: The Editable Text
  String _makerInfo = "Project: Headless Migration Agent (NMIMS Hackathon)\n\n"
      "Purpose: Simulating a live migration from a monolithic architecture to a headless API-driven system according to the hackathon problem statement.\n\n"
      "Built by: Team Orbit consisting Pushkar Wagh, Anika Nair and Srishti Mishra.\n"
      "Status: Prototype V1";

  void _showMakerInfoDialog() {
    TextEditingController controller = TextEditingController(text: _makerInfo);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.tealAccent),
            SizedBox(width: 10),
            Text("Maker Info & Purpose", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 300),
          child: TextField(
            controller: controller,
            maxLines: null,
            style: const TextStyle(color: Colors.white70, height: 1.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Enter project details here...",
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // LAYER 1: The Split Screen Content
          Row(
            children: [
              // LEFT: Merchant (Storefront) - Light Theme
              Expanded(
                child: HoverRoleCard(
                  title: "I am a Merchant",
                  subtitle: "View my live storefront",
                  icon: Icons.storefront,
                  baseColor: const Color(0xFFF5F5F7),
                  hoverGradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: Colors.grey.shade800,
                  textColor: Colors.grey.shade900,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MerchantStorefront()),
                    );
                  },
                ),
              ),

              // RIGHT: Provider (Admin Console) - Dark Theme
              Expanded(
                child: HoverRoleCard(
                  title: "I am the Provider",
                  subtitle: "Manage keys & agents",
                  icon: Icons.terminal,
                  baseColor: const Color(0xFF1E1E1E),
                  hoverGradient: LinearGradient(
                    colors: [const Color(0xFF2C2C2C), Colors.black.withOpacity(0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: Colors.tealAccent,
                  textColor: Colors.white,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          // LAYER 2: The Floating Capsule (Bottom Center)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showMakerInfoDialog,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade800, Colors.blue.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Maker Info & Purpose",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ✨ NEW: ANIMATED HOVER CARD WIDGET ---
// --- ✨ REFINED: FLICKER-FREE HOVER CARD ---
class HoverRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;
  final LinearGradient hoverGradient;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const HoverRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
    required this.hoverGradient,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<HoverRoleCard> createState() => _HoverRoleCardState();
}

class _HoverRoleCardState extends State<HoverRoleCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovering ? 1.02 : 1.0, // Reduced scale slightly for stability
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            // Use a Stack to layer the Gradient ON TOP of the Base Color
            // This prevents the "lightning" flash because we aren't switching decorations, just fading one in.
            child: Stack(
              children: [
                // LAYER 1: The Base Solid Color (Always there)
                Container(
                  decoration: BoxDecoration(
                    color: widget.baseColor,
                    // No border radius needed here if parent clips, but good to be safe
                  ),
                ),

                // LAYER 2: The Gradient (Fades in smoothly)
                AnimatedOpacity(
                  opacity: _isHovering ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300), // Smooth fade duration
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: widget.hoverGradient,
                    ),
                  ),
                ),

                // LAYER 3: The Content (Text/Icons)
                // Needs to be on top so the gradient doesn't cover it
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with subtle lift animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        transform: Matrix4.translationValues(0, _isHovering ? -8 : 0, 0),
                        child: Icon(widget.icon, size: 80, color: widget.iconColor),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.6,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: widget.textColor, // Removed opacity here to avoid double-fade
                            fontSize: 14,
                            fontWeight: _isHovering ? FontWeight.w500 : FontWeight.normal,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 2. THE ADMIN DASHBOARD (Provider View) ---
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Admin Console'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () {}, // Future settings
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateApiScreen()),
          );
        },
        icon: const Icon(Icons.add_circle_outline),
        label: const Text("New API Key"),
        backgroundColor: Colors.tealAccent.shade700,
        foregroundColor: Colors.white,
      ),
      body: const ApiKeyList(),
    );
  }
}

class ApiKeyList extends StatelessWidget {
  const ApiKeyList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vpn_key_off, size: 64, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                const Text("No Active Keys", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String orgName = data['name'] ?? 'Unknown Org';
            final String apiKey = data['apiKey'] ?? 'No Key';
            final String id = docs[index].id;

            return Card(
              color: const Color(0xFF2C2C2C),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.tealAccent),
                ),
                title: Text(
                  orgName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        apiKey,
                        style: const TextStyle(fontFamily: 'Courier', color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MigrationScreen(
                        orgId: id,
                        apiKey: apiKey,
                        orgName: orgName,
                      ),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // COPY BUTTON
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: Colors.tealAccent),
                      tooltip: 'Copy API Key',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: apiKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("API Key Copied"),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.tealAccent.shade700,
                            duration: const Duration(seconds: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                    // DELETE BUTTON
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      tooltip: 'Delete Organization',
                      onPressed: () {
                        _confirmDelete(context, id, orgName);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Revoke Access?", style: TextStyle(color: Colors.white)),
        content: Text("This will permanently delete the organization '$name' and invalidate the API key.",
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('organizations').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text("Revoke & Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}