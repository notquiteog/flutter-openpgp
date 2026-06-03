import 'dart:io';

import 'package:flutter/material.dart';

import 'package:openpgp/openpgp.dart';
import 'package:openpgp_example/main.dart';
import 'package:openpgp_example/shared/button_widget.dart';
import 'package:openpgp_example/shared/title_widget.dart';

class EncryptAndDecryptFile extends StatefulWidget {
  const EncryptAndDecryptFile({
    super.key,
    required this.title,
    required this.keyPair,
  });

  final KeyPair? keyPair;
  final String title;

  @override
  State<EncryptAndDecryptFile> createState() => _EncryptAndDecryptFileState();
}

class _EncryptAndDecryptFileState extends State<EncryptAndDecryptFile> {
  String _encrypted = "";
  String _decrypted = "";

  Future<void> _encrypt() async {
    String inputPath = "/home/usuario/Desktop/zip/sample.zip";
    File input = File(inputPath);
    debugPrint("start");
    var encrypted = await OpenPGP.encryptBytes(
      input.readAsBytesSync(),
      widget.keyPair!.publicKey,
      fileHints: FileHints()..isBinary = true,
    );
    debugPrint("end");
    String outputPath = "$inputPath.encrypted";
    debugPrint("output $outputPath");
    File output = File(outputPath);
    await output.writeAsBytes(encrypted);

    await File("$inputPath.pub").writeAsString(widget.keyPair!.publicKey);
    await File("$inputPath.key").writeAsString(widget.keyPair!.privateKey);

    debugPrint("saved");
    setState(() {
      _encrypted = "saved in $outputPath";
    });
  }

  Future<void> _decrypt() async {
    {
      String inputPath = "/home/usuario/Desktop/zip/sample.zip.encrypted";
      File input = File(inputPath);
      debugPrint("start");
      var decrypted = await OpenPGP.decryptBytes(
        input.readAsBytesSync(),
        widget.keyPair!.privateKey,
        passphrase,
      );
      debugPrint("end");
      String outputPath = "$inputPath.decrypted.zip";
      debugPrint("output $outputPath");
      File output = File(outputPath);
      await output.writeAsBytes(decrypted);
      debugPrint("saved");
      setState(() {
        _decrypted = "saved in $outputPath";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Card(
        child: Column(
          children: [
            TitleWidget(widget.title),
            ButtonWidget(
              title: "Encrypt file",
              key: Key("encrypt-file"),
              result: _encrypted,
              onPressed: _encrypt,
            ),
            ButtonWidget(
              title: "Decrypt file",
              key: Key("decrypt-file"),
              result: _decrypted,
              onPressed: _decrypt,
            ),
          ],
        ),
      ),
    );
  }
}
