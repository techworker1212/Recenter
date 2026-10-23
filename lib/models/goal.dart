/// A goal for today. The list is kept natively so ticking a goal off from a warning
/// notification works even when the app isn't open.
class Goal {
  static const textMax = 40;

  const Goal({required this.id, required this.text, required this.done});

  final String id;
  final String text;
  final bool done;
}
