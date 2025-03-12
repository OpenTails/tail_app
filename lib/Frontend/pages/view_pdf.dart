import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';

part 'view_pdf.freezed.dart';

@freezed
abstract class PDFInfo with _$PDFInfo {
  const factory PDFInfo({
    required String url,
    required String title,
  }) = _PDFInfo;
}

class ViewPDF extends StatefulWidget {
  final PDFInfo pdfInfo;

  const ViewPDF({required this.pdfInfo, super.key});

  @override
  State<ViewPDF> createState() => _ViewPDFState();
}

class _ViewPDFState extends State<ViewPDF> {
  CancelToken cancelToken = CancelToken();
  double progress = 0;

  Uint8List? data;
  PdfControllerPinch? pdfPinchController;

  @override
  void dispose() {
    super.dispose();
    cancelToken.cancel();
  }

  @override
  void initState() {
    super.initState();
    downloadPDF();
  }

  Future<void> downloadPDF() async {
    final Response<List<int>> rs = await (await initDio()).get(
      widget.pdfInfo.url,
      cancelToken: cancelToken,
      options: Options(
        contentType: 'application/pdf',
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (current, total) {
        setState(
          () {
            progress = current / total;
          },
        );
      },
    );
    if (rs.statusCode! < 400) {
      if (context.mounted) {
        progress = 0;
        setState(() {
          data = Uint8List.fromList(rs.data!);
        });
      }
    } else {
      setState(
        () {
          progress = 0;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.pdfInfo.title),
        ),
        body: AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: Builder(
              key: ValueKey(data != null),
              builder: (context) {
                if (data != null) {
                  pdfPinchController ??= PdfControllerPinch(
                    document: PdfDocument.openData(data!),
                  );
                  return PdfViewPinch(
                    controller: pdfPinchController!,
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress,
                    ),
                  );
                }
              }),
        ));
  }
}
