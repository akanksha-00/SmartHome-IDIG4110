import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/models/authentication/auth_user.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';
import 'package:smart_home/src/screen/authentication/sign_in_page.dart';

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key, required this.signedInBuilder});
  final Widget Function(BuildContext context, AuthUser user) signedInBuilder;

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous.user?.id != current.user?.id ||
            (current.user != null && current.error != null),
        listener: (context, state) {
          final user = state.user;
          if (user != null && state.status == AuthStatus.signedIn) {
            if (state.error != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.error!)));
              return;
            }
            final settings = AppSettingsScope.read(context);
            if (settings.profile.name != user.name ||
                settings.profile.email != user.email) {
              settings.setProfile(
                  ProfileDetails(name: user.name, email: user.email));
            }
          }
        },
        builder: (context, state) {
          if (state.status == AuthStatus.restoring) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = state.user;
          if (user != null) return signedInBuilder(context, user);
          return const SignInPage();
        },
      );
}
