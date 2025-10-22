import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_data.dart';
import '../data.dart';
import '../services/game_library_service.dart';
import '../services/auth_service.dart';

class SessionDetailsScreen extends StatelessWidget {
  final GameSession session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.gameTitle),
        backgroundColor: const Color(0xFF1E2A44),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1419),
              Color(0xFF1E2A44),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Header Card
              _buildGameHeaderCard(),
              const SizedBox(height: 20),
              
              // Session Info Card
              _buildSessionInfoCard(),
              const SizedBox(height: 20),
              
              // Players Card
              _buildPlayersCard(),
              const SizedBox(height: 20),
              
              // Actions Card
              _buildActionsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameHeaderCard() {
    // Find the game in our mock data
    GameItem? game;
    try {
      game = mockGames.firstWhere((g) => g.id == session.gameId);
    } catch (e) {
      // If not found in mockGames, try other lists
      try {
        game = mostPlayedGames.firstWhere((g) => g.id == session.gameId);
      } catch (e) {
        try {
          game = topSellersGames.firstWhere((g) => g.id == session.gameId);
        } catch (e) {
          // Game not found, use default
        }
      }
    }

    return Card(
      color: const Color(0xFF121E3D),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: game != null ? DecorationImage(
            image: CachedNetworkImageProvider(game.imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ) : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                session.gameTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  'ACTIVE SESSION',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final duration = DateTime.now().difference(session.startTime);
    
    return Card(
      color: const Color(0xFF121E3D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Duration',
              value: _formatDuration(duration),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.people,
              label: 'Players',
              value: '${session.participants.length} players',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: _getSessionIcon(session.type),
              label: 'Type',
              value: _getSessionTypeText(session.type),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Started',
              value: _formatDateTime(session.startTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersCard() {
    return Card(
      color: const Color(0xFF121E3D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Players in Session',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...session.participants.map((participantId) => _buildPlayerTile(participantId)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTile(String participantId) {
    // Mock player data - in a real app, you'd fetch this from a service
    final playerNames = {
      'user1': 'GamerPro123',
      'user2': 'GameMaster',
      'user3': 'PlayerOne',
      'user4': 'EpicGamer',
      'user5': 'GameDev',
    };
    
    final playerName = playerNames[participantId] ?? 'Player $participantId';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(playerName[0].toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'In Game',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    return Card(
      color: const Color(0xFF121E3D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Joining session...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Join Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showInviteFriendsDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Friends'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _SessionChatScreen(sessionId: session.id, sessionTitle: session.gameTitle),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Open Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  String _formatDateTime(DateTime dateTime) {
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

  void _showInviteFriendsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Friend>>(
        future: GameLibraryService.getFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              title: Text('Invite Friends'),
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final friends = snapshot.data ?? [];
          if (friends.isEmpty) {
            return AlertDialog(
              title: const Text('Invite Friends'),
              content: const Text('You don\'t have any friends to invite.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text('Invite Friends to ${session.gameTitle}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(friend.avatarUrl),
                    ),
                    title: Text(friend.username),
                    subtitle: Text(friend.isOnline ? 'Online' : 'Offline'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        try {
                          await GameLibraryService.sendSessionInvite(
                            toUserId: friend.id,
                            sessionId: session.id,
                            sessionTitle: session.gameTitle,
                            gameTitle: session.gameTitle,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Session invite sent to ${friend.username}!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error sending invite: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Invite'),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionChatScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  const _SessionChatScreen({required this.sessionId, required this.sessionTitle});

  @override
  State<_SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<_SessionChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SessionChatMessage> _messages = [];
  String? _currentUserId;
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
    final msgs = await GameLibraryService.getSessionChat(widget.sessionId);
    final me = await AuthService.getCurrentUser();
    setState(() {
      _messages = msgs;
      _currentUserId = me?.id;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await GameLibraryService.sendSessionChatMessage(widget.sessionId, text);
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
    final messages = _messages;
    final bool canSend = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sessionTitle} Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMe = _currentUserId != null && m.fromUserId == _currentUserId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Theme.of(context).colorScheme.primary : const Color(0xFF162447),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(m.fromUsername, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          ),
                        Text(
                          m.text,
                          style: TextStyle(color: isMe ? Colors.white : Colors.white),
                        ),
                      ],
                    ),
                  ),
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
                        decoration: const InputDecoration(
                          hintText: 'Message session...',
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
