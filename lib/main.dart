import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Default IP for fresh installs
const String _defaultIp = "192.168.0.202";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('server_ip') == null) {
    await prefs.setString('server_ip', _defaultIp);
  }
  runApp(const PrintApp());
}

class PrintApp extends StatelessWidget {
  const PrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Print App",
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
        ),
        scaffoldBackgroundColor: Colors.black,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
          labelStyle: TextStyle(color: Colors.orange),
        ),
      ),
      home: const PrintScreen(),
    );
  }
}

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _fromController = TextEditingController(
    text:
    "Aniruddha Innovatives, A24, Yashashree Industrial Premises, "
        "F-2 Block, MIDC, Above Tata Motors Showroom, Pimpri Colony, Pimpri-Chinchwad, Maharashtra 411018",
  );
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = false;
  String _status = "";

  Future<String> _getServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("server_ip") ?? _defaultIp;
  }

  Future<File> _generatePdf(
      String address, String from, String name, String phone) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          final pageWidth = PdfPageFormat.a4.landscape.width;
          final pageHeight = PdfPageFormat.a4.landscape.height;

          // Define the area for "To," + address
          final contentWidth = pageWidth * 0.75;   // 75% of page width
          final contentHeight = pageHeight * 0.5;  // top half of page

          // Vertical offsets
          final verticalOffsetTop = 80.0;   // shift "To," block upwards
          final verticalOffsetBottom = 5.0; // shift bottom-right block downward

          return pw.Stack(
            children: [
              // Left-aligned, vertically centered "To," + address
              pw.Positioned(
                top: (pageHeight - contentHeight) / 2 - verticalOffsetTop,
                left: (pageWidth - contentWidth) / 2,
                child: pw.Container(
                  width: contentWidth,
                  height: contentHeight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "To,",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 36,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Expanded(
                        child: pw.Text(
                          address,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 36,
                          ),
                          maxLines: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom-right info block
              pw.Positioned(
                bottom: verticalOffsetBottom,
                right: 40,
                child: pw.Container(
                  width: 400,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "From: $from",
                        style: const pw.TextStyle(fontSize: 12),
                        textAlign: pw.TextAlign.right,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Name: $name",
                        style: const pw.TextStyle(fontSize: 12),
                        textAlign: pw.TextAlign.right,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Phone Number: $phone",
                        style: const pw.TextStyle(fontSize: 12),
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/to_print.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }



  Future<void> _previewPdf() async {
    final address = _addressController.text.trim();
    final from = _fromController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (address.isEmpty || from.isEmpty || name.isEmpty || phone.isEmpty) {
      setState(() => _status = "Please fill all fields.");
      return;
    }

    setState(() {
      _loading = true;
      _status = "";
    });

    try {
      final pdfFile = await _generatePdf(address, from, name, phone);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfFile: pdfFile,
            onPrint: () async {
              Navigator.pop(context);
              await _sendPdfToPrinter(pdfFile);
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _status = "Failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendPdfToPrinter(File pdfFile) async {
    setState(() => _loading = true);
    try {
      final serverIp = await _getServerIp();
      final url = Uri.parse("http://$serverIp:5000/upload");
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', pdfFile.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        setState(() => _status = "Sent to printer ✅");
      } else {
        setState(() => _status = "Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _status = "Failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Print App"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.orange),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _addressController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: "Address"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fromController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "From"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading ? null : _previewPdf,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("Preview & Print", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class PdfPreviewScreen extends StatelessWidget {
  final File pdfFile;
  final VoidCallback onPrint;

  const PdfPreviewScreen({super.key, required this.pdfFile, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preview PDF"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.orange),
            onPressed: onPrint,
          )
        ],
      ),
      body: SfPdfViewer.file(pdfFile),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    _ipController.text = prefs.getString("server_ip") ?? _defaultIp;
    setState(() {});
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("server_ip", _ipController.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: "PC IP Address"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              onPressed: _saveIp,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}