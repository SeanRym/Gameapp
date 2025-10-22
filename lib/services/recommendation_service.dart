import 'package:flutter/material.dart';
import '../data.dart';
import '../services/game_library_service.dart';
import '../models/user_data.dart';

class RecommendationService {
  // Get personalized recommendations based on user's library
  static Future<List<GameItem>> getPersonalizedRecommendations() async {
    final userLibrary = await GameLibraryService.getUserLibrary();
    
    if (userLibrary.isEmpty) {
      // If no library, return popular games
      return _getPopularGames();
    }
    
    // Analyze user preferences
    final preferences = _analyzeUserPreferences(userLibrary);
    
    // Get recommendations based on preferences
    return _getRecommendationsBasedOnPreferences(preferences);
  }
  
  // Analyze user's gaming preferences from their library
  static Map<String, double> _analyzeUserPreferences(List<LibraryGame> library) {
    final preferences = <String, double>{};
    final tagCounts = <String, int>{};
    
    // Count genres and tags (we'll use a simplified approach since LibraryGame doesn't have tags)
    for (final game in library) {
      // For now, we'll use a simple categorization based on game titles
      // In a real app, you'd have genre data for each game
      if (game.title.toLowerCase().contains('action') || 
          game.title.toLowerCase().contains('shooter') ||
          game.title.toLowerCase().contains('fighting')) {
        tagCounts['Action'] = (tagCounts['Action'] ?? 0) + 1;
      }
      if (game.title.toLowerCase().contains('rpg') || 
          game.title.toLowerCase().contains('role')) {
        tagCounts['RPG'] = (tagCounts['RPG'] ?? 0) + 1;
      }
      if (game.title.toLowerCase().contains('strategy') || 
          game.title.toLowerCase().contains('tactics')) {
        tagCounts['Strategy'] = (tagCounts['Strategy'] ?? 0) + 1;
      }
      if (game.title.toLowerCase().contains('racing') || 
          game.title.toLowerCase().contains('driving')) {
        tagCounts['Racing'] = (tagCounts['Racing'] ?? 0) + 1;
      }
      
      // Count price preferences
      if (game.pricePaid == 0) {
        preferences['free_games'] = (preferences['free_games'] ?? 0) + 1;
      } else {
        preferences['paid_games'] = (preferences['paid_games'] ?? 0) + 1;
      }
      
      // Count playtime preferences (as a proxy for popularity)
      preferences['avg_playtime'] = (preferences['avg_playtime'] ?? 0) + game.playtimeHours;
    }
    
    // Calculate average playtime
    if (library.isNotEmpty) {
      preferences['avg_playtime'] = preferences['avg_playtime']! / library.length;
    }
    
    // Convert counts to preferences (normalized)
    final totalGames = library.length.toDouble();
    for (final entry in tagCounts.entries) {
      preferences[entry.key] = entry.value / totalGames;
    }
    
    return preferences;
  }
  
  // Get recommendations based on user preferences
  static List<GameItem> _getRecommendationsBasedOnPreferences(Map<String, double> preferences) {
    final allGames = _getAllAvailableGames();
    final userLibrary = <GameItem>[]; // Simplified - in real app, you'd get this from cache
    final userLibraryIds = userLibrary.map((game) => game.id).toSet();
    
    // Score games based on preferences
    final scoredGames = <GameItem, double>{};
    
    for (final game in allGames) {
      // Skip games already in library
      if (userLibraryIds.contains(game.id)) continue;
      
      double score = 0.0;
      
      // Score based on genre/tag preferences
      for (final tag in game.tags) {
        score += preferences[tag] ?? 0.0;
      }
      
      // Score based on price preference
      if (game.price == 0 && (preferences['free_games'] ?? 0) > 0.5) {
        score += 0.3;
      } else if (game.price > 0 && (preferences['paid_games'] ?? 0) > 0.5) {
        score += 0.3;
      }
      
      // Score based on popularity preference (using playtime as proxy)
      final avgPlaytime = preferences['avg_playtime'] ?? 0.0;
      if (avgPlaytime > 10) { // If user plays games for long hours, prefer popular games
        if (game.popularity > 80) {
          score += 0.2;
        }
      }
      
      // Bonus for highly rated games
      if (game.popularity > 80) {
        score += 0.1;
      }
      
      scoredGames[game] = score;
    }
    
    // Sort by score and return top recommendations
    final sortedGames = scoredGames.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedGames.take(12).map((entry) => entry.key).toList();
  }
  
  // Get popular games (fallback when no library)
  static List<GameItem> _getPopularGames() {
    final allGames = _getAllAvailableGames();
    final sortedGames = List<GameItem>.from(allGames)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    
    return sortedGames.take(12).toList();
  }
  
  // Get all available games (mock data)
  static List<GameItem> _getAllAvailableGames() {
    // This would normally come from your game database
    // For now, we'll use a subset of the mock games
    return [
      GameItem(
        id: 'elden-ring',
        title: 'ELDEN RING',
        imageUrl: 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1245620/capsule_616x353.jpg?t=1748630546',
        tags: ['Action', 'RPG'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A fantasy action RPG set in a world created by Hidetaka Miyazaki and George R.R. Martin.',
        screenshots: [],
      ),
      GameItem(
        id: 'dota2',
        title: 'Dota 2',
        imageUrl: 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/570/capsule_616x353.jpg?t=1757000652',
        tags: ['MOBA', 'Multiplayer'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A multiplayer online battle arena video game.',
        screenshots: [],
      ),
      GameItem(
        id: 'gowr',
        title: 'God of War Ragnarök',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/en/e/ee/God_of_War_Ragnar%C3%B6k_cover.jpg',
        tags: ['Action', 'Adventure'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An action-adventure game developed by Santa Monica Studio.',
        screenshots: [],
      ),
      GameItem(
        id: 'witcher3',
        title: 'The Witcher 3: Wild Hunt',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Witcher_3_cover_art.jpg/250px-Witcher_3_cover_art.jpg',
        tags: ['Action', 'RPG'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An action role-playing game with a mature fantasy setting.',
        screenshots: [],
      ),
      GameItem(
        id: 'wuthering-waves',
        title: 'Wuthering Waves',
        imageUrl: 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3513350/d63b9d52dd39c72fee8c43e286522640650d02b1/capsule_616x353.jpg?t=1756342405',
        tags: ['Action', 'RPG'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An open-world action RPG with a focus on exploration and combat.',
        screenshots: [],
      ),
      GameItem(
        id: 'gta5',
        title: 'Grand Theft Auto V',
        imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR47LjFayYHU_-Hc43iGrZkvbyFmG5YXrcrmA&s',
        tags: ['Open World', 'Action'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An action-adventure game set in the fictional city of Los Santos.',
        screenshots: [],
      ),
      GameItem(
        id: 'valorant',
        title: 'Valorant',
        imageUrl: 'https://cdn1.epicgames.com/offer/cbd5b3d310a54b12bf3fe8c41994174f/EGS_VALORANT_RiotGames_S1_2560x1440-4f0cdb8f0cb0d06ea289ed24b28819b7',
        tags: ['Shooter', 'Multiplayer'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A free-to-play first-person tactical hero shooter.',
        screenshots: [],
      ),
      GameItem(
        id: 'honkai_star_rail',
        title: 'Honkai: Star Rail',
        imageUrl: 'https://image.api.playstation.com/vulcan/ap/rnd/202308/1103/8c3ce3611a4bb187418bb5e24924a055ba33d3046a7aaacb.png',
        tags: ['RPG', 'Anime'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A turn-based RPG with anime-style graphics.',
        screenshots: [],
      ),
      GameItem(
        id: 'rocket-league',
        title: 'Rocket League',
        imageUrl: 'https://cdn1.epicgames.com/offer/9773aa1aa54f4f7b80e44bef04986cea/EGS_RocketLeague_PsyonixLLC_S1_2560x1440-4c231557ef0a0626fbb97e0bd137d837',
        tags: ['Sports', 'Racing'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A vehicular soccer video game.',
        screenshots: [],
      ),
      GameItem(
        id: 'fortnite',
        title: 'Fortnite',
        imageUrl: 'https://cdn1.epicgames.com/offer/fn/FNBR_37-00_C6S4_EGS_Launcher_KeyArt_FNLogo_Blade_1200x1600_1200x1600-0924136c90b79f9006796f69f24a07f6',
        tags: ['Battle Royale', 'Shooter'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'A battle royale game with building mechanics.',
        screenshots: [],
      ),
      GameItem(
        id: 'cyberpunk_phantom_liberty',
        title: 'Cyberpunk 2077',
        imageUrl: 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2358720/header.jpg?t=1749182199',
        tags: ['RPG', 'Sci-Fi'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An open-world action-adventure RPG set in a dystopian future.',
        screenshots: [],
      ),
      GameItem(
        id: 'minecraft',
        title: 'Minecraft',
        imageUrl: 'https://cdn.akamai.steamstatic.com/steam/apps/255710/header.jpg?t=1702315890',
        tags: ['Sandbox', 'Survival'],
        price: 0,
        popularity: 9,
        color: const Color(0xFF2A27F5),
        description: 'A sandbox game where players can build and explore.',
        screenshots: [],
      ),
      GameItem(
        id: 'diablo_4_season_3',
        title: 'Diablo IV',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/en/1/1c/Diablo_IV_cover_art.png',
        tags: ['Action', 'RPG'],
        price: 0,
        popularity: 9,
        color: const Color(0xFF2A27F5),
        description: 'An action role-playing game in the Diablo series.',
        screenshots: [],
      ),
      GameItem(
        id: 'dead_by_daylight',
        title: 'Dead by Daylight',
        imageUrl: 'https://cdn1.epicgames.com/spt-assets/2b2299be8ae84d679d4dc57c55af1510/dead-by-daylight-1hg3x.jpg',
        tags: ['Action', 'Multiplayer'],
        price: 0,
        popularity: 9,
        color: const Color(0xFF2A27F5),
        description: 'An asymmetrical multiplayer horror game.',
        screenshots: [],
      ),
      GameItem(
        id: 'genshin_impact',
        title: 'Genshin Impact',
        imageUrl: 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1089090/capsule_616x353.jpg?t=1754949684',
        tags: ['Action', 'Anime'],
        price: 0,
        popularity: 9,
        color: const Color(0xFF2A27F5),
        description: 'An open-world action RPG with gacha mechanics.',
        screenshots: [],
      ),
      GameItem(
        id: 'civilization-vi',
        title: 'Sid Meier\'s Civilization VI',
        imageUrl: 'https://cdn.akamai.steamstatic.com/steam/apps/289070/header.jpg?t=1702315890',
        tags: ['Strategy', 'Turn-Based'],
        price: 0,
        popularity: 9,
        color: const Color(0xFF2A27F5),
        description: 'A turn-based strategy game.',
        screenshots: [],
      ),
      GameItem(
        id: 'fifa_25',
        title: 'EA SPORTS FC™ 26 Standard Edition',
        imageUrl: 'https://image.api.playstation.com/vulcan/ap/rnd/202507/1617/2e757ffb0a6bb4b91af84db64e0183d725e56e5354f45eba.png',
        tags: ['Sports', 'Football'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'The latest football simulation game.',
        screenshots: [],
      ),
      GameItem(
        id: 'borderlands_4',
        title: 'Borderlands 4',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/en/f/fd/Borderlands_4_cover_art.jpg',
        tags: ['Action', 'Looter Shooter'],
        price: 0,
        popularity: 10,
        color: const Color(0xFF2A27F5),
        description: 'An action role-playing first-person shooter.',
        screenshots: [],
      ),
    ];
  }
}
