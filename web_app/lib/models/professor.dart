class Professor {
  Professor({
    required this.id,
    required this.crisRpId,
    this.nameEn,
    this.nameZh,
    required this.titles,
    this.faculty,
    this.department,
    this.researchInterests,
    this.profileUrl,
    this.displayHeading,
    required this.publications,
    required this.externalRelations,
    required this.universityResponsibilities,
    required this.grants,
    this.syncedAt,
  });

  final String id;
  final String crisRpId;
  final String? nameEn;
  final String? nameZh;
  final List<String> titles;
  final String? faculty;
  final String? department;
  final String? researchInterests;
  final String? profileUrl;
  final String? displayHeading;
  final List<Map<String, dynamic>> publications;
  final List<Map<String, dynamic>> externalRelations;
  final List<Map<String, dynamic>> universityResponsibilities;
  final List<Map<String, dynamic>> grants;
  final DateTime? syncedAt;

  String get displayName => nameEn ?? displayHeading ?? crisRpId;

  factory Professor.fromJson(Map<String, dynamic> json) {
    List<String> titles = [];
    final t = json['titles'];
    if (t is List) {
      titles = t.map((e) => e.toString()).toList();
    }

    List<Map<String, dynamic>> asMapList(dynamic v) {
      if (v is! List) return [];
      return v
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    DateTime? synced;
    final s = json['synced_at'];
    if (s is String) {
      synced = DateTime.tryParse(s);
    }

    return Professor(
      id: json['id'] as String,
      crisRpId: json['cris_rp_id'] as String,
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      titles: titles,
      faculty: json['faculty'] as String?,
      department: json['department'] as String?,
      researchInterests: json['research_interests'] as String?,
      profileUrl: json['profile_url'] as String?,
      displayHeading: json['display_heading'] as String?,
      publications: asMapList(json['publications']),
      externalRelations: asMapList(json['external_relations']),
      universityResponsibilities:
          asMapList(json['university_responsibilities']),
      grants: asMapList(json['grants']),
      syncedAt: synced,
    );
  }
}
