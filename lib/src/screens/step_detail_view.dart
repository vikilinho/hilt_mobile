import 'package:flutter/material.dart';
import 'package:hilt_core/hilt_core.dart';
import 'package:intl/intl.dart';

class StepDetailView extends StatelessWidget {
  final WorkoutSession session;

  const StepDetailView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final steps = session.steps ?? 0;
    // Fallback calculation just in case old data doesn't have the fields
    final miles = session.distance ?? (steps * 0.00047);
    final calories = session.calories ?? (steps * 0.04);
    final isMatchReady = steps >= 10000;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(session.timestamp);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Dark tactical background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "DAILY ACTIVITY",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade400,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -----------------------------------------------------------------
              // TOP SECTION: Date & Total Steps
              // -----------------------------------------------------------------
              Center(
                child: Column(
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.grey.shade500,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle background glow for steps
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isMatchReady
                                        ? const Color(0xFF00897B)
                                        : Colors.grey.shade800)
                                    .withOpacity(0.15),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: isMatchReady
                                  ? const Color(0xFF00897B)
                                  : Colors.grey.shade600,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              NumberFormat.decimalPattern().format(steps),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 56,
                                  ),
                            ),
                            Text(
                              "TOTAL STEPS",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.grey.shade500,
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // -----------------------------------------------------------------
              // MIDDLE SECTION: 1x2 Data Grid (Miles & Calories)
              // -----------------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      label: "MILES",
                      value: miles.toStringAsFixed(1),
                      icon: Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      label: "CALORIES",
                      value: calories.toStringAsFixed(1),
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Bottom accent line
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Super dark grey, distinct from bg
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF00897B), // Hilt Teal
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
