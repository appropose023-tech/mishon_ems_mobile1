import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';

class EMSStateEngine extends ChangeNotifier {
  // Configured directly to your GCP infrastructure IP
  final String baseUrl = "http://104.154.76.47:5000/api";
  
  UserProfile? currentUser;
  DateTime? activePunchInTime;

  List<JobBatch> batches = [];
  List<LedgerEntry> materialLedger = [];
  List<FloorTarget> targetingMatrix = [];
  Map<String, Map<String, int>> processingCounters = {};

  Future<bool> authenticateUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          currentUser = UserProfile(
            username: data['user']['username'],
            role: data['user']['role'],
            team: data['user']['team'] ?? "None",
            segment: data['user']['segment'] ?? "None",
          );
          await syncOperationalData();
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      print("Auth Error: $e");
    }
    return false;
  }

  Future<void> syncOperationalData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sync'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        batches = (data['batches'] as List).map((b) => JobBatch(
          batchNo: b['batch_no'],
          jobName: b['job_name'],
          clientName: b['client_name'],
          projectName: b['project_name'],
          initialQty: b['initial_qty'],
          status: b['status'],
        )).toList();

        materialLedger = (data['ledger'] as List).map((l) => LedgerEntry(
          batchNo: l['batch_no'],
          fromStage: l['from_stage'],
          toStage: l['to_stage'],
          qtyTransferred: l['qty_transferred'],
          timestamp: DateTime.parse(l['entry_timestamp']),
          operator: l['operator_username'],
          comments: l['comments'] ?? "",
        )).toList();

        targetingMatrix = (data['targets'] as List).map((t) => FloorTarget(
          batchNo: t['batch_no'],
          segment: t['segment'],
          team: t['team'],
          targetQty: t['target_qty'],
        )).toList();
        
        notifyListeners();
      }
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  void clearSession() {
    currentUser = null;
    activePunchInTime = null;
    batches.clear();
    materialLedger.clear();
    targetingMatrix.clear();
    notifyListeners();
  }

  Future<void> toggleShiftPunch(bool punchIn) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/punch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': currentUser!.username,
          'action': punchIn ? 'in' : 'out'
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        activePunchInTime = punchIn ? DateTime.parse(data['time']) : null;
        notifyListeners();
      }
    } catch (e) {
      print("Punch Error: $e");
    }
  }

  int getLayerRunningTotal(String batchNo, String side) {
    return processingCounters[batchNo]?[side] ?? 0;
  }

  Future<void> commitHourlyStatus(String batchNo, String side, int amount, String remarks) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/log_hourly'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': currentUser!.username,
          'batch_no': batchNo,
          'side': side,
          'qty': amount,
          'comments': remarks,
          'team': currentUser!.team,
          'segment': currentUser!.segment
        }),
      );

      if (!processingCounters.containsKey(batchNo)) {
        processingCounters[batchNo] = {"TOP": 0, "BOTTOM": 0};
      }
      processingCounters[batchNo]![side] = (processingCounters[batchNo]![side] ?? 0) + amount;
      notifyListeners();
    } catch (e) {
      print("Hourly Log Error: $e");
    }
  }

  void closeBatchProcessingBlock(String batchNo) {
    final idx = batches.indexWhere((element) => element.batchNo == batchNo);
    if (idx != -1) {
      batches[idx].status = 'CLOSED';
      notifyListeners();
    }
  }

  void dispatchBillingClearance(String batchNo) {
    final idx = batches.indexWhere((element) => element.batchNo == batchNo);
    if (idx != -1) {
      batches[idx].status = 'DISPATCHED';
      notifyListeners();
    }
  }

  Future<void> injectLedgerTransaction({
    required String batchNo,
    required String fromStage,
    required String toStage,
    required int qty,
    required String operator,
    required String remarks,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/ledger_transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batch_no': batchNo,
          'from_stage': fromStage,
          'to_stage': toStage,
          'qty': qty,
          'operator': operator,
          'comments': remarks
        }),
      );
      await syncOperationalData(); // Refresh ledger from DB
    } catch (e) {
      print("Ledger Error: $e");
    }
  }

  void provisionNewTarget(String batchNo, String segment, String team, int targetQty) {
    targetingMatrix.add(FloorTarget(batchNo: batchNo, segment: segment, team: team, targetQty: targetQty));
    notifyListeners();
  }
}
