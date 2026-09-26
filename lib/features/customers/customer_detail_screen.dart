import 'package:flutter/material.dart';

import 'widgets/customer_detail_body.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return CustomerDetailBody(id: id);
  }
}
