import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Ensure these models mirror the fields inside your backend tables
class UserProfile {
  final String username;
  final String role;
  final String team;
  final String segment;
  UserProfile({required this.username, required this.role, required this.team, required this.segment});
}

class JobBatch {
  final String batchNo;
  final String jobName;
  final String clientName;
  final String projectName;
  final int initialQty;
  String status;
  JobBatch({required this.batchNo, required this.jobName, required this.clientName, required this.projectName, required this.initialQty, required this.status});
}

class EMSStateEngine extends ChangeNotifier {
  final String baseUrl = "http://192.168.1.100:5030"; // Replace with your Flask backend server IP address
  UserProfile? currentUser;
  String? activePunchInTime;
  List<JobBatch> batches = [];
  bool isLoading = false;

  Future<void> fetchAndSyncFromBackend() async {
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sync'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List fetchedBatches = data['batches'];
        batches = fetchedBatches.map((b) => JobBatch(
          batchNo: b['batch_no'] ?? '',
          jobName: b['job_name'] ?? '',
          clientName: b['client_name'] ?? '',
          projectName: b['project_name'] ?? '',
          initialQty: b['initial_qty'] ?? 0,
          status: b['status'] ?? 'OPEN',
        )).toList();
      }
    } catch (e) {
      debugPrint("Synchronization error pipeline down: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> authenticateUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"username": username, "password": password}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final u = data['user'];
        currentUser = UserProfile(
          username: u['username'],
          role: u['role'],
          team: u['team'] ?? 'None',
          segment: u['segment'] ?? 'None',
        );
        await fetchAndSyncFromBackend();
        return true;
      }
    } catch (e) {
      debugPrint("Authentication system network failure: $e");
    }
    return false;
  }

  Future<bool> toggleShiftPunch(bool isPunchIn) async {
    if (currentUser == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/punch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": currentUser!.username,
          "action": isPunchIn ? "in" : "out"
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        activePunchInTime = isPunchIn ? data['time'] : null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Punch operation tracking failure: $e");
    }
    return false;
  }

  Future<String?> logHourlyStatus(String batchNo, String side, int qty, String comments) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/log_hourly'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": currentUser!.username,
          "batch_no": batchNo,
          "side": side,
          "qty": qty,
          "comments": comments,
          "team": currentUser!.team,
          "segment": currentUser!.segment
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null; // Null means success (no error message)
      } else {
        return data['message'] ?? "Validation failure on shopfloor log entry.";
      }
    } catch (e) {
      return "Network connection issue reporting status data.";
    }
  }

  Future<String?> executeLedgerTransfer(String batchNo, String fromStage, String toStage, int qty, String remarks) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ledger_transfer'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "batch_no": batchNo,
          "from_stage": fromStage,
          "to_stage": toStage,
          "qty": qty,
          "operator": currentUser!.username,
          "comments": remarks
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchAndSyncFromBackend();
        return null;
      } else {
        return data['message'] ?? "Failed to authorize data transfer handshake transaction.";
      }
    } catch (e) {
      return "Network structural communication failure.";
    }
  }

  void clearSession() {
    currentUser = null;
    activePunchInTime = null;
    notifyListeners();
  }
}
