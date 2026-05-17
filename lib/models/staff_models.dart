class Staff {
  final String id;
  final String name;
  final String role;

  Staff({required this.id, required this.name, required this.role});

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id'].toString(),
      name: map['name'],
      role: map['role'], // MANAGER, BARISTA, atau KASIR
    );
  }
}