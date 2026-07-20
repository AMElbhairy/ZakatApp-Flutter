package com.zakahwealth.app.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ZakahWealthMediumWidgetReceiver : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views: RemoteViews =
          ZakahWealthWidgetRemoteViews.createMedium(context = context, widgetData = widgetData)
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
