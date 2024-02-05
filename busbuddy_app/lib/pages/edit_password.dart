import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;

class EditPasswordPage extends StatefulWidget {
  @override
  _EditPasswordPageState createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  TextEditingController _oldPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  // @override
  // void dispose() {
  //   _oldPasswordController.dispose();
  //   _newPasswordController.dispose();
  //   _confirmPasswordController.dispose();
  //   super.dispose();
  // }

  bool showicon = true;
  bool obscureText1 = true;
  bool obscureText2 = true;
  bool obscureText3 = true;

  @override
  void initState() {
    super.initState();
    // Add any initialization logic if needed
  }

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _oldPasswordController,
                  decoration: InputDecoration(
                      labelText: 'Old Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            showicon ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            obscureText1 = !obscureText1;
                            showicon = !showicon;
                          });
                        },
                      )),
                  obscureText: obscureText1,
                  // add visibility icon when clicked will show the password and when clicked again will hide it
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            showicon ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            obscureText2 = !obscureText2;
                            showicon = !showicon;
                          });
                        },
                      )),
                  obscureText: obscureText2,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            showicon ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            obscureText3 = !obscureText3;
                            showicon = !showicon;
                          });
                        },
                      )),
                  obscureText: obscureText3,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Validate and save password changes
                    _savePasswordChanges();
                  },
                  child: Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePasswordChanges() async {
    String oldPassword = _oldPasswordController.text;
    String newPassword = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;

    context.loaderOverlay.show();

    if (newPassword != confirmPassword) {
      // Show fluttertoast
      Fluttertoast.showToast(
          msg: "New password and confirm password do not match",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return;
    }

    var r = await Requests.post(globel.serverIp + 'updatePassword',
        body: {
          'old': oldPassword,
          'new': newPassword,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    if (json['success'] == true) {
      // Show fluttertoast
      Fluttertoast.showToast(
          msg: "Password updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0);
      GoRouter.of(context).replace("/show_profile");
      context.loaderOverlay.hide();
    } else {
      // Show fluttertoast
      Fluttertoast.showToast(
          msg: "Password update failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return;
    }

    print('Old Password: $oldPassword');
    print('New Password: $newPassword');
    print('Confirm Password: $confirmPassword');
  }
}
