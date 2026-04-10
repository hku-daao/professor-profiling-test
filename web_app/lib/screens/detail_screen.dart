import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/professor.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.professor});

  final Professor professor;

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = professor;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Publications'),
              Tab(text: 'External'),
              Tab(text: 'Responsibilities'),
              Tab(text: 'Grants'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(professor: p, onOpen: _open),
            _PublicationsTab(publications: p.publications, onOpen: _open),
            _SectionsTab(sections: p.externalRelations),
            _SectionsTab(sections: p.universityResponsibilities),
            _GrantsTab(grants: p.grants, onOpen: _open),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.professor, required this.onOpen});

  final Professor professor;
  final Future<void> Function(String?) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = professor;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (p.displayHeading != null && p.displayHeading!.isNotEmpty)
          Text(
            p.displayHeading!,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        const SizedBox(height: 12),
        if (p.nameZh != null && p.nameZh!.isNotEmpty)
          Text('Chinese name: ${p.nameZh}', style: Theme.of(context).textTheme.bodyLarge),
        if (p.titles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Titles', style: Theme.of(context).textTheme.titleMedium),
          ...p.titles.map((t) => Text('· $t')),
        ],
        if (p.faculty != null && p.faculty!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Faculty: ${p.faculty}'),
        ],
        if (p.department != null && p.department!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Department: ${p.department}'),
        ],
        if (p.researchInterests != null && p.researchInterests!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Research interests', style: Theme.of(context).textTheme.titleMedium),
          Text(p.researchInterests!),
        ],
        if (p.syncedAt != null) ...[
          const SizedBox(height: 16),
          Text(
            'Last synced: ${p.syncedAt!.toUtc()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => onOpen(p.profileUrl),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open HKU Scholars Hub profile'),
        ),
      ],
    );
  }
}

class _PublicationsTab extends StatelessWidget {
  const _PublicationsTab({required this.publications, required this.onOpen});

  final List<Map<String, dynamic>> publications;
  final Future<void> Function(String?) onOpen;

  @override
  Widget build(BuildContext context) {
    if (publications.isEmpty) {
      return const Center(child: Text('No publications in database for this profile.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: publications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final pub = publications[i];
        final title = pub['title']?.toString() ?? '';
        final journal = pub['journal']?.toString() ?? '';
        final date = pub['issue_date']?.toString() ?? '';
        final abstract = pub['abstract']?.toString() ?? '';
        final url = pub['url']?.toString();
        final meta = [
          if (journal.isNotEmpty) journal,
          if (date.isNotEmpty) date,
        ].join(' · ');
        if (abstract.isNotEmpty) {
          return ExpansionTile(
            title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: meta.isEmpty ? null : Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
            children: [
              if (url != null && url.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open HKU item page'),
                  onTap: () => onOpen(url),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abstract', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      SelectableText(
                        abstract,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return ListTile(
          title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: url != null && url.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () => onOpen(url),
                )
              : null,
          onTap: url != null && url.isNotEmpty ? () => onOpen(url) : null,
        );
      },
    );
  }
}

class _SectionsTab extends StatelessWidget {
  const _SectionsTab({required this.sections});

  final List<Map<String, dynamic>> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Center(child: Text('No entries in database for this section.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        final name = s['section']?.toString() ?? 'Section';
        final entries = (s['entries'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(name),
            children: entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(e),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

List<Widget> _grantDetailFields(Map<String, dynamic> g) {
  const spec = <(String, String)>[
    ('principal_investigator', 'Principal investigator'),
    ('duration', 'Duration'),
    ('start_date', 'Start date'),
    ('completion_date', 'Completion date'),
    ('grant_type', 'Grant type'),
    ('discipline', 'Discipline'),
    ('panel', 'Panel'),
    ('keywords', 'Keywords'),
    ('conference_title', 'Conference title'),
    ('objectives', 'Objectives'),
    ('project_title', 'Project title'),
    ('hku_project_code', 'HKU project code'),
    ('funding_year', 'Funding year'),
    ('status', 'Status'),
    ('amount', 'Amount'),
  ];
  final out = <Widget>[];
  for (final row in spec) {
    final v = g[row.$1]?.toString().trim();
    if (v == null || v.isEmpty) continue;
    out.add(
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SelectableText.rich(
          TextSpan(
            style: const TextStyle(height: 1.35),
            children: [
              TextSpan(
                text: '${row.$2}: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: v),
            ],
          ),
        ),
      ),
    );
  }
  return out;
}

class _GrantsTab extends StatelessWidget {
  const _GrantsTab({required this.grants, required this.onOpen});

  final List<Map<String, dynamic>> grants;
  final Future<void> Function(String?) onOpen;

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) {
      return const Center(child: Text('No grants in database for this profile.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: grants.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final g = grants[i];
        final title = (g['title'] ?? g['project_title'])?.toString() ?? '';
        final code = g['project_code']?.toString() ?? '';
        final year = g['funding_year']?.toString() ?? '';
        final status = g['status']?.toString() ?? '';
        final rawRole = g['grant_role']?.toString() ?? '';
        final roleLabel = switch (rawRole) {
          'principal_investigator' => 'PI',
          'co_investigator' => 'Co-I',
          'unknown' => '',
          _ when rawRole.isNotEmpty => rawRole,
          _ => '',
        };
        final url = g['url']?.toString();
        final details = _grantDetailFields(g);
        return ExpansionTile(
          title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [roleLabel, status, code, year].where((x) => x.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...details,
                  if (details.isEmpty)
                    const Text(
                      'Run a full sync with FETCH_GRANT_DETAILS=true to load project-page fields.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  if (url != null && url.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => onOpen(url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open project page'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
