import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
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
    label: 'CSV flashcards',
    extensions: ['csv'],
    mimeTypes: ['text/csv'],
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
        : _readCsv(utf8.decode(bytes, allowMalformed: true));
    if (rows.length < 2) {
      return DeckImportResult(cards: const [], sourceName: name);
    }
    final cards = _rowsToCards(rows);
    return DeckImportResult(cards: cards, sourceName: name);
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

  List<List<String>> _readCsv(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < csv.length; i++) {
      final ch = csv[i];
      final next = i + 1 < csv.length ? csv[i + 1] : '';
      if (ch == '"' && inQuotes && next == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
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

  List<VocabEntry> _rowsToCards(List<List<String>> rows) {
    final header = rows.first
        .map((cell) => cell.toLowerCase().trim().replaceAll(' ', '_'))
        .toList();
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
    final simplified = get(row, ['simplified', 's', 'front', 'hanzi', 'word']);
    final traditional = get(row, ['traditional', 't', 'traditional_hanzi']);
    final meaning = get(row, [
      'meaning',
      'm',
      'back',
      'translation',
      'translations',
      'definition',
      'definitions',
    ]);
    if (simplified.isEmpty || meaning.isEmpty) return null;

    int? parseInt(String raw) => raw.isEmpty ? null : int.tryParse(raw);
    return VocabEntry(
      simplified: simplified,
      traditional: traditional.isEmpty ? simplified : traditional,
      pinyin: get(row, ['pinyin', 'py', 'reading']),
      zhuyin: get(row, ['zhuyin', 'zy', 'bopomofo']),
      meaning: VocabEntry.splitMeanings(meaning).join(' / '),
      exampleS: get(row, ['example_s', 'examples', 'example']),
      exampleT: get(row, ['example_t']),
      exampleId: get(row, ['example_id', 'example_translation', 'notes']),
      tone: parseInt(get(row, ['tone'])) ?? 1,
      hskLevel: parseInt(get(row, ['hsk', 'hsk_level'])),
      tocflLevel: parseInt(get(row, ['tocfl', 'tocfl_level'])),
    );
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
