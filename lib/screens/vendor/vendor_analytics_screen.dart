import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/vendor_request.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<AppProvider>().currentUser;
    if (vendor == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _firestoreService.followersStream(vendor.followers),
        builder: (context, followersSnapshot) {
          return StreamBuilder<List<AppNotification>>(
            stream: _notificationService.notificationsForVendor(vendor.id),
            builder: (context, notificationsSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.vendorRequestsStream(vendor.id),
                builder: (context, requestsSnapshot) {
                  final followers = followersSnapshot.data ?? [];
                  final notifications = notificationsSnapshot.data ?? [];
                  
                  final requestsDocs = requestsSnapshot.data?.docs ?? [];
                  final requests = requestsDocs.map((d) => VendorRequest.fromMap(d.id, d.data())).toList();

                  // Compute Followers by Location
                  final locationCounts = <String, int>{};
                  for (final f in followers) {
                    final loc = f.locationName.isNotEmpty ? f.locationName : 'Location not set';
                    locationCounts[loc] = (locationCounts[loc] ?? 0) + 1;
                  }
                  final sortedLocations = locationCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  // Compute Notifications by Street
                  final streetCounts = <String, int>{};
                  for (final n in notifications) {
                    final st = n.street.isNotEmpty ? n.street : 'Unknown street';
                    streetCounts[st] = (streetCounts[st] ?? 0) + 1;
                  }
                  final sortedStreets = streetCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  // Compute Request Insights
                  int pendingRequests = requests.where((r) => r.status == 'pending').length;
                  
                  final itemCounts = <String, int>{};
                  final questionCounts = <String, int>{};
                  for (final r in requests) {
                    if (r.itemName.isNotEmpty) {
                      itemCounts[r.itemName] = (itemCounts[r.itemName] ?? 0) + 1;
                    }
                    if (r.question.isNotEmpty) {
                      questionCounts[r.question] = (questionCounts[r.question] ?? 0) + 1;
                    }
                  }
                  
                  String mostRequestedItem = 'None';
                  if (itemCounts.isNotEmpty) {
                    mostRequestedItem = itemCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                  }

                  String mostCommonQuestion = 'None';
                  if (questionCounts.isNotEmpty) {
                    mostCommonQuestion = questionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                  }

                  // Top Suggested Street (combining locations and notification streets)
                  final combinedStreets = <String, int>{};
                  for (final f in followers) {
                    if (f.locationName.isNotEmpty) {
                      combinedStreets[f.locationName] = (combinedStreets[f.locationName] ?? 0) + 1;
                    }
                  }
                  for (final n in notifications) {
                    if (n.street.isNotEmpty) {
                      combinedStreets[n.street] = (combinedStreets[n.street] ?? 0) + 1;
                    }
                  }
                  
                  String topStreet = 'Not enough data';
                  if (combinedStreets.isNotEmpty) {
                    topStreet = combinedStreets.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                  }

                  // ── Follower Interest Insights ──────────────────────────────────────
                  int matchingFollowersCount = 0;
                  int noMatchingFollowersCount = 0;
                  final Map<String, int> followerInterestDistribution = {};
                  final Map<String, int> vendorCategoryMatchCounts = {
                    for (var interest in vendor.interests) interest: 0
                  };

                  for (final f in followers) {
                    bool hasMatch = false;
                    
                    if (f.interests.isEmpty) {
                      noMatchingFollowersCount++;
                    } else {
                      for (final interest in f.interests) {
                        // Distribution among ALL followers
                        followerInterestDistribution[interest] = (followerInterestDistribution[interest] ?? 0) + 1;
                        
                        // Check match with vendor categories
                        if (vendor.interests.contains(interest)) {
                          hasMatch = true;
                          vendorCategoryMatchCounts[interest] = (vendorCategoryMatchCounts[interest] ?? 0) + 1;
                        }
                      }
                      
                      if (hasMatch) {
                        matchingFollowersCount++;
                      } else {
                        noMatchingFollowersCount++;
                      }
                    }
                  }

                  final sortedFollowerInterests = followerInterestDistribution.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final sortedVendorMatches = vendorCategoryMatchCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Overview Cards ──────────────────────────────────────
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildStatCard('Total Followers', followers.length.toString(), Icons.people, Colors.blue),
                          _buildStatCard('Notifications Sent', notifications.length.toString(), Icons.notifications, Colors.orange),
                          _buildStatCard('Total Requests', requests.length.toString(), Icons.forum, Colors.purple),
                          _buildStatCard('Pending Requests', pendingRequests.toString(), Icons.pending_actions, Colors.red),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Top Suggested Street ─────────────────────────────────
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Top Suggested Street', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(topStreet, style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              const Text('Based on follower locations & past routes', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Follower Interest Insights ─────────────────────────────────────
                      const Text('Follower Interest Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSmallStat('Matches', matchingFollowersCount.toString(), Colors.green),
                                  ),
                                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                                  Expanded(
                                    child: _buildSmallStat('No Match', noMatchingFollowersCount.toString(), Colors.grey),
                                  ),
                                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                                  Expanded(
                                    child: _buildSmallStat('Match %', 
                                      followers.isEmpty ? '0%' : '${(matchingFollowersCount / followers.length * 100).toStringAsFixed(0)}%', 
                                      Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (vendor.interests.isNotEmpty) ...[
                        const Text('Matches by Your Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: sortedVendorMatches.isEmpty 
                              ? [const ListTile(title: Text('No categories set'))]
                              : sortedVendorMatches.map((entry) {
                                  return _buildBarRow(
                                    label: entry.key,
                                    count: entry.value,
                                    maxCount: followers.isNotEmpty ? followers.length : 1,
                                    color: Colors.green,
                                  );
                                }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Text('Top Follower Interests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: sortedFollowerInterests.isEmpty
                            ? [const ListTile(title: Text('No interests recorded'))]
                            : sortedFollowerInterests.take(5).map((entry) {
                                return _buildBarRow(
                                  label: entry.key,
                                  count: entry.value,
                                  maxCount: followers.isNotEmpty ? followers.length : 1,
                                  color: Colors.blue,
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Request Insights ─────────────────────────────────────
                      if (requests.isNotEmpty) ...[
                        const Text('Request Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInsightRow('Most Requested Item', mostRequestedItem),
                                const Divider(),
                                _buildInsightRow('Most Common Question', mostCommonQuestion),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Followers by Location ────────────────────────────────
                      const Text('Followers by Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (sortedLocations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No followers yet.'),
                        )
                      else
                        Card(
                          child: Column(
                            children: sortedLocations.map((entry) {
                              return _buildBarRow(
                                label: entry.key,
                                count: entry.value,
                                maxCount: followers.isNotEmpty ? followers.length : 1,
                                color: Colors.blue,
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ── Notifications by Street ──────────────────────────────
                      const Text('Notifications by Street', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (sortedStreets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No notifications sent yet.'),
                        )
                      else
                        Card(
                          child: Column(
                            children: sortedStreets.map((entry) {
                              return _buildBarRow(
                                label: entry.key,
                                count: entry.value,
                                maxCount: notifications.isNotEmpty ? notifications.length : 1,
                                color: Colors.orange,
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color) {
    return Card(
      elevation: 0,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.shade700, size: 24),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade900)),
            Text(title, style: TextStyle(fontSize: 12, color: color.shade800), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 3,
          child: Text(value, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildBarRow({
    required String label,
    required int count,
    required int maxCount,
    required MaterialColor color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
              Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: count / maxCount,
              backgroundColor: color.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color.shade400),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
