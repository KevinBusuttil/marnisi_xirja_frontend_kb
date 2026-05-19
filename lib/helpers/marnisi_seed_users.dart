class MarnisiSeedUser {
  final String personalId;
  final String userGroup;
  final String firstName;
  final String lastName;
  final String email;

  const MarnisiSeedUser({
    required this.personalId,
    required this.userGroup,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  Map<String, dynamic> toLocalDbRow() {
    return {
      'user_personnel_id': personalId,
      'user_group': userGroup,
      'user_email': email,
      'user_first_name': firstName,
      'user_last_name': lastName,
    };
  }
}

const List<MarnisiSeedUser> marnisiSeedUsers = <MarnisiSeedUser>[
  MarnisiSeedUser(
    personalId: '11111',
    userGroup: 'Vineyard Admin',
    firstName: 'North',
    lastName: 'Admin',
    email: 'marnisi.admin.north@example.com',
  ),
  MarnisiSeedUser(
    personalId: '22222',
    userGroup: 'Vineyard Admin',
    firstName: 'South',
    lastName: 'Admin',
    email: 'marnisi.admin.south@example.com',
  ),
  MarnisiSeedUser(
    personalId: '33333',
    userGroup: 'Vineyard Staff',
    firstName: 'Vineyard',
    lastName: 'Staff',
    email: 'marnisi.staff@example.com',
  ),
  MarnisiSeedUser(
    personalId: '44444',
    userGroup: 'Viewer',
    firstName: 'Vineyard',
    lastName: 'Viewer',
    email: 'marnisi.viewer@example.com',
  ),
];
