class WikiSummary {
  final String title;
  final String extract;
  final String? description;
  final Map<String, dynamic>
  metadata; // For dynamic fields like height, architect
  final String? thumbnailUrl;

  WikiSummary({
    required this.title,
    required this.extract,
    this.description,
    required this.metadata,
    this.thumbnailUrl,
  });

  factory WikiSummary.fromJson(Map<String, dynamic> json) {
    final metadata = <String, dynamic>{};

    // Extract infobox-like data from extract or other fields
    if (json['extract'] != null) {
      final extract = json['extract'].toString();
      // Example: Parse height, architect, etc., from extract (heuristic-based)
      final heightMatch = RegExp(r'Height:?\s*([\s\w]+)').firstMatch(extract);
      final architectMatch = RegExp(
        r'Architect:?\s*([^\n]+)',
      ).firstMatch(extract);
      final directorMatch = RegExp(
        r'Director:?\s*([^\n]+)',
      ).firstMatch(extract);
      final builtMatch = RegExp(r'Built:?\s*([^\n]+)').firstMatch(extract);
      final collectionMatch = RegExp(
        r'Collection size:?\s*([^\n]+)',
      ).firstMatch(extract);

      if (heightMatch != null) {
        metadata['height'] = heightMatch.group(1)?.trim();
      }
      if (architectMatch != null) {
        metadata['architect'] = architectMatch.group(1)?.trim();
      }
      if (directorMatch != null) {
        metadata['director'] = directorMatch.group(1)?.trim();
      }
      if (builtMatch != null) {
        metadata['date_built'] = builtMatch.group(1)?.trim();
      }
      if (collectionMatch != null) {
        metadata['collection_size'] = collectionMatch.group(1)?.trim();
      }
    }

    return WikiSummary(
      title: json['title']?.toString() ?? 'Unknown',
      extract: json['extract']?.toString() ?? 'No summary available',
      description: json['description']?.toString(),
      metadata: metadata,
      thumbnailUrl: json['thumbnail']?['source']?.toString(),
    );
  }
}
