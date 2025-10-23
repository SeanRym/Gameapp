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
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  @override
  void dispose() {
    // Clear any existing snackbars to prevent looping
    ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    
    // Load user achievements first
    final userAchievements = await GameLibraryService.getUserAchievements();
    
    // Load user profile for XP/level info
    final userProfile = await GameLibraryService.getUserProfile();
    
    // Load all available achievements
    final allAchievements = _getAllAchievements();
    
    setState(() {
      _userAchievements = userAchievements;
      _allAchievements = allAchievements;
      _userProfile = userProfile;
      _isLoading = false;
    });
  }

  Future<void> _forceCheckAchievements() async {
    setState(() => _isLoading = true);
    
    // Force check achievements
    final unlockedAchievements = await GameLibraryService.checkAndUnlockAchievements();
    
    // Show notification if any achievements were unlocked
    if (unlockedAchievements.isNotEmpty && mounted) {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show only one notification for all unlocked achievements
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${unlockedAchievements.length} achievement(s) unlocked!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted) {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No new achievements unlocked'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Reload achievements to update UI
    await _loadAchievements();
  }

  List<Achievement> _getAllAchievements() {
    return GameLibraryService.getAllAchievements();
  }

  Future<void> _showDebugInfo() async {
    final debugStats = await GameLibraryService.getDebugStats();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('User ID: ${debugStats['user_id'] ?? 'None'}'),
                Text('Level: ${debugStats['user_level'] ?? 0}'),
                Text('XP: ${debugStats['user_xp'] ?? 0}'),
                Text('Games in Library: ${debugStats['games_in_library'] ?? 0}'),
                Text('Friends: ${debugStats['friends_count'] ?? 0}'),
                Text('Reviews Written: ${debugStats['reviews_written'] ?? 0}'),
                Text('Total Playtime: ${debugStats['total_playtime'] ?? 0.0} hours'),
                const SizedBox(height: 16),
                const Text('Achievement Requirements:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('• First Steps: 1+ games'),
                const Text('• Game Collector: 10+ games'),
                const Text('• Library Master: 25+ games'),
                const Text('• Social Butterfly: 5+ friends'),
                const Text('• Social Networker: 10+ friends'),
                const Text('• Critic: 1+ reviews'),
                const Text('• Review Master: 10+ reviews'),
                const Text('• Time Master: 100+ hours'),
                const Text('• Dedicated Gamer: 500+ hours'),
                const Text('• Early Bird: 3+ games'),
              ],
            ),
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
  }

  Future<void> _forceUnlockLibrary() async {
    setState(() => _isLoading = true);
    
    // Force unlock library achievements
    await GameLibraryService.forceUnlockLibraryAchievements();
    
    if (mounted) {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Library achievements unlocked!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // Reload achievements to update UI
    await _loadAchievements();
  }

  Future<void> _forceUnlockAll() async {
    setState(() => _isLoading = true);
    
    // Force unlock all achievements
    await GameLibraryService.forceUnlockAllAchievements();
    
    if (mounted) {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All achievements unlocked!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // Reload achievements to update UI
    await _loadAchievements();
  }

  Future<void> _testGameCollector() async {
    setState(() => _isLoading = true);
    
    // Force unlock game_collector specifically
    await GameLibraryService.forceUnlockGameCollector();
    
    if (mounted) {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game Collector achievement force unlocked!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // Reload achievements to update UI
    await _loadAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            onPressed: _showDebugInfo,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Show debug info',
          ),
          IconButton(
            onPressed: _testGameCollector,
            icon: const Icon(Icons.sports_esports),
            tooltip: 'Test Game Collector unlock',
          ),
          IconButton(
            onPressed: _forceUnlockLibrary,
            icon: const Icon(Icons.library_books),
            tooltip: 'Force unlock library achievements',
          ),
          IconButton(
            onPressed: _forceUnlockAll,
            icon: const Icon(Icons.star),
            tooltip: 'Force unlock all achievements',
          ),
          IconButton(
            onPressed: _forceCheckAchievements,
            icon: const Icon(Icons.refresh),
            tooltip: 'Check for new achievements',
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
