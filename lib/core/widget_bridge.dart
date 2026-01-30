import 'package:home_widget/home_widget.dart';

class WidgetBridge {
  static const String widgetName = 'FocusFlowWidgetProvider';

  static Future<void> updateTodayMinutes(int minutes) async {
    await HomeWidget.saveWidgetData<int>('today_minutes', minutes);
    await HomeWidget.updateWidget(name: widgetName);
  }
}
