import 'package:flutter/material.dart';

// Widget hiển thị vòng quay loading với text tùy chọn
class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Thu gọn lại
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[ // Nếu có message thì hiển thị
            const SizedBox(height: 15),
            Text(message!, textAlign: TextAlign.center),
          ]
        ],
      ),
    );
  }
}