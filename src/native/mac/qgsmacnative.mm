/***************************************************************************
    qgsmacnative.cpp - abstracted interface to native Mac objective-c
                             -------------------
    begin                : January 2014
    copyright            : (C) 2014 by Larry Shaffer
    email                : larrys at dakotacarto dot com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "qgsmacnative.h"

#include <Cocoa/Cocoa.h>

#include <QPixmap>
#include <QString>

@interface QgsUserNotificationCenterDelegate
    : NSObject <NSUserNotificationCenterDelegate>
@end

@implementation QgsUserNotificationCenterDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
#pragma unused(notification)
#pragma unused(center)
  return YES;
}

@end

class QgsMacNative::QgsUserNotificationCenter {
public:
  QgsUserNotificationCenterDelegate *_qgsUserNotificationCenter;
  NSImage *_qgisIcon;
};

class QgsMacNative::QgsUserInitiatedActivity {
public:
  id _token = nil;
  int _count = 0;
};

QgsMacNative::QgsMacNative()
    : mQgsUserNotificationCenter(
          new QgsMacNative::QgsUserNotificationCenter()),
      mUserInitiatedActivity(new QgsMacNative::QgsUserInitiatedActivity()) {
  mQgsUserNotificationCenter->_qgsUserNotificationCenter =
      [[QgsUserNotificationCenterDelegate alloc] init];
  [[NSUserNotificationCenter defaultUserNotificationCenter]
      setDelegate:mQgsUserNotificationCenter->_qgsUserNotificationCenter];
}

QgsMacNative::~QgsMacNative() {
  cleanup();
  [mQgsUserNotificationCenter->_qgsUserNotificationCenter dealloc];
  delete mQgsUserNotificationCenter;
  delete mUserInitiatedActivity;
}

void QgsMacNative::cleanup() {
  if (mUserInitiatedActivity->_token) {
    [[NSProcessInfo processInfo]
        endActivity:mUserInitiatedActivity->_token];
    [mUserInitiatedActivity->_token release];
    mUserInitiatedActivity->_token = nil;
  }
  mUserInitiatedActivity->_count = 0;
}

void QgsMacNative::setIconPath(const QString &iconPath) {
  mQgsUserNotificationCenter->_qgisIcon =
      [[NSImage alloc] initWithCGImage:QPixmap(iconPath).toImage().toCGImage()
                                  size:NSZeroSize];
}

const char *QgsMacNative::currentAppLocalizedName() {
  return [[[NSRunningApplication currentApplication] localizedName] UTF8String];
}

void QgsMacNative::currentAppActivateIgnoringOtherApps() {
  [[NSRunningApplication currentApplication]
      activateWithOptions:(NSApplicationActivateAllWindows |
                           NSApplicationActivateIgnoringOtherApps)];
}

void QgsMacNative::openFileExplorerAndSelectFile(const QString &path) {
  NSString *pathStr =
      [[NSString alloc] initWithUTF8String:path.toUtf8().constData()];
  NSArray *fileURLs =
      [NSArray arrayWithObjects:[NSURL fileURLWithPath:pathStr], nil];
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

QgsNative::Capabilities QgsMacNative::capabilities() const {
  return NativeDesktopNotifications | NativeUserInitiatedActivities;
}

QgsNative::NotificationResult QgsMacNative::showDesktopNotification(
    const QString &summary, const QString &body,
    const QgsNative::NotificationSettings &settings) {
  NSUserNotification *notification = [[NSUserNotification alloc] init];
  notification.title = summary.toNSString();
  notification.informativeText = body.toNSString();
  notification.soundName =
      NSUserNotificationDefaultSoundName; // Will play a default sound
  NSImage *image = nil;
  if (settings.image.isNull()) {
    // image application (qgis.icns) seems not to be set for now, although
    // present in the plist whenever fixed, try following line (and remove
    // corresponding code in QgsMacNative::QgsUserNotificationCenter) image =
    // [[NSImage imageNamed:@"NSApplicationIcon"] retain]
    image = mQgsUserNotificationCenter->_qgisIcon;
  } else {
    const QPixmap px = QPixmap::fromImage(settings.image);
    image = [[NSImage alloc] initWithCGImage:px.toImage().toCGImage()
                                        size:NSZeroSize];
  }
  notification.contentImage = image;

  [[NSUserNotificationCenter defaultUserNotificationCenter]
      deliverNotification:notification];
  [notification autorelease];

  //[userCenterDelegate dealloc];

  NotificationResult result;
  result.successful = true;
  return result;
}

bool QgsMacNative::hasDarkTheme() {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
  // Version comparison needs to be numeric, in case __MAC_10_10_4 is not
  // defined, e.g. some pre-10.14 SDKs See:
  // https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/cross_development/Using/using.html
  //      Section "Conditionally Compiling for Different SDKs"
  if ([NSApp respondsToSelector:@selector(effectiveAppearance)]) {
    // compiled on macos 10.14+ AND running on macos 10.14+
    // check the settings of effective appearance of the user
    NSAppearanceName appearanceName =
        [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[
          NSAppearanceNameAqua, NSAppearanceNameDarkAqua
        ]];
    return ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]);
  } else {
    // compiled on macos 10.14+ BUT running on macos 10.13-
    // DarkTheme was introduced in MacOS 10.14, fallback to light theme
    return false;
  }
#endif
#endif
  // compiled on macos 10.13-
  // NSAppearanceNameDarkAqua is not in SDK headers
  // fallback to light theme
  return false;
}

void QgsMacNative::beginUserInitiatedActivity(const QString &reason) {
  ++mUserInitiatedActivity->_count;
  if (mUserInitiatedActivity->_count != 1) {
    return;
  }

  NSString *activityReason = reason.isEmpty()
                                 ? @"QGIS user-initiated processing"
                                 : reason.toNSString();
  mUserInitiatedActivity->_token = [[[NSProcessInfo processInfo]
      beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep
                        reason:activityReason] retain];
}

void QgsMacNative::endUserInitiatedActivity() {
  if (mUserInitiatedActivity->_count == 0) {
    return;
  }

  --mUserInitiatedActivity->_count;
  if (mUserInitiatedActivity->_count != 0) {
    return;
  }

  if (mUserInitiatedActivity->_token) {
    [[NSProcessInfo processInfo]
        endActivity:mUserInitiatedActivity->_token];
    [mUserInitiatedActivity->_token release];
    mUserInitiatedActivity->_token = nil;
  }
}

int QgsMacNative::userInitiatedActivityCount() const {
  return mUserInitiatedActivity->_count;
}
