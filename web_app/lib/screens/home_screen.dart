import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/professor.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  List<Professor> _items = [];
  List<String> _faculties = [];
  bool _facultiesLoading = true;
  String? _selectedFaculty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFaculties();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Loads every non-empty faculty string from the table (paginated), then dedupes.
  Future<void> _loadFaculties() async {
    setState(() => _facultiesLoading = true);
    try {
      const pageSize = 1000;
      final seen = <String>{};
      for (var from = 0; ; from += pageSize) {
        final rows = await Supabase.instance.client
            .from('professors')
            .select('faculty')
            .order('id')
            .range(from, from + pageSize - 1);
        if (rows.isEmpty) break;
        for (final r in rows) {
          final f = r['faculty'] as String?;
          if (f != null && f.isNotEmpty) {
            seen.add(f);
          }
        }
        if (rows.length < pageSize) break;
      }
      final list = seen.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _faculties = list;
        _facultiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _faculties = [];
        _facultiesLoading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      var base = Supabase.instance.client.from('professors').select();
      if (_selectedFaculty != null && _selectedFaculty!.isNotEmpty) {
        base = base.eq('faculty', _selectedFaculty!);
      }
      final List<dynamic> rows;
      if (q.isEmpty) {
        rows = await base.order('name_en', ascending: true).limit(200);
      } else {
        final safe = q
            .replaceAll('%', '')
            .replaceAll(RegExp(r'[(),]'), ' ')
            .trim();
        final pattern = '%$safe%';
        rows = await base
            .or(
              'name_en.ilike.$pattern,name_zh.ilike.$pattern,faculty.ilike.$pattern,department.ilike.$pattern,research_interests.ilike.$pattern',
            )
            .order('name_en', ascending: true)
            .limit(200);
      }
      setState(() {
        _items = rows
            .map((e) => Professor.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HKU professors (mirror)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBar(
                  controller: _search,
                  hintText: 'Search name, faculty, department, interests',
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
                  ],
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _facultiesLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedFaculty,
                      borderRadius: BorderRadius.circular(4),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All faculties'),
                        ),
                        ..._faculties.map(
                          (f) => DropdownMenuItem<String?>(
                            value: f,
                            child: Text(f, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: _facultiesLoading
                          ? null
                          : (v) {
                              setState(() => _selectedFaculty = v);
                              _load();
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('No rows yet. Run the Python sync job against Supabase.'),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _items[i];
        final sub = [
          if (p.faculty != null && p.faculty!.isNotEmpty) p.faculty,
          if (p.department != null && p.department!.isNotEmpty) p.department,
        ].whereType<String>().join(' · ');
        return ListTile(
          title: Text(p.displayName),
          subtitle: sub.isEmpty ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DetailScreen(professor: p),
              ),
            );
          },
        );
      },
    );
  }
}
