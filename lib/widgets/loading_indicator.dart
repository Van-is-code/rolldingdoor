import 'package:flutter/material.dart';

// Widget đơn giản hiển thị vòng quay loading
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}