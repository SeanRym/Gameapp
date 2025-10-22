import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'screens/game_library_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/social_screen.dart';
import 'screens/login_screen.dart';
import 'services/game_library_service.dart';
import 'services/auth_service.dart';
import 'models/user_data.dart';
import 'models/auth_user.dart';
import 'services/recommendation_service.dart';
import 'database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Helper function to find similar games based on tags overlap
List<GameItem> findSimilarGames(GameItem targetGame, int count) {
  final targetTags = Set.from(targetGame.tags.map((t) => t.toLowerCase()));
  
  // Only consider games that share at least one tag with the target game
  final allGames = [...mockGames, ...vrGames];
  final candidates = allGames.where((g) {
    if (g.id == targetGame.id) return false; // Exclude the same game
    return g.tags.any((tag) => targetTags.contains(tag.toLowerCase()));
  }).toList();
  
  if (candidates.isEmpty) {
    // Fallback: return popular games if no similar games found
    return allGames.where((g) => g.id != targetGame.id).take(count).toList();
  }
  
  // Score games based on tag overlap and other factors
  final scored = candidates.map((g) {
    final gameTags = Set.from(g.tags.map((t) => t.toLowerCase()));
    final sharedTags = targetTags.intersection(gameTags);
    final overlapCount = sharedTags.length;
    
    // Primary score: number of shared tags (most important)
    double score = overlapCount * 200.0;
    
    // Secondary score: percentage of shared tags relative to target game
    final tagMatchRatio = overlapCount / targetTags.length;
    score += tagMatchRatio * 100.0;
    
    // Tertiary score: popularity bonus (smaller impact)
    score += g.popularity * 0.5;
    
    // Price similarity bonus (very small impact)
    if (targetGame.price == g.price) {
      score += 10.0;
    }
    
    return (game: g, score: score);
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  
  return scored.map((e) => e.game).take(count).toList();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database factory for Windows
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize database and run migration
  await DatabaseHelper.database; // This initializes the database
  
  // Clear database to fix session_invites table issue
  await DatabaseHelper.clearDatabase();
  
  await GameLibraryService.migrateFromSharedPreferences();
  
  await AuthService.initializeDemoUser();
  runApp(const GameRecApp());
}

class GameRecApp extends StatelessWidget {
  const GameRecApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Royal/Galaxy blue palette
    const primary = Color(0xFF2A27F5); // requested accent
    const background = Color(0xFF0A1226); // deep royal backdrop
    const surface = Color(0xFF121E3D); // surface royal blue

    final baseTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surface,
        background: background,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A1226),
        elevation: 0,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Recommendation',
      theme: baseTheme,
      home: const AuthWrapper(),
    );
  }
}

// Authentication wrapper to handle login state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      final currentUser = await AuthService.getCurrentUser();
      
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _currentUser = currentUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors gracefully - default to logged out state
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _currentUser = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onLogout() async {
    await AuthService.logout();
    await _checkAuthState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1226),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A27F5)),
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return HomeScreen(
        currentUser: _currentUser,
        onLogout: _onLogout,
      );
    } else {
      return LoginScreen(
        onLoginSuccess: () async {
          await _checkAuthState();
        },
      );
    }
  }
}


String formatPhp(num usd) {
  const double phpPerUsd = 56.0; // display rate
  final double php = usd * phpPerUsd;
  return '₱${php.toStringAsFixed(0)}';
}

String priceLabel(num usd) {
  if (usd == 0) return 'FREE';
  return formatPhp(usd);
}

class HomeScreen extends StatefulWidget {
  final AuthUser? currentUser;
  final VoidCallback? onLogout;
  
  const HomeScreen({super.key, this.currentUser, this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();
  final List<String> _selectedTags = ['Action', 'RPG'];
  int _index = 0; // bottom nav
  int _topTab = 0; // 0 Browse, 1 Recommendations, 2 Categories

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset index when user login status changes
    if (oldWidget.currentUser != widget.currentUser) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _navigateToStore() {
    setState(() {
      _index = 1; // Store is at index 1
      _topTab = 0; // Make sure we're on Browse tab
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter games based on selected tags
    List<GameItem> getFilteredGames() {
      if (_selectedTags.isEmpty) {
        return mockGames;
      }
      
      return mockGames.where((game) {
        return _selectedTags.any((tag) => 
          game.tags.any((gameTag) => 
            gameTag.toLowerCase() == tag.toLowerCase()
          )
        );
      }).toList();
    }
    
    final filteredGames = getFilteredGames();
    
    // Create trending games from filtered list
    final trending = List.of(filteredGames.take(4))..sort((a, b) => b.popularity.compareTo(a.popularity));
    
    // Create top picks with specific games prioritized (from filtered list)
    var topPicks = <GameItem>[];
    
    // Add specific games first (if they match the filter)
    GameItem? findById(String id) {
      for (final g in filteredGames) { if (g.id == id) return g; }
      return null;
    }
    
    // Add Wuthering Waves if found
    final ww = findById('wuthering-waves');
    if (ww != null) topPicks.add(ww);
    
    // Add Dead by Daylight if found
    final dbd = findById('dbd');
    if (dbd != null) topPicks.add(dbd);
    
    // Add more games from filteredGames to fill up to 6
    for (final game in filteredGames) {
      if (topPicks.length >= 6) break;
      if (!topPicks.any((g) => g.id == game.id)) {
        topPicks.add(game);
      }
    }
    
    print('Selected tags: $_selectedTags');
    print('Filtered games length: ${filteredGames.length}');
    print('Final topPicks length: ${topPicks.length}');
    print('Trending length: ${trending.length}');

    // Create pages based on login status
    final pages = widget.currentUser != null 
        ? [
      _HomeFeed(
        search: _search,
        selectedTags: _selectedTags,
        onTagsChanged: () => setState(() {}),
        onSearchChanged: () => setState(() {}),
              topPicks: topPicks,
              trending: trending,
      ),
            _StoreFeed(items: trending),
GameLibraryScreen(onNavigateToStore: _navigateToStore),
      const AchievementsScreen(),
      const SocialScreen(),
            _ProfileScreen(
              currentUser: widget.currentUser,
              onLogout: widget.onLogout,
            ),
          ]
        : [
            _HomeFeed(
              search: _search,
              selectedTags: _selectedTags,
              onTagsChanged: () => setState(() {}),
              onSearchChanged: () => setState(() {}),
              topPicks: topPicks,
              trending: trending,
            ),
            _StoreFeed(items: trending),
            _ProfileScreen(
              currentUser: widget.currentUser,
              onLogout: widget.onLogout,
            ),
    ];

    final globalFiltered = _search.text.isEmpty
        ? null
        : mockGames
            .where((g) => g.title.toLowerCase().contains(_search.text.toLowerCase()))
            .toList();

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _TopNavBar(
          currentTab: _topTab,
          onTabSelected: (i) => setState(() => _topTab = i),
        ),
      ),
      drawer: const _MainDrawer(),
      body: globalFiltered != null
          ? _SearchResultsList(
              items: globalFiltered,
              searchController: _search,
              onSearchChanged: () => setState(() {}),
            )
          : (_topTab == 0
              ? pages[_index.clamp(0, pages.length - 1)]
              : _topTab == 1
                  ? _PersonalizedRecommendationsPane(onTapGame: (g) => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))))
                  : _NewsPane()),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _index.clamp(0, pages.length - 1),
        onTap: (i) {
          // If we're on Recommendations or News tab, switch to Browse first
          if (_topTab != 0) {
            setState(() {
              _topTab = 0; // Switch to Browse tab
              _index = i.clamp(0, pages.length - 1); // Then navigate to selected page
            });
          } else {
            setState(() => _index = i.clamp(0, pages.length - 1));
          }
        },
        isLoggedIn: widget.currentUser != null,
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentTab;
  final ValueChanged<int> onTabSelected;
  const _TopNavBar({
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
              const SizedBox(width: 6),
              _TabLink(text: 'Browse', active: currentTab == 0, onTap: () => onTabSelected(0)),
              _TabLink(text: 'Recommendations', active: currentTab == 1, onTap: () => onTabSelected(1)),
              _TabLink(text: 'News', active: currentTab == 2, onTap: () => onTabSelected(2)),
              const Spacer(),
              _InviteBell(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String text;
  const _NavLink({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

class _TabLink extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _TabLink({required this.text, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 2),
            Container(height: 2, width: 24, color: active ? Theme.of(context).colorScheme.primary : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

class _InviteBell extends StatefulWidget {
  @override
  State<_InviteBell> createState() => _InviteBellState();
}

class _InviteBellState extends State<_InviteBell> {
  List<GameInvite> _gameInvites = [];
  List<SessionInvite> _sessionInvites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gameInvites = await GameLibraryService.getInvites();
    final sessionInvites = await GameLibraryService.getSessionInvites();
    if (mounted) {
      setState(() {
        _gameInvites = gameInvites;
        _sessionInvites = sessionInvites;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadGameInvites = _gameInvites.where((i) => !i.read).length;
    final unreadSessionInvites = _sessionInvites.where((i) => !i.read).length;
    final totalUnread = unreadGameInvites + unreadSessionInvites;
    
    return GestureDetector(
      onTap: () async {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invites'),
            content: SizedBox(
              width: 320,
              child: _gameInvites.isEmpty && _sessionInvites.isEmpty
                  ? const Text('No invites')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game Invites Section
                        if (_gameInvites.isNotEmpty) ...[
                          const Text('Game Invites', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._gameInvites.map((i) => ListTile(
                            leading: const Icon(Icons.games),
                            title: Text('${i.fromUsername} invited you'),
                            subtitle: Text(i.gameTitle),
                            onTap: () async {
                              // Open per-invite actions
                              Navigator.pop(context);
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(i.gameTitle),
                                  content: Text('Invitation from ${i.fromUsername}'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        GameItem? game;
                                        if (i.gameId != null) {
                                          try { game = mockGames.firstWhere((g) => g.id == i.gameId); } catch (_) {}
                                        }
                                        game ??= mockGames.firstWhere(
                                          (g) => g.title.toLowerCase() == i.gameTitle.toLowerCase(),
                                          orElse: () => mockGames.firstWhere(
                                            (g) => g.title.toLowerCase().contains(i.gameTitle.toLowerCase()),
                                            orElse: () => mockGames.first,
                                          ),
                                        );
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailScreen(game: game!)));
                                      },
                                      child: const Text('View Game'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await GameLibraryService.acceptInvite(i.id);
                                        await _load();
                                      },
                                      child: const Text('Accept'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await GameLibraryService.declineInvite(i.id);
                                        await _load();
                                      },
                                      child: const Text('Decline'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )).toList(),
                          const SizedBox(height: 16),
                        ],
                        // Session Invites Section
                        if (_sessionInvites.isNotEmpty) ...[
                          const Text('Session Invites', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._sessionInvites.map((i) => ListTile(
                            leading: const Icon(Icons.group),
                            title: Text('${i.fromUsername} invited you to session'),
                            subtitle: Text('${i.sessionTitle} - ${i.gameTitle}'),
                            onTap: () async {
                              // Open per-invite actions
                              Navigator.pop(context);
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(i.sessionTitle),
                                  content: Text('Session invitation from ${i.fromUsername}\nGame: ${i.gameTitle}'),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await GameLibraryService.acceptSessionInvite(i.id);
                                        await _load();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Session invite accepted!'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Text('Accept'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await GameLibraryService.declineSessionInvite(i.id);
                                        await _load();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Session invite declined'),
                                            backgroundColor: Colors.orange,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Text('Decline'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )).toList(),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
        await GameLibraryService.markAllInvitesRead();
        await GameLibraryService.markAllSessionInvitesRead();
        await _load();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (totalUnread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$totalUnread', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}

class _WideSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _WideSearchBar({required this.controller, required this.onChanged});

  @override
  State<_WideSearchBar> createState() => _WideSearchBarState();
}

class _WideSearchBarState extends State<_WideSearchBar> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search the store',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isLoggedIn;
  const _GlassNavBar({required this.currentIndex, required this.onTap, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Define all possible items
    final allItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Store'),
      const BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: 'Library'),
      const BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Achievements'),
      const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    // Filter items based on login status
    final items = isLoggedIn 
        ? allItems 
        : [
            allItems[0], // Home
            allItems[1], // Store
            allItems[5], // Profile
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            backgroundColor: Colors.white10,
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
          ),
        ),
      ),
    );
  }
}

class CategoryPage extends StatelessWidget {
  final CategoryItem category;
  const CategoryPage({required this.category});

  @override
  Widget build(BuildContext context) {
    // Filter games that match this category's tags from all game lists
    final allGames = [...mockGames, ...mostPlayedGames, ...topSellersGames, ...vrGames];
    final categoryGames = allGames.where((game) {
      return game.tags.any((tag) => 
        category.tags.any((categoryTag) => 
          tag.toLowerCase() == categoryTag.toLowerCase()
        )
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.name} Games'),
        backgroundColor: category.accent,
        foregroundColor: Colors.white,
      ),
      body: categoryGames.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.games, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No games found in this category',
                    style: TextStyle(fontSize: 18, color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Category header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [category.accent, category.accent.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${categoryGames.length} games available',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Games grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75, // Increased to prevent overflow
                  ),
                  itemCount: categoryGames.length,
                  itemBuilder: (context, index) {
                    final game = categoryGames[index];
                    return _PressableScale(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(game: game),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: CachedNetworkImage(
                                  imageUrl: game.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => _ShimmerBox(color: game.color),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.games, color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: game.tags.take(2).map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            tag,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      priceLabel(game.price),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final List<GameItem> items;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  const _SearchResultsList({
    required this.items,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar showing current search
                TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search the store',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No games found',
                    style: TextStyle(fontSize: 18, color: Colors.white54),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try searching with different keywords',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search bar showing current search
              TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search the store',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final g = items[i];
              return _PressableScale(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(game: g),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
            borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: g.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (c, _) => _ShimmerBox(color: g.color),
                          errorWidget: (c, _, __) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: g.tags.take(3).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              priceLabel(g.price),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Optimized home feed with better performance
class _OptimizedHomeFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      children: [
        // Welcome Section
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A27F5), Color(0xFF1A1A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to Game Recommendation!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover your next favorite game',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // Featured Games Section
        _Section(
          title: 'Featured Games',
          child: _GameScroller(
            items: mockGames.take(3).toList(),
          ),
        ),
        
        // Categories Section
        _Section(
          title: 'Browse by Category',
          child: _CategoryCarousel(
            onSelect: (c) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryPage(category: c),
                ),
              );
            },
          ),
        ),
        
        // Quick Stats
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121E3D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCard(
                icon: Icons.videogame_asset,
                title: '${mockGames.length}',
                subtitle: 'Games',
              ),
              _StatCard(
                icon: Icons.category,
                title: '${categories.length}',
                subtitle: 'Categories',
              ),
              _StatCard(
                icon: Icons.people,
                title: '1.2K',
                subtitle: 'Users',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2A27F5), size: 32),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _HomeFeed extends StatelessWidget {
  final TextEditingController search;
  final List<String> selectedTags;
  final VoidCallback onTagsChanged;
  final VoidCallback onSearchChanged;
  final List<GameItem> topPicks;
  final List<GameItem> trending;
  const _HomeFeed({
    required this.search,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.onSearchChanged,
    required this.topPicks,
    required this.trending,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = search.text.isEmpty ? mockGames.take(6).toList() : mockGames.where((g) => g.title.toLowerCase().contains(search.text.toLowerCase())).take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _WideSearchBar(controller: search, onChanged: (_) => onSearchChanged()),
        ),
        const SizedBox(height: 8),
        _FeaturedStrip(items: mockGames.take(5).toList()),
        const SizedBox(height: 70),
        _TagFilterRow(
          tags: const ['Action', 'RPG', 'Strategy', 'Sports', 'Indie', 'Simulation'],
          selected: selectedTags,
          onToggle: (t, v) {
            if (v) { 
              selectedTags.add(t); 
            } else { 
              selectedTags.remove(t); 
            }
            onTagsChanged();
          },
        ),
        const SizedBox(height: 12),
        _Section(title: 'Top Picks', child: _GameScroller(items: topPicks)),
        _Section(title: 'Trending', child: _GameScroller(items: trending)),
        _Section(
          title: 'Browse by Category',
          child: _CategoryCarousel(onSelect: (c) { 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryPage(category: c),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        _Section(
          title: selectedTags.isEmpty 
              ? 'Recommended Games' 
              : '${selectedTags.first} Games',
          child: _GameGrid(items: filtered)
        ),
        const SizedBox(height: 16),
        _ThreeColumnPager(),
      ],
    );
  }
}

class _StoreFeed extends StatefulWidget {
  final List<GameItem> items;
  const _StoreFeed({required this.items});
  @override
  State<_StoreFeed> createState() => _StoreFeedState();
}

class _StoreFeedState extends State<_StoreFeed> {
  List<GameItem> _recommendations = [];
  bool _isLoadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final recommendations = await RecommendationService.getPersonalizedRecommendations();
      setState(() {
        _recommendations = recommendations;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      setState(() {
        _recommendations = [];
        _isLoadingRecommendations = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      children: [
        _FeaturedStrip(items: widget.items.take(5).toList()),
        const SizedBox(height: 24),
        _RecommendedForYouSection(
          recommendations: _recommendations,
          isLoading: _isLoadingRecommendations,
          onRefresh: _loadRecommendations,
        ),
        const SizedBox(height: 24),
        _PopularReleasesSection(items: newGames),
        const SizedBox(height: 24),
        _VirtualRealitySection(items: vrGames),
      ],
    );
  }
}

class _RecommendedForYouSection extends StatelessWidget {
  final List<GameItem> recommendations;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _RecommendedForYouSection({
    required this.recommendations,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Recommended for You',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh recommendations',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A27F5)),
              ),
            ),
          )
        else if (recommendations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.games_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recommendations available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some games to your library to get personalized recommendations!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final game = recommendations[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 12),
                  child: _GameCard(game: game),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PopularReleasesSection extends StatelessWidget {
  final List<GameItem> items;

  const _PopularReleasesSection({required this.items});

  @override
  Widget build(BuildContext context) {
    // Sort games by popularity for popular releases
    final sortedGames = List<GameItem>.from(items)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Popular New Releases',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedGames.length,
            itemBuilder: (context, index) {
              final game = sortedGames[index];
              return _GameCard(game: game);
            },
          ),
        ),
      ],
    );
  }
}

class _VirtualRealitySection extends StatelessWidget {
  final List<GameItem> items;

  const _VirtualRealitySection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Virtual Reality',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Navigate to VR category page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryPage(
                        category: CategoryItem(
                          name: 'Virtual Reality',
                          imageUrl: 'https://images.unsplash.com/photo-1592478411213-6153e4c4c8b8?w=500',
                          accent: Colors.purple,
                          tags: ['VR', 'Virtual Reality', 'Immersive'],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Browse All',
                  style: TextStyle(
                    color: Color(0xFF2A27F5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final game = items[index];
              return _GameCard(game: game);
            },
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameItem game;

  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    print('_GameCard building for: ${game.title}');
    final isFree = game.price == 0;
    
    return Container(
      width: 180,
      height: 280, // Increased height to accommodate content
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('Game tapped: ${game.title}');
            // Navigate to game detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameDetailScreen(game: game),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                Expanded(
                  flex: 4, // Increased flex to give more space to image
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: game.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.games, size: 50, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                // Content section - Use Expanded with proper constraints
                Expanded(
                  flex: 2, // Reduced flex but still flexible
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Text(
                          game.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12, // Slightly smaller font
                          ),
                        ),
                        const SizedBox(height: 3), // Reduced spacing
                        Expanded( // Wrap tags in Expanded to prevent overflow
                          child: Wrap(
                            spacing: 3, // Reduced spacing
                            runSpacing: 1, // Reduced run spacing
                            children: game.tags.take(2).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8, // Smaller font
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 3), // Reduced spacing
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                          decoration: BoxDecoration(
                            color: isFree ? Colors.green.shade600 : Colors.blueGrey.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isFree ? 'FREE' : '₱${game.price.toStringAsFixed(0)}', // Removed decimal places
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
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


class _PersonalizedRecommendationsPane extends StatefulWidget {
  final void Function(GameItem) onTapGame;
  const _PersonalizedRecommendationsPane({required this.onTapGame});
  @override
  State<_PersonalizedRecommendationsPane> createState() => _PersonalizedRecommendationsPaneState();
}

class _PersonalizedRecommendationsPaneState extends State<_PersonalizedRecommendationsPane> {
  List<GameItem> _recommendations = [];
  bool _isLoading = true;
  String _recommendationType = 'Based on your library';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    
    try {
      final recommendations = await RecommendationService.getPersonalizedRecommendations();
      final userLibrary = await GameLibraryService.getUserLibrary();
      
      setState(() {
        _recommendations = recommendations;
        _recommendationType = userLibrary.isEmpty 
            ? 'Popular games' 
            : 'Based on your library (${userLibrary.length} games)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _recommendations = [];
        _recommendationType = 'Popular games';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended for you',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recommendationType,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh recommendations',
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Recommendations grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A27F5)),
                    ),
                  )
                : _recommendations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.games_outlined,
                              size: 64,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recommendations available',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add some games to your library to get personalized recommendations!',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0, // Increased to prevent overflow
            ),
                        itemCount: _recommendations.length,
            itemBuilder: (_, i) {
                          final g = _recommendations[i];
              final isFree = g.price == 0;
              return GestureDetector(
                onTap: () => widget.onTapGame(g),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                                  Positioned.fill(
                                    child: CachedNetworkImage(
                                      imageUrl: g.imageUrl, 
                                      fit: BoxFit.cover, 
                                      errorWidget: (c, _, __) => Container(color: Colors.grey.shade800)
                                    )
                                  ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.75), Colors.black.withOpacity(0.1)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                        Text(
                                          g.title, 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis, 
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            fontSize: 14,
                                          )
                                        ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: -6,
                                    children: g.tags.take(2).map((t) => _Tag(text: t)).toList(),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isFree ? Colors.green.shade600 : Colors.blueGrey.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                              child: Text(
                                                isFree ? 'FREE' : priceLabel(g.price), 
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                )
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
              );
            },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesPane extends StatelessWidget {
  final void Function(String) onSelectTag;
  const _CategoriesPane({required this.onSelectTag});
  @override
  Widget build(BuildContext context) {
    final topGenres = ['Racing','MOBA','Rogue-likes & Rogue-lites','Esports','Third-person Shooter','Team-based'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        Text('Your top genres', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) => AspectRatio(
              aspectRatio: 16/9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: mockGames[i % mockGames.length].imageUrl, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(color: Colors.grey.shade800)),
                    Container(color: Colors.black.withOpacity(0.4)),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.white,
                        child: Text(topGenres[i], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: topGenres.length,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in ['Competitive','Free to Play','Online Co-op','PvP','Action RPG','Difficult','Co-op','Character Customization','Strategy','Fantasy','3D'])
              ActionChip(label: Text(tag), onPressed: () => onSelectTag(tag)),
          ],
        ),
      ],
    );
  }
}

class _NewsPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'title': 'Major Update Released',
        'subtitle': 'Patch notes, balance changes, and new features.',
        'image': mostPlayedGames.first.imageUrl,
        'body': 'A new version is live today with performance improvements, weapon tuning, and quality-of-life fixes. Read on for full patch notes including mode updates and bug fixes for popular maps. Competitive matchmaking has also received adjustments to improve fairness at all ranks.',
      },
      {
        'title': 'New Event Starts This Week',
        'subtitle': 'Earn rewards by completing limited-time quests.',
        'image': topSellersGames.first.imageUrl,
        'body': 'Log in this week to participate in a limited-time event featuring themed quests, free cosmetics, and bonus XP. Completing the event card will grant an exclusive banner and profile decorations. The store will rotate daily with discounted bundles.',
      },
      {
        'title': 'Creator Spotlight',
        'subtitle': 'Check out this week\'s featured community creations.',
        'image': mockGames.first.imageUrl,
        'body': 'This week we highlight outstanding community creations including custom maps, mod packs, and fan art. Support your favorite creators by following their pages and trying out their latest content in-game.',
      },
      {
        'title': 'New Game Announcement',
        'subtitle': 'Exciting new title coming to the platform next month.',
        'image': mockGames[1].imageUrl,
        'body': 'We\'re thrilled to announce the upcoming release of a highly anticipated game that will be available exclusively on our platform. Pre-orders are now open with exclusive bonuses including early access, special skins, and in-game currency. Stay tuned for more details and gameplay reveals.',
      },
      {
        'title': 'Community Tournament Results',
        'subtitle': 'Champions crowned in the latest competitive season.',
        'image': mostPlayedGames[1].imageUrl,
        'body': 'The latest community tournament has concluded with spectacular matches and incredible displays of skill. Congratulations to all participants and especially our champions who will receive exclusive rewards and recognition. The next tournament season begins in two weeks with even bigger prizes.',
      },
      {
        'title': 'Platform Maintenance Complete',
        'subtitle': 'Server improvements and new features are now live.',
        'image': topSellersGames[1].imageUrl,
        'body': 'Our scheduled maintenance has been completed successfully. The platform now features improved server stability, faster loading times, and new social features including enhanced friend systems and party chat improvements. All services are fully operational.',
      },
      {
        'title': 'Holiday Sale Event',
        'subtitle': 'Massive discounts on popular games and DLCs.',
        'image': mockGames[2].imageUrl,
        'body': 'Don\'t miss our biggest sale of the year! Enjoy up to 80% off on hundreds of games, including recent releases and classic titles. The sale includes special bundles, seasonal content, and exclusive deals that won\'t be available anywhere else. Sale ends this weekend.',
      },
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemBuilder: (_, i) {
        final it = items[i];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: it['image'] as String, width: 64, height: 64, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(width: 64, height: 64, color: Colors.grey.shade800)),
            ),
            title: Text(it['title'] as String),
            subtitle: Text(it['subtitle'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailsScreen(
                    title: it['title'] as String,
                    subtitle: it['subtitle'] as String,
                    imageUrl: it['image'] as String,
                    body: it['body'] as String,
                  ),
                ),
              );
            },
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length,
    );
  }
}

class NewsDetailsScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String body;
  const NewsDetailsScreen({required this.title, required this.subtitle, required this.imageUrl, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, height: 200, width: double.infinity, placeholder: (c, _) => Container(height: 200, color: Colors.black26)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeColumnPager extends StatefulWidget {
  @override
  State<_ThreeColumnPager> createState() => _ThreeColumnPagerState();
}

class _ThreeColumnPagerState extends State<_ThreeColumnPager> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _MiniListSection(title: 'Top Sellers', items: topSellersGames),
      _MiniListSection(title: 'Most Played', items: mostPlayedGames),
      _MiniListSection(title: 'Top Upcoming Wishlisted', items: mockGames.take(5).toList(), comingSoon: true),
    ];
    return Column(
      children: [
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: pages.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: pages[i],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DotsIndicator(currentIndex: _index, length: pages.length),
      ],
    );
  }
}

class _MiniListSection extends StatelessWidget {
  final String title;
  final List<GameItem> items;
  final bool comingSoon;
  const _MiniListSection({required this.title, required this.items, this.comingSoon = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        ...items.take(6).map((g) => ListTile(
              dense: true,
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: g.imageUrl, width: 52, height: 52, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(width: 52, height: 52, color: Colors.grey.shade800))),
              title: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: comingSoon && g.price > 0 ? const Text('Coming Soon') : Text(priceLabel(g.price)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
            )),
      ],
    );
  }
}

class _AnimatedHeader extends StatefulWidget {
  const _AnimatedHeader();
  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 120,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + 2 * t, -1),
                    end: Alignment(1 - 2 * t, 1),
                    colors: const [Color(0xFF263238), Color(0xFF1B5E20), Color(0xFF0D47A1)],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Discover your next game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TopNavButton extends StatelessWidget {
  final String label;
  const _TopNavButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}


class _RecommendationsSection extends StatefulWidget {
  @override
  State<_RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<_RecommendationsSection> {
  final List<String> _selected = ['Action', 'RPG'];

  @override
  Widget build(BuildContext context) {
    final games = recommendGames(_selected, max: 10);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recommended For You', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in ['Action','RPG','Strategy','Sports','Indie'])
                    FilterChip(
                      label: Text(tag),
                      selected: _selected.contains(tag),
                      onSelected: (v) => setState(() {
                        if (v) { _selected.add(tag); } else { _selected.remove(tag); }
                      }),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) => _GameCard(game: games[i]),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: games.length,
            ),
          ),
        ],
      ),
    );
  }
}


class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableScale({required this.child, this.onTap});
  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final Color color;
  const _ShimmerBox({required this.color});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [
                widget.color.withOpacity(0.25),
                widget.color.withOpacity(0.45),
                widget.color.withOpacity(0.25),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GameDetailsScreen extends StatefulWidget {
  final GameItem game;
  const GameDetailsScreen({required this.game});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _isInLibrary = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLibraryStatus();
  }

  Future<void> _checkLibraryStatus() async {
    final library = await GameLibraryService.getUserLibrary();
    setState(() {
      _isInLibrary = library.any((game) => game.gameId == widget.game.id);
    });
  }

  Future<void> _purchaseGame() async {
    setState(() => _isLoading = true);
    
    try {
      await GameLibraryService.addGameToLibrary(widget.game.id, widget.game.price);
      setState(() {
        _isInLibrary = true;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.game.title} added to your library!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.title),
        actions: [
          if (_isInLibrary)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameLibraryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.videogame_asset),
            ),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16/9,
            child: CachedNetworkImage(
              imageUrl: widget.game.imageUrl, 
              fit: BoxFit.cover, 
              placeholder: (c, _) => _ShimmerBox(color: widget.game.color)
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, children: widget.game.tags.map((t) => _Tag(text: t)).toList()),
                const SizedBox(height: 12),
                Text(widget.game.description),
                const SizedBox(height: 16),
                Row(children: [
                  Text(priceLabel(widget.game.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_isInLibrary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('In Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _purchaseGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add to Library'),
                    ),
                ]),
                const SizedBox(height: 12),
                // Reviews Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      print('Reviews button pressed for game: ${widget.game.id}');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameReviewsScreen(gameId: widget.game.id, gameTitle: widget.game.title),
                        ),
                      );
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('Reviews'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Additional game info
                _buildGameInfo(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Screenshots', style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(imageUrl: widget.game.screenshots[i], width: 260, height: 160, fit: BoxFit.cover, placeholder: (c, _) => _ShimmerBox(color: widget.game.color)),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: widget.game.screenshots.length,
            ),
          ),
          const SizedBox(height: 24),
          // Similar Games Section
          _buildSimilarGames(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121E3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(
                icon: Icons.star,
                label: 'Rating',
                value: '${widget.game.popularity}/10',
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.category,
                label: 'Genre',
                value: widget.game.tags.first,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(
                icon: Icons.access_time,
                label: 'Release',
                value: '2024',
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.language,
                label: 'Language',
                value: 'English',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarGames() {
    // Find similar games based on shared tags
    final similarGames = mockGames.where((game) {
      if (game.id == widget.game.id) return false; // Exclude current game
      
      // Count shared tags
      final sharedTags = game.tags.where((tag) => 
        widget.game.tags.any((currentTag) => 
          currentTag.toLowerCase() == tag.toLowerCase()
        )
      ).length;
      
      return sharedTags > 0; // Include games with at least one shared tag
    }).toList();
    
    // Sort by number of shared tags and popularity
    similarGames.sort((a, b) {
      final aSharedTags = a.tags.where((tag) => 
        widget.game.tags.any((currentTag) => 
          currentTag.toLowerCase() == tag.toLowerCase()
        )
      ).length;
      final bSharedTags = b.tags.where((tag) => 
        widget.game.tags.any((currentTag) => 
          currentTag.toLowerCase() == tag.toLowerCase()
        )
      ).length;
      
      if (aSharedTags != bSharedTags) {
        return bSharedTags.compareTo(aSharedTags); // More shared tags first
      }
      return b.popularity.compareTo(a.popularity); // Higher popularity first
    });
    
    // Take only the top 4 similar games
    final topSimilarGames = similarGames.take(4).toList();
    
    if (topSimilarGames.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Similar Games',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final game = topSimilarGames[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailScreen(game: game),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF1E2A44),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: game.imageUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _ShimmerBox(color: game.color),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              priceLabel(game.price),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: game.tags.take(2).map((tag) => 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: topSimilarGames.length,
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
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
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final String label;
  const _Link({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Colors.white70,
          ),
    );
  }
}

class _BrowseRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CategoryTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FeaturedCarousel extends StatelessWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  const _FeaturedCarousel({required this.controller, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    final features = List.generate(5, (i) => i);
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: controller,
        onPageChanged: onPageChanged,
        itemCount: features.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _FeatureCard(index: index),
          );
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final int index;
  const _FeatureCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.blueGrey,
      Colors.deepOrange,
      Colors.blue,
      Colors.purple,
      Colors.green,
    ];
    final bg = colors[index % colors.length];
    return Container(
      decoration: BoxDecoration(
        color: bg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.45)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Tag(text: 'FEATURED'),
                    const SizedBox(width: 8),
                    _Tag(text: 'ACTION'),
                  ],
                ),
                const Spacer(),
            Text(
                  'Amazing Game ${index + 1}',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('-20%'),
                    ),
                    const SizedBox(width: 8),
                    Text(priceLabel(39.99), style: Theme.of(context).textTheme.titleMedium!.copyWith(decoration: TextDecoration.lineThrough, color: Colors.white70)),
                    const SizedBox(width: 8),
                    Text(priceLabel(31.99), style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int length;
  const _DotsIndicator({required this.currentIndex, required this.length});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search games',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _TagFilterRow extends StatelessWidget {
  final List<String> tags;
  final List<String> selected;
  final void Function(String, bool) onToggle;
  const _TagFilterRow({required this.tags, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    color: selected.contains(tag) ? Colors.black : Colors.white,
                    fontWeight: selected.contains(tag) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selected.contains(tag),
                onSelected: (v) => onToggle(tag, v),
                showCheckmark: false,
                backgroundColor: const Color(0xFF2A2A2A),
                selectedColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected.contains(tag) ? const Color(0xFF4CAF50) : const Color(0xFF666666),
                    width: 1.5,
                  ),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GameScroller extends StatelessWidget {
  final List<GameItem> items;
  const _GameScroller({required this.items});

  @override
  Widget build(BuildContext context) {
    print('_GameScroller: items.length = ${items.length}');
    if (items.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No games available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) => _GameCard(
          game: items[i],
        ),
        itemCount: items.length,
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  final List<GameItem> items;
  const _GameGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75, // Increased to accommodate content better
        ),
        itemBuilder: (_, i) => _GameCard(
          game: items[i],
        ),
      ),
    );
  }
}

class _MainDrawer extends StatelessWidget {
  const _MainDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Support'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const _SupportScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  final AuthUser? currentUser;
  final VoidCallback? onLogout;
  
  const _ProfileScreen({this.currentUser, this.onLogout});
  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  XFile? _avatar;
  final ImagePicker _picker = ImagePicker();
  int _libraryCount = 0;
  int _friendsCount = 0;
  int _achievementsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final library = await GameLibraryService.getUserLibrary();
    final friends = await GameLibraryService.getFriends();
    final achievements = await GameLibraryService.getUserAchievements();
    
    setState(() {
      _libraryCount = library.length;
      _friendsCount = friends.length;
      _achievementsCount = achievements.length;
    });
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() => _avatar = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is not logged in, show login screen
    if (widget.currentUser == null) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.white38,
              ),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(
                              onLoginSuccess: () {
                                Navigator.pop(context);
                                // The AuthWrapper will handle the state update
                              },
                            ),
                          ),
                        );
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A27F5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accent = const LinearGradient(colors: [Color(0xFF123865), Color(0xFF0E2A4A)]);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLogout?.call();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _avatar != null
                        ? Image.file(
                            File(_avatar!.path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.white12,
                            child: const Icon(Icons.person, size: 40),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
        child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentUser!.username,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.currentUser!.email,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Level ${widget.currentUser!.level}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<bool>(
                            stream: Stream.periodic(const Duration(seconds: 2))
                                .asyncMap((_) => AuthService.isUserOnline(widget.currentUser!.id)),
                            initialData: false,
                            builder: (context, snapshot) {
                              final online = snapshot.data == true;
                              return Container(
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
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats Grid
          _ProfileStatsGrid(
            libraryCount: _libraryCount,
            friendsCount: _friendsCount,
            achievementsCount: _achievementsCount,
          ),
          const SizedBox(height: 20),
          // Quick Actions
          _QuickActionsSection(),
        ],
      ),
    );
  }
}

class _ProfileStatsGrid extends StatelessWidget {
  final int libraryCount;
  final int friendsCount;
  final int achievementsCount;

  const _ProfileStatsGrid({
    required this.libraryCount,
    required this.friendsCount,
    required this.achievementsCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (_, i) {
        final stats = [
          _StatData('Games', libraryCount.toString(), Icons.videogame_asset, Colors.blue),
          _StatData('Friends', friendsCount.toString(), Icons.people, Colors.green),
          _StatData('Achievements', achievementsCount.toString(), Icons.emoji_events, Colors.orange),
        ];
        final stat = stats[i];
        
        return GestureDetector(
          onTap: () {
            switch (i) {
              case 0:
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLibraryScreen()));
                break;
              case 1:
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialScreen()));
                break;
              case 2:
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
                break;
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E2A4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stat.color.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Icon(stat.icon, color: stat.color, size: 28),
                const SizedBox(height: 6),
                Text(stat.count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stat.color)),
                const SizedBox(height: 2),
                Text(stat.title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E2A4A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white70),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings coming soon!')),
                  );
                },
              ),
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.white70),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const _SupportScreen()));
                },
              ),
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Sala\'s Mobile App',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.games, size: 48),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatData {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  _StatData(this.title, this.count, this.icon, this.color);
}


class _SupportScreen extends StatelessWidget {
  const _SupportScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.help_outline), title: Text('FAQ')),
          ListTile(leading: Icon(Icons.bug_report_outlined), title: Text('Report a problem')),
          ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy & Safety')),
          ListTile(leading: Icon(Icons.mail_outline), title: Text('Contact support')),
        ],
      ),
    );
  }
}

class _CategoryCarousel extends StatefulWidget {
  final void Function(CategoryItem) onSelect;
  const _CategoryCarousel({required this.onSelect});

  @override
  State<_CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<_CategoryCarousel> {
  int _index = 0;
  final PageController _controller = PageController(viewportFraction: 0.6);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final c = categories[i];
              final active = i == _index;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.symmetric(horizontal: active ? 4 : 8, vertical: active ? 0 : 4),
                child: GestureDetector(
                  onTap: () => widget.onSelect(c),
                  child: _CategoryTile(cat: c, active: active),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(categories.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 14 : 6,
              height: 6,
              decoration: BoxDecoration(color: active ? categories[i].accent : Colors.white24, borderRadius: BorderRadius.circular(4)),
            );
          }),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryItem cat;
  final bool active;
  const _CategoryTile({required this.cat, required this.active});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: cat.imageUrl, fit: BoxFit.cover, placeholder: (c, _) => _ShimmerBox(color: cat.accent)),
          Container(color: Colors.black.withOpacity(active ? 0.25 : 0.45)),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text(cat.name.toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedStrip extends StatefulWidget {
  final List<GameItem> items;
  const _FeaturedStrip({required this.items});

  @override
  State<_FeaturedStrip> createState() => _FeaturedStripState();
}

class _FeaturedStripState extends State<_FeaturedStrip> {
  final PageController _controller = PageController(viewportFraction: 0.80);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final g = widget.items[i];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double value = 1.0;
                  if (_controller.position.haveDimensions) {
                    value = 1 - ((_controller.page ?? _controller.initialPage) - i).abs() * 0.1;
                  }
                  return Transform.scale(scale: value.clamp(0.9, 1.0), child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _FeaturedCard(game: g),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 18 : 6,
              decoration: BoxDecoration(color: active ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(4)),
            );
          }),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final GameItem game;
  const _FeaturedCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameDetailsScreen(game: game),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: game.imageUrl,
                fit: BoxFit.cover,
                placeholder: (c, _) => _ShimmerBox(color: game.color),
                errorWidget: (c, _, __) => Container(color: Colors.grey.shade800),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.0)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, children: game.tags.take(2).map((t) => _Tag(text: t)).toList()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)),
                      child: Text(priceLabel(game.price), style: const TextStyle(fontWeight: FontWeight.w800)),
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
}

class GameReviewsScreen extends StatefulWidget {
  final String gameId;
  final String gameTitle;
  
  const GameReviewsScreen({
    required this.gameId,
    required this.gameTitle,
  });

  @override
  State<GameReviewsScreen> createState() => _GameReviewsScreenState();
}

class _GameReviewsScreenState extends State<GameReviewsScreen> {
  List<GameReview> _reviews = [];
  bool _isLoading = true;
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final reviews = await GameLibraryService.getGameReviews(widget.gameId);
      print('Loaded ${reviews.length} reviews for game ${widget.gameId}');
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty || _userRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide both a rating and review text')),
      );
      return;
    }

    // Get current user info
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to submit a review')),
      );
      return;
    }

    final review = GameReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      gameId: widget.gameId,
      userId: currentUser.id,
      username: currentUser.username,
      avatarUrl: '',
      rating: _userRating,
      title: 'Review',
      content: _reviewController.text.trim(),
      createdAt: DateTime.now(),
      helpfulVotes: 0,
      isVerified: false,
      tags: [],
    );

    try {
      await GameLibraryService.addGameReview(review);
      print('Review submitted successfully for game ${widget.gameId}');
      _reviewController.clear();
      _userRating = 0.0;
      _loadReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
    } catch (e) {
      print('Error submitting review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building GameReviewsScreen for game: ${widget.gameId} (${widget.gameTitle})');
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gameTitle} Reviews'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add Review Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2A4A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Write a Review',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // Rating
                      Row(
                        children: [
                          const Text('Rating: '),
                          ...List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _userRating = (index + 1).toDouble();
                                });
                              },
                              child: Icon(
                                index < _userRating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 24,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Review Text
                      TextField(
                        controller: _reviewController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Write your review here...',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitReview,
                          child: const Text('Submit Review'),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                // Reviews List
                Expanded(
                  child: _reviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No reviews yet.\nBe the first to review this game!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Game ID: ${widget.gameId}',
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${_reviews.length} Review${_reviews.length == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: const Color(0xFF0E2A4A),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          child: Text(review.username[0].toUpperCase()),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                review.username,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(5, (starIndex) {
                                            return Icon(
                                              starIndex < review.rating ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(review.content),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            // TODO: Implement helpful functionality
                                          },
                                          icon: const Icon(Icons.thumb_up_outlined, size: 16),
                                        ),
                                        Text('${review.helpfulVotes} helpful'),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            // TODO: Implement report functionality
                                          },
                                          child: const Text('Report'),
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
                            ],
                          ),
                ),
              ],
      ),
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  final GameItem game;

  const GameDetailScreen({super.key, required this.game});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  bool _isInLibrary = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLibraryStatus();
  }

  Future<void> _checkLibraryStatus() async {
    final library = await GameLibraryService.getUserLibrary();
    setState(() {
      _isInLibrary = library.any((game) => game.gameId == widget.game.id);
    });
  }

  Future<void> _toggleLibrary() async {
    setState(() => _isLoading = true);
    
    try {
      if (_isInLibrary) {
        await GameLibraryService.removeGameFromLibrary(widget.game.id);
        setState(() => _isInLibrary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.game.title} removed from library'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        await GameLibraryService.addGameToLibrary(
          widget.game.id,
          widget.game.price
        );
        setState(() => _isInLibrary = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.game.title} added to library!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showReviews() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameReviewsScreen(
            gameId: widget.game.id,
            gameTitle: widget.game.title,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open reviews: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.game.price == 0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A1226),
      body: CustomScrollView(
        slivers: [
          // App Bar with back button
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.game.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  // Show more options
                },
              ),
            ],
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  CachedNetworkImage(
                    imageUrl: widget.game.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.games, size: 100, color: Colors.white38),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.game.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.5)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    widget.game.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Price and Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Text(
                        isFree ? 'FREE' : '₱${widget.game.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isFree ? Colors.green : Colors.blue,
                        ),
                      ),
                      // In Library Button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _toggleLibrary,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(_isInLibrary ? Icons.check : Icons.add),
                        label: Text(_isInLibrary ? 'In Library' : 'Add to Library'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isInLibrary ? Colors.green : const Color(0xFF2A27F5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Reviews Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showReviews,
                      icon: const Icon(Icons.star, color: Color(0xFF2A27F5), size: 20),
                      label: const Text(
                        'Reviews',
                        style: TextStyle(
                          color: Color(0xFF2A27F5),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Game Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Game Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Rating
                        _InfoRow(
                          icon: Icons.star,
                          label: 'Rating',
                          value: '${widget.game.popularity}/10',
                        ),
                        const SizedBox(height: 12),
                        
                        // Genre
                        _InfoRow(
                          icon: Icons.category,
                          label: 'Genre',
                          value: widget.game.tags.isNotEmpty ? widget.game.tags.first : 'Unknown',
                        ),
                        const SizedBox(height: 12),
                        
                        // Release
                        _InfoRow(
                          icon: Icons.access_time,
                          label: 'Release',
                          value: '2024',
                        ),
                        const SizedBox(height: 12),
                        
                        // Language
                        _InfoRow(
                          icon: Icons.language,
                          label: 'Language',
                          value: 'English',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Screenshots Section
                  const Text(
                    'Screenshots',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Screenshots Grid
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.game.screenshots.isNotEmpty ? widget.game.screenshots.length : 1,
                      itemBuilder: (context, index) {
                        final screenshotUrl = widget.game.screenshots.isNotEmpty 
                            ? widget.game.screenshots[index] 
                            : widget.game.imageUrl;
                        
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: screenshotUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.image, color: Colors.white38),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Similar Games Section
                  const Text(
                    'Similar Games',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Similar Games ListView (horizontal)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        final candidates = findSimilarGames(widget.game, 6);
                        if (index >= candidates.length) return const SizedBox.shrink();
                        final game = candidates[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GameDetailScreen(game: game),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 160,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2A44),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Game Image
                                      Expanded(
                                        flex: 3,
                                        child: CachedNetworkImage(
                                          imageUrl: game.imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey.shade800,
                                            child: const Icon(Icons.games, size: 40, color: Colors.white38),
                                          ),
                                        ),
                                      ),
                                      // Game Info
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                game.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                game.price == 0 ? 'FREE' : '₱${game.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: game.price == 0 ? Colors.green : Colors.blue,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 2,
                                                  runSpacing: 1,
                                                  children: game.tags.take(2).map((tag) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontSize: 7,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  )).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 100), // Bottom padding for navigation
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const Spacer(),
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
}
