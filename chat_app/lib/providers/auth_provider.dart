import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    _token = await ApiService.getToken();
    _user = await ApiService.getUser();
    notifyListeners();
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.register(name, email, password);
      
      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['user']);
        
        await ApiService.saveToken(_token!);
        await ApiService.saveUser(_user!);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);
      
      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['user']);
        
        await ApiService.saveToken(_token!);
        await ApiService.saveUser(_user!);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await ApiService.logout(_token!);
      }
    } catch (e) {
      print('Error during logout: $e');
    }
    
    _token = null;
    _user = null;
    await ApiService.removeToken();
    await ApiService.removeUser();
    notifyListeners();
  }
}
