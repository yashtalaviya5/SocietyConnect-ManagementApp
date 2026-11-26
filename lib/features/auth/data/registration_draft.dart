enum AccountRole { admin, resident }

class RegistrationDraft {
  const RegistrationDraft({
    required this.role,
    required this.fullName,
    required this.mobile,
    required this.societyId,
    this.societyName = '',
    this.address = '',
    this.contactNumber = '',
    this.flatNumber = '',
    this.flatId = '',
  });

  final AccountRole role;
  final String fullName;
  final String mobile;
  final String societyId;
  final String societyName;
  final String address;
  final String contactNumber;
  final String flatNumber;
  final String flatId;

  String get roleValue => role.name;
}
