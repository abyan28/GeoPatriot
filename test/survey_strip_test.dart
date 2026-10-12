import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/camera/widgets/survey_strip.dart';
import 'package:geotag_camera/survey/survey_controller.dart';
import 'package:geotag_camera/survey/survey_service.dart';

class _FakeSurveyService extends SurveyService {
  @override
  Future<SurveyData> load() async => const SurveyData();
  @override
  Future<void> save(SurveyData data) async {}
}

Future<SurveyController> _readySurvey() async {
  final survey = SurveyController(service: _FakeSurveyService());
  await survey.setEnabled(true);
  await survey.setLocation('Belu 2');
  await survey.setObject('Rias', code: 'Kapitan Meo');
  return survey;
}

/// Layar 411x891 dp (Galaxy S25+) dengan kontrol di Positioned di dasar seperti
/// pada layar kamera.
Widget _harness(Widget child, {Alignment alignment = Alignment.bottomCenter}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 411,
        height: 891,
        child: Stack(children: [Align(alignment: alignment, child: child)]),
      ),
    ),
  );
}

void main() {
  late SurveyController survey;

  setUp(() async {
    survey = await _readySurvey();
  });

  test('surveyStripHeight: 64 untuk portrait dan 0 untuk landscape', () {
    expect(surveyStripHeight(landscape: false), 64.0);
    expect(surveyStripHeight(landscape: true), 0.0);
  });

  testWidgets('SurveyObjectHeader menampilkan objek, lokasi, dan tombol berikutnya', (tester) async {
    await tester.pumpWidget(_harness(SurveyObjectHeader(survey: survey), alignment: Alignment.topCenter));

    expect(find.text('Rias · Kapitan Meo'), findsOneWidget);
    expect(find.text('Belu 2'), findsOneWidget);
    expect(find.text('Objek berikutnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SurveyObjectInline (landscape) ringkas: tombol berikutnya hanya ikon', (tester) async {
    await tester.pumpWidget(_harness(SurveyObjectInline(survey: survey), alignment: Alignment.topCenter));

    expect(find.text('Rias · Kapitan Meo'), findsOneWidget);
    expect(find.text('Objek berikutnya'), findsNothing);
    expect(find.byTooltip('Objek berikutnya'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('objek kosong menampilkan ajakan mengisi nama', (tester) async {
    survey.nextObject();
    await tester.pumpWidget(_harness(SurveyObjectHeader(survey: survey), alignment: Alignment.topCenter));

    expect(find.text('Isi nama objek'), findsOneWidget);
    expect(find.text('Objek berikutnya'), findsNothing);
  });

  group('SurveyCategoryControl', () {
    testWidgets('tertutup: hanya pill dengan nama kategori terpilih dan panah kanan (portrait)', (tester) async {
      await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey)));

      expect(find.text('Rumah'), findsOneWidget);
      expect(find.text('Lahan'), findsNothing);
      expect(find.text('KK'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('tertutup (landscape): panah menunjuk ke kiri', (tester) async {
      await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey, quarterTurns: 1)));

      expect(find.text('Rumah'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('diketuk membuka bar berisi semua kategori dan pratinjau nama file', (tester) async {
      await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey)));

      await tester.tap(find.text('Rumah'));
      await tester.pumpAndSettle();

      for (final cat in survey.categories) {
        expect(find.text(cat.label), findsOneWidget, reason: cat.label);
      }
      expect(find.text(survey.previewFileName!), findsOneWidget);
      expect(find.byTooltip('Tutup'), findsOneWidget);
    });

    testWidgets('memilih kategori menutup bar dan pill menampilkan kategori baru', (tester) async {
      await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey)));

      await tester.tap(find.text('Rumah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KK'));
      await tester.pumpAndSettle();

      expect(survey.selectedCategory!.id, 'kk');
      expect(find.byTooltip('Tutup'), findsNothing);
      expect(find.text('KK'), findsOneWidget);
      expect(find.text('Rumah'), findsNothing);
    });

    testWidgets('tombol tutup menutup bar tanpa mengubah kategori', (tester) async {
      await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey)));

      await tester.tap(find.text('Rumah'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(survey.selectedCategory!.id, 'rumah');
      expect(find.byTooltip('Tutup'), findsNothing);
    });

    for (final turns in [0, 1, 3]) {
      testWidgets('tidak overflow pada layar 411x891 (quarterTurns=$turns)', (tester) async {
        await tester.pumpWidget(_harness(SurveyCategoryControl(survey: survey, quarterTurns: turns)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Rumah'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(SurveyCategoryControl));
        expect(bar.left, greaterThanOrEqualTo(0));
        expect(bar.right, lessThanOrEqualTo(411));
      });
    }
  });
}
