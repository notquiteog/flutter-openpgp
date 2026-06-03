import 'package:flutter/material.dart';

import 'package:openpgp/openpgp.dart' as openpgp;
import 'package:openpgp_example/shared/button_widget.dart';
import 'package:openpgp_example/shared/title_widget.dart';

class Generate extends StatefulWidget {
  const Generate({super.key, required this.title});

  final String title;

  @override
  State<Generate> createState() => _GenerateState();
}

class _GenerateState extends State<Generate> {
  openpgp.KeyPair _keyPair = openpgp.KeyPair("", "");

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Card(
        child: Column(
          children: [
            TitleWidget(widget.title),
            ButtonWidget(
              title: "Generate",
              key: Key("action"),
              result: _keyPair.privateKey,
              onPressed: () async {
                var keyOptions = openpgp.KeyOptions()
                  ..algorithm = openpgp.Algorithm.EDDSA;
                var keyPair = await openpgp.OpenPGP.generate(
                  options: openpgp.Options()
                    ..name = 'test'
                    ..email = 'test@test.com'
                    ..passphrase = 'test'
                    ..keyOptions = keyOptions,
                );
                setState(() {
                  _keyPair = keyPair;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
