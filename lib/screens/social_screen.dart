import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_data.dart';
import '../models/auth_user.dart';
import '../services/game_library_service.dart';
import '../services/auth_service.dart';
import 'session_details_screen.dart';
import '../data.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with TickerProviderStateMixin {
  List<Friend> _friends = [];
  List<GameSession> _activeSessions = [];
  List<FriendRequest> _pendingRequests = [];
  List<MessageThread> _inbox = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSocialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialData() async {
    setState(() => _isLoading = true);
    
    // Load friends
    final friends = await GameLibraryService.getFriends();
    
    // Load pending friend requests
    final currentUser = await AuthService.getCurrentUser();
    final pendingRequests = currentUser != null 
        ? await GameLibraryService.getPendingFriendRequests(currentUser.id)
        : <FriendRequest>[];
    
    // Load active sessions (mock data for now)
    final sessions = _getMockSessions();
    // Load inbox
    final inbox = await GameLibraryService.getInbox();
    
    setState(() {
      _friends = friends;
      _pendingRequests = pendingRequests;
      _activeSessions = sessions;
      _inbox = inbox;
      _isLoading = false;
    });
  }

  List<GameSession> _getMockSessions() {
    return [
      GameSession(
        id: 'session1',
        gameId: 'elden-ring',
        gameTitle: 'ELDEN RING',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        participants: ['user1', 'user2', 'user3'],
        type: SessionType.multiplayer,
      ),
      GameSession(
        id: 'session2',
        gameId: 'mhw',
        gameTitle: 'Monster Hunter: World',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        participants: ['user4', 'user5'],
        type: SessionType.coOp,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(
              text: 'Requests', 
              icon: Stack(
                children: [
                  const Icon(Icons.person_add),
                  if (_pendingRequests.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Messages', icon: Icon(Icons.mail_outline)),
            const Tab(text: 'Sessions', icon: Icon(Icons.games)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAddFriendDialog,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(
                  friends: _friends, 
                  onRefresh: _loadSocialData,
                  onAddFriend: _showAddFriendDialog,
                ),
                _PendingRequestsTab(
                  requests: _pendingRequests,
                  onRefresh: _loadSocialData,
                ),
                _MessagesTab(inbox: _inbox),
                _SessionsTab(sessions: _activeSessions),
              ],
            ),
    );
  }

  void _showAddFriendDialog() {
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
        title: const Text('Add Friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                  controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Username or Email',
                border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Rebuild to show/hide suggestions
                  },
                ),
                const SizedBox(height: 16),
                if (searchController.text.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildSuggestedFriends(searchController.text),
                ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
              FutureBuilder<List<AuthUser>>(
                future: AuthService.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ElevatedButton(
                      onPressed: null,
                      child: Text('Loading...'),
                    );
                  }
                  
                  final registeredUsers = snapshot.data ?? [];
                  final userExists = searchController.text.isNotEmpty && 
                      registeredUsers.any((user) => 
                          user.username.toLowerCase() == searchController.text.toLowerCase());
                  
                  return ElevatedButton(
                    onPressed: userExists ? () => _sendFriendRequest(searchController.text) : null,
                    child: Text(userExists ? 'Send Request' : 'User Not Found'),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuggestedFriends(String query) {
    return FutureBuilder<List<AuthUser>>(
      future: AuthService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData) {
          return const Text(
            'Error loading users',
            style: TextStyle(color: Colors.red),
          );
        }

        final registeredUsers = snapshot.data!;
        final suggestions = registeredUsers.where((user) =>
            user.username.toLowerCase().contains(query.toLowerCase()) ||
            user.username.toLowerCase().startsWith(query.toLowerCase())
        ).take(3).toList();

        if (suggestions.isEmpty) {
          return const Text(
            'No users found',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: suggestions.map((user) => ListTile(
            leading: CircleAvatar(
              child: Text(user.username[0].toUpperCase()),
            ),
            title: Text(user.username),
            subtitle: Text('Level ${user.level}'),
            trailing: ElevatedButton(
              onPressed: () => _addRegisteredUserAsFriend(user),
              child: const Text('Add'),
            ),
          )).toList(),
        );
      },
    );
  }


  void _sendFriendRequest(String username) async {
    // Validate if username exists in registered users
    final registeredUsers = await AuthService.getAllUsers();
    final targetUser = registeredUsers.firstWhere(
      (user) => user.username.toLowerCase() == username.toLowerCase(),
      orElse: () => AuthUser(
        id: '',
        username: '',
        email: '',
        password: '',
        createdAt: DateTime.now(),
      ),
    );
    
    Navigator.pop(context);
    
    if (targetUser.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username "$username" not found. Please check the spelling.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get current user
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to send friend requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Send friend request
      await GameLibraryService.sendFriendRequest(
        currentUser.id,
        currentUser.username,
        targetUser.id,
        targetUser.username,
      );
      
      // Refresh the social data to show the new request
      await _loadSocialData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to $username!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addRegisteredUserAsFriend(AuthUser user) async {
    Navigator.pop(context);
    
    // Get current user
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to send friend requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Send friend request
      await GameLibraryService.sendFriendRequest(
        currentUser.id,
        currentUser.username,
        user.id,
        user.username,
      );
      
      // Refresh the social data to show the new request
      await _loadSocialData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${user.username}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
      ),
    );
  }
  }

}

class _FriendsTab extends StatelessWidget {
  final List<Friend> friends;
  final VoidCallback onRefresh;
  final VoidCallback onAddFriend;

  const _FriendsTab({
    required this.friends,
    required this.onRefresh,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return _EmptyFriendsView(onAddFriend: onAddFriend);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _FriendCard(friend: friend, onRefresh: onRefresh);
        },
      ),
    );
  }
}

class _EmptyFriendsView extends StatelessWidget {
  final VoidCallback onAddFriend;

  const _EmptyFriendsView({required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to see their gaming activity',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddFriend,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final Friend friend;
  final VoidCallback onRefresh;

  const _FriendCard({required this.friend, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF121E3D),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(friend.avatarUrl),
              child: friend.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    friend.isOnline ? Icons.circle : Icons.circle_outlined,
                    size: 14,
                    color: friend.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          friend.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (friend.isOnline && friend.currentGame.isNotEmpty)
              Text('Playing ${friend.currentGame}')
            else
              Text(friend.isOnline ? 'Online' : 'Offline'),
            Text('Level ${friend.level}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'message',
              child: Text('Send Message'),
            ),
            const PopupMenuItem(
              value: 'invite',
              child: Text('Invite to Game'),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove Friend'),
            ),
          ],
          onSelected: (value) => _handleFriendAction(context, value),
        ),
      ),
    );
  }

  void _handleFriendAction(BuildContext context, String action) {
    switch (action) {
      case 'message':
        _showMessageDialog(context);
        break;
      case 'invite':
        _showInviteDialog(context);
        break;
      case 'remove':
        _showRemoveFriendDialog(context);
        break;
    }
  }

  void _showMessageDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message ${friend.username}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Type your message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = messageController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              try {
                await GameLibraryService.sendMessage(
                  toUserId: friend.id,
                  toUsername: friend.username,
                  text: text,
                );
                onRefresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message sent to ${friend.username}!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error sending message: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    final games = mockGames; // use canonical game list
    // Preselect the first game so the action button is enabled by default
    GameItem? selectedGame = games.isNotEmpty ? games.first : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Invite ${friend.username} to Game'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<GameItem>(
                  value: selectedGame,
                  decoration: const InputDecoration(
                    labelText: 'Select Game',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: games.map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g.title),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGame = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedGame != null ? () async {
                  Navigator.pop(context);
                  await GameLibraryService.sendGameInvite(
                    toUserId: friend.id,
                    gameId: selectedGame!.id,
                    gameTitle: selectedGame!.title,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invitation sent to ${friend.username} for ${selectedGame!.title}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } : null,
                child: const Text('Send Invite'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRemoveFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove ${friend.username} from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              GameLibraryService.removeFriend(friend.id).then((_) {
                onRefresh(); // Refresh the friends list
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${friend.username} removed from friends'),
                    backgroundColor: Colors.red,
                  ),
              );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // last seen formatting removed since we now show Online/Offline only
}

class _MessagesTab extends StatefulWidget {
  final List<MessageThread> inbox;
  const _MessagesTab({required this.inbox});

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  late List<MessageThread> _threads;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _threads = List<MessageThread>.from(widget.inbox);
    _loadMe();
  }

  @override
  void didUpdateWidget(covariant _MessagesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inbox != widget.inbox) {
      _threads = List<MessageThread>.from(widget.inbox);
    }
  }

  Future<void> _loadMe() async {
    final me = await AuthService.getCurrentUser();
    setState(() {
      _currentUserId = me?.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_threads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 80, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your inbox is empty',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final thread = _threads[index];
        final last = thread.messages.isNotEmpty ? thread.messages.last : null;
        final unread = thread.messages
            .where((m) => (_currentUserId != null && m.toUserId == _currentUserId && !m.read))
            .length;
        return Card(
          color: const Color(0xFF121E3D),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(thread.withUsername[0].toUpperCase()),
            ),
            title: Text(
              thread.withUsername,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              last?.text ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  last != null ? _formatInboxTime(last.sentAt) : '',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              // Optimistically mark as read locally for immediate UI update
              setState(() {
                final msgs = thread.messages.map((m) => ChatMessage(
                  id: m.id,
                  fromUserId: m.fromUserId,
                  toUserId: m.toUserId,
                  text: m.text,
                  sentAt: m.sentAt,
                  read: true,
                )).toList();
                _threads[index] = MessageThread(
                  withUserId: thread.withUserId,
                  withUsername: thread.withUsername,
                  messages: msgs,
                );
              });

              // Persist as read before navigating
              await GameLibraryService.markThreadRead(thread.withUserId);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ChatScreen(
                    otherUserId: thread.withUserId,
                    otherUsername: thread.withUsername,
                  ),
                ),
              );
              // After returning, try to refresh the parent Social screen if possible
              final state = context.findAncestorStateOfType<_SocialScreenState>();
              state?._loadSocialData();
            },
          ),
        );
      },
    );
  }

  String _formatInboxTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return 'now';
  }
}

class _ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;
  const _ChatScreen({required this.otherUserId, required this.otherUsername});

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  MessageThread? _thread;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(() {
      final next = _controller.text.trim().isNotEmpty;
      if (next != _canSend) {
        setState(() {
          _canSend = next;
        });
      }
    });
  }

  Future<void> _load() async {
    final t = await GameLibraryService.getThread(widget.otherUserId);
    await GameLibraryService.markThreadRead(widget.otherUserId);
    setState(() {
      _thread = t;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await GameLibraryService.sendMessage(
        toUserId: widget.otherUserId,
        toUsername: widget.otherUsername,
        text: text,
      );
      await _load();
      // Show success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _thread?.messages ?? [];
    final bool canSend = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: AuthService.isUserOnline(widget.otherUserId),
          builder: (context, snapshot) {
            final online = snapshot.data == true;
            return Row(
              children: [
                Text(widget.otherUsername),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: online ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: online ? Colors.green : Colors.grey),
                  ),
                  child: Row(
                    children: [
                      Icon(online ? Icons.circle : Icons.circle_outlined, size: 10, color: online ? Colors.green : Colors.grey),
                      const SizedBox(width: 6),
                      Text(online ? 'Online' : 'Offline', style: TextStyle(color: online ? Colors.green : Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMeFuture = AuthService.getCurrentUser();
                return FutureBuilder(
                  future: isMeFuture,
                  builder: (context, snapshot) {
                    final meId = snapshot.data?.id;
                    final isMe = meId == m.fromUserId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primary : const Color(0xFF162447),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(color: isMe ? Colors.white : Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1530),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canSend ? _send : null,
                        customBorder: const CircleBorder(),
                        child: Opacity(
                          opacity: canSend ? 1.0 : 0.5,
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  final List<GameSession> sessions;

  const _SessionsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.games, size: 80, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No Active Sessions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Start a game session with friends',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(session: session);
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final GameSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF121E3D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getSessionIcon(session.type),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  session.gameTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${session.participants.length} players • ${_getSessionTypeText(session.type)}',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Started ${_formatDuration(DateTime.now().difference(session.startTime))} ago',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joining session...')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionDetailsScreen(session: session),
                    ),
                  );
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSessionIcon(SessionType type) {
    switch (type) {
      case SessionType.singleplayer:
        return Icons.person;
      case SessionType.multiplayer:
        return Icons.people;
      case SessionType.coOp:
        return Icons.group;
      case SessionType.competitive:
        return Icons.emoji_events;
    }
  }

  String _getSessionTypeText(SessionType type) {
    switch (type) {
      case SessionType.singleplayer:
        return 'Single Player';
      case SessionType.multiplayer:
        return 'Multiplayer';
      case SessionType.coOp:
        return 'Co-op';
      case SessionType.competitive:
        return 'Competitive';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

class _PendingRequestsTab extends StatelessWidget {
  final List<FriendRequest> requests;
  final VoidCallback onRefresh;

  const _PendingRequestsTab({
    required this.requests,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_disabled, size: 80, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No Pending Requests',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You have no pending friend requests',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _FriendRequestCard(
            request: request,
            onAccept: () => _acceptRequest(context, request.id),
            onDecline: () => _declineRequest(context, request.id),
          );
        },
      ),
    );
  }

  void _acceptRequest(BuildContext context, String requestId) async {
    try {
      await GameLibraryService.acceptFriendRequest(requestId);
      onRefresh(); // Refresh the data
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _declineRequest(BuildContext context, String requestId) async {
    try {
      await GameLibraryService.declineFriendRequest(requestId);
      onRefresh(); // Refresh the data
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FriendRequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF121E3D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(request.fromUsername[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fromUsername,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'wants to be your friend',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(request.sentAt),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
