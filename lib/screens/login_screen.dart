import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService authService = AuthService();

  void login() async {
    AuthResult result = await authService.signIn(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (result.user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: Scaffold(
        backgroundColor: Colors.purple[900],
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/versatale_home_image.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("Welcome back!", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center,),
                          SizedBox(height: 20),
                          TextField(
                            controller: emailController,
                            decoration: InputDecoration(labelText: "Email", filled: true, fillColor: Colors.grey[200]),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: passwordController,
                            decoration: InputDecoration(labelText: "Password", filled: true, fillColor: Colors.grey[200]),
                            obscureText: true,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(60, 30),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: login,
                            child: Text("Log In", style: TextStyle(color: Colors.black, fontSize: 18)),
                          ),
                          TextButton(
                            onPressed: () async {
                              String email = emailController.text.trim();
                              if (email.isNotEmpty) {
                                AuthResult result = await authService.resetPassword(email);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Please enter your email address to reset your password.")),
                                );
                              }
                            },
                            child: Text("Forgot Password?", style: GoogleFonts.poppins(color: Colors.black)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegisterScreen()),
                              );
                            },
                            child: Text("Don't have an account? Sign Up", style: GoogleFonts.poppins(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/versatale_home_image.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("Welcome back!", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center,),
                          SizedBox(height: 20),
                          TextField(
                            controller: emailController,
                            decoration: InputDecoration(labelText: "Email", filled: true, fillColor: Colors.grey[200]),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: passwordController,
                            decoration: InputDecoration(labelText: "Password", filled: true, fillColor: Colors.grey[200]),
                            obscureText: true,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(60, 30),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: login,
                            child: Text("Log In", style: TextStyle(color: Colors.black, fontSize: 18)),
                          ),
                          TextButton(
                            onPressed: () async {
                              String email = emailController.text.trim();
                              if (email.isNotEmpty) {
                                AuthResult result = await authService.resetPassword(email);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Please enter your email address to reset your password.")),
                                );
                              }
                            },
                            child: Text("Forgot Password?", style: GoogleFonts.poppins(color: Colors.black)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegisterScreen()),
                              );
                            },
                            child: Text("Don't have an account? Sign Up", style: GoogleFonts.poppins(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
