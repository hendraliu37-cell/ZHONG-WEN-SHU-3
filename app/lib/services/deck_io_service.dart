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
          card.meaningPreview,
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
        [for (final cell in row) cell?.value?.toString().trim() ?? ''],
    ].where((row) => row.any((cell) => cell.isNotEmpty)).toList();
  }

  @visibleForTesting
  List<List<String>> readDelimitedForTest(String text) => _readDelimited(text);

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
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
        cell.clear();
      } else {
        cell.write(ch);
      }
    }

    row.add(cell.toString());
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  String _detectDelimiter(String text) {
    final firstLine = text
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final counts = {
      '\t': '\t'.allMatches(firstLine).length,
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<VocabEntry> _rowsToCards(List<List<String>> rows) {
    if (rows.isEmpty) return const [];
    final first = rows.first.map(_normalizeHeader).toList();
    final hasHeader = first.any(_isKnownHeader);
    if (!hasHeader) {
      return rows.map(_headerlessRowToCard).whereType<VocabEntry>().toList();
    }

    final header = first;
    String get(List<String> row, List<String> names) {
      for (final name in names) {
        final idx = header.indexOf(name);
        if (idx >= 0 && idx < row.length) return row[idx].trim();
      }
      return '';
    }

    return rows
        .skip(1)
        .map((row) => _rowToCard(row, get))
        .whereType<VocabEntry>()
        .toList();
  }

  VocabEntry? _rowToCard(
    List<String> row,
    String Function(List<String>, List<String>) get,
  ) {
    final simplified = get(row, [
      'simplified',
      'simplified_chinese',
      's',
      'front',
      'hanzi',
      'chinese',
      'mandarin',
      'zh',
      'zhongwen',
      'word',
      'term',
      'question',
    ]);
    final traditional = get(row, [
      'traditional',
      'traditional_chinese',
      't',
      'traditional_hanzi',
    ]);
    final meaning = get(row, [
      'meaning',
      'm',
      'back',
      'definition',
      'term_definition',
      'answer',
      'translation',
      'translations',
      'translation_english',
      'definitions',
      'english_definition',
      'english',
      'indonesian',
      'indonesia',
      'arti',
      'bahasa_indonesia',
    ]);
    if (simplified.isEmpty || meaning.isEmpty) return null;

    int? parseInt(String raw) => raw.isEmpty ? null : int.tryParse(raw);
    return VocabEntry.fromJson({
      's': simplified,
      't': traditional.isEmpty ? simplified : traditional,
      'py': get(row, ['pinyin', 'py', 'reading']),
      'zy': get(row, ['zhuyin', 'zy', 'bopomofo']),
      'm': VocabEntry.splitMeanings(meaning).join(' / '),
      'exs': get(row, ['example_s', 'examples', 'example']),
      'ext': get(row, ['example_t']),
      'exi': get(row, ['example_id', 'example_translation', 'notes']),
      'tone': parseInt(get(row, ['tone'])) ?? 1,
      'hsk': parseInt(get(row, ['hsk', 'hsk_level'])),
      'tocfl': parseInt(get(row, ['tocfl', 'tocfl_level'])),
    });
  }

  VocabEntry? _headerlessRowToCard(List<String> row) {
    final cells = row.map((cell) => cell.trim()).toList();
    if (cells.length < 2 || cells[0].isEmpty || cells[1].isEmpty) return null;
    var front = cells[0];
    var back = cells[1];
    var pinyin = cells.length > 2 ? cells[2] : '';
    var traditional = cells.length > 3 && cells[3].isNotEmpty ? cells[3] : '';
    if (_hasCjk(front) &&
        cells.length > 2 &&
        _looksLikePinyin(cells[1]) &&
        cells[2].isNotEmpty) {
      pinyin = cells[1];
      back = cells[2];
      traditional = cells.length > 3 && cells[3].isNotEmpty ? cells[3] : '';
    }
    if (!_hasCjk(front) && _hasCjk(back)) {
      final tmp = front;
      front = back;
      back = tmp;
    }
    return VocabEntry.fromJson({
      's': front,
      't': traditional.isNotEmpty ? traditional : front,
      'py': pinyin,
      'm': VocabEntry.splitMeanings(back).join(' / '),
    });
  }

  String _normalizeHeader(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '');

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
    'word',
    'term',
    'definition',
    'translation',
    'translation_english',
    'translations',
    'definitions',
    'english_definition',
    'english',
    'indonesian',
    'indonesia',
    'arti',
    'bahasa_indonesia',
    'pinyin',
    'py',
    'reading',
    'meaning',
    'question',
    'answer',
  }.contains(value);

  bool _hasCjk(String value) => RegExp(r'[一-鿿㐀-䶿]').hasMatch(value);

  bool _looksLikePinyin(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty || _hasCjk(v)) return false;
    final normalized = _stripPinyinToneMarks(
      v,
    ).replaceAll('ü', 'v').replaceAll(RegExp(r"[^a-z0-9\s:;,./-]+"), ' ');
    final words = normalized
        .split(RegExp(r'[\s:;,./-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || words.length > 8) return false;
    return words.every(_isPinyinSyllable);
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
