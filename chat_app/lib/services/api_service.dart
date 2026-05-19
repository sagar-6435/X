import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/user.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Constants.tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.tokenKey, token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.tokenKey);
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.userKey, jsonEncode(user.toJson()));
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(Constants.userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<void> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.userKey);
  }

  static Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/auth/me'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(
      String token, String name, String? profilePic) async {
    final response = await http.put(
      Uri.parse('${Constants.baseUrl}/auth/profile'),
      headers: _getHeaders(token),
      body: jsonEncode({
        'name': name,
        if (profilePic != null) 'profilePic': profilePic,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateFcmToken(
      String token, String fcmToken) async {
    final response = await http.put(
      Uri.parse('${Constants.baseUrl}/auth/fcm-token'),
      headers: _getHeaders(token),
      body: jsonEncode({'fcmToken': fcmToken}),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/logout'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  // Chat endpoints
  static Future<Map<String, dynamic>> getChats(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/chat/chats'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOrCreateChat(
      String token, String userId) async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/chat/chat/$userId'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMessages(
      String token, String chatId) async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/chat/messages/$chatId'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> markMessagesAsSeen(
      String token, String chatId) async {
    final response = await http.put(
      Uri.parse('${Constants.baseUrl}/chat/messages/$chatId/seen'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAllUsers(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/chat/users'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> clearChat(
      String token, String chatId) async {
    final response = await http.delete(
      Uri.parse('${Constants.baseUrl}/chat/chat/$chatId/clear'),
      headers: _getHeaders(token),
    );

    return jsonDecode(response.body);
  }

  // Upload endpoint
  static Future<Map<String, dynamic>> uploadImage(
      String token, String imagePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${Constants.baseUrl}/upload/image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('image', imagePath),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    return jsonDecode(responseBody);
  }
}
