class ExerciseAnimationMap {
  // All exercises now use local assets since LottieFiles blocks direct URL access
  static const Map<String, String> _map = {
    // Barbell Exercises - each with dedicated animation
    'Barbell Back Squat': 'assets/animations/backsquat.json',
    'Back Squat': 'assets/animations/backsquat.json',
    'Barbell Deadlift': 'assets/animations/deadlift.json',
    'Deadlift': 'assets/animations/deadlift.json',
    'Barbell Power Clean': 'assets/animations/Barbell Power Clean.json',
    'Power Clean': 'assets/animations/Barbell Power Clean.json',
    'Clean Press': 'assets/animations/Power Clean.json',
    'Match Primer': 'assets/animations/Power Clean.json', // Legacy support
    'Barbell Push Press': 'assets/animations/push_press.json',

    'Push Press': 'assets/animations/push_press.json',

    // Dumbbell Exercises
    'Dumbbell Goblet Squat': 'assets/animations/dumbellsquat.json',
    'Dumbbell Lunges': 'assets/animations/dumbelllunges.json',
    'Dumbbell Overhead Press': 'assets/animations/dumbelloverheadpress.json',
    'Dumbbell Romanian Deadlift': 'assets/animations/dumbellRomania.json',

    // Bench Exercises
    'Bench Dips': 'assets/animations/Bench Dips.json',
    'Bulgarian Split Squats': 'assets/animations/Bulgarian Split Squats.json',
    'Bench Step-Ups': 'assets/animations/Bench Step-Ups.json',
    'Bench Leg Raises': 'assets/animations/Bench Leg Raises.json',

    // No-Equipment / Bodyweight Exercises
    'Air Squats': 'assets/animations/Air Squats.json',
    'Walking Lunges': 'assets/animations/Walking Lunges.json',
    'Burpees': 'assets/animations/Burpees.json',
    'Mountain Climbers': 'assets/animations/Mountain Climbers.json',

    // Preset Previews
    'Clean Press (5m)': 'assets/animations/Power Clean.json',
    'Explosive Power (15m)': 'assets/animations/Barbell Lunges.json',
    'Strength Engine (30m)': 'assets/animations/deadlift.json',
    'The Iron 90 (45m)': 'assets/animations/backsquat.json',

    // Rest
    'Recovery': 'assets/animations/rest_breathing.json',
    'Rest': 'assets/animations/rest_breathing.json',
  };

  static String? get(String exerciseName) => _map[exerciseName];
}
