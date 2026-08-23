import 'package:flutter/material.dart';

import '../../../core/enterprise/enterprise_audit_service.dart';
import '../../../core/enterprise/enterprise_models.dart';

class EnterpriseGovernanceScreen extends StatefulWidget {
  const EnterpriseGovernanceScreen({super.key});

  @override
  State<EnterpriseGovernanceScreen> createState() =>
      _EnterpriseGovernanceScreenState();
}

class _EnterpriseGovernanceScreenState
    extends State<EnterpriseGovernanceScreen> {
  bool _isChainValid = true;
  bool _isLoading = false;
  List<AuditLogEntry> _auditLogs = [];
  int _eligibleRetentionCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshGovernanceData();
  }

  Future<void> _refreshGovernanceData() async {
    setState(() => _isLoading = true);
    final valid = await EnterpriseAuditService.instance.verifyAuditChain();
    final logs = await EnterpriseAuditService.instance.getAuditLogs();
    final eligible = await EnterpriseAuditService.instance
        .getEligibleRetentionCount();

    if (mounted) {
      setState(() {
        _isChainValid = valid;
        _auditLogs = logs;
        _eligibleRetentionCount = eligible;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndExecuteRemoteWipe() async {
    final textController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8),
              Expanded(child: Text('CONFIRM SECURE DATA WIPE')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This operation will permanently purge local messages, conversations, members, and attachments.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'To prevent accidental deletion, type "WIPE" below to proceed:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'WIPE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                if (textController.text.trim().toUpperCase() == 'WIPE') {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Verification failed. Type WIPE to confirm.',
                      ),
                      backgroundColor: Colors.amberAccent,
                    ),
                  );
                }
              },
              child: const Text('CONFIRM PURGE'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await EnterpriseAuditService.instance.executeRemoteWipe();
      await _refreshGovernanceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Secure Remote Wipe executed successfully. All local data cleared and audit log recorded.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Governance & Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGovernanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tamper-Evident Hash Chain Verification Card
                Card(
                  color: _isChainValid
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _isChainValid ? Icons.verified : Icons.gpp_bad,
                          color: Colors.white,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isChainValid
                                    ? 'Tamper-Evident Audit Chain VERIFIED'
                                    : 'WARNING: Audit Chain Tampering Detected!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isChainValid
                                    ? 'SHA-256 hash chaining guarantees unalterable compliance logs.'
                                    : 'An entry in audit_logs failed SHA-256 verification.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Enterprise Security Policies Card
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'ENTERPRISE SECURITY & RETENTION POLICIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.auto_delete,
                          color: Colors.amberAccent,
                        ),
                        title: const Text(
                          'Data Retention Policy (30-Day Purge)',
                        ),
                        subtitle: Text(
                          'Eligible Expired Records: $_eligibleRetentionCount',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final count = await EnterpriseAuditService.instance
                                .enforceRetentionPolicies();
                            await _refreshGovernanceData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Purged $count expired messages',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Enforce'),
                        ),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.badge, color: Colors.purpleAccent),
                        title: Text('Role-Based Access Control (RBAC)'),
                        subtitle: Text(
                          'Current Role: SUPER_ADMIN (Full Compliance Access)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Audit Event Trail Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AUDIT EVENT HISTORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${_auditLogs.length} events',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_auditLogs.isEmpty)
                  Card(
                    color: const Color(0xFF0F172A),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No audit events logged yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  Card(
                    color: const Color(0xFF0F172A),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _auditLogs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final log = _auditLogs[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.history,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          title: Text(
                            log.eventType.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'User: ${log.userId} | Hash: ${log.hash.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Text(
                            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // Multi-Step Confirmed Secure Data Wipe Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.phonelink_erase),
                  label: const Text('Trigger Secure Data Wipe'),
                  onPressed: _confirmAndExecuteRemoteWipe,
                ),
              ],
            ),
    );
  }
}
