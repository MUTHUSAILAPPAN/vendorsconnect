import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/app_user.dart';
import '../../widgets/confirm_dialog.dart';
import '../../l10n/app_strings.dart';
import '../login_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(
        children: [
          _sectionHeader(context, context.t('Appearance')),
          ListTile(
            title: Text(context.t('Theme')),
            subtitle: Text(context.t(provider.themeMode)),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'Light', label: Text(context.t('Light'))),
                ButtonSegment(value: 'Dark', label: Text(context.t('Dark'))),
                ButtonSegment(value: 'System', label: Text(context.t('System'))),
              ],
              selected: {provider.themeMode},
              onSelectionChanged: (value) => provider.updateThemeMode(value.first),
            ),
          ),
          ListTile(
            title: Text(context.t('Font Size')),
            subtitle: Text(context.t(provider.fontSize)),
            trailing: DropdownButton<String>(
              value: provider.fontSize,
              onChanged: (v) => provider.updateFontSize(v!),
              items: ['Small', 'Normal', 'Large', 'Extra Large']
                  .map((s) => DropdownMenuItem(value: s, child: Text(context.t(s))))
                  .toList(),
            ),
          ),

          const Divider(),
          _sectionHeader(context, context.t('Language')),
          ListTile(
            title: Text(context.t('Language')),
            subtitle: Text(provider.selectedLanguageCode == 'en' 
                ? 'English' 
                : provider.selectedLanguageCode == 'ta' ? 'Tamil' : 'Hindi'),
            trailing: DropdownButton<String>(
              value: provider.selectedLanguageCode,
              onChanged: (v) => provider.updateLanguageCode(v!),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi')),
              ],
            ),
          ),

          const Divider(),
          _sectionHeader(context, context.t('Privacy')),
          SwitchListTile(
            title: Text(context.t('Contact Visibility')),
            subtitle: provider.isGuest 
                ? const Text('Login required to manage privacy') 
                : const Text('Allow others to see your phone number'),
            value: provider.isContactPublic,
            onChanged: provider.isGuest ? null : (v) async {
              try {
                await provider.updateContactVisibility(v);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(v ? 'Contact info is now public' : 'Contact info is now private')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not update contact visibility')),
                  );
                }
              }
            },
          ),

          const Divider(),
          _sectionHeader(context, context.t('Blocked Users')),
          if (provider.isGuest)
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(context.t('Blocked Users')),
              subtitle: const Text('Login to manage blocked users'),
            )
          else
            StreamBuilder<List<AppUser>>(
              stream: FirestoreService().blockedUsersStream(provider.currentUser?.blockedUserIds ?? []),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(title: Text('Loading...'));
                }
                final blockedUsers = snapshot.data ?? [];
                if (blockedUsers.isEmpty) {
                  return ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(context.t('Blocked Users')),
                    subtitle: const Text('No users blocked'),
                  );
                }
                return Column(
                  children: blockedUsers.map((user) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                    title: Text(user.name),
                    subtitle: Text(user.role.toUpperCase()),
                    trailing: TextButton(
                      onPressed: () async {
                        final confirm = await showConfirmDialog(
                          context: context,
                          title: 'Unblock User',
                          message: 'Are you sure you want to unblock ${user.name}?',
                          confirmText: 'Unblock',
                        );
                        if (confirm) {
                          try {
                            await provider.unblockUser(user.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not unblock user')),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  )).toList(),
                );
              },
            ),

          const Divider(),
          _sectionHeader(context, context.t('Account')),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text(context.t('Logout'), style: TextStyle(color: colorScheme.error)),
            onTap: () async {
              final confirm = await showConfirmDialog(
                context: context,
                title: context.t('Logout'),
                message: 'Are you sure you want to log out?',
                confirmText: context.t('Logout'),
              );
              if (confirm) {
                if (context.mounted) {
                  provider.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
