import 'package:flutter/material.dart';

/// One "مادة" row on the (dummy, ahead-of-backend) "موادي" tab and its
/// detail screen — shared between [SubjectsScreen] and [SubjectDetailScreen]
/// so both agree on name/teacher/progress for the same [id].
class DummySubject {
  const DummySubject({
    required this.id,
    required this.name,
    required this.teacher,
    required this.icon,
    required this.lecturesTotal,
    required this.progress,
    required this.description,
  });

  final int id;
  final String name;
  final String teacher;
  final IconData icon;
  final int lecturesTotal;

  /// 0.0–1.0.
  final double progress;
  final String description;

  int get lecturesDone => (progress * lecturesTotal).round();
}

const dummySubjects = <DummySubject>[
  DummySubject(
    id: 1,
    name: 'محاسبة مالية',
    teacher: 'أ. محمد عامر',
    icon: Icons.calculate_rounded,
    lecturesTotal: 20,
    progress: 0.75,
    description:
        'أساسيات المحاسبة المالية وإعداد القوائم المالية، مع تطبيقات عملية '
        'على دفاتر القيد والموازنات.',
  ),
  DummySubject(
    id: 2,
    name: 'تكنولوجيا المعلومات',
    teacher: 'أ. أحمد سمير',
    icon: Icons.computer_rounded,
    lecturesTotal: 20,
    progress: 0.60,
    description:
        'مقدمة في أنظمة الحاسب والشبكات وأساسيات البرمجة، مع مشاريع '
        'تطبيقية طول الترم.',
  ),
  DummySubject(
    id: 3,
    name: 'رياضيات تطبيقية',
    teacher: 'أ. خالد حسن',
    icon: Icons.functions_rounded,
    lecturesTotal: 20,
    progress: 0.40,
    description:
        'الجبر والتفاضل والتكامل التطبيقي، مع حل مسائل من واقع التخصصات '
        'الفنية.',
  ),
  DummySubject(
    id: 4,
    name: 'اللغة الإنجليزية',
    teacher: 'أ. سارة علي',
    icon: Icons.menu_book_rounded,
    lecturesTotal: 15,
    progress: 0.90,
    description: 'تنمية مهارات القراءة والمحادثة والمصطلحات الفنية بالإنجليزي.',
  ),
  DummySubject(
    id: 5,
    name: 'أساسيات الكهرباء',
    teacher: 'أ. عمرو فتحي',
    icon: Icons.bolt_rounded,
    lecturesTotal: 18,
    progress: 0.20,
    description:
        'مبادئ الدوائر الكهربائية وقوانين كيرشوف والتطبيقات العملية في '
        'المعامل.',
  ),
];

DummySubject? dummySubjectById(int id) {
  for (final subject in dummySubjects) {
    if (subject.id == id) return subject;
  }
  return null;
}
