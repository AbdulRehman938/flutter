import 'package:flutter/material.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/widgets/top_toast.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  bool _isLoggingOut = false;
  bool _isProfileLoading = true;
  String _fullName = 'User';
  String _email = '';
  String _username = 'Not set';
  String _joinedDate = 'Not available';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _fullName = profile?.fullName ?? 'User';
        _email = profile?.email ?? '';
        _username = (profile?.username != null && profile!.username!.isNotEmpty)
            ? profile.username!
            : 'Not set';
        _joinedDate = _formatJoinedDate(profile?.createdAt);
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProfileLoading = false;
      });
    }
  }

  String _formatJoinedDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingOut = false;
      });
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoggingOut = false;
      });
      TopToast.show(context, 'Something went wrong. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              primary.withValues(alpha: 0.08),
              const Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.dashboard_customize_rounded,
                          size: 34,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isProfileLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        Text(
                          'Welcome, $_fullName',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Username: $_username',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Joined: $_joinedDate',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoggingOut ? null : _logout,
                        child: _isLoggingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
