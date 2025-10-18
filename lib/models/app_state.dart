import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState with ChangeNotifier {
  // Authentication state
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  
  // Connection state
  bool _isConnected = false;
  Map<String, dynamic>? _currentSession;
  Map<String, dynamic>? _currentServer;
  
  // UI State with persistence
  String _selectedLocation = 'Automatic';
  String _securityLevel = 'high';
  bool _enableKillSwitch = true;
  bool _enableDnsProtection = true;
  
  // Data
  List<dynamic> _servers = [];
  List<dynamic> _userSessions = [];
  Map<String, dynamic> _userStats = {};

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  bool get isConnected => _isConnected;
  Map<String, dynamic>? get currentSession => _currentSession;
  Map<String, dynamic>? get currentServer => _currentServer;
  String get selectedLocation => _selectedLocation;
  String get securityLevel => _securityLevel;
  bool get enableKillSwitch => _enableKillSwitch;
  bool get enableDnsProtection => _enableDnsProtection;
  List<dynamic> get servers => _servers;
  List<dynamic> get userSessions => _userSessions;
  Map<String, dynamic> get userStats => _userStats;

  AppState() {
    _loadPreferences();
  }

  // Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedLocation = prefs.getString('selected_location') ?? 'Automatic';
      _securityLevel = prefs.getString('security_level') ?? 'high';
      _enableKillSwitch = prefs.getBool('enable_kill_switch') ?? true;
      _enableDnsProtection = prefs.getBool('enable_dns_protection') ?? true;
      notifyListeners();
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  // Save preference to SharedPreferences
  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (e) {
      print('Error saving preference $key: $e');
    }
  }

  // Authentication methods
  void login(Map<String, dynamic> userData) {
    _isLoggedIn = true;
    _user = userData;
    notifyListeners();
  }
  
  void logout() {
    _isLoggedIn = false;
    _user = null;
    _isConnected = false;
    _currentSession = null;
    _currentServer = null;
    _servers = [];
    _userSessions = [];
    _userStats = {};
    notifyListeners();
  }
  
  // Connection methods
  void setConnected(bool connected, {Map<String, dynamic>? session, Map<String, dynamic>? server}) {
    _isConnected = connected;
    _currentSession = session;
    _currentServer = server;
    notifyListeners();
  }
  
  // UI configuration methods with persistence
  void setLocation(String location) {
    _selectedLocation = location;
    _savePreference('selected_location', location);
    notifyListeners();
  }
  
  void setSecurityLevel(String level) {
    _securityLevel = level;
    _savePreference('security_level', level);
    notifyListeners();
  }
  
  void setKillSwitch(bool enabled) {
    _enableKillSwitch = enabled;
    _savePreference('enable_kill_switch', enabled);
    notifyListeners();
  }
  
  void setDnsProtection(bool enabled) {
    _enableDnsProtection = enabled;
    _savePreference('enable_dns_protection', enabled);
    notifyListeners();
  }
  
  // Data methods
  void setServers(List<dynamic> servers) {
    _servers = servers;
    notifyListeners();
  }
  
  void setUserSessions(List<dynamic> sessions) {
    _userSessions = sessions;
    notifyListeners();
  }
  
  void setUserStats(Map<String, dynamic> stats) {
    _userStats = stats;
    notifyListeners();
  }
  
  void updateUserData(Map<String, dynamic> userData) {
    _user = userData;
    notifyListeners();
  }

  // Clear all persisted data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }

  // Reset to default settings
  Future<void> resetToDefaults() async {
    _selectedLocation = 'Automatic';
    _securityLevel = 'high';
    _enableKillSwitch = true;
    _enableDnsProtection = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_location');
      await prefs.remove('security_level');
      await prefs.remove('enable_kill_switch');
      await prefs.remove('enable_dns_protection');
    } catch (e) {
      print('Error resetting to defaults: $e');
    }
    
    notifyListeners();
  }
}