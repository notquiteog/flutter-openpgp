import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpgp/mixin/openpgp_response_handlers.dart';
import 'package:openpgp/model/bridge_model_generated.dart' as model;
import 'package:openpgp/openpgp.dart';

void main() {
  group('OpenPGPResponseHandlers', () {
    test('bytesResponse preserves empty output', () {
      final data = model.BytesResponseObjectBuilder(output: const []).toBytes();

      final output = OpenPGPResponseHandlers.bytesResponse(data);

      expect(output, isA<Uint8List>());
      expect(output, isEmpty);
    });

    test('bytesResponse treats omitted output as legacy empty output', () {
      final data = model.BytesResponseObjectBuilder().toBytes();

      expect(OpenPGPResponseHandlers.bytesResponse(data), isEmpty);
    });

    test('stringResponse preserves empty output', () {
      final data = model.StringResponseObjectBuilder(output: '').toBytes();

      expect(OpenPGPResponseHandlers.stringResponse(data), '');
    });

    test('response errors still throw', () {
      final data = model.BytesResponseObjectBuilder(
        error: 'bridge failed',
      ).toBytes();

      expect(
        () => OpenPGPResponseHandlers.bytesResponse(data),
        throwsA(isA<OpenPGPException>()),
      );
    });
  });
}
