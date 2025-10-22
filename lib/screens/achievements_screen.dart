import 'package:flutter/material.dart';
import '../models/user_data.dart';
import '../services/game_library_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<UserAchievement> _userAchievements = [];
  List<Achievement> _allAchievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    
    // Load user achievements
    final userAchievements = await GameLibraryService.getUserAchievements();
    
    // Load all available achievements
    final allAchievements = _getAllAchievements();
    
    setState(() {
      _userAchievements = userAchievements;
      _allAchievements = allAchievements;
      _isLoading = false;
    });
  }

  List<Achievement> _getAllAchievements() {
    return [
      Achievement(
        id: 'first_game',
        title: 'First Steps',
        description: 'Purchase your first game',
        iconUrl: '🎮',
        xpReward: 50,
        type: AchievementType.milestone,
        requirements: {'games_purchased': 1},
      ),
      Achievement(
        id: 'game_collector',
        title: 'Game Collector',
        description: 'Own 10 games in your library',
        iconUrl: '📚',
        xpReward: 100,
        type: AchievementType.collection,
        requirements: {'games_owned': 10},
      ),
      Achievement(
        id: 'social_butterfly',
        title: 'Social Butterfly',
        description: 'Add 5 friends',
        iconUrl: '👥',
        xpReward: 75,
        type: AchievementType.social,
        requirements: {'friends_count': 5},
      ),
      Achievement(
        id: 'reviewer',
        title: 'Critic',
        description: 'Write your first game review',
        iconUrl: '✍️',
        xpReward: 25,
        type: AchievementType.gaming,
        requirements: {'reviews_written': 1},
      ),
      Achievement(
        id: 'time_master',
        title: 'Time Master',
        description: 'Play games for 100 hours total',
        iconUrl: '⏰',
        xpReward: 200,
        type: AchievementType.gaming,
        requirements: {'total_playtime': 100},
      ),
      Achievement(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Purchase a game on release day',
        iconUrl: '🐦',
        xpReward: 150,
        type: AchievementType.special,
        requirements: {'day_one_purchase': 1},
        isSecret: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            onPressed: _loadAchievements,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildAchievementsList(),
    );
  }

  Widget _buildAchievementsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allAchievements.length,
      itemBuilder: (context, index) {
        final achievement = _allAchievements[index];
        final userAchievement = _userAchievements.firstWhere(
          (ua) => ua.achievementId == achievement.id,
          orElse: () => UserAchievement(
            achievementId: achievement.id,
            unlockedAt: DateTime.now(),
            progress: 0,
            isUnlocked: false,
          ),
        );
        
        return _AchievementCard(
          achievement: achievement,
          userAchievement: userAchievement,
          onTap: () => _showAchievementDetails(achievement, userAchievement),
        );
      },
    );
  }

  void _showAchievementDetails(Achievement achievement, UserAchievement userAchievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(achievement.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (userAchievement.isUnlocked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Unlocked ${_formatDate(userAchievement.unlockedAt)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Locked',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (achievement.isSecret) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'This is a secret achievement!',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('XP Reward: ${achievement.xpReward}'),
                Text('Type: ${achievement.type.name.toUpperCase()}'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement userAchievement;
  final VoidCallback onTap;

  const _AchievementCard({
    required this.achievement,
    required this.userAchievement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = userAchievement.isUnlocked;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isUnlocked ? const Color(0xFF1B5E20) : const Color(0xFF121E3D),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Achievement Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isUnlocked ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    achievement.iconUrl,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Achievement Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isUnlocked ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                        if (isUnlocked)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        if (achievement.isSecret && !isUnlocked)
                          const Icon(Icons.visibility_off, color: Colors.grey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white70 : Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${achievement.xpReward} XP',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (isUnlocked)
                          Text(
                            'Unlocked',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        else
                          Text(
                            'Locked',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
