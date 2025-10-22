import 'package:flutter/material.dart';

class GameItem {
  final String id;
  final String title;
  final String imageUrl;
  final List<String> tags;
  final double price;
  final double popularity;
  final Color color;
  final String description;
  final List<String> screenshots;

  const GameItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.tags,
    required this.price,
    required this.popularity,
    required this.color,
    required this.description,
    required this.screenshots,
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      tags: List<String>.from(json['tags']),
      price: json['price']?.toDouble() ?? 0.0,
      popularity: json['popularity']?.toDouble() ?? 0.0,
      color: Color(json['color'] ?? 0xFF2A27F5),
      description: json['description'] ?? '',
      screenshots: List<String>.from(json['screenshots'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'tags': tags,
      'price': price,
      'popularity': popularity,
      'color': color.value,
      'description': description,
      'screenshots': screenshots,
    };
  }

  GameItem copyWith({
    String? id,
    String? title,
    String? imageUrl,
    List<String>? tags,
    double? price,
    double? popularity,
    Color? color,
    String? description,
    List<String>? screenshots,
  }) {
    return GameItem(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      price: price ?? this.price,
      popularity: popularity ?? this.popularity,
      color: color ?? this.color,
      description: description ?? this.description,
      screenshots: screenshots ?? this.screenshots,
    );
  }
}
