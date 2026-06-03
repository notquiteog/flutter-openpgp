import 'package:flutter/material.dart';

class ButtonWidget extends StatefulWidget {
  const ButtonWidget({
    super.key,
    required this.result,
    required this.title,
    required this.onPressed,
  });

  final Function onPressed;
  final String title;
  final String result;

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          ElevatedButton(
            onPressed: () async {
              await widget.onPressed();
              setState(() {
                _loading = false;
              });
            },
            key: Key("button"),
            child: Text(widget.title),
          ),
          (_loading)
              ? Text(widget.result, key: Key("loading"))
              : Text(widget.result, key: Key("result")),
        ],
      ),
    );
  }
}
