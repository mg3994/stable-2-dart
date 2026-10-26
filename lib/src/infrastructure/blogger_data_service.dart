import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/schema_extractor.dart';

class BloggerDataService {
  Future<Map<String, dynamic>> fetchFeedData({
    int maxResults = 50,
    int startIndex = 1,
    dynamic labels = '',
    String searchQuery = '',
  }) async {
    String labelPath = '';

    if (labels != null && labels != '') {
      final labelsArray = labels is List ? labels : [labels];
      final filteredLabels = labelsArray.where((l) => l.toString().trim().isNotEmpty).toList();
      if (filteredLabels.isNotEmpty) {
        final encodedLabels = filteredLabels.map((l) => Uri.encodeComponent(l.toString().trim())).join(',');
        labelPath = '/-/$encodedLabels';
      }
    }

    String feedUrl = '/feeds/posts/default$labelPath?alt=json&max-results=$maxResults&start-index=$startIndex';

    if (searchQuery.isNotEmpty) {
      feedUrl += '&q=${Uri.encodeComponent(searchQuery)}';
    }

    try {
      final response = await http.get(Uri.parse(feedUrl));
      final data = jsonDecode(response.body);
      final feed = data['feed'] ?? {};
      final entries = feed['entry'] as List? ?? [];
      final totalResults = int.tryParse(feed['openSearch\$totalResults']?['\$t']?.toString() ?? '0') ?? 0;

      return {
        'entries': entries,
        'totalResults': totalResults,
      };
    } catch (e) {
      web.console.error("Failed to fetch Blogger feed: $e".toJS);
      return {'entries': [], 'totalResults': 0};
    }
  }

  dynamic extractSchemaFromEntry(dynamic entry) {
    if (entry is! Map) return null;
    final content = entry['content']?['\$t']?.toString() ?? "";
    return SchemaExtractor.extractJsonLd(content);
  }

  Future<List<String>> fetchSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      final labelRegex = RegExp(r'label:([^|\s]+)');
      final List<String> labels = [];
      String labelPrefix = "";

      final matches = labelRegex.allMatches(query).toList();
      for (final match in matches) {
        final rawLabel = match.group(1) ?? "";
        labels.add(Uri.decodeComponent(rawLabel.trim().replaceAll('_', ' ')));
      }

      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        labelPrefix = query.substring(0, lastMatch.end).trim() + " ";
        if (query.trim().endsWith('|')) {
          labelPrefix = "${query.trim()} ";
        }
      }

      final cleanedQuery = query.replaceAll(labelRegex, '').replaceAll('|', '').trim();

      final feedResult = await fetchFeedData(maxResults: 50, startIndex: 1, labels: labels, searchQuery: cleanedQuery);
      final List entries = feedResult['entries'] as List;
      final Set<String> suggestions = {};
      final normalizedKeyword = cleanedQuery.toLowerCase();

      for (final entry in entries) {
        if (entry is! Map) continue;
        final title = entry['title']?['\$t']?.toString() ?? "";
        if (normalizedKeyword.isEmpty || title.toLowerCase().contains(normalizedKeyword)) {
          suggestions.add('$labelPrefix$title');
        }

        final data = extractSchemaFromEntry(entry);
        if (data != null) {
          final keywords = SchemaExtractor.getFirst(data['keywords']);
          if (keywords is String) {
            for (final k in keywords.split(',')) {
              final trimmed = k.trim();
              if (normalizedKeyword.isEmpty || trimmed.toLowerCase().contains(normalizedKeyword)) {
                suggestions.add('$labelPrefix$trimmed');
              }
            }
          }
          final name = SchemaExtractor.getFirst(data['name']);
          if (name is String && (normalizedKeyword.isEmpty || name.toLowerCase().contains(normalizedKeyword))) {
            suggestions.add('$labelPrefix$name');
          }
        }
      }

      return suggestions.toList().take(10).toList();
    } catch (e) {
      web.console.error("Failed to fetch suggestions: $e".toJS);
      return [];
    }
  }
}
