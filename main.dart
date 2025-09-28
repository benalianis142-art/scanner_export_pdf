import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() {
  runApp(const MyApp());
}

class Item {
  final String code;
  int quantity;
  Item({required this.code, required this.quantity});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner & Export PDF',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController manualCodeController = TextEditingController();
  final List<Item> items = [];
  bool isScanning = true;
  String lastScanned = '';

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    if (code == lastScanned) return;
    lastScanned = code;

    final int q = int.tryParse(qtyController.text) ?? 1;
    setState(() {
      final idx = items.indexWhere((e) => e.code == code);
      if (idx >= 0) {
        items[idx].quantity += q;
      } else {
        items.add(Item(code: code, quantity: q));
      }
    });
  }

  void _addManual() {
    final code = manualCodeController.text.trim();
    if (code.isEmpty) return;
    final int q = int.tryParse(qtyController.text) ?? 1;
    setState(() {
      final idx = items.indexWhere((e) => e.code == code);
      if (idx >= 0) {
        items[idx].quantity += q;
      } else {
        items.add(Item(code: code, quantity: q));
      }
      manualCodeController.clear();
    });
  }

  void _removeItem(Item it) {
    setState(() {
      items.remove(it);
    });
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Liste d\'articles', style: pw.TextStyle(fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['#', 'Code-barres / Référence', 'Quantité'],
                data: List<List<String>>.generate(
                  items.length,
                  (i) => [
                    '${i + 1}',
                    items[i].code,
                    items[i].quantity.toString()
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Text('Généré le : ${DateTime.now().toLocal()}',
                  style: pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'liste_articles.pdf');
  }

  @override
  void dispose() {
    cameraController.dispose();
    qtyController.dispose();
    manualCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner & Export PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: items.isEmpty ? null : _exportPdf,
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            width: mq.width,
            height: mq.height * 0.35,
            child: MobileScanner(
              controller: cameraController,
              allowDuplicates: false,
              onDetect: _onDetect,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantité',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: manualCodeController,
                    decoration: InputDecoration(
                      labelText: 'Code (manuel)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addManual,
                      ),
                    ),
                    onSubmitted: (_) => _addManual(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Aucun article pour l\'instant'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(it.code),
                        subtitle: Text('Quantité: ${it.quantity}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeItem(it),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: items.isEmpty ? null : _exportPdf,
        label: const Text('Exporter PDF'),
        icon: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
