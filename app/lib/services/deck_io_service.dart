import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share;

import '../models/vocab.dart';

class DeckImportResult {
  final List<VocabEntry> cards;
  final String sourceName;
  const DeckImportResult({required this.cards, required this.sourceName});
}

class DeckIoService {
  static const headers = [
    'simplified',
    'traditional',
    'pinyin',
    'zhuyin',
    'meaning',
    'example_s',
    'example_t',
    'example_id',
    'tone',
    'hsk',
    'tocfl',
  ];

  static const _csvType = XTypeGroup(
    label: 'CSV / TSV flashcards',
    extensions: ['csv', 'tsv', 'txt'],
    mimeTypes: ['text/csv', 'text/tab-separated-values', 'text/plain'],
  );
  static const _excelType = XTypeGroup(
    label: 'Excel flashcards',
    extensions: ['xlsx'],
    mimeTypes: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ],
  );

  Future<String?> exportDeck({
    required String deckName,
    required Iterable<VocabEntry> cards,
    required bool excel,
  }) async {
    final safeName = _safeFileName(deckName);
    final ext = excel ? 'xlsx' : 'csv';
    final filename = '$safeName.$ext';
    final bytes = excel ? _buildExcel(cards) : utf8.encode(_buildCsv(cards));
    FileSaveLocation? location;
    if (!Platform.isAndroid) {
      try {
        location = await getSaveLocation(
          acceptedTypeGroups: [excel ? _excelType : _csvType],
          suggestedName: filename,
        );
      } catch (_) {
        location = null;
      }
      if (location == null) return null;
    }

    final path = location?.path ?? await _fallbackExportPath(filename);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (Platform.isAndroid) {
      await _shareExport(path, filename, excel: excel);
    }
    return path;
  }

  Future<DeckImportResult?> importDeck() async {
    XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: const [_csvType, _excelType],
        confirmButtonText: 'Import',
      );
    } catch (e) {
      throw Exception('File picker tidak tersedia: $e');
    }
    if (file == null) return null;
    final name = file.name;
    final bytes = await file.readAsBytes();
    final rows = name.toLowerCase().endsWith('.xlsx')
        ? _readExcel(bytes)
        : _readDelimited(utf8.decode(bytes, allowMalformed: true));
    return importRowsForTest(rows, sourceName: name);
  }

  String _buildCsv(Iterable<VocabEntry> cards) {
    final rows = [
      headers,
      for (final card in cards)
        [
          card.simplified,
          card.traditional,
          card.pinyin,
          card.zhuyin,
          card.meaning,
          card.exampleS,
          card.exampleT,
          card.exampleId,
          '${card.tone}',
          card.hskLevel?.toString() ?? '',
          card.tocflLevel?.toString() ?? '',
        ],
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  List<int> _buildExcel(Iterable<VocabEntry> cards) {
    final excel = Excel.createExcel();
    const sheet = 'Deck';
    excel.rename('Sheet1', sheet);
    excel.appendRow(sheet, headers.map(TextCellValue.new).toList());
    for (final card in cards) {
      excel.appendRow(sheet, [
        TextCellValue(card.simplified),
        TextCellValue(card.traditional),
        TextCellValue(card.pinyin),
        TextCellValue(card.zhuyin),
        TextCellValue(card.meaning),
        TextCellValue(card.exampleS),
        TextCellValue(card.exampleT),
        TextCellValue(card.exampleId),
        IntCellValue(card.tone),
        if (card.hskLevel == null)
          TextCellValue('')
        else
          IntCellValue(card.hskLevel!),
        if (card.tocflLevel == null)
          TextCellValue('')
        else
          IntCellValue(card.tocflLevel!),
      ]);
    }
    return excel.encode() ?? const <int>[];
  }

  List<List<String>> _readExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final table = excel.tables.values.first;
    return [
      for (final row in table.rows)
        _cleanRow([for (final cell in row) cell?.value?.toString() ?? '']),
    ].where((row) => row.any((cell) => cell.isNotEmpty)).toList();
  }

  @visibleForTesting
  List<List<String>> readDelimitedForTest(String text) => _readDelimited(text);

  @visibleForTesting
  List<List<String>> readExcelForTest(List<int> bytes) => _readExcel(bytes);

  @visibleForTesting
  List<int> buildExcelForTest(Iterable<VocabEntry> cards) => _buildExcel(cards);

  @visibleForTesting
  String buildCsvForTest(Iterable<VocabEntry> cards) => _buildCsv(cards);

  @visibleForTesting
  List<VocabEntry> rowsToCardsForTest(List<List<String>> rows) =>
      _rowsToCards(rows);

  @visibleForTesting
  DeckImportResult importRowsForTest(
    List<List<String>> rows, {
    String sourceName = 'test',
  }) {
    if (rows.isEmpty) {
      return DeckImportResult(cards: const [], sourceName: sourceName);
    }
    return DeckImportResult(cards: _rowsToCards(rows), sourceName: sourceName);
  }

  List<List<String>> _readDelimited(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    final delimiter = _detectDelimiter(csv);

    for (var i = 0; i < csv.length; i++) {
      final ch = csv[i];
      final next = i + 1 < csv.length ? csv[i + 1] : '';
      if (ch == '"' && inQuotes && next == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == delimiter && !inQuotes) {
        row.add(cell.toString());
        cell.clear();
      } else if ((ch == '\n' || ch == '\r') && !inQuotes) {
        if (ch == '\r' && next == '\n') i++;
        row.add(cell.toString());
        if (row.any((value) => value.trim().isNotEmpty)) {
          rows.add(_cleanRow(row));
        }
        row = <String>[];
        cell.clear();
      } else {
        cell.write(ch);
      }
    }

    row.add(cell.toString());
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(_cleanRow(row));
    return rows;
  }

  List<String> _cleanRow(List<String> row) {
    if (row.isEmpty) return row;
    return [
      for (var i = 0; i < row.length; i++)
        _cleanImportCell(row[i], first: i == 0),
    ];
  }

  String _cleanImportCell(String value, {bool first = false}) {
    var text = first ? value.replaceFirst('\uFEFF', '') : value;
    text = text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</\s*(?:div|p|li|tr|td|th)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .trim();
    return _decodeHtmlEntities(text);
  }

  String _decodeHtmlEntities(String value) {
    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|\w+);'), (m) {
      final entity = m.group(1) ?? '';
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code == null ? m.group(0)! : String.fromCharCode(code);
      }
      return switch (entity.toLowerCase()) {
        'nbsp' => ' ',
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        _ => m.group(0)!,
      };
    });
  }

  String _detectDelimiter(String text) {
    final firstLine = text
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final directive = _delimiterDirective(firstLine);
    if (directive != null) return directive;
    final counts = {
      '\t': '\t'.allMatches(firstLine).length,
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? _delimiterDirective(String line) {
    final text = line.replaceFirst('\uFEFF', '').trim().toLowerCase();
    if (text.startsWith('sep=') && text.length >= 5) {
      final value = text.substring(4).trim();
      if (value == r'\t' || value == 'tab') return '\t';
      if (value.startsWith(';')) return ';';
      if (value.startsWith(',')) return ',';
    }
    if (!text.startsWith('#separator:')) return null;
    final value = text.substring('#separator:'.length).trim();
    return switch (value) {
      r'\t' || 'tab' || 'tabs' => '\t',
      ';' || 'semicolon' || 'semi-colon' => ';',
      ',' || 'comma' => ',',
      _ => null,
    };
  }

  List<VocabEntry> _rowsToCards(List<List<String>> rows) {
    final dataRows = rows.where((row) => !_isImportDirective(row)).toList();
    if (dataRows.isEmpty) return const [];
    final first = dataRows.first.map(_normalizeHeader).toList();
    final hasHeader = _looksLikeHeaderRow(dataRows.first, first);
    if (!hasHeader) {
      return dataRows
          .map(_headerlessRowToCard)
          .whereType<VocabEntry>()
          .toList();
    }

    final header = first;
    String get(List<String> row, List<String> names) {
      for (final name in names) {
        final idx = header.indexOf(name);
        if (idx >= 0 && idx < row.length) return row[idx].trim();
      }
      return '';
    }

    return dataRows
        .skip(1)
        .map((row) => _rowToCard(row, get))
        .whereType<VocabEntry>()
        .toList();
  }

  bool _isDelimiterDirective(List<String> row) {
    if (row.isEmpty) return false;
    final first = row.first.trim().toLowerCase();
    return first.startsWith('sep=') &&
        row.skip(1).every((cell) => cell.trim().isEmpty);
  }

  bool _isImportDirective(List<String> row) {
    if (_isDelimiterDirective(row)) return true;
    if (row.isEmpty || row.skip(1).any((cell) => cell.trim().isNotEmpty)) {
      return false;
    }
    final first = row.first.trim().toLowerCase();
    return first.startsWith('#separator:') ||
        first.startsWith('#html:') ||
        first.startsWith('#notetype column:') ||
        first.startsWith('#deck column:') ||
        first.startsWith('#tags column:') ||
        first.startsWith('#columns:');
  }

  bool _looksLikeHeaderRow(List<String> row, List<String> normalized) {
    final knownCount = normalized.where(_isKnownHeader).length;
    if (knownCount == 0) return false;
    if (knownCount >= 2) return true;
    return !row.any(_hasCjk);
  }

  VocabEntry? _rowToCard(
    List<String> row,
    String Function(List<String>, List<String>) get,
  ) {
    var simplified = get(row, [
      'simplified',
      'simplified_chinese',
      's',
      'front',
      'hanzi',
      'chinese',
      'mandarin',
      'zh',
      'zhongwen',
      'expression',
      'expressions',
      'characters',
      'character',
      'vocab',
      'vocabulary',
      'headword',
      'headwords',
      'word',
      'term',
      'question',
    ]);
    var traditional = get(row, [
      'traditional',
      'traditional_chinese',
      't',
      'traditional_hanzi',
    ]);
    var meaning = get(row, [
      'meaning',
      'm',
      'back',
      'definition',
      'term_definition',
      'answer',
      'translation',
      'translations',
      'translation_english',
      'translation_indonesian',
      'indonesian_translation',
      'definitions',
      'english_definition',
      'gloss',
      'glosses',
      'english',
      'indonesian',
      'indonesia',
      'arti',
      'bahasa_indonesia',
    ]);
    if (simplified.isEmpty || meaning.isEmpty) return null;
    if (!_hasCjk(simplified) && _hasCjk(meaning)) {
      final originalFront = simplified;
      simplified = meaning;
      meaning = originalFront;
      if (traditional.isEmpty || !_hasCjk(traditional)) {
        traditional = simplified;
      }
    }
    if (!_hasCjk(simplified)) return null;

    return VocabEntry.fromJson({
      's': simplified,
      't': traditional.isEmpty ? simplified : traditional,
      'py': get(row, ['pinyin', 'py', 'reading', 'pronunciation']),
      'zy': get(row, ['zhuyin', 'zy', 'bopomofo']),
      'm': VocabEntry.splitMeanings(meaning).join(' / '),
      'exs': get(row, ['example_s', 'examples', 'example']),
      'ext': get(row, ['example_t']),
      'exi': get(row, [
        'example_id',
        'example_translation',
        'notes',
        'note',
        'extra',
        'extras',
        'comment',
        'comments',
      ]),
      'tone': _parseIntish(get(row, ['tone'])) ?? 1,
      'hsk': _parseIntish(get(row, ['hsk', 'hsk_level'])),
      'tocfl': _parseIntish(get(row, ['tocfl', 'tocfl_level'])),
    });
  }

  VocabEntry? _headerlessRowToCard(List<String> row) {
    final cells = row.map((cell) => cell.trim()).toList();
    if (cells.length < 2 || cells.every((cell) => cell.isEmpty)) return null;
    final frontIndex = cells.indexWhere(_hasCjk);
    if (frontIndex < 0) return null;

    final front = cells[frontIndex];
    final before = cells.take(frontIndex).toList();
    final after = cells.skip(frontIndex + 1).toList();
    var back = '';
    var pinyin = '';
    var traditional = _firstCjkCell(after, except: front);

    if (frontIndex == 0) {
      if (after.isNotEmpty && _looksLikePinyin(after.first)) {
        pinyin = after.first;
        back = _firstMeaningCell(after.skip(1));
      } else {
        back = _firstMeaningCell(after);
        pinyin = _firstPinyinCell(after.skip(1));
      }
    } else {
      if (after.isNotEmpty && _looksLikePinyin(after.first)) {
        pinyin = after.first;
        back = _firstMeaningCell(after.skip(1));
      } else {
        back = _firstMeaningCell(after);
        pinyin = _firstPinyinCell(after);
      }
      if (back.isEmpty && frontIndex == 1) {
        back = _firstMeaningCell(before);
      }
    }

    if (traditional.isEmpty && cells.length > 3 && _hasCjk(cells[3])) {
      traditional = cells[3];
    }
    if (back.isEmpty) return null;
    if (!_hasCjk(front)) return null;
    return VocabEntry.fromJson({
      's': front,
      't': traditional.isNotEmpty ? traditional : front,
      'py': pinyin,
      'm': VocabEntry.splitMeanings(back).join(' / '),
    });
  }

  String _firstMeaningCell(Iterable<String> cells) {
    for (final cell in cells) {
      final value = cell.trim();
      if (value.isEmpty || _hasCjk(value) || _looksLikePinyin(value)) continue;
      return value;
    }
    return '';
  }

  String _firstPinyinCell(Iterable<String> cells) {
    for (final cell in cells) {
      final value = cell.trim();
      if (value.isNotEmpty && _looksLikePinyin(value)) return value;
    }
    return '';
  }

  String _firstCjkCell(Iterable<String> cells, {required String except}) {
    for (final cell in cells) {
      final value = cell.trim();
      if (value.isNotEmpty && value != except && _hasCjk(value)) return value;
    }
    return '';
  }

  String _normalizeHeader(String value) {
    final cleaned = value.replaceFirst('\uFEFF', '');
    final compact = cleaned.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '');
    const localized = {
      '汉字': 'hanzi',
      '漢字': 'hanzi',
      '中文': 'chinese',
      '简体': 'simplified',
      '簡體': 'simplified',
      '简体字': 'simplified',
      '簡體字': 'simplified',
      '简体中文': 'simplified_chinese',
      '簡體中文': 'simplified_chinese',
      '繁体': 'traditional',
      '繁體': 'traditional',
      '繁体字': 'traditional',
      '繁體字': 'traditional',
      '繁体中文': 'traditional_chinese',
      '繁體中文': 'traditional_chinese',
      '拼音': 'pinyin',
      '注音': 'zhuyin',
      '意思': 'meaning',
      '释义': 'meaning',
      '釋義': 'meaning',
      '含义': 'meaning',
      '含義': 'meaning',
      '翻译': 'translation',
      '翻譯': 'translation',
      '英文': 'english',
      '印尼语': 'indonesian',
      '印尼語': 'indonesian',
      '印度尼西亚语': 'indonesian',
      '印度尼西亞語': 'indonesian',
      '例句': 'example_s',
      '简体例句': 'example_s',
      '簡體例句': 'example_s',
      '繁体例句': 'example_t',
      '繁體例句': 'example_t',
      '例句翻译': 'example_id',
      '例句翻譯': 'example_id',
      '声调': 'tone',
      '聲調': 'tone',
      '等级': 'hsk',
      '等級': 'hsk',
    };
    final mapped = localized[compact];
    if (mapped != null) return mapped;
    return cleaned
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  }

  bool _isKnownHeader(String value) => const {
    'simplified',
    'simplified_chinese',
    'traditional',
    'traditional_chinese',
    'front',
    'back',
    'hanzi',
    'chinese',
    'mandarin',
    'zh',
    'zhongwen',
    'expression',
    'expressions',
    'characters',
    'character',
    'vocab',
    'vocabulary',
    'headword',
    'headwords',
    'word',
    'term',
    'definition',
    'translation',
    'translation_english',
    'translation_indonesian',
    'indonesian_translation',
    'translations',
    'definitions',
    'english_definition',
    'gloss',
    'glosses',
    'english',
    'indonesian',
    'indonesia',
    'arti',
    'bahasa_indonesia',
    'pinyin',
    'py',
    'reading',
    'pronunciation',
    'zhuyin',
    'zy',
    'bopomofo',
    'meaning',
    'question',
    'answer',
    'example_s',
    'example_t',
    'example_id',
    'note',
    'notes',
    'extra',
    'extras',
    'comment',
    'comments',
    'tone',
    'hsk',
    'hsk_level',
    'tocfl',
    'tocfl_level',
  }.contains(value);

  bool _hasCjk(String value) => RegExp(r'[一-鿿㐀-䶿]').hasMatch(value);

  bool _looksLikePinyin(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty || _hasCjk(v)) return false;
    final hasToneCue =
        RegExp(r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ]').hasMatch(v) ||
        RegExp(r'[a-züv]+[1-5]\b').hasMatch(v);
    final normalized = _stripPinyinToneMarks(
      v,
    ).replaceAll('ü', 'v').replaceAll(RegExp(r"[^a-z0-9\s:;,./-]+"), ' ');
    final words = normalized
        .split(RegExp(r'[\s:;,./-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || words.length > 8) return false;
    if (words.every(_isPinyinSyllable)) return true;
    return hasToneCue &&
        RegExp(r'^[a-z0-9üāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ\s:;,./-]+$').hasMatch(v);
  }

  String _stripPinyinToneMarks(String value) {
    const tones = {
      'ā': 'a',
      'á': 'a',
      'ǎ': 'a',
      'à': 'a',
      'ē': 'e',
      'é': 'e',
      'ě': 'e',
      'è': 'e',
      'ī': 'i',
      'í': 'i',
      'ǐ': 'i',
      'ì': 'i',
      'ō': 'o',
      'ó': 'o',
      'ǒ': 'o',
      'ò': 'o',
      'ū': 'u',
      'ú': 'u',
      'ǔ': 'u',
      'ù': 'u',
      'ǖ': 'v',
      'ǘ': 'v',
      'ǚ': 'v',
      'ǜ': 'v',
      'ń': 'n',
      'ň': 'n',
      'ǹ': 'n',
      'ḿ': 'm',
    };
    final out = StringBuffer();
    for (final ch in value.split('')) {
      out.write(tones[ch] ?? ch);
    }
    return out.toString();
  }

  bool _isPinyinSyllable(String raw) {
    final syllable = raw.replaceFirst(RegExp(r'[1-5]$'), '');
    return RegExp(
      r'^(?:zh|ch|sh|[bpmfdtnlgkhjqxzcsryw])?'
      r'(?:a|ai|an|ang|ao|e|ei|en|eng|er|i|ia|ian|iang|iao|ie|in|ing|iong|iu|'
      r'o|ong|ou|u|ua|uai|uan|uang|ui|un|uo|v|ve|van|vn|ue)$',
    ).hasMatch(syllable);
  }

  int? _parseIntish(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _safeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return cleaned.isEmpty ? 'zhongwen-shu-deck' : cleaned;
  }

  Future<String> _fallbackExportPath(String filename) async {
    final dir = Platform.isAndroid
        ? (await getExternalStorageDirectory()) ??
              await getApplicationDocumentsDirectory()
        : await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}exports${Platform.pathSeparator}$filename';
  }

  Future<void> _shareExport(
    String path,
    String filename, {
    required bool excel,
  }) async {
    final mime = excel
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'text/csv';
    await share.SharePlus.instance.share(
      share.ShareParams(
        files: [share.XFile(path, mimeType: mime)],
        fileNameOverrides: [filename],
        subject: filename,
        text: 'Export deck Zhongwen Shu: $filename',
      ),
    );
  }
}
