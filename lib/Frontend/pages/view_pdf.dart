import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewPDF extends StatelessWidget {
  final Uint8List asset;

  const ViewPDF({required this.asset, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: PdfViewer.data(
        asset,
        sourceName: '',
      ),
    );
  }
}
