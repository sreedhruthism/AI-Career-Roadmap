import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // ✅ Needed for RenderRepaintBoundary
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfHandler {
  Future<void> createResume(GlobalKey key) async {
    try {
      // Ensure currentContext exists
      if (key.currentContext == null) {
        throw Exception("GlobalKey context is null");
      }

      // Get the boundary from the RepaintBoundary
      final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Convert boundary to image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Create PDF document
      final pdf = pw.Document();
      final imagePdf = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(imagePdf));
          },
        ),
      );

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/resume.pdf");
      await file.writeAsBytes(await pdf.save());

      print("PDF saved at: ${file.path}");
    } catch (e) {
      print("Error generating PDF: $e");
      rethrow;
    }
  }
}
