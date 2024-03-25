import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class ViewPDF extends StatelessWidget {
  ViewPDF({super.key, required String assetPath}) {
    pdfPinchController = PdfControllerPinch(
      document: PdfDocument.openFile(assetPath),
    );
  }

  late final PdfControllerPinch pdfPinchController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: PdfViewPinch(
        controller: pdfPinchController,
      ),
    );
  }
}
