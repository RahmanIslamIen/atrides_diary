import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
// Dalam proyek nyata, Anda perlu menambahkan path_provider ke pubspec.yaml
import 'package:path_provider/path_provider.dart';

// Variabel global disediakan (tidak digunakan di sini karena kita menggunakan lokal storage)
const String __app_id = 'flutter-diary-app';
final String __firebase_config = '{}';
final String __initial_auth_token = '';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiaryApp());
}

// Model untuk Entri Diari
class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  // Factory constructor untuk membuat objek dari Map JSON
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      // Konversi string ISO 8601 kembali ke DateTime
      date: DateTime.parse(json['date'] as String),
    );
  }

  // Konversi objek ke Map JSON untuk disimpan
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      // Konversi DateTime ke string ISO 8601
      'date': date.toIso8601String(),
    };
  }
}

// Service untuk menangani operasi file I/O
class DiaryService {
  // Nama file penyimpanan lokal
  static const String _fileName = 'atrides_diary_data.json';

  // Mendapatkan path lengkap ke file penyimpanan
  Future<File> _getLocalFile() async {
    // path_provider akan memberikan direktori data aplikasi (Aman untuk dihapus saat uninstall)
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  // Memuat semua entri diari dari file
  Future<List<DiaryEntry>> loadEntries() async {
    try {
      final file = await _getLocalFile();
      // Pastikan file ada sebelum mencoba membacanya
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      // Decode string JSON menjadi List of Maps
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => DiaryEntry.fromJson(json)).toList();
    } catch (e) {
      print("Error loading diary entries: $e");
      return []; // Kembalikan list kosong jika ada error
    }
  }

  // Menyimpan semua entri diari ke file
  Future<void> saveEntries(List<DiaryEntry> entries) async {
    try {
      final file = await _getLocalFile();
      // Konversi List<DiaryEntry> menjadi List<Map> dan kemudian menjadi string JSON
      final jsonList = entries.map((entry) => entry.toJson()).toList();
      final contents = json.encode(jsonList);

      await file.writeAsString(contents);
    } catch (e) {
      print("Error saving diary entries: $e");
    }
  }
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Diari Lokal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DiaryHomePage(),
    );
  }
}

class DiaryHomePage extends StatefulWidget {
  const DiaryHomePage({super.key});

  @override
  State<DiaryHomePage> createState() => _DiaryHomePageState();
}

class _DiaryHomePageState extends State<DiaryHomePage> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;
  final DiaryService _diaryService = DiaryService();

  // ID pengguna disimulasikan sebagai string unik acak untuk memenuhi persyaratan UI
  final String _mockUserId =
      'Local-User-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Memuat data awal saat aplikasi dimulai
  Future<void> _loadInitialData() async {
    final loadedEntries = await _diaryService.loadEntries();
    setState(() {
      _entries = loadedEntries;
      _isLoading = false;
    });
  }

  // Fungsi untuk menampilkan dialog tambah entri baru
  void _showAddEntryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEntryDialog(onSave: _addDiaryEntry);
      },
    );
  }

  // Fungsi untuk menambahkan entri baru ke list dan menyimpannya ke file
  Future<void> _addDiaryEntry(String title, String content) async {
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan Konten tidak boleh kosong!')),
      );
      return;
    }

    // Buat ID unik sederhana (simulasi)
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newEntry = DiaryEntry(
      id: newId,
      title: title,
      content: content,
      date: DateTime.now(),
    );

    // Perbarui state lokal dan simpan ke file
    setState(() {
      // Tambahkan di awal agar yang terbaru muncul di atas
      _entries.insert(0, newEntry);
    });

    await _diaryService.saveEntries(_entries);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entri diari berhasil disimpan secara lokal!'),
        ),
      );
    }
  }

  // Fungsi untuk menghapus entri dari list dan menyimpannya ke file
  Future<void> _deleteEntry(String entryId) async {
    // Perbarui state lokal
    setState(() {
      _entries.removeWhere((entry) => entry.id == entryId);
    });

    // Simpan ke file
    await _diaryService.saveEntries(_entries);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entri diari berhasil dihapus!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diari Lokal Pribadi Saya (File I/O)'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'User ID (Lokal): $_mockUserId', // Tampilkan ID pengguna simulasi
                style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800,
          ), // Batasi lebar untuk desktop
          child: Column(children: [Expanded(child: _buildDiaryList())]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntryDialog,
        tooltip: 'Tambah Entri Baru',
        icon: const Icon(Icons.add),
        label: const Text('Entri Baru'),
      ),
    );
  }

  // Widget untuk menampilkan daftar entri
  Widget _buildDiaryList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada entri diari. Tambahkan yang pertama! (Disimpan Lokal)',
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        // Format tanggal agar lebih mudah dibaca
        final formattedDate =
            '${entry.date.day.toString().padLeft(2, '0')}/'
            '${entry.date.month.toString().padLeft(2, '0')}/'
            '${entry.date.year} '
            '${entry.date.hour.toString().padLeft(2, '0')}:'
            '${entry.date.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: Colors.blueGrey[700],
          child: ListTile(
            leading: const Icon(Icons.book_online, color: Colors.amber),
            title: Text(
              entry.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              '$formattedDate - ${entry.content}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[300]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.visibility,
                    color: Colors.lightBlueAccent,
                  ),
                  onPressed: () => _showEntryDetails(entry),
                  tooltip: 'Lihat Detail',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _deleteEntry(entry.id),
                  tooltip: 'Hapus Entri',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fungsi untuk menampilkan detail entri
  void _showEntryDetails(DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tanggal: ${entry.date.day}/${entry.date.month}/${entry.date.year}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                ),
                const Divider(),
                Text(entry.content, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Tutup',
                style: TextStyle(color: Colors.lightBlueAccent),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// Dialog untuk menambah entri baru
class AddEntryDialog extends StatefulWidget {
  final Function(String title, String content) onSave;

  const AddEntryDialog({super.key, required this.onSave});

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Entri Diari Baru'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500, // Lebar yang sesuai untuk desktop
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Konten Diari',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                minLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Batal'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton.icon(
          onPressed: () {
            widget.onSave(_titleController.text, _contentController.text);
            Navigator.of(context).pop(); // Tutup dialog setelah menyimpan
          },
          icon: const Icon(Icons.save),
          label: const Text('Simpan Entri'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
