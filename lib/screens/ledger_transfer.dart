import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';

class InterDepartmentLedgerGatewayView extends StatefulWidget {
  const InterDepartmentLedgerGatewayView({Key? key}) : super(key: key);

  @override
  State<InterDepartmentLedgerGatewayView> createState() => _InterDepartmentLedgerGatewayViewState();
}

class _InterDepartmentLedgerGatewayViewState extends State<InterDepartmentLedgerGatewayView> {
  String? _batchNo;
  String _fromStage = "SMT_QUALITY";
  String _toStage = "TH_PRODUCTION";
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    final openBatches = state.batches;
    final isManagement = (state.currentUser?.role == 'admin' || state.currentUser?.role == 'manager');

    if (openBatches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text("No live active manufacturing tracks synced from Store Database pipeline configuration.", 
               textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
      );
    }
    
    // Maintain reliable selection alignment loops
    if (_batchNo == null || !openBatches.any((b) => b.batchNo == _batchNo)) {
      _batchNo = openBatches.first.batchNo;
    }

    // Identify total volume ceiling rules for the selected batch tracking key
    final activeBatchData = openBatches.firstWhere((b) => b.batchNo == _batchNo);
    final int maxAllowedQty = activeBatchData.initialQty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isManagement) ...[
            const Text("🔄 Material Interlink Dispatch Routing Terminal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _batchNo,
              decoration: const InputDecoration(labelText: "Target Traceability Batch Reference", border: OutlineInputBorder()),
              items: openBatches.map((b) => DropdownMenuItem(value: b.batchNo, child: Text("${b.batchNo} (${b.projectName}) [Max: ${b.initialQty}]"))).toList(),
              onChanged: (v) => setState(() => _batchNo = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fromStage,
              decoration: const InputDecoration(labelText: "Origin Routing Terminal Node", border: OutlineInputBorder()),
              items: ["SMT_PRODUCTION", "SMT_QUALITY", "TH_PRODUCTION", "TH_QUALITY"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _fromStage = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _toStage,
              decoration: const InputDecoration(labelText: "Destination Pipeline Intake Terminal", border: OutlineInputBorder()),
              items: ["SMT_QUALITY", "TH_PRODUCTION", "TH_QUALITY", "PACKAGING_DEPT"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _toStage = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Verified Shipped Volume Quantities", 
                helperText: "System maximum threshold value capacity: $maxAllowedQty units.",
                border: const OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remarksController,
              decoration: const InputDecoration(labelText: "Traceability Validation Sign-Off Reference Details", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _isSubmitting
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                  onPressed: () async {
                    int q = int.tryParse(_qtyController.text) ?? 0;
                    
                    // CRITICAL VALIDATION: Assert volume quantities do not cross limits
                    if (q <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Error: Operational quantities must be greater than zero."), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    if (q > maxAllowedQty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("CRITICAL REJECTION: Requested units ($q) exceed initial Kit Issue bounds ($maxAllowedQty) for Batch $_batchNo."), 
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                      return;
                    }

                    setState(() => _isSubmitting = true);
                    await state.injectLedgerTransaction(
                      batchNo: _batchNo!,
                      fromStage: _fromStage,
                      toStage: _toStage,
                      qty: q,
                      operator: state.currentUser?.username ?? "System Mobile UI",
                      remarks: _remarksController.text,
                    );
                    
                    _qtyController.clear();
                    _remarksController.clear();
                    setState(() => _isSubmitting = false);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Traceability transactional token emitted successfully across chains."), backgroundColor: Colors.green)
                    );
                  },
                  child: const Text("EMIT SECURE LEDGER ROUTE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            const Divider(height: 32, thickness: 2),
          ],
          const Text("📋 Operational Tracking Ledger Historical Blocks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.materialLedger.length,
            itemBuilder: (context, idx) {
              final ent = state.materialLedger[state.materialLedger.length - 1 - idx];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history_toggle_off, color: Color(0xFF008080)),
                  title: Text("Batch: ${ent.batchNo} -> ${ent.qtyTransferred} Units"),
                  subtitle: Text("Node Path: ${ent.fromStage} ➔ ${ent.toStage}\nSign-Off Operator: ${ent.operator}\nTimestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(ent.timestamp)}"),
                  trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
