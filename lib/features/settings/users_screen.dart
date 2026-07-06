import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/user.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().users.list();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final list = snap.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = context.read<AppServices>().users.list();
            });
            await _future;
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final u = list[i];
              return ListTile(
                title: Text(u.name),
                subtitle: Text(u.email),
                trailing: Text(u.roles.join(', ')),
              );
            },
          ),
        );
      },
    );
  }
}
