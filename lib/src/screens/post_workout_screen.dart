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
    // Start measuring recovery if just finished
    // Start measuring recovery if just finished
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
    final color = grade == 'A'
        ? Colors.green
        : (grade == 'B' ? Colors.amber : Colors.red);

    // Listen to manager for recovery score updates
    final manager = context.watch<WorkoutManager>();
    // Ideally we'd map this to the session, but for now we use the live "recoveryScore" from manager
    // if the logic was to update the session in DB, we'd watch the session query.
    // Simplified: Manager exposes current recovery score.

    return Scaffold(
      appBar: AppBar(
        title: const Text("MATCH REPORT"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResult,
          )
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: Container(
          color:
              Theme.of(context).scaffoldBackgroundColor, // Capture background
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Grade Badge
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                  child: Text("MATCH GRADE",
                      style: Theme.of(context).textTheme.bodySmall)),

              const SizedBox(height: 32),

              // 2. Stats Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem("AVG BPM",
                      "${widget.session.averageBpm.toStringAsFixed(0)}"),
                  _statItem("PEAK BPM", "${widget.session.peakBpm}"),
                  _statItem("DURATION",
                      "${(widget.session.heartRateReadings.length / 60).toStringAsFixed(1)}m"),
                ],
              ),

              const SizedBox(height: 32),

              // 3. Heart Rate Chart
              SizedBox(
                height: 200,
                child: LineChart(
                  //Recovery Data colour update
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
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
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 40,
                    maxY: 200,
                    lineBarsData: [
                      LineChartBarData(
                          spots: widget.session.heartRateReadings
                              .asMap()
                              .entries
                              .map((e) =>
                                  FlSpot(e.key.toDouble(), e.value.toDouble()))
                              .toList(),
                          isCurved: true,
                          color: Colors.black, // High contrast line
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            cutOffY: manager.profile.targetHeartRate.toDouble(),
                            applyCutOffY: true,
                            color: Colors.red.withOpacity(0.1),
                          ),
                          aboveBarData: BarAreaData(
                            show: true,
                            cutOffY: manager.profile.targetHeartRate.toDouble(),
                            applyCutOffY: true,
                            color: Colors.green.withOpacity(0.1),
                          )),
                    ],
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                            y: manager.profile.targetHeartRate.toDouble(),
                            color: Colors.black,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                            label: HorizontalLineLabel(
                              show: true,
                              labelResolver: (line) => " TARGET",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              alignment: Alignment.topRight,
                            )),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Recovery Analytics

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (widget.isFromHistory) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text("DONE"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
