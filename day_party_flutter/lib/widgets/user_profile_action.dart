import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/knesset/knesset_database_service.dart';

class UserProfileAction extends StatelessWidget {
  const UserProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn || authProvider.user == null) {
          return const SizedBox.shrink();
        }

        final user = authProvider.user!;
        final displayName = user['displayName'] as String? ?? 'User';
        final profilePicture = user['profilePicture'] as String?;

        return PopupMenuButton<String>(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profilePicture != null && profilePicture.isNotEmpty)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(profilePicture),
                    onBackgroundImageError: (exception, stackTrace) {},
                    child: const Icon(Icons.person, size: 20),
                  )
                else
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 20),
                  ),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
          onSelected: (value) async {
            if (value == 'logout') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('התנתק'),
                  content: const Text('האם אתה בטוח שברצונך להתנתק?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('ביטול'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('התנתק', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            } else if (value == 'update_db') {
              // Show loading dialog
              if (!context.mounted) return;
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('מעדכן את מסד הנתונים...'),
                    ],
                  ),
                ),
              );

              try {
                final dbService = KnessetDatabaseService();
                final success = await dbService.updateDatabase();
                
                if (!context.mounted) return;
                Navigator.of(context).pop(); // Close loading dialog
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('מסד הנתונים עודכן בהצלחה'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Update failed');
                }
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop(); // Close loading dialog
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('שגיאה בעדכון מסד הנתונים: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('התנתק', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'update_db',
              child: const Row(
                children: [
                  Icon(Icons.update, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('עדכן מסד נתונים'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


