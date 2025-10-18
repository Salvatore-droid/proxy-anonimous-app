import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/app_state.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService;
  bool _isLoading = false;
  List<dynamic> _servers = [];
  List<String> _availableCountries = ['Automatic', 'South Africa'];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(http.Client());
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadUserData();
    await _loadServers();
    await _loadCountries();
    await _checkActiveSession();
  }

  Future<void> _loadUserData() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final profile = await _apiService.getUserProfile();
      final stats = await _apiService.getUserStats();
      
      if (profile != null) {
        appState.updateUserData(profile);
      }
      if (stats != null) {
        appState.setUserStats(stats);
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      _servers = await _apiService.getProxyServers();
      appState.setServers(_servers);
    } catch (e) {
      _showError('Error loading servers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await _apiService.getAvailableCountries();
      setState(() {
        _availableCountries = ['Automatic', 'South Africa', ...countries.cast<String>()];
      });
    } catch (e) {
      print('Error loading countries: $e');
    }
  }

  Future<void> _checkActiveSession() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final activeSession = await _apiService.getActiveSession();
      
      if (activeSession != null && activeSession['is_active'] == true) {
        appState.setConnected(
          true,
          session: activeSession,
          server: activeSession['proxy_server'],
        );
      }
    } catch (e) {
      print('No active session: $e');
    }
  }

  Future<void> _handleConnect() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.connectToServer(
        country: appState.selectedLocation == 'Automatic' ? null : appState.selectedLocation,
        securityLevel: appState.securityLevel,
        enableKillSwitch: appState.enableKillSwitch,
        enableDnsProtection: appState.enableDnsProtection,
      );
      
      appState.setConnected(
        true,
        session: response,
        server: response['proxy_server'],
      );
      
      _showSuccess('Connected to ${response['proxy_server']['country']} successfully!');
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDisconnect() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() => _isLoading = true);
    try {
      if (appState.currentSession != null) {
        await _apiService.disconnectSession(appState.currentSession!['id']);
      }
      
      appState.setConnected(false);
      _showSuccess('Disconnected successfully!');
    } catch (e) {
      _showError('Disconnect failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showServerDetails(Map<String, dynamic> server) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(server['name']),
        backgroundColor: const Color(0xFF1a1f26),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Country:', server['country']),
            _buildDetailRow('City:', server['city']),
            _buildDetailRow('Protocol:', server['protocol'].toString().toUpperCase()),
            _buildDetailRow('Load:', '${(server['load'] * 100).toStringAsFixed(1)}%'),
            _buildDetailRow('Latency:', '${server['latency']}ms'),
            _buildDetailRow('Users:', '${server['current_users']}/${server['max_users']}'),
            _buildDetailRow('Status:', server['is_active'] ? 'Active' : 'Inactive'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Color _getLoadColor(double load) {
    if (load < 0.3) return Colors.green;
    if (load < 0.7) return Colors.orange;
    return Colors.red;
  }

  String _formatDataUsage(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SecureProxy', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Advanced Anonymity', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadServers,
            tooltip: 'Refresh servers',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Connection Status Card
                  _buildConnectionStatusCard(appState),
                  
                  const SizedBox(height: 20),
                  
                  // User Stats Card
                  if (appState.userStats.isNotEmpty) _buildUserStatsCard(appState),
                  
                  const SizedBox(height: 20),
                  
                  // Location Selector
                  _buildLocationSelector(appState),
                  
                  const SizedBox(height: 20),
                  
                  // Security Settings
                  _buildSecuritySettings(appState),
                  
                  const SizedBox(height: 20),
                  
                  // Advanced Features
                  _buildAdvancedFeatures(appState),
                  
                  const SizedBox(height: 20),
                  
                  // Server List
                  _buildServerList(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionStatusCard(AppState appState) {
    return Card(
      color: const Color(0xFF1a1f26),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Remove const
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: appState.isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      appState.isConnected ? 'Protected' : 'Not Protected',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : appState.isConnected 
                          ? _handleDisconnect 
                          : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.isConnected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0), // Remove const
                    ),
                  ),
                  child: Text(
                    appState.isConnected ? 'DISCONNECT' : 'CONNECT',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (appState.isConnected && appState.currentServer != null) ...[
              const SizedBox(height: 15),
              _buildConnectionInfo(appState.currentServer!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(Map<String, dynamic> server) {
    return Column(
      children: [
        _buildInfoRow('Server:', server['name']),
        _buildInfoRow('Location:', '${server['country']}, ${server['city']}'),
        _buildInfoRow('Protocol:', server['protocol'].toString().toUpperCase()),
        _buildInfoRow('Load:', '${(server['load'] * 100).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildUserStatsCard(AppState appState) {
    return Card(
      color: const Color(0xFF1a1f26),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Remove const
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Sessions',
              appState.userStats['total_sessions']?.toString() ?? '0',
              Icons.history,
            ),
            _buildStatItem(
              'Data Used',
              _formatDataUsage(appState.userStats['total_data_used'] ?? 0),
              Icons.data_usage,
            ),
            _buildStatItem(
              'Tier',
              (appState.userStats['subscription_tier'] ?? 'Free').toString().toUpperCase(),
              Icons.star,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF2196F3)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelector(AppState appState) {
    final defaultLocations = [
      {'name': 'Automatic', 'flag': '🌐'},
      {'name': 'South Africa', 'flag': '🇿🇦'},
      {'name': 'USA', 'flag': '🇺🇸'},
      {'name': 'Germany', 'flag': '🇩🇪'},
      {'name': 'Japan', 'flag': '🇯🇵'},
      {'name': 'Singapore', 'flag': '🇸🇬'},
      {'name': 'Brazil', 'flag': '🇧🇷'},
      {'name': 'United Kingdom', 'flag': '🇬🇧'},
      {'name': 'Canada', 'flag': '🇨🇦'},
      {'name': 'Australia', 'flag': '🇦🇺'},
      {'name': 'France', 'flag': '🇫🇷'},
      {'name': 'Netherlands', 'flag': '🇳🇱'},
    ];
    
    final availableLocations = _availableCountries.isEmpty 
        ? defaultLocations 
        : defaultLocations.where((loc) => _availableCountries.contains(loc['name'])).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Virtual Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableLocations.length,
            itemBuilder: (context, index) {
              final location = availableLocations[index];
              final isSelected = appState.selectedLocation == location['name'];
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    appState.setLocation(location['name']!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF1a1f26),
                      borderRadius: BorderRadius.circular(20.0), // Remove const
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          location['flag']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          location['name']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings(AppState appState) {
    final levels = [
      {'value': 'basic', 'label': 'Basic', 'desc': 'Standard encryption'},
      {'value': 'standard', 'label': 'Standard', 'desc': 'Enhanced security'},
      {'value': 'high', 'label': 'High', 'desc': 'Strong encryption'},
      {'value': 'maximum', 'label': 'Maximum', 'desc': 'Maximum security'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security Level',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...levels.map((level) => Card(
          color: const Color(0xFF1a1f26),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0), // Remove const
          ),
          child: ListTile(
            title: Text(level['label']!),
            subtitle: Text(level['desc']!),
            trailing: Radio<String>(
              value: level['value']!,
              groupValue: appState.securityLevel,
              onChanged: (value) {
                appState.setSecurityLevel(value!);
              },
            ),
            onTap: () {
              appState.setSecurityLevel(level['value']!);
            },
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildAdvancedFeatures(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Advanced Features',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          color: const Color(0xFF1a1f26),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0), // Remove const
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Kill Switch'),
                subtitle: const Text('Block internet if proxy disconnects'),
                value: appState.enableKillSwitch,
                onChanged: (value) {
                  appState.setKillSwitch(value);
                },
              ),
              SwitchListTile(
                title: const Text('DNS Leak Protection'),
                subtitle: const Text('Prevent DNS queries from leaking'),
                value: appState.enableDnsProtection,
                onChanged: (value) {
                  appState.setDnsProtection(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerList() {
    if (_servers.isEmpty) {
      return Card(
        color: const Color(0xFF1a1f26),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), // Remove const
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No servers available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Group servers by country
    final serversByCountry = <String, List<dynamic>>{};
    for (final server in _servers) {
      final country = server['country'];
      if (!serversByCountry.containsKey(country)) {
        serversByCountry[country] = [];
      }
      serversByCountry[country]!.add(server);
    }

    // Country flag mapping
    final countryFlags = {
      'South Africa': '🇿🇦',
      'USA': '🇺🇸',
      'Germany': '🇩🇪',
      'Japan': '🇯🇵',
      'Singapore': '🇸🇬',
      'Brazil': '🇧🇷',
      'United Kingdom': '🇬🇧',
      'Canada': '🇨🇦',
      'Australia': '🇦🇺',
      'France': '🇫🇷',
      'Netherlands': '🇳🇱',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Servers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        
        ...serversByCountry.entries.map((entry) {
          final country = entry.key;
          final servers = entry.value;
          final flag = countryFlags[country] ?? '🌐';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      country,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${servers.length} servers)',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ...servers.map((server) => Card(
                color: const Color(0xFF1a1f26),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0), // Remove const
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getLoadColor(server['load'] ?? 0.0),
                    child: Text(
                      server['country'].toString().substring(0, 2),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(server['name']),
                  subtitle: Text(
                    '${server['city']} • ${(server['load'] * 100).toStringAsFixed(1)}% load • ${server['latency']}ms'
                  ),
                  trailing: const Icon(Icons.info_outline),
                  onTap: () => _showServerDetails(server),
                ),
              )).toList(),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ],
    );
  }
}