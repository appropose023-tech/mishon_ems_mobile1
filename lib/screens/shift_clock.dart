import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../app_state.dart';

class ShiftClockTerminalView extends StatefulWidget {
  const ShiftClockTerminalView({Key? key}) : super(key: key);

  @override
  State<ShiftClockTerminalView> createState() => _ShiftClockTerminalViewState();
}

class _ShiftClockTerminalViewState extends State<ShiftClockTerminalView> {
  Timer? _timer;
  int _elapsedMinutes = 0;
  bool _isProcessingPunch = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final state = Provider.of<EMSStateEngine>(context, listen: false);
      if (state.activePunchInTime != null) {
        setState(() {
          _elapsedMinutes = DateTime.now().difference(state.activePunchInTime!).inMinutes;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerPunchSequence(EMSStateEngine state, bool targetPunchIn) async {
    setState(() => _isProcessingPunch = true);
    await state.toggleShiftPunch(targetPunchIn);
    setState(() {
      _isProcessingPunch = false;
      if (!targetPunchIn) _elapsedMinutes = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    bool punchedIn = state.activePunchInTime != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text("⏱️ Operational Chrono Punch Gateway", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                  const SizedBox(height: 16),
                  Text(
                    punchedIn ? "STATUS: SHIFT ACTIVE" : "STATUS: AWAITING PUNCH-IN",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: punchedIn ? Colors.green : Colors.red),
                  ),
                  const SizedBox(height: 24),
                  _isProcessingPunch
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: punchedIn ? Colors.red : const Color(0xFF008080),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        onPressed: () => _triggerPunchSequence(state, !punchedIn),
                        child: Text(
                          punchedIn ? "EXECUTE SHIFT PUNCH-OUT" : "EXECUTE SHIFT PUNCH-IN", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                ],
              ),
            ),
          ),
          if (punchedIn) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Color(0xFFD97706)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "HOURLY TRACKING ALERT: Shift active for $_elapsedMinutes minutes. Maintain active production tracking records in execution floor sub-systems.",
                      style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}
