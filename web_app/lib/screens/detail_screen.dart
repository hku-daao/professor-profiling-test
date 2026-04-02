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
        final url = pub['url']?.toString();
        return ListTile(
          title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [if (journal.isNotEmpty) journal, if (date.isNotEmpty) date].join(' · '),
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
        final title = g['title']?.toString() ?? '';
        final code = g['project_code']?.toString() ?? '';
        final year = g['funding_year']?.toString() ?? '';
        final status = g['status']?.toString() ?? '';
        final url = g['url']?.toString();
        return ListTile(
          title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text([status, code, year].where((x) => x.isNotEmpty).join(' · ')),
          trailing: url != null && url.isNotEmpty
              ? IconButton(icon: const Icon(Icons.link), onPressed: () => onOpen(url))
              : null,
          onTap: url != null && url.isNotEmpty ? () => onOpen(url) : null,
        );
      },
    );
  }
}
