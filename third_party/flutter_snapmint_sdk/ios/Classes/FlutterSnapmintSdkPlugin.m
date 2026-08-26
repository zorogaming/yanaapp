#import "FlutterSnapmintSdkPlugin.h"
#import <Flutter/Flutter.h>
#if __has_include(<flutter_snapmint_sdk/flutter_snapmint_sdk-Swift.h>)
#import <flutter_snapmint_sdk/flutter_snapmint_sdk-Swift.h>
#else
#import "flutter_snapmint_sdk-Swift.h"
#endif

@implementation FlutterSnapmintSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_snapmint_sdk"
            binaryMessenger:[registrar messenger]];
  FlutterSnapmintSdkPlugin* instance = [[FlutterSnapmintSdkPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (UIViewController *)yana_topViewController {
  UIWindow *window = nil;

  if (@available(iOS 13.0, *)) {
    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
    for (UIScene *scene in scenes) {
      if (![scene isKindOfClass:[UIWindowScene class]]) {
        continue;
      }
      UIWindowScene *windowScene = (UIWindowScene *)scene;
      if (windowScene.activationState != UISceneActivationStateForegroundActive &&
          windowScene.activationState != UISceneActivationStateForegroundInactive) {
        continue;
      }

      for (UIWindow *candidate in windowScene.windows) {
        if (candidate.isKeyWindow) {
          window = candidate;
          break;
        }
      }

      if (window == nil && windowScene.windows.count > 0) {
        window = windowScene.windows.firstObject;
      }

      if (window != nil) {
        break;
      }
    }
  }

  if (window == nil) {
    window = [UIApplication sharedApplication].delegate.window;
  }

  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController != nil) {
    controller = controller.presentedViewController;
  }

  if ([controller isKindOfClass:[UINavigationController class]]) {
    UINavigationController *nav = (UINavigationController *)controller;
    controller = nav.visibleViewController ?: nav.topViewController ?: controller;
  } else if ([controller isKindOfClass:[UITabBarController class]]) {
    UITabBarController *tab = (UITabBarController *)controller;
    controller = tab.selectedViewController ?: controller;
  }

  return controller;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  }if([@"openSnapmintMerchant" isEqualToString:call.method]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)call.arguments;
            NSString *urlStr = dict[@"url"];
            NSDictionary *header = dict[@"header"];
            NSLog(@"[FlutterSnapmintSdkPlugin] openSnapmintMerchant called with map payload, url=%@", urlStr);
            NSURL *url = [NSURL URLWithString:urlStr ?: @""];
            if (url == nil) {
                NSDictionary *errorResponse = @{
                    @"status": @"failure",
                    @"statusCode": @400,
                    @"responseMsg": @"Invalid checkout URL"
                };
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:errorResponse options:0 error:nil];
                NSLog(@"[FlutterSnapmintSdkPlugin] Invalid URL. Returning: %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
                result([[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
                return;
            }
            [self startSnapmintURL:url header:header result:result];
        } else {
            NSString *arg = (NSString *)call.arguments;
            NSLog(@"[FlutterSnapmintSdkPlugin] openSnapmintMerchant called with arg=%@", arg);
            NSURL *url = [NSURL URLWithString:arg];
            if (url == nil) {
                NSDictionary *errorResponse = @{
                    @"status": @"failure",
                    @"statusCode": @400,
                    @"responseMsg": @"Invalid checkout URL"
                };
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:errorResponse options:0 error:nil];
                NSLog(@"[FlutterSnapmintSdkPlugin] Invalid URL. Returning: %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
                result([[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
                return;
            }
            [self startSnapmintURL:url result:result];
        }
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startSnapmintURL:(NSURL*)url result:(FlutterResult)result {
    if (@available(iOS 13.0, *)) {
        NSLog(@"[FlutterSnapmintSdkPlugin] Launching Snapmint SDK with redirect_url: %@", url.absoluteString);
        UIViewController *host = [SnapmintUIHostingControllerFactory hostingControllerFor:url resultHandler:^(id  _Nullable payload) {
            if (payload) {
                NSLog(@"[FlutterSnapmintSdkPlugin] Raw payload from native (class=%@): %@", NSStringFromClass([payload class]), payload);
            } else {
                NSLog(@"[FlutterSnapmintSdkPlugin] Raw payload from native is <nil>");
            }
            // Align iOS return schema with Android: {status, statusCode, responseMsg}
            NSString *status = nil;
            NSString *payloadStr = nil;

            if (payload) {
                if ([payload isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = (NSDictionary *)payload;
                    id s = dict[@"status"]; if ([s isKindOfClass:[NSString class]]) status = (NSString *)s;
                    id dataVal = dict[@"data"];
                    if ([dataVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)dataVal;
                    } else if (dataVal && [NSJSONSerialization isValidJSONObject:dataVal]) {
                        NSData *json = [NSJSONSerialization dataWithJSONObject:dataVal options:0 error:nil];
                        payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                    }
                    if (!payloadStr) {
                        id msg = dict[@"message"]; if ([msg isKindOfClass:[NSString class]]) payloadStr = (NSString *)msg;
                    }
                } else if ([payload respondsToSelector:@selector(status)]) {
                    status = [payload valueForKey:@"status"] ?: @"";
                    id dataVal = nil; if ([payload respondsToSelector:@selector(data)]) dataVal = [payload valueForKey:@"data"];
                    id msgVal = nil; if ([payload respondsToSelector:@selector(message)]) msgVal = [payload valueForKey:@"message"];
                    if ([dataVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)dataVal;
                    } else if (dataVal && [NSJSONSerialization isValidJSONObject:dataVal]) {
                        NSData *json = [NSJSONSerialization dataWithJSONObject:dataVal options:0 error:nil];
                        payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                    } else if ([msgVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)msgVal;
                    }
                } else if ([payload isKindOfClass:[NSString class]]) {
                    payloadStr = (NSString *)payload;
                } else if ([NSJSONSerialization isValidJSONObject:payload]) {
                    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
                    payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                }
            }

            NSNumber *code = @400;
            if (status && [[status lowercaseString] isEqualToString:@"success"]) {
                code = @200;
            }
            if (!status) status = @"failure"; // default when unknown

            NSMutableDictionary *resp = [@{ @"status": status, @"statusCode": code } mutableCopy];
            if (payloadStr) resp[@"responseMsg"] = payloadStr;
            NSData *jsonResp = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonResp encoding:NSUTF8StringEncoding];
            NSLog(@"[FlutterSnapmintSdkPlugin] Returning JSON to Dart (android-like): %@", jsonStr);
            result(jsonStr);
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *topVC = [self yana_topViewController];
                [topVC dismissViewControllerAnimated:YES completion:nil];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *rootVC = [self yana_topViewController];
            if (rootVC == nil) {
                NSDictionary *resp = @{ @"status": @"failure", @"statusCode": @500, @"responseMsg": @"Unable to find active iOS view controller" };
                NSData *json = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
                result([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
                return;
            }
            host.modalPresentationStyle = UIModalPresentationFullScreen;
            [rootVC presentViewController:host animated:YES completion:nil];
        });
    } else {
        NSDictionary *resp = @{ @"status": @"failure", @"statusCode": @400, @"responseMsg": @"iOS 13+ required" };
        NSData *json = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
        result([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
    }
}

- (void)startSnapmintURL:(NSURL*)url header:(NSDictionary*)header result:(FlutterResult)result {
    if (@available(iOS 13.0, *)) {
        NSLog(@"[FlutterSnapmintSdkPlugin] Launching Snapmint SDK with redirect_url: %@ (with header)", url.absoluteString);
        UIViewController *host = [SnapmintUIHostingControllerFactory hostingControllerFor:url header:header resultHandler:^(id  _Nullable payload) {
            if (payload) {
                NSLog(@"[FlutterSnapmintSdkPlugin] Raw payload from native (class=%@): %@", NSStringFromClass([payload class]), payload);
            } else {
                NSLog(@"[FlutterSnapmintSdkPlugin] Raw payload from native is <nil>");
            }
            NSString *status = nil;
            NSString *payloadStr = nil;

            if (payload) {
                if ([payload isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = (NSDictionary *)payload;
                    id s = dict[@"status"]; if ([s isKindOfClass:[NSString class]]) status = (NSString *)s;
                    id dataVal = dict[@"data"];
                    if ([dataVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)dataVal;
                    } else if (dataVal && [NSJSONSerialization isValidJSONObject:dataVal]) {
                        NSData *json = [NSJSONSerialization dataWithJSONObject:dataVal options:0 error:nil];
                        payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                    }
                    if (!payloadStr) {
                        id msg = dict[@"message"]; if ([msg isKindOfClass:[NSString class]]) payloadStr = (NSString *)msg;
                    }
                } else if ([payload respondsToSelector:@selector(status)]) {
                    status = [payload valueForKey:@"status"] ?: @"";
                    id dataVal = nil; if ([payload respondsToSelector:@selector(data)]) dataVal = [payload valueForKey:@"data"];
                    id msgVal = nil; if ([payload respondsToSelector:@selector(message)]) msgVal = [payload valueForKey:@"message"];
                    if ([dataVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)dataVal;
                    } else if (dataVal && [NSJSONSerialization isValidJSONObject:dataVal]) {
                        NSData *json = [NSJSONSerialization dataWithJSONObject:dataVal options:0 error:nil];
                        payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                    } else if ([msgVal isKindOfClass:[NSString class]]) {
                        payloadStr = (NSString *)msgVal;
                    }
                } else if ([payload isKindOfClass:[NSString class]]) {
                    payloadStr = (NSString *)payload;
                } else if ([NSJSONSerialization isValidJSONObject:payload]) {
                    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
                    payloadStr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                }
            }

            NSNumber *code = @400;
            if (status && [[status lowercaseString] isEqualToString:@"success"]) {
                code = @200;
            }
            if (!status) status = @"failure";

            NSMutableDictionary *resp = [@{ @"status": status, @"statusCode": code } mutableCopy];
            if (payloadStr) resp[@"responseMsg"] = payloadStr;
            NSData *jsonResp = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonResp encoding:NSUTF8StringEncoding];
            NSLog(@"[FlutterSnapmintSdkPlugin] Returning JSON to Dart (android-like): %@", jsonStr);
            result(jsonStr);
            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *topVC = [self yana_topViewController];
                [topVC dismissViewControllerAnimated:YES completion:nil];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *rootVC = [self yana_topViewController];
            if (rootVC == nil) {
                NSDictionary *resp = @{ @"status": @"failure", @"statusCode": @500, @"responseMsg": @"Unable to find active iOS view controller" };
                NSData *json = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
                result([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
                return;
            }
            host.modalPresentationStyle = UIModalPresentationFullScreen;
            [rootVC presentViewController:host animated:YES completion:nil];
        });
    } else {
        NSDictionary *resp = @{ @"status": @"failure", @"statusCode": @400, @"responseMsg": @"iOS 13+ required" };
        NSData *json = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
        result([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
    }
}

@end
