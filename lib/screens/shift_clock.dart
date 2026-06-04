import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';

class ShiftClockTerminalView extends StatelessWidget {
  const ShiftClockTerminalView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    final bool isPunchedIn = state.activePunchInTime != null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(isPunchedIn ? Icons.timer : Icons.timer_off, size: 100, color: isPunchedIn ? const Color(0xFF008080) : Colors.grey),
          const SizedBox(height: 24),
          Text(
            isPunchedIn 
              ? "Shift Active Since:\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(state.activePunchInTime!)}" 
              : "Awaiting Shift Verification Sequence",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPunchedIn ? Colors.amber[800] : const Color(0xFF008080),
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onPressed: () => state.toggleShiftPunch(!isPunchedIn),
            child: Text(
              isPunchedIn ? "EXECUTE SHIFT PUNCH-OUT" : "EXECUTE SHIFT PUNCH-IN",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
