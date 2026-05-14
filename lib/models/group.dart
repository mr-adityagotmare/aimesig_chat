class Group {
  final String id;
  final String name;
  final String creatorDeviceId;
  final List<String> memberDeviceIds; // deviceIds of members
  final List<String> memberNames;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.creatorDeviceId,
    required this.memberDeviceIds,
    required this.memberNames,
    required this.createdAt,
  });

  bool get isValid => memberDeviceIds.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'creatorDeviceId': creatorDeviceId,
        'memberDeviceIds': memberDeviceIds.join(','),
        'memberNames': memberNames.join(','),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Group.fromMap(Map<String, dynamic> map) => Group(
        id: map['id'],
        name: map['name'],
        creatorDeviceId: map['creatorDeviceId'],
        memberDeviceIds: (map['memberDeviceIds'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        memberNames: (map['memberNames'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );

  Group copyWith({List<String>? memberDeviceIds, List<String>? memberNames}) =>
      Group(
        id: id,
        name: name,
        creatorDeviceId: creatorDeviceId,
        memberDeviceIds: memberDeviceIds ?? this.memberDeviceIds,
        memberNames: memberNames ?? this.memberNames,
        createdAt: createdAt,
      );
}
