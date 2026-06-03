import 'package:flutter/material.dart';

import 'package:openpgp/openpgp.dart';
import 'package:openpgp_example/main.dart';
import 'package:openpgp_example/shared/button_widget.dart';
import 'package:openpgp_example/shared/input_widget.dart';
import 'package:openpgp_example/shared/title_widget.dart';

class EncryptAndDecrypt extends StatefulWidget {
  const EncryptAndDecrypt({
    super.key,
    required this.title,
    required this.keyPair,
  });

  final KeyPair? keyPair;
  final String title;

  @override
  State<EncryptAndDecrypt> createState() => _EncryptAndDecryptState();
}

class _EncryptAndDecryptState extends State<EncryptAndDecrypt> {
  String _encrypted = "";
  String _decrypted = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Card(
        child: Column(
          children: [
            TitleWidget(widget.title),
            InputWidget(
              title: "Encrypt",
              key: Key("encrypt"),
              result: _encrypted,
              onPressed: (controller) async {
                try {
                  var encrypted = await OpenPGP.encrypt(
                    controller.text,
                    widget.keyPair!.publicKey,
                  );
                  setState(() {
                    _encrypted = encrypted;
                  });
                } catch (e) {
                  debugPrint(e.toString());
                }
              },
            ),
            ButtonWidget(
              title: "Decrypt",
              key: Key("decrypt"),
              result: _decrypted,
              onPressed: () async {
                var decrypted = await OpenPGP.decrypt(
                  _encrypted,
                  widget.keyPair!.privateKey,
                  passphrase,
                );
                setState(() {
                  _decrypted = decrypted;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
