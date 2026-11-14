/// The learning path map: every "place" a learner can stand on, in the order
/// the course walks them, plus the artwork that previews each place.
///
/// Kept in one file so the full map (LMS hub) and the compact map shown right
/// after login (Home) always agree on the same places and order.
library;

/// One place on the learning map.
class LearningPlace {
  LearningPlace({
    required this.number,
    required this.duration,
    required this.publicId,
  }) : title = videoTitleFromPublicId(publicId);

  /// Two-digit place number, e.g. `01`.
  final String number;

  /// Human name of the place, read from the video's Cloudinary file name,
  /// e.g. "Advancing your career with Python".
  final String title;

  /// Short caption shown under the title (duration or "Next lesson").
  final String duration;

  /// Cloudinary public id of the place's video.
  final String publicId;
}

/// The name of a video, read from its Cloudinary public id.
///
/// Uploads are named `<index>._<Words_joined_by_underscores>.mp4`, so the name
/// is the file name with the index prefix and the extension removed and the
/// underscores turned back into spaces. The academy tag that some uploads carry
/// (`SEPNET`, any case) is shown as "SkillBridge Academy". Reading the name off the
/// link keeps the app and the video library in step.
///
/// The tag is matched *after* the underscores become spaces: `_` is a word
/// character in a regular expression, so `\bSEPNET\b` can never match inside
/// `Python_SEPNET`.
String videoTitleFromPublicId(String publicId) {
  final file = publicId.split('/').last;
  final stem = file.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
  final words = stem
      .replaceFirst(RegExp(r'^\d+\._?'), '')
      .replaceAll('_', ' ')
      .replaceAll(
        RegExp(r'\b(sepnet|skills?bridge)\b', caseSensitive: false),
        'SkillBridge Academy',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return words.isEmpty ? stem : words;
}

/// The learning map for Unit 1, in walk order. The title of every place is read
/// from its Cloudinary link, so each `publicId` is the single source of truth
/// for the lesson's name.
final List<LearningPlace> learningPlaces = <LearningPlace>[
  LearningPlace(
    number: '01',
    duration: 'Intro video',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880576/01._Advancing_your_career_with_Python.mp4',
  ),
  LearningPlace(
    number: '02',
    duration: '8h 45m',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880586/01._Demystifying_Python_SEPNET.mp4',
  ),
  LearningPlace(
    number: '03',
    duration: '15h 20m',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880599/02._Starting_with_Python.mp4',
  ),
  LearningPlace(
    number: '04',
    duration: 'Next lesson',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880607/03._Comparing_Python_vs_Java.mp4',
  ),
  LearningPlace(
    number: '05',
    duration: 'Next lesson',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880614/04._Harnessing_the_power_of_Python.mp4',
  ),
  LearningPlace(
    number: '06',
    duration: 'Next lesson',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880631/01._Setting_up_your_Python_environment.mp4',
  ),
  LearningPlace(
    number: '07',
    duration: 'Next lesson',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880639/02._Sorting_your_types_of_data.mp4',
  ),
  LearningPlace(
    number: '08',
    duration: 'Next lesson',
    publicId: 'https://res.cloudinary.com/ea91sdts/video/upload/v1791880644/03._Storing_data_using_variables.mp4',
  ),
];

/// Preview artwork for a place. Falls back to the course hero so a tile never
/// renders an empty box.
String previewForPlace(String number) {
  switch (number) {
    case '03':
      return 'assets/course_previews/lesson_03_arithmetic.png';
    case '06':
      return 'assets/course_previews/lesson_06_functions.png';
    case '07':
      return 'assets/course_previews/lesson_07_lists.png';
    default:
      return 'assets/course_previews/python_quick_start.png';
  }
}
