import 'package:flutter/material.dart';
import 'package:ussd_session/ussd_session.dart';

void main() => runApp(const MaterialApp(home: UssdDemo()));

/// Demo screen: permission status, SIM list, send and dial.
class UssdDemo extends StatefulWidget {
  /// Creates the demo screen.
  const UssdDemo({super.key});

  @override
  State<UssdDemo> createState() => _UssdDemoState();
}

class _UssdDemoState extends State<UssdDemo> {
  final _code = TextEditingController(text: '*222#');
  UssdPermissions? _permissions;
  List<SimCard> _sims = const [];
  int? _subscriptionId;
  String _output = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final permissions = await UssdSession.permissionsStatus();
    var sims = const <SimCard>[];
    try {
      sims = await UssdSession.simCards();
    } on UssdException catch (e) {
      _output = e.toString();
    }
    setState(() {
      _permissions = permissions;
      _sims = sims;
    });
  }

  Future<void> _send() async {
    setState(() => _output = 'Sending...');
    try {
      final r = await UssdSession.send(_code.text,
          subscriptionId: _subscriptionId,
          timeout: const Duration(seconds: 20));
      final amounts = extractAmounts(r.text);
      setState(() => _output = '${r.text}\n\nAmounts: $amounts');
    } on UssdException catch (e) {
      setState(() => _output = '${e.code.name}: ${e.message}');
    }
  }

  Future<void> _dial() async {
    try {
      await UssdSession.dial(_code.text);
    } on UssdException catch (e) {
      setState(() => _output = '${e.code.name}: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ussd_session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Permissions: $_permissions'),
          const SizedBox(height: 8),
          DropdownButton<int?>(
            value: _subscriptionId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Default SIM')),
              for (final sim in _sims)
                DropdownMenuItem(
                  value: sim.subscriptionId,
                  child: Text('Slot ${sim.slotIndex + 1}: '
                      '${sim.carrierName ?? sim.displayName ?? '?'}'),
                ),
            ],
            onChanged: (id) {
              setState(() => _subscriptionId = id);
              final sim = _sims.where((s) => s.subscriptionId == id);
              final preset = sim.isEmpty
                  ? null
                  : AlgerianCarrierPresets.balanceFor(sim.first);
              if (preset != null) _code.text = preset.code;
            },
          ),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'USSD code'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _send, child: const Text('Send')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: _dial, child: const Text('Open dialer')),
              const SizedBox(width: 8),
              TextButton(onPressed: _refresh, child: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(_output),
        ],
      ),
    );
  }
}
