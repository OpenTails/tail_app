import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:go_router/go_router.dart';

class JsonPreview extends StatelessWidget {
  const JsonPreview({super.key});

  @override
  Widget build(BuildContext context) {
    Object? jsonDataRaw = GoRouterState.of(context).extra;
    String jsonData = jsonDataRaw != null ? jsonDataRaw as String : "null";
    return Scaffold(
      appBar: AppBar(
        title: const Text('Json Preview'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: getJsonWidget(jsonData),
    );
  }

  Widget getJsonWidget(String data) {
    if (data == 'null') {
      return const Center(
        child: Text('No data stored'),
      );
    } else {
      return JsonView.string(data);
    }
  }
}
