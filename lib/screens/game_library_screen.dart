import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_data.dart';
import '../services/game_library_service.dart';
import '../main.dart';

class GameLibraryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToStore;
  
  const GameLibraryScreen({super.key, this.onNavigateToStore});

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen> {
  List<LibraryGame> _libraryGames = [];
  bool _isLoading = true;
  String _filter = 'All'; // All, Installed, Favorites, Recently Played

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if not currently loading to avoid infinite loops
    if (!_isLoading) {
      _loadLibrary();
    }
  }

  Future<void> _loadLibrary() async {
    print('DEBUG: Loading library in GameLibraryScreen');
    setState(() => _isLoading = true);
    final library = await GameLibraryService.getUserLibrary();
    print('DEBUG: Library screen received ${library.length} games');
    setState(() {
      _libraryGames = library;
      _isLoading = false;
    });
    print('DEBUG: Library screen state updated with ${_libraryGames.length} games');
  }

  List<LibraryGame> get _filteredGames {
    switch (_filter) {
      case 'Installed':
        return _libraryGames.where((game) => game.isInstalled).toList();
      case 'Favorites':
        return _libraryGames.where((game) => game.isFavorite).toList();
      case 'Recently Played':
        return _libraryGames.where((game) => game.lastPlayed != null).toList()
          ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
      default:
        return _libraryGames;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            onPressed: _loadLibrary,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Library',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Games')),
              const PopupMenuItem(value: 'Installed', child: Text('Installed')),
              const PopupMenuItem(value: 'Favorites', child: Text('Favorites')),
              const PopupMenuItem(value: 'Recently Played', child: Text('Recently Played')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_filter),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLibrary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredGames.isEmpty
                ? _EmptyLibraryView(onNavigateToStore: widget.onNavigateToStore)
                : _LibraryGridView(games: _filteredGames, onGameTap: _onGameTap),
      ),
    );
  }

  void _onGameTap(LibraryGame game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameLibraryDetailsScreen(game: game),
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  final VoidCallback? onNavigateToStore;
  
  const _EmptyLibraryView({this.onNavigateToStore});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videogame_asset_outlined,
            size: 80,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start building your collection by purchasing games',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (onNavigateToStore != null) {
                onNavigateToStore!();
              } else {
                // Fallback: just pop if no callback is provided
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.storefront),
            label: const Text('Browse Store'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGridView extends StatelessWidget {
  final List<LibraryGame> games;
  final Function(LibraryGame) onGameTap;

  const _LibraryGridView({
    required this.games,
    required this.onGameTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _LibraryGameCard(
          game: game,
          onTap: () => onGameTap(game),
        );
      },
    );
  }
}

class _LibraryGameCard extends StatelessWidget {
  final LibraryGame game;
  final VoidCallback onTap;

  const _LibraryGameCard({
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF121E3D),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: game.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.videogame_asset, size: 40),
                      ),
                    ),
                  ),
                  // Status badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
                        if (game.isInstalled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INSTALLED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (game.isFavorite) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.favorite, color: Colors.red, size: 16),
                        ],
                      ],
                    ),
                  ),
                  // Playtime overlay
                  if (game.playtimeHours > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${game.playtimeHours}h',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Game Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${game.version}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (game.userRating > 0) ...[
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            game.userRating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const Spacer(),
                        if (game.lastPlayed != null)
                          Text(
                            _formatLastPlayed(game.lastPlayed!),
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastPlayed(DateTime lastPlayed) {
    final now = DateTime.now();
    final difference = now.difference(lastPlayed);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}

class GameLibraryDetailsScreen extends StatefulWidget {
  final LibraryGame game;

  const GameLibraryDetailsScreen({super.key, required this.game});

  @override
  State<GameLibraryDetailsScreen> createState() => _GameLibraryDetailsScreenState();
}

class _GameLibraryDetailsScreenState extends State<GameLibraryDetailsScreen> {
  late LibraryGame _game;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isLoading = true);
    await GameLibraryService.toggleFavorite(_game.gameId);
    await _refreshGame();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshGame() async {
    final library = await GameLibraryService.getUserLibrary();
    final updatedGame = library.firstWhere((g) => g.gameId == _game.gameId);
    setState(() => _game = updatedGame);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_game.title),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _toggleFavorite,
            icon: Icon(
              _game.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _game.isFavorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Header
            Container(
              height: 200,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: _game.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.videogame_asset, size: 60),
                ),
              ),
            ),
            // Game Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _game.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _game.isInstalled ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _game.isInstalled ? 'INSTALLED' : 'NOT INSTALLED',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Version ${_game.version}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121E3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatItem(
                icon: Icons.access_time,
                label: 'Playtime',
                value: '${_game.playtimeHours}h',
              ),
              const SizedBox(width: 24),
              _StatItem(
                icon: Icons.calendar_today,
                label: 'Purchased',
                value: _formatDate(_game.purchaseDate),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                icon: Icons.attach_money,
                label: 'Price Paid',
                value: '₱${(_game.pricePaid * 56).toStringAsFixed(0)}',
              ),
              const SizedBox(width: 24),
              _StatItem(
                icon: Icons.star,
                label: 'Your Rating',
                value: _game.userRating > 0 ? '${_game.userRating}/5' : 'Not rated',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _game.isInstalled ? _launchGame : _installGame,
            icon: Icon(_game.isInstalled ? Icons.play_arrow : Icons.download),
            label: Text(_game.isInstalled ? 'Play' : 'Install'),
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
            onPressed: _openReviews,
            icon: const Icon(Icons.rate_review),
            label: const Text('Reviews'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _launchGame() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Launching game...')),
    );
  }

  void _installGame() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting installation...')),
    );
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameReviewsScreen(gameId: _game.gameId, gameTitle: _game.title),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

