import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'dashboard.dart';

class IdentityGatewayPortal extends StatefulWidget {
  const IdentityGatewayPortal({Key? key}) : super(key: key);

  @override
  State<IdentityGatewayPortal> createState() => _IdentityGatewayPortalState();
}

class _IdentityGatewayPortalState extends State<IdentityGatewayPortal> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.precision_manufacturing, size: 80, color: Color(0xFF008080)),
              const SizedBox(height: 16),
              const Text("Mishon Solutions EMS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
              const Text("Unified Floor Management Portal", style: TextStyle(color: Color(0xFF008080))),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    final state = Provider.of<EMSStateEngine>(context, listen: false);
                    bool success = await state.authenticateUser(
                      _usernameController.text.trim(),
                      _passwordController.text.trim(),
                    );
                    setState(() => _isLoading = false);
                    
                    if (success) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PrimaryDashboardRouter()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid credentials or server unreachable.")));
                    }
                  },
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("AUTHENTICATE ACCESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
