class AppTarget {
  final String id;
  final String name;
  final String? iconBase64;
  final bool selected;

  const AppTarget({
    required this.id,
    required this.name,
    this.iconBase64,
    this.selected = false,
  });

  AppTarget copyWith({bool? selected}) => AppTarget(
        id: id,
        name: name,
        iconBase64: iconBase64,
        selected: selected ?? this.selected,
      );

  factory AppTarget.fromMap(Map<dynamic, dynamic> m) => AppTarget(
        id: m['id'] as String,
        name: m['name'] as String,
        iconBase64: m['iconBase64'] as String?,
      );
}
