import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../workout_manager.dart';
import 'package:hilt_core/hilt_core.dart';

class PostWorkoutSummaryScreen extends StatefulWidget {
  final WorkoutSession session;
  final bool isFromHistory;

  const PostWorkoutSummaryScreen({
    super.key,
    required this.session,
    this.isFromHistory = false,
  });

  @override
  State<PostWorkoutSummaryScreen> createState() =>
      _PostWorkoutSummaryScreenState();
}

class _PostWorkoutSummaryScreenState extends State<PostWorkoutSummaryScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // Recovery tracking removed as per request
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (!widget.isFromHistory) {
    //     context.read<WorkoutManager>().startRecoveryTracking(widget.session.id);
    //   }
    // });
  }

  Future<void> _shareResult() async {
    setState(() => _isSharing = true);
    try {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final imagePath = await _screenshotController.captureAndSave(directory,
          fileName: "hilt_workout_${widget.session.id}.png");

      if (imagePath != null) {
        await Share.shareXFiles([XFile(imagePath)],
            text: 'Check out my HILT workout session!');
      }
    } catch (e) {
      print("Error sharing: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.session.grade ?? 'C';
    final gradeColor = _getGradeColor(grade);

    // Listen to manager for recovery score updates
    final manager = context.watch<WorkoutManager>();
    final targetBpm = manager.profile.targetHeartRate.toDouble();
    const hiltTeal = Color(0xFF00897B);

    return Scaffold(
      appBar: AppBar(
        title: const Text("MATCH REPORT",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1), // Subtle shadow
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.share, color: hiltTeal), // Hilt Teal
                onPressed: _shareResult,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    children: [
                      const SizedBox(height: 10),
                      // 1. Header Hierarchy (Grade + Output)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildGradeBadge(context, grade, gradeColor),
                          if (widget.session.totalVolume != null &&
                              widget.session.totalVolume! > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: _buildStrengthOutputCard(context),
                            ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // 2. Tactical Data Grid
                      _buildTacticalDataGrid(context),

                      const SizedBox(height: 40),

                      // 3. Intensity Chart
                      SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots
                                      .map((LineBarSpot touchedSpot) {
                                    return LineTooltipItem(
                                      touchedSpot.y.toInt().toString(),
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 40,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade200, // Minimalist grid
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 40,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const SizedBox();
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey
                                            .shade400, // Minimalist Light Font
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            minY: 40,
                            maxY: 200,
                            lineBarsData: [
                              LineChartBarData(
                                spots: widget.session.heartRateReadings
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(
                                        e.key.toDouble(), e.value.toDouble()))
                                    .toList(),
                                isCurved: true,
                                color: Colors.black,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                                aboveBarData: BarAreaData(show: false),
                              ),
                            ],
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: targetBpm,
                                  color: hiltTeal, // Hilt Teal
                                  strokeWidth: 1.5, // Thicker line
                                  dashArray: [4, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    labelResolver: (line) => "TARGET",
                                    style: const TextStyle(
                                      color: hiltTeal, // Hilt Teal
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(bottom: 4),
                                  ),
                                ),
                              ],
                            ),
                            rangeAnnotations: RangeAnnotations(
                              horizontalRangeAnnotations: [
                                HorizontalRangeAnnotation(
                                  y1: targetBpm,
                                  y2: 200,
                                  color: hiltTeal
                                      .withOpacity(0.05), // Subtle Teal fill
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 4. Action Button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (context.mounted) {
                          if (widget.isFromHistory) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        }
                      },
                      child: const Text(
                        "DONE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final _distanceController = TextEditingController();
  final _inclineController = TextEditingController();

  Widget _buildTreadmillInputs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TREADMILL STATS (OPTIONAL)",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInput(_distanceController, "DISTANCE", "KM"),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInput(_inclineController, "INCLINE", "%"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInput(
      TextEditingController controller, String label, String suffix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              suffixText: suffix,
              suffixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalDataGrid(BuildContext context) {
    const dividerColor = Color(0xFF00897B); // Hilt Teal
    // 0.3 opacity for dividers
    final subtleDivider = dividerColor.withOpacity(0.3);
    const dividerThickness = 1.0;

    final isTreadmill = widget.session.distance != null;

    return Container(
      decoration: BoxDecoration(
          border: Border(
        top: BorderSide(color: subtleDivider, width: dividerThickness),
        bottom: BorderSide(color: subtleDivider, width: dividerThickness),
      )),
      child: Column(
        children: [
          // Row 1
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                    child: _statItem("AVG BPM",
                        "${widget.session.averageBpm.toStringAsFixed(0)}")),
                VerticalDivider(color: subtleDivider, width: dividerThickness),
                Expanded(
                    child: isTreadmill
                        ? _editableStatItem(
                            context,
                            "DISTANCE",
                            "${((widget.session.distance ?? 0.0) * 0.621371).toStringAsFixed(2)} MILES",
                            icon: Icons.edit,
                            onTap: () => _showEditDistanceDialog(context),
                          )
                        : _statItem("PEAK BPM", "${widget.session.peakBpm}")),
              ],
            ),
          ),
          Divider(color: subtleDivider, height: dividerThickness),
          // Row 2
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                    child: _statItem(
                        "DURATION",
                        _formatDuration(widget.session.durationSeconds ??
                            widget.session.heartRateReadings.length))),
                VerticalDivider(color: subtleDivider, width: dividerThickness),
                Expanded(
                    child: _statItem("CARDIO LOAD",
                        widget.session.cardioLoad?.toStringAsFixed(1) ?? "-")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDistanceDialog(BuildContext context) {
    // Convert stored KM to Miles for editing
    final currentMiles = (widget.session.distance ?? 0.0) * 0.621371;
    final controller =
        TextEditingController(text: currentMiles.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Distance"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: "MILES"),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          FilledButton(
              onPressed: () {
                final newDistMiles = double.tryParse(controller.text);
                if (newDistMiles != null) {
                  // Convert Miles back to KM for storage
                  final newDistKm = newDistMiles / 0.621371;
                  setState(() {
                    widget.session.distance = newDistKm;
                    context.read<WorkoutManager>().updateSessionStats(
                        widget.session.id, newDistKm, widget.session.incline);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("SAVE"))
        ],
      ),
    );
  }

  Widget _editableStatItem(BuildContext context, String label, String value,
      {IconData? icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Serif',
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 20, color: Colors.grey),
                ]
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28, // Classic Bold size
              fontWeight: FontWeight.bold, // Bold (updated from w900)
              color: Colors.black,
              fontFamily: 'Serif',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333), // Charcoal tactical grey
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(BuildContext context, String grade, Color color) {
    // 15% increase from 120 -> ~138
    const size = 140.0;

    BoxShadow? glow;
    if (grade == 'B') {
      glow = BoxShadow(
        color: Colors.amber.withOpacity(0.4),
        blurRadius: 30,
        spreadRadius: 5,
      );
    } else if (grade == 'A') {
      glow = BoxShadow(
        color: const Color(0xFF00E676).withOpacity(0.4),
        blurRadius: 30,
        spreadRadius: 5,
      );
    }

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 8),
            boxShadow: glow != null ? [glow] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            grade,
            style: TextStyle(
              fontSize: 72, // Scaled font
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text("MATCH GRADE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 2.0,
            )),
      ],
    );
  }

  Widget _buildStrengthOutputCard(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90, // Smaller, sleek card
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                "${(widget.session.totalVolume! / 1000).toStringAsFixed(1)}k",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "VOL",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16), // Match spacing of grade label
        Text("OUTPUT",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 2.0,
            )),
      ],
    );
  }

  Color _getGradeColor(String? grade) {
    if (grade == 'A') return const Color(0xFF00E676); // Neon Green
    if (grade == 'B') return Colors.amber; // Gold
    return Colors.deepOrange; // Red/Orange
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) {
      return "${totalSeconds}s";
    }
    final int min = totalSeconds ~/ 60;
    final int sec = totalSeconds % 60;

    if (sec == 0) {
      return "${min}m";
    }
    return "${min}m${sec}s";
  }
}
