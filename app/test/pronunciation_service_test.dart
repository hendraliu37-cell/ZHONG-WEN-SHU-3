import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/ocr_service.dart';
import 'package:zhongwen_shu/services/pronunciation_service.dart';
import 'package:zhongwen_shu/services/stt_service.dart';

void main() {
  test('parses pronunciation scoring response safely', () {
    final result = PronunciationResult.fromJson({
      'transcript': '你好',
      'score': 87.6,
      'words': [
        {'word': '你', 'confidence': 91.2},
        {'word': '好', 'confidence': 84},
      ],
    });

    expect(result.transcript, '你好');
    expect(result.score, 88);
    expect(result.words.map((w) => w.word), ['你', '好']);
    expect(result.words.map((w) => w.confidence), [91, 84]);
  });

  test('clamps invalid pronunciation scores', () {
    expect(PronunciationResult.fromJson({'score': 140}).score, 100);
    expect(PronunciationResult.fromJson({'score': -5}).score, 0);
  });

  test('parses loose pronunciation scoring response values', () {
    final result = parsePronunciationResponseForTest(
      '{"transcript":"你好","score":"87.6","words":[{"word":"你","confidence":"91.2"}]}',
    );

    expect(result, isNotNull);
    expect(result!.score, 88);
    expect(result.words.single.confidence, 91);
    expect(parsePronunciationResponseForTest('not-json'), isNull);
  });

  test('pronunciation cancel removes temporary recording file', () async {
    final dir = await Directory.systemTemp.createTemp('zws_pron_test_');
    final file = File('${dir.path}/recording.wav');
    await file.writeAsBytes([1, 2, 3]);
    final service = PronunciationService()..setRecordingPathForTest(file.path);

    await service.cancel();

    expect(await file.exists(), isFalse);
    await dir.delete(recursive: true);
  });

  test('STT cancel removes temporary recording file', () async {
    final dir = await Directory.systemTemp.createTemp('zws_stt_test_');
    final file = File('${dir.path}/recording.wav');
    await file.writeAsBytes([1, 2, 3]);
    final service = SttService()..setRecordingPathForTest(file.path);

    await service.cancel();

    expect(await file.exists(), isFalse);
    await dir.delete(recursive: true);
  });

  test('STT parser accepts raw JSON strings and loose text values', () {
    expect(parseSttTextResponseForTest({'text': 123}), '123');
    expect(parseSttTextResponseForTest('{"text":"你好"}'), '你好');
    expect(parseSttTextResponseForTest('  halo  '), 'halo');
    expect(parseSttTextResponseForTest({'text': '  '}), isNull);
  });

  test('OCR parser accepts raw JSON strings and loose text values', () {
    expect(parseOcrTextResponseForTest({'text': 456}), '456');
    expect(parseOcrTextResponseForTest('{"text":"中文"}'), '中文');
    expect(parseOcrTextResponseForTest('  你好  '), '你好');
    expect(parseOcrTextResponseForTest(null), isNull);
  });
}
