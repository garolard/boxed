import 'game.dart';

/// A friend's collection received through a QR code, stored separately
/// from the user's own shelf.
class SharedCollection {
  final int id;
  final String name;
  final DateTime createdAt;
  final List<Game> games;

  const SharedCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.games,
  });
}
