import 'package:itaaleem/features/center/domain/entities/center_model.dart';

/// Stand-in for a future `GET /public/centers` response — 5 fake centers
/// covering a spread of ratings, sizes and contact-info combinations so the
/// UI (search, profile, grade selection) has real variety to render.
final List<CenterModel> centerDummyData = [
  const CenterModel(
    id: 1,
    name: 'سنتر الأستاذ عامر',
    code: 'AX-204',
    description:
        'سنتر متخصص في تأهيل طلاب الكهرباء بأحدث المعامل والمدرسين المتميزين.',
    address: 'شارع الجمهورية، المنصورة',
    primaryColor: '#4338CA',
    phoneNumbers: ['01012345678', '01112345678'],
    socialLinks: {
      'facebook': 'https://facebook.com/amer.center',
      'whatsapp': 'https://wa.me/201012345678',
      'youtube': 'https://youtube.com/@amer.center',
    },
    rating: 4.8,
    studentsCount: 320,
    grades: [
      GradeModel(id: 1, name: 'الكورس الأول — كهرباء', sortOrder: 1),
      GradeModel(id: 2, name: 'الكورس الثاني — كهرباء', sortOrder: 2),
      GradeModel(id: 3, name: 'الكورس الثالث — كهرباء', sortOrder: 3),
    ],
  ),
  const CenterModel(
    id: 2,
    name: 'مركز النور التعليمي',
    code: 'NR-118',
    description: 'مركز تعليمي متخصص في تخصص الميكانيكا لطلاب المعاهد الفنية.',
    address: 'شارع النصر، طنطا',
    primaryColor: '#047857',
    phoneNumbers: ['01098765432'],
    socialLinks: {
      'facebook': 'https://facebook.com/alnoor.center',
      'whatsapp': 'https://wa.me/201098765432',
    },
    rating: 4.5,
    studentsCount: 210,
    grades: [
      GradeModel(id: 4, name: 'الكورس الأول — ميكانيكا', sortOrder: 1),
      GradeModel(id: 5, name: 'الكورس الثاني — ميكانيكا', sortOrder: 2),
    ],
  ),
  const CenterModel(
    id: 3,
    name: 'أكاديمية الفيصل',
    code: 'FS-331',
    description: 'أكاديمية تعليمية تقدم شرح مكثف ومتابعة دورية لكل طالب.',
    address: 'شارع الجيش، الزقازيق',
    primaryColor: '#DC2626',
    phoneNumbers: ['01234567890'],
    socialLinks: {'facebook': 'https://facebook.com/alfaisal.academy'},
    rating: 4.2,
    studentsCount: 150,
    grades: [
      GradeModel(id: 6, name: 'الكورس الأول', sortOrder: 1),
      GradeModel(id: 7, name: 'الكورس الثاني', sortOrder: 2),
    ],
  ),
  const CenterModel(
    id: 4,
    name: 'معهد التفوق',
    code: 'TF-500',
    description: 'معهد التفوق أكبر سنتر معتمد بمتابعة أسبوعية وامتحانات دورية.',
    address: 'شارع الثورة، أسيوط',
    primaryColor: '#7C3AED',
    phoneNumbers: ['01555555555', '01666666666'],
    socialLinks: {
      'whatsapp': 'https://wa.me/201555555555',
      'instagram': 'https://instagram.com/altafawoq.institute',
      'tiktok': 'https://tiktok.com/@altafawoq.institute',
    },
    rating: 4.9,
    studentsCount: 500,
    grades: [
      GradeModel(id: 8, name: 'الكورس الأول', sortOrder: 1),
      GradeModel(id: 9, name: 'الكورس الثاني', sortOrder: 2),
      GradeModel(id: 10, name: 'الكورس الثالث', sortOrder: 3),
    ],
  ),
  const CenterModel(
    id: 5,
    name: 'سنتر المستقبل',
    code: 'MQ-205',
    description: 'سنتر حديث بإمكانيات بسيطة يناسب الطلاب المبتدئين.',
    address: 'شارع الاستاد، بنها',
    primaryColor: '#0369A1',
    phoneNumbers: ['01777777777'],
    socialLinks: {
      'telegram': 'https://t.me/almostakbal_center',
      'whatsapp': 'https://wa.me/201777777777',
    },
    rating: 3.8,
    studentsCount: 80,
    grades: [
      GradeModel(id: 11, name: 'الكورس الأول', sortOrder: 1),
      GradeModel(id: 12, name: 'الكورس الثاني', sortOrder: 2),
    ],
  ),
];
