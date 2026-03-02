class Player {
  final String id;
  final String name;
  final bool active;

  const Player({required this.id, required this.name, this.active = true});

  Player copyWith({String? id, String? name, bool? active}) => Player(
        id: id ?? this.id,
        name: name ?? this.name,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'active': active};

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String,
        active: (j['active'] as bool?) ?? true,
      );
}
