#import "AMapFlutterLocationPlugin.h"
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "AMapFlutterStreamManager.h"

@interface AMapFlutterLocationManager : AMapLocationManager

@property (nonatomic, assign) BOOL onceLocation;
@property (nonatomic, copy) FlutterResult flutterResult;
@property (nonatomic, strong) NSString *pluginKey;
@property (nonatomic, copy) NSString *fullAccuracyPurposeKey;

@end

@implementation AMapFlutterLocationManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _onceLocation = false;
        _fullAccuracyPurposeKey = nil;
    }
    return self;
}

@end

@interface AMapFlutterLocationPlugin()<AMapLocationManagerDelegate,AMapGeoFenceManagerDelegate>
@property (nonatomic, strong) NSMutableDictionary<NSString*, AMapFlutterLocationManager*> *pluginsDict;
@property (nonatomic, strong) AMapGeoFenceManager *geoFenceManager;
@property (nonatomic, strong) FlutterResult result;

@end

@implementation AMapFlutterLocationPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"amap_flutter_location"
                                     binaryMessenger:[registrar messenger]];
    AMapFlutterLocationPlugin* instance = [[AMapFlutterLocationPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    //AMapFlutterStreamHandler * streamHandler = [[AMapFlutterStreamHandler alloc] init];
    FlutterEventChannel *eventChanel = [FlutterEventChannel eventChannelWithName:@"amap_flutter_location_stream" binaryMessenger:[registrar messenger]];
    [eventChanel setStreamHandler:[[AMapFlutterStreamManager sharedInstance] streamHandler]];
        
}

- (instancetype)init {
    if ([super init] == self) {
        _pluginsDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startLocation" isEqualToString:call.method]){
        [self startLocation:call result:result];
    }else if ([@"stopLocation" isEqualToString:call.method]){
        [self stopLocation:call];
        result(@YES);
    }else if ([@"setLocationOption" isEqualToString:call.method]){
        [self setLocationOption:call];
    }else if ([@"destroy" isEqualToString:call.method]){
        [self destroyLocation:call];
    }else if ([@"setApiKey" isEqualToString:call.method]){
        NSString *apiKey = call.arguments[@"ios"];
        if (apiKey && [apiKey isKindOfClass:[NSString class]]) {
            [AMapServices sharedServices].apiKey = apiKey;
            result(@YES);
        }else {
            result(@NO);
        }
    }else if ([@"getSystemAccuracyAuthorization" isEqualToString:call.method]) {
        [self getSystemAccuracyAuthorization:call result:result];
    } else if ([@"updatePrivacyStatement" isEqualToString:call.method]) {
        [self updatePrivacyStatement:call.arguments];
    }else if ([@"addGeoFence" isEqualToString:call.method]) {
        [self addGeoFence:call.arguments result:result];
    }else if ([@"removeGeoFence" isEqualToString:call.method]) {
        [self removeGeoFence];
    } else {
        result(FlutterMethodNotImplemented);
    }
}


- (void)amapGeoFenceManager:(AMapGeoFenceManager *)manager didAddRegionForMonitoringFinished:(NSArray<AMapGeoFenceRegion *> *)regions customID:(NSString *)customID error:(NSError *)error{
    if (error) {
           NSLog(@"???????????????????????? %@",error);
       } else {
           NSLog(@"????????????????????????");
       }
}

- (void)amapGeoFenceManager:(AMapGeoFenceManager *)manager didGeoFencesStatusChangedForRegion:(AMapGeoFenceRegion *)region customID:(NSString *)customID error:(NSError *)error {
    if (error) {
        NSLog(@"status changed error %@",error);
    }else{
        if (self.result != nil) {
            self.result(@(region.fenceStatus));
            self.result = nil;
                       }
        NSLog(@"status changed success %@",[region description]);
    }
}


- (void)addGeoFence:(NSDictionary *)arguments result:(FlutterResult)result
{
    self.geoFenceManager = [[AMapGeoFenceManager alloc] init];
    if(self.result==nil){
        self.result = result;
    }
    NSString *keyword = arguments[@"keyword"];
    NSString *poiType = arguments[@"poiType"];
    NSString *city = arguments[@"city"];
    NSNumber *size = arguments[@"size"];
    NSString *customId = arguments[@"customId"];
    
    [self.geoFenceManager addKeywordPOIRegionForMonitoringWithKeyword:keyword POIType:poiType city:@"?????????" size:size customID:customId];
    self.geoFenceManager.delegate = self;
    self.geoFenceManager.activeAction = AMapGeoFenceActiveActionInside | AMapGeoFenceActiveActionOutside | AMapGeoFenceActiveActionStayed; //??????????????????????????????????????????????????????????????????????????????????????????AMapGeoFenceActiveActionInside?????????????????????????????????????????????????????????10?????????????????????????????????
//    self.geoFenceManager.allowsBackgroundLocationUpdates = YES;  //??????????????????
}

- (void)removeGeoFence
{
    NSLog(@"????????????????????????");
    [self.geoFenceManager removeAllGeoFenceRegions];
}

- (void)updatePrivacyStatement:(NSDictionary *)arguments {
    if ((AMapLocationVersionNumber) < 20800) {
        NSLog(@"????????????SDK????????????????????????????????????????????????SDK???2.8.0???????????????");
        return;
    }
    if (arguments == nil) {
        return;
    }
    if (arguments[@"hasContains"] != nil && arguments[@"hasShow"] != nil) {
        [AMapLocationManager updatePrivacyShow:[arguments[@"hasShow"] integerValue] privacyInfo:[arguments[@"hasContains"] integerValue]];
    }
    if (arguments[@"hasAgree"] != nil) {
        [AMapLocationManager updatePrivacyAgree:[arguments[@"hasAgree"] integerValue]];
    }
}

- (void)getSystemAccuracyAuthorization:(FlutterMethodCall*)call result:(FlutterResult)result {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
    if (@available(iOS 14.0, *)) {
        AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
        CLAccuracyAuthorization curacyAuthorization = [manager currentAuthorization];
        result(@(curacyAuthorization));
    }
#else
    if (result) {
        result(@(0));//????????????iOS14,???????????????????????????????????????
    }
#endif
}

- (void)startLocation:(FlutterMethodCall*)call result:(FlutterResult)result
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    if (manager.onceLocation) {
        [manager requestLocationWithReGeocode:manager.locatingWithReGeocode completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            [self handlePlugin:manager.pluginKey location:location reGeocode:regeocode error:error];
        }];
    } else {
        [manager setFlutterResult:result];
        [manager startUpdatingLocation];
    }
}

- (void)stopLocation:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }

    [manager setFlutterResult:nil];
    [[self locManagerWithCall:call] stopUpdatingLocation];
}

- (void)setLocationOption:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    NSNumber *needAddress = call.arguments[@"needAddress"];
    if (needAddress) {
        [manager setLocatingWithReGeocode:[needAddress boolValue]];
    }
        
    NSNumber *geoLanguage = call.arguments[@"geoLanguage"];
    if (geoLanguage) {
        if ([geoLanguage integerValue] == 0) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageDefault];
        } else if ([geoLanguage integerValue] == 1) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageChinse];
        } else if ([geoLanguage integerValue] == 2) {
            [manager setReGeocodeLanguage:AMapLocationReGeocodeLanguageEnglish];
        }
    }

    NSNumber *onceLocation = call.arguments[@"onceLocation"];
    if (onceLocation) {
        manager.onceLocation = [onceLocation boolValue];
    }

    NSNumber *pausesLocationUpdatesAutomatically = call.arguments[@"pausesLocationUpdatesAutomatically"];
    if (pausesLocationUpdatesAutomatically) {
        [manager setPausesLocationUpdatesAutomatically:[pausesLocationUpdatesAutomatically boolValue]];
    }
    
    NSNumber *desiredAccuracy = call.arguments[@"desiredAccuracy"];
    if (desiredAccuracy) {
        
        if (desiredAccuracy.integerValue == 0) {
            [manager setDesiredAccuracy:kCLLocationAccuracyBest];
        } else if (desiredAccuracy.integerValue == 1){
            [manager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
        } else if (desiredAccuracy.integerValue == 2){
            [manager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
        } else if (desiredAccuracy.integerValue == 3){
            [manager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
        } else if (desiredAccuracy.integerValue == 4){
            [manager setDesiredAccuracy:kCLLocationAccuracyKilometer];
        } else if (desiredAccuracy.integerValue == 5){
            [manager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
        }
    }
    
    NSNumber *distanceFilter = call.arguments[@"distanceFilter"];
    if (distanceFilter) {
        if (distanceFilter.doubleValue == -1) {
            [manager setDistanceFilter:kCLDistanceFilterNone];
        } else if (distanceFilter.doubleValue > 0) {
            [manager setDistanceFilter:distanceFilter.doubleValue];
        }
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
    if (@available(iOS 14.0, *)) {
        NSNumber *accuracyAuthorizationMode = call.arguments[@"locationAccuracyAuthorizationMode"];
        if (accuracyAuthorizationMode) {
            if ([accuracyAuthorizationMode integerValue] == 0) {
                [manager setLocationAccuracyMode:AMapLocationFullAndReduceAccuracy];
            } else if ([accuracyAuthorizationMode integerValue] == 1) {
                [manager setLocationAccuracyMode:AMapLocationFullAccuracy];
            } else if ([accuracyAuthorizationMode integerValue] == 2) {
                [manager setLocationAccuracyMode:AMapLocationReduceAccuracy];
            }
        }
        
        NSString *fullAccuracyPurposeKey = call.arguments[@"fullAccuracyPurposeKey"];
        if (fullAccuracyPurposeKey) {
            manager.fullAccuracyPurposeKey = fullAccuracyPurposeKey;
        }
    }
#endif
}

- (void)destroyLocation:(FlutterMethodCall*)call
{
    AMapFlutterLocationManager *manager = [self locManagerWithCall:call];
    if (!manager) {
        return;
    }
    
    @synchronized (self) {
        if (manager.pluginKey) {
            [_pluginsDict removeObjectForKey:manager.pluginKey];
        }
    }
    
}

- (void)handlePlugin:(NSString *)pluginKey location:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode error:(NSError *)error
{
    if (!pluginKey || ![[AMapFlutterStreamManager sharedInstance] streamHandler].eventSink) {
        return;
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:1];
    [dic setObject:[self getFormatTime:[NSDate date]] forKey:@"callbackTime"];
    [dic setObject:pluginKey forKey:@"pluginKey"];
    
    if (location) {
        [dic setObject:[self getFormatTime:location.timestamp] forKey:@"locTime"];
        [dic setValue:@1 forKey:@"locationType"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.latitude] forKey:@"latitude"];
        [dic setObject:[NSString stringWithFormat:@"%f",location.coordinate.longitude] forKey:@"longitude"];
        [dic setValue:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"accuracy"];
        [dic setValue:[NSNumber numberWithDouble:location.altitude] forKey:@"altitude"];
        [dic setValue:[NSNumber numberWithDouble:location.course] forKey:@"bearing"];
        [dic setValue:[NSNumber numberWithDouble:location.speed] forKey:@"speed"];
        
        if (reGeocode) {
            if (reGeocode.country) {
                [dic setValue:reGeocode.country forKey:@"country"];
            }
            
            if (reGeocode.province) {
                [dic setValue:reGeocode.province forKey:@"province"];
            }
            
            if (reGeocode.city) {
                [dic setValue:reGeocode.city forKey:@"city"];
            }
            
            if (reGeocode.district) {
                [dic setValue:reGeocode.district forKey:@"district"];
            }
            
            if (reGeocode.street) {
                [dic setValue:reGeocode.street forKey:@"street"];
            }
            
            if (reGeocode.number) {
                [dic setValue:reGeocode.number forKey:@"streetNumber"];
            }
            
            if (reGeocode.citycode) {
                [dic setValue:reGeocode.citycode forKey:@"cityCode"];
            }

            if (reGeocode.adcode) {
                [dic setValue:reGeocode.adcode forKey:@"adCode"];
            }
            
            if (reGeocode.description) {
                [dic setValue:reGeocode.formattedAddress forKey:@"description"];
            }
                        
            if (reGeocode.formattedAddress.length) {
                [dic setObject:reGeocode.formattedAddress forKey:@"address"];
            }
        }
        
    } else {
        [dic setObject:@"-1" forKey:@"errorCode"];
        [dic setObject:@"location is null" forKey:@"errorInfo"];
        
    }
    
    if (error) {
        [dic setObject:[NSNumber numberWithInteger:error.code]  forKey:@"errorCode"];
        [dic setObject:error.description forKey:@"errorInfo"];
    }
    
    [[AMapFlutterStreamManager sharedInstance] streamHandler].eventSink(dic);
    //NSLog(@"x===%f,y===%f",location.coordinate.latitude,location.coordinate.longitude);
}

- (AMapFlutterLocationManager *)locManagerWithCall:(FlutterMethodCall*)call {
    
    if (!call || !call.arguments || !call.arguments[@"pluginKey"] || [call.arguments[@"pluginKey"] isKindOfClass:[NSString class]] == NO) {
        return nil;
    }
    
    NSString *pluginKey = call.arguments[@"pluginKey"];
    
    AMapFlutterLocationManager *manager = nil;
    @synchronized (self) {
            manager = [_pluginsDict objectForKey:pluginKey];
    }
    
    if (!manager) {
        manager = [[AMapFlutterLocationManager alloc] init];
        if (manager == nil && (AMapLocationVersionNumber) >= 20800) {
            NSAssert(manager,@"AMapLocationManager????????????????????????SDK2.8.0?????????????????????????????????SDK??????????????????????????????????????????updatePrivacyShow:privacyInfo???updatePrivacyAgree????????????");
        }
        manager.pluginKey = pluginKey;
        manager.locatingWithReGeocode = YES;
        manager.delegate = self;
        @synchronized (self) {
            [_pluginsDict setObject:manager forKey:pluginKey];
        }
    }
    return manager;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000

/**
 *  @brief ???plist??????NSLocationTemporaryUsageDescriptionDictionary???desiredAccuracyMode??????CLAccuracyAuthorizationFullAccuracy?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????API?????????
 *  [manager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"PurposeKey" completion:^(NSError *error){
 *     if(completion){
 *        completion(error);
 *     }
 *  }]; (????????????,????????????????????????????????????????????????)
 *  @param manager ?????? AMapLocationManager ??????
 *  @param locationManager ???????????????????????????????????????locationManager???
 *  @param completion ????????????????????????API???????????????error: ??????????????????error?????????
 *  @since 2.6.7
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireTemporaryFullAccuracyAuth:(CLLocationManager*)locationManager completion:(void(^)(NSError *error))completion {
    if (@available(iOS 14.0, *)) {
        if ([manager isKindOfClass:[AMapFlutterLocationManager class]]) {
            AMapFlutterLocationManager *flutterLocationManager = (AMapFlutterLocationManager*)manager;
            if (flutterLocationManager.fullAccuracyPurposeKey && [flutterLocationManager.fullAccuracyPurposeKey length] > 0) {
                NSDictionary *locationTemporaryDictionary = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationTemporaryUsageDescriptionDictionary"];
                BOOL hasLocationTemporaryKey = locationTemporaryDictionary != nil && locationTemporaryDictionary.count != 0;
                if (hasLocationTemporaryKey) {
                    if ([locationTemporaryDictionary objectForKey:flutterLocationManager.fullAccuracyPurposeKey]) {
                        [locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:flutterLocationManager.fullAccuracyPurposeKey completion:^(NSError * _Nullable error) {
                            if (completion) {
                                completion(error);
                            }
                   
                        }];
                    } else {
                        NSLog(@"[AMapLocationKit] ??????iOS 14?????????????????????????????????, ???amap_location_option.dart ????????????fullAccuracyPurposeKey???key????????????infoPlist???,??????????????????key????????????");
                    }
                } else {
                    NSLog(@"[AMapLocationKit] ??????iOS 14?????????????????????????????????, ?????????Info.plist?????????NSLocationTemporaryUsageDescriptionDictionary?????????????????????Key????????????????????????????????????");
                }
        
            } else {
                NSLog(@"[AMapLocationKit] ??????iOS 14?????????????????????????????????, ?????????amap_location_option.dart ????????????????????????fullAccuracyPurposeKey???key??????????????????key??????infoPlist??????????????????");
            }
        }
    }
}
#endif

/**
 *  @brief ???plist??????NSLocationAlwaysUsageDescription??????NSLocationAlwaysAndWhenInUseUsageDescription?????????[CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined?????????????????????????????????
     ???????????????????????????????????????API?????????[locationManager requestAlwaysAuthorization](????????????,????????????????????????????????????)
 *  @param manager ?????? AMapLocationManager ??????
 *  @param locationManager  ?????????????????????????????????locationManager???
 *  @since 2.6.2
 */
- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager*)locationManager
{
    [locationManager requestWhenInUseAuthorization];
}

 /**
 *  @brief ?????????????????????????????????????????????????????????
 *  @param manager ?????? AMapLocationManager ??????
 *  @param error ???????????????????????? CLError ???
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:nil reGeocode:nil error:error];
}


/**
 *  @brief ????????????????????????.???????????????????????????????????????????????????????????????amapLocationManager:didUpdateLocation:???????????????
 *  @param manager ?????? AMapLocationManager ??????
 *  @param location ???????????????
 *  @param reGeocode ??????????????????
 */
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode
{
    [self handlePlugin:((AMapFlutterLocationManager *)manager).pluginKey location:location reGeocode:reGeocode error:nil];
}

- (NSString *)getFormatTime:(NSDate*)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSString *timeString = [formatter stringFromDate:date];
    return timeString;
}

@end
