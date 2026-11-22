import 'package:zing/Modal/types.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';

// Adjust imports as needed
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import '../Service/ChatProvider.dart';
import 'ChatScreen.dart';

class OwnerChatListScreen extends StatefulWidget {
  final Store store;

  OwnerChatListScreen({required this.store});

  @override
  _OwnerChatListScreenState createState() => _OwnerChatListScreenState();
}

class _OwnerChatListScreenState extends State<OwnerChatListScreen>
    with SingleTickerProviderStateMixin {
  // --------------------------------------------------------------------------
  // Animation fields declared as late:
  late AnimationController _animationController;
  late Animation<Offset> _listSlideAnimation;
  late Animation<double> _listFadeAnimation;

  // --------------------------------------------------------------------------
  // Cache of user data
  Map<String, CustomUser> usersCache = {};

  @override
  void initState() {
    super.initState();

    // Initialize animations in initState
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _listSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Start slightly down
      end: const Offset(0, 0),     // End at normal position
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _listFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Fetch user profiles for each chat's customer
  Future<void> _fetchUsers(List<Map<String, dynamic>> chats) async {
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);

    for (var chat in chats) {
      final customerId = chat['customerId'];
      if (!usersCache.containsKey(customerId)) {
        CustomUser? user = await userProvider.fetchUserById(customerId);
        if (user != null) {
          usersCache[customerId] = user;
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // Friendly timestamp formatting (e.g., "Today at 2:00 PM")
  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final justDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (justDate == today) {
      final timeString = DateFormat('h:mm a').format(dateTime);
      return "Today at $timeString";
    } else if (justDate == yesterday) {
      final timeString = DateFormat('h:mm a').format(dateTime);
      return "Yesterday at $timeString";
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: FutureBuilder(
        future: chatProvider.fetchAllUserChats(widget.store.id!),
        builder: (context, snapshot) {
          final chats = chatProvider.allChats;

          // If no chats exist yet
          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          // Once we have chats, we fetch the user info for each
          return FutureBuilder(
            future: _fetchUsers(chats),
            builder: (context, userSnapshot) {
              // If still loading user data and we haven't cached them all
              if (userSnapshot.connectionState == ConnectionState.waiting &&
                  usersCache.length < chats.length) {
                return const Center(child: CircularProgressIndicator());
              }

              return Container(
                color: cs.surface,
                // Use the animations
                child: SlideTransition(
                  position: _listSlideAnimation,
                  child: FadeTransition(
                    opacity: _listFadeAnimation,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final customerId = chat['customerId'];
                        final lastMessage = chat['lastMessage'] ?? '';
                        final lastUpdated = chat['lastUpdated'] as Timestamp;
                        final user = usersCache[customerId];

                        // Format the lastUpdated time
                        final formattedTime = _formatTimestamp(lastUpdated);

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: chat['chatId'],
                                  userId: widget.store.id!,
                                  storeId: widget.store.id!,
                                  // We'll set the "storeName" in ChatScreen to the user's name
                                  // because from the store's perspective, they're chatting with that user.
                                  storeName:
                                  user != null ? user.name : "User: $customerId",
                                  storeImageUrl: widget.store.imageUrl,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: ZingShadows.soft,
                            ),
                            child: Row(
                              children: [
                                // Avatar with "online" dot
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: (user?.profileImageUrl != null &&
                                          user!.profileImageUrl.isNotEmpty)
                                          ? NetworkImage(user.profileImageUrl)
                                          : const AssetImage('assets/images/zing.png')
                                      as ImageProvider,
                                    ),
                                    // For demonstration, always green
                                    // In a real app, you'd check user.isOnline
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        height: 12,
                                        width: 12,
                                        decoration: BoxDecoration(
                                          color: ZingColors.success,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: cs.surface, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Middle: user name & last message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user != null
                                            ? user.name
                                            : "User: $customerId",
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMessage,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right side: time + arrow
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formattedTime,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/zing.png',
            height: 150,
          ),
          const SizedBox(height: 16),
          Text(
            "No messages yet",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Users who message your store will appear here.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}