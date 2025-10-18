import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  // For deployed backend
  static const String baseUrl = 'https://anonimity-proxy-backend.onrender.com/api';
  
  // For local development
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS simulator
  // static const String baseUrl = 'http://192.168.1.100:8000/api'; // Physical device

  static const int timeoutSeconds = 10;
  
  final http.Client client;
  String? _accessToken;
  
  ApiService(this.client);

  // Enhanced debugging method
  void _log(String message) {
    print('🔐 API Service: $message');
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      _accessToken = accessToken;
      _log('Tokens saved successfully');
    } catch (e) {
      _log('Error saving tokens: $e');
      throw Exception('Failed to save authentication tokens');
    }
  }
  
  Future<void> _loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _log('Loaded access token: ${_accessToken != null ? "YES" : "NO"}');
    } catch (e) {
      _log('Error loading tokens: $e');
    }
  }
  
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      _accessToken = null;
      _log('Tokens cleared');
    } catch (e) {
      _log('Error clearing tokens: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    await _loadTokens();
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    _log('Response status: ${response.statusCode}');
    _log('Response body: ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (e) {
        _log('JSON decode error: $e');
        throw Exception('Invalid JSON response: $e');
      }
    } else if (response.statusCode == 401) {
      _log('Authentication failed - token may be expired');
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await clearTokens();
        throw Exception('Session expired. Please login again.');
      }
      return null;
    } else if (response.statusCode == 400) {
      final errorBody = json.decode(response.body);
      final errorMessage = _extractErrorMessage(errorBody);
      throw Exception(errorMessage);
    } else if (response.statusCode == 404) {
      throw Exception('API endpoint not found. Check server configuration.');
    } else if (response.statusCode == 500) {
      throw Exception('Server error. Please try again later.');
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  String _extractErrorMessage(dynamic errorBody) {
    if (errorBody is Map<String, dynamic>) {
      if (errorBody.containsKey('error')) {
        return errorBody['error'].toString();
      }
      if (errorBody.containsKey('detail')) {
        return errorBody['detail'].toString();
      }
      if (errorBody.containsKey('non_field_errors')) {
        return errorBody['non_field_errors'].first.toString();
      }
      for (final key in errorBody.keys) {
        if (errorBody[key] is List && (errorBody[key] as List).isNotEmpty) {
          return '${key.replaceAll('_', ' ')}: ${errorBody[key].first}';
        }
      }
    }
    return 'An error occurred';
  }

  Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    
    if (refreshToken == null) {
      _log('No refresh token available');
      return false;
    }
    
    try {
      _log('Attempting token refresh...');
      final response = await client.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        body: json.encode({'refresh': refreshToken}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(data['access'], refreshToken);
        _log('Token refresh successful');
        return true;
      } else {
        _log('Token refresh failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log('Token refresh error: $e');
      return false;
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      _log('Network connectivity: $isConnected');
      return isConnected;
    } catch (e) {
      _log('Connectivity check error: $e');
      return false;
    }
  }

  Future<bool> testConnection() async {
    try {
      _log('Testing server connection...');
      
      // Check basic network connectivity
      if (!await checkConnectivity()) {
        _log('No network connectivity');
        return false;
      }

      // Make a simple GET request to check if server is reachable
      final response = await client.get(
        Uri.parse('$baseUrl/servers/'),
      ).timeout(const Duration(seconds: 5));
      
      // Any response means the server is reachable
      _log('Server responded with status: ${response.statusCode}');
      return true;
    } catch (e) {
      _log('Server connection test failed: $e');
      return false;
    }
  }

  Future<http.Response> _makeRequest(Future<http.Response> Function() request) async {
    if (!await checkConnectivity()) {
      throw Exception('No internet connection. Please check your network.');
    }

    try {
      _log('Making API request...');
      final response = await request().timeout(
        const Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw Exception('Request timeout. Server may be unavailable.');
        },
      );
      return response;
    } on SocketException {
      throw Exception('Network error. Cannot connect to server.');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } on FormatException {
      throw Exception('Invalid response format from server');
    }
  }

  // Authentication endpoints
  Future<dynamic> register({
    required String username,
    required String password,
    String? email,
    String? mobileId,
  }) async {
    _log('Attempting registration for user: $username');
    
    final response = await _makeRequest(() => client.post(
      Uri.parse('$baseUrl/auth/register/'),
      body: json.encode({
        'username': username,
        'password': password,
        'email': email ?? '',
        'mobile_id': mobileId ?? 'flutter-app-${DateTime.now().millisecondsSinceEpoch}',
      }),
      headers: {'Content-Type': 'application/json'},
    ));

    final data = await _handleResponse(response);
    if (data != null) {
      await _saveTokens(data['access'], data['refresh']);
      _log('Registration successful');
    }
    return data;
  }
  
  Future<dynamic> login({
    required String username,
    required String password,
    String? mobileId,
  }) async {
    _log('Attempting login for user: $username');
    
    final response = await _makeRequest(() => client.post(
      Uri.parse('$baseUrl/auth/login/'),
      body: json.encode({
        'username': username,
        'password': password,
        'mobile_id': mobileId ?? 'flutter-app-${DateTime.now().millisecondsSinceEpoch}',
      }),
      headers: {'Content-Type': 'application/json'},
    ));

    final data = await _handleResponse(response);
    if (data != null) {
      await _saveTokens(data['access'], data['refresh']);
      _log('Login successful');
    } else {
      _log('Login failed - no data received');
    }
    return data;
  }
  
  Future<void> logout() async {
    _log('Logging out user');
    await clearTokens();
  }

  Future<bool> isAuthenticated() async {
    await _loadTokens();
    if (_accessToken == null) {
      _log('No access token - user not authenticated');
      return false;
    }
    
    try {
      await getUserProfile();
      _log('User is authenticated');
      return true;
    } catch (e) {
      _log('Authentication check failed: $e');
      await clearTokens();
      return false;
    }
  }

  // Proxy server endpoints
  Future<List<dynamic>> getProxyServers({String? country}) async {
    final headers = await _getHeaders();
    final url = country != null && country != 'Automatic' 
        ? Uri.parse('$baseUrl/servers/?country=$country')
        : Uri.parse('$baseUrl/servers/');
    
    final response = await _makeRequest(() => client.get(url, headers: headers));
    return await _handleResponse(response) ?? [];
  }
  
  Future<List<dynamic>> getAvailableCountries() async {
    final headers = await _getHeaders();
    final response = await _makeRequest(() => client.get(
      Uri.parse('$baseUrl/servers/countries/'),
      headers: headers,
    ));
    return await _handleResponse(response) ?? [];
  }

  // Session management
  Future<dynamic> connectToServer({
    String? serverId,
    String? country,
    String securityLevel = 'high',
    bool enableKillSwitch = true,
    bool enableDnsProtection = true,
  }) async {
    final headers = await _getHeaders();
    
    final body = <String, dynamic>{
      'security_level': securityLevel,
      'enable_kill_switch': enableKillSwitch,
      'enable_dns_protection': enableDnsProtection,
    };
    
    if (serverId != null) {
      body['server_id'] = serverId;
    }
    if (country != null && country != 'Automatic') {
      body['country'] = country;
    }

    final response = await _makeRequest(() => client.post(
      Uri.parse('$baseUrl/sessions/'),
      body: json.encode(body),
      headers: headers,
    ));
    
    return await _handleResponse(response);
  }
  
  Future<dynamic> disconnectSession(String sessionId) async {
    final headers = await _getHeaders();
    final response = await _makeRequest(() => client.post(
      Uri.parse('$baseUrl/sessions/$sessionId/disconnect/'),
      headers: headers,
    ));
    return await _handleResponse(response);
  }
  
  Future<dynamic> getActiveSession() async {
    final headers = await _getHeaders();
    try {
      final response = await _makeRequest(() => client.get(
        Uri.parse('$baseUrl/sessions/active/'),
        headers: headers,
      ));
      return await _handleResponse(response);
    } catch (e) {
      // 404 is expected when no active session exists
      if (e.toString().contains('404')) {
        return null;
      }
      rethrow;
    }
  }
  
  Future<List<dynamic>> getUserSessions() async {
    final headers = await _getHeaders();
    final response = await _makeRequest(() => client.get(
      Uri.parse('$baseUrl/sessions/'),
      headers: headers,
    ));
    return await _handleResponse(response) ?? [];
  }

  // User management
  Future<dynamic> getUserProfile() async {
    final headers = await _getHeaders();
    final response = await _makeRequest(() => client.get(
      Uri.parse('$baseUrl/users/profile/'),
      headers: headers,
    ));
    return await _handleResponse(response);
  }
  
  Future<dynamic> getUserStats() async {
    final headers = await _getHeaders();
    final response = await _makeRequest(() => client.get(
      Uri.parse('$baseUrl/users/stats/'),
      headers: headers,
    ));
    return await _handleResponse(response);
  }
}