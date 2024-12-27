import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'upload_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = '이메일과 비밀번호를 모두 입력해주세요.';
        });
        return;
      }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 성공 시 화면 전환은 main.dart의 StreamBuilder가 처리
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = '해당 이메일의 사용자를 찾을 수 없습니다.';
            break;
          case 'wrong-password':
            _errorMessage = '비밀번호가 잘못되었습니다.';
            break;
          default:
            _errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '로그인 중 예기치 않은 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = '이메일과 비밀번호를 모두 입력해주세요.';
        });
        return;
      }

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 회원가입 성공 시 화면 전환은 main.dart의 StreamBuilder가 처리
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = '이미 사용 중인 이메일입니다.';
            break;
          case 'weak-password':
            _errorMessage = '비밀번호가 너무 약합니다.';
            break;
          default:
            _errorMessage = '회원가입 중 오류가 발생했습니다: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '회원가입 중 예기치 않은 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('이력서 분석 로그인'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _login,
                child: Text('로그인'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: _signUp,
                child: Text('회원가입'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
