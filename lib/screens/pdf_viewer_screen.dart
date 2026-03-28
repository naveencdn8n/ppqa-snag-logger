import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/ppqa_app_bar.dart';

/// A placeholder screen for PDF documents.
///
/// In FlutterFlow, replace the body with FF's native PDF viewer component
/// using the same [title] and [pdfUrl] parameters.
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  final String title;
  final String pdfUrl;

  Future<void> _launchPdf() async {
    final uri = Uri.parse(pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PPQAAppBar(title: title, showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  size: 72,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to open this document in your PDF viewer.',
                style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Document'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                onPressed: _launchPdf,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
