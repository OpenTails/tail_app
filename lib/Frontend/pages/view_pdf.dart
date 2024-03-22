import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: PdfViewPinch(
        controller: pdfPinchController,
      ),
    );
  }
}
