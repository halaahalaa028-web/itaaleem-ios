/// Every center-admin screen lives under `/center-admin/` (registered in
/// `app_router.dart`, admin-only via its redirect).
const centerAdminPath = '/center-admin';
const centerAdminStudentsPath = '$centerAdminPath/students';
String centerAdminStudentPath(int id) => '$centerAdminStudentsPath/$id';
const centerAdminSubjectsPath = '$centerAdminPath/subjects';
String centerAdminSubjectPath(int id) => '$centerAdminSubjectsPath/$id';
const centerAdminTeachersPath = '$centerAdminPath/teachers';
String centerAdminTeacherPath(int id) => '$centerAdminTeachersPath/$id';
const centerAdminLecturesPath = '$centerAdminPath/lectures';
const centerAdminExamsPath = '$centerAdminPath/exams';
String centerAdminExamPath(int id) => '$centerAdminExamsPath/$id';
const centerAdminAssignmentsPath = '$centerAdminPath/assignments';
String centerAdminAssignmentPath(int id) => '$centerAdminAssignmentsPath/$id';
const centerAdminSubscriptionsPath = '$centerAdminPath/subscriptions';
const centerAdminNotificationsPath = '$centerAdminPath/notifications';
const centerAdminBannersPath = '$centerAdminPath/banners';
const centerAdminFilesPath = '$centerAdminPath/files';
const centerAdminSettingsPath = '$centerAdminPath/settings';
const centerAdminStatsPath = '$centerAdminPath/stats';
const centerAdminRequestsPath = '$centerAdminPath/requests';
String centerAdminRequestPath(int id) => '$centerAdminRequestsPath/$id';
const centerAdminActivationCodesPath = '$centerAdminPath/activation-codes';
