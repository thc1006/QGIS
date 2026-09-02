/***************************************************************************
     testqgsmacnative.cpp
     --------------------------------------
    Date                 : January 2014
    Copyright            : (C) 2014 by Larry Shaffer
    Email                : larrys at dakotacarto dot com
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "qgstest.h"

#include <QObject>
#include <QString>

using namespace Qt::StringLiterals;

//header for class being tested
#include "qgsmacnative.h"

class TestQgsMacNative : public QObject
{
    Q_OBJECT

  private slots:
    void testGetRunningAppName();
    void testUserInitiatedActivityLifecycle();
};

void TestQgsMacNative::testGetRunningAppName()
{
  QgsMacNative *macNative = new QgsMacNative();
  QCOMPARE( u"qgis_macnativetest"_s, QString( macNative->currentAppLocalizedName() ) );
  delete macNative;
}

void TestQgsMacNative::testUserInitiatedActivityLifecycle()
{
  QgsMacNative macNative;

  QVERIFY( macNative.capabilities().testFlag( QgsNative::NativeUserInitiatedActivities ) );
  QCOMPARE( macNative.userInitiatedActivityCount(), 0 );

  // An unmatched end must not affect a later activity.
  macNative.endUserInitiatedActivity();
  QCOMPARE( macNative.userInitiatedActivityCount(), 0 );

  macNative.beginUserInitiatedActivity( u"First activity"_s );
  QCOMPARE( macNative.userInitiatedActivityCount(), 1 );

  // Overlapping activities share the same process activity and are only
  // released after the last matching end call.
  macNative.beginUserInitiatedActivity( u"Second activity"_s );
  QCOMPARE( macNative.userInitiatedActivityCount(), 2 );
  macNative.endUserInitiatedActivity();
  QCOMPARE( macNative.userInitiatedActivityCount(), 1 );
  macNative.endUserInitiatedActivity();
  QCOMPARE( macNative.userInitiatedActivityCount(), 0 );

  // Cleanup must release all outstanding activities and be idempotent.
  macNative.beginUserInitiatedActivity( u"Outstanding activity"_s );
  macNative.beginUserInitiatedActivity( u"Another outstanding activity"_s );
  QCOMPARE( macNative.userInitiatedActivityCount(), 2 );
  macNative.cleanup();
  QCOMPARE( macNative.userInitiatedActivityCount(), 0 );
  macNative.cleanup();
  QCOMPARE( macNative.userInitiatedActivityCount(), 0 );
}

QGSTEST_MAIN( TestQgsMacNative )
#include "testqgsmacnative.moc"
