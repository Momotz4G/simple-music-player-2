class AlbumModel {
  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String releaseDate;

  final List<dynamic>? localSongs; // ADDED To support local library albums

  AlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.releaseDate,
    this.localSongs,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    // Safety check for images
    String image = "";
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      image = json['images'][0]['url'];
    }

    return AlbumModel(
      id: json['id'],
      title: json['name'],
      artist: json['artists'][0]['name'], // Grab the first artist
      imageUrl: image,
      releaseDate: json['release_date'] ?? "",
    );
  }
}
