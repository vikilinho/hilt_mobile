import 'package:flutter/material.dart';
import 'package:hilt_core/hilt_core.dart';

class EquipmentSelector extends StatelessWidget {
  final GarageGear selectedGear;
  final ValueChanged<GarageGear> onEquipmentSelected;

  final bool showLabel;

  const EquipmentSelector({
    super.key,
    required this.selectedGear,
    required this.onEquipmentSelected,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              "EQUIPMENT",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEquipmentOption(
                context,
                GarageGear.noEquipment,
                Icons.bolt,
                "None",
              ),
              _buildEquipmentOption(
                context,
                GarageGear.dumbbells,
                Icons.grid_view,
                "Dumbbell",
              ),
              _buildEquipmentOption(
                context,
                GarageGear.barbell,
                Icons.iron,
                "Barbell",
                rotateIcon: true,
              ),
              _buildEquipmentOption(
                context,
                GarageGear.bench,
                Icons.horizontal_rule,
                "Bench",
                scaleY: 4.0, // Thicken the line to look like a bench
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentOption(
    BuildContext context,
    GarageGear gear,
    IconData icon,
    String label, {
    bool rotateIcon = false,
    double scaleY = 1.0,
  }) {
    final isSelected = selectedGear == gear;
    final hiltGreen = const Color(0xFF00897B);

    return InkWell(
      onTap: () => onEquipmentSelected(gear),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? hiltGreen.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? hiltGreen : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              transform: Matrix4.identity()
                ..rotateZ(rotateIcon ? 1.5708 : 0)
                ..scale(1.0, scaleY),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isSelected ? hiltGreen : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? hiltGreen : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
