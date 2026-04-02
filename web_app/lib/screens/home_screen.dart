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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      final base = Supabase.instance.client.from('professors').select();
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
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
