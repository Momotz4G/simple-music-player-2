class ArtistModel {
  final String id;
  final String name;
  final String imageUrl;

  ArtistModel({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    String image = "";
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      image = json['images'][0]['url'];
    }

    return ArtistModel(
      id: json['id'],
      name: json['name'],
      imageUrl: image,
    );
  }
}
