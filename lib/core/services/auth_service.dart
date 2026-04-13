import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // se o usuário está logado ou não
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  //dados do usuário atual (ID, email, etc)
  User? get currentUser => _supabase.auth.currentUser;

  AuthService() {
    //verifica se já tem alguém logado ao abrir o app
    _isLoggedIn = _supabase.auth.currentUser != null;

    // fica escutando qualquer mudança no Supabase (Login, Logout, Token expirado)
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _isLoggedIn = true;
        notifyListeners(); // avisa o goRouter
      } else if (event == AuthChangeEvent.signedOut) {
        _isLoggedIn = false;
        notifyListeners(); 
      }
    });
  }

  // --- MÉTODOS ---

  // login
  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // cadastro
  Future<void> signUp(String email, String password) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

// instância global para o GoRouter poder acessar facilmente
final authService = AuthService();