/// A study grade ("فرقة") offered by a [CenterModel].
class GradeModel {
  const GradeModel({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;
}

/// A tutoring center a student can search for and join — currently backed
/// by dummy data ([centerDummyData]) rather than a real `/public/centers`
/// endpoint.
class CenterModel {
  const CenterModel({
    required this.id,
    required this.name,
    required this.code,
    this.logo,
    this.cover,
    this.description,
    this.address,
    required this.primaryColor,
    this.phoneNumbers = const [],
    this.email,
    this.socialLinks = const {},
    required this.rating,
    required this.studentsCount,
    this.isActive = true,
    this.grades = const [],
  });

  final int id;
  final String name;
  final String code;
  final String? logo;
  final String? cover;
  final String? description;
  final String? address;

  /// Hex string, e.g. `"#4338CA"` — kept as a plain string here since this
  /// entity is UI-framework agnostic; the presentation layer parses it into
  /// a `Color`.
  final String primaryColor;
  final List<String> phoneNumbers;

  /// The center's contact email (`email` / `contact_email` in the API).
  final String? email;

  /// Keys: facebook, whatsapp, youtube, telegram, instagram, tiktok,
  /// website. Only keys the center actually set should be present.
  final Map<String, String?> socialLinks;
  final double rating;
  final int studentsCount;
  final bool isActive;
  final List<GradeModel> grades;

  /// First letter of [name], used as a placeholder avatar until real center
  /// logos exist.
  CenterModel copyWith({String? logo, String? cover}) => CenterModel(
    id: id,
    name: name,
    code: code,
    logo: logo ?? this.logo,
    cover: cover ?? this.cover,
    description: description,
    address: address,
    primaryColor: primaryColor,
    phoneNumbers: phoneNumbers,
    email: email,
    socialLinks: socialLinks,
    rating: rating,
    studentsCount: studentsCount,
    isActive: isActive,
    grades: grades,
  );

  String get initial => name.isNotEmpty ? name.substring(0, 1) : '؟';
}
