//
//  OPMonitor.m
//  RSFrameworksHook
//
//  Created by Costin Andronache on 1/18/17.
//  Copyright © 2017 RomSoft. All rights reserved.
//

#import "OPMonitor.h"
#import "LocationInputSupervisor.h"
#import "NSURLSessionSupervisor.h"
#import "ProximityInputSupervisor.h"
#import "PedometerInputSupervisor.h"
#import "ContactsInputSupervisor.h"
#import "MicrophoneInputSupervisor.h"
#import "CameraInputSupervisor.h"
#import "TouchIdSupervisor.h"
#import "MagnetometerInputSupervisor.h"
#import "AccelerometerInputSupervisor.h"
#import "BarometerInputSupervisor.h"
#import "PickerControllerSupervisor.h"
#import "BatteryInputSupervisor.h"
#import "DeviceInfoInputSupervisor.h"
#import "DeviceMotionInputSupervisor.h"
#import "GyroscopeInputSupervisor.h"
#import "DefaultConfirmationSupervisor.h"

#import "PPSupervisingModule.h"
#import "PPInputSwizzlingModule.h"

#import "PlistReportsStorage.h"
#import "JRSwizzle.h"
#import "LocationInputSwizzler.h"
#import "CommonViewUtils.h"
#import "PPFlowBuilder.h"
#import "Security.h"
#import "SCDSender.h"
#import <PPCommonUI/PPCommonUI-Swift.h>
#import "PPBasicHttpBodyParser.h"



@interface NSArray(FindObjectOfClass)
-(id _Nullable)firstObjectOfClass:(Class)class;
@end

@implementation NSArray(FindObjectOfClass)

-(id)firstObjectOfClass:(Class)class{
    for (id obj in self) {
        if ([obj isKindOfClass:class]) {
            return obj;
        }
    }
    return nil;
}

@end

@interface OPMonitor() <InputSupervisorDelegate>

@property (strong, nonatomic) OPMonitorSettings *monitorSettings;
@property (strong, nonatomic) NSDictionary *scdJson;
@property (strong, nonatomic) SCDDocument *document;
@property (strong, nonatomic) UIButton *handle;
@property (strong, nonatomic) id<SCDSender> scdSender;
@property (strong, nonatomic) PPSupervisingModule *supervisingModule;
@property (strong, nonatomic) PPInputSwizzlingModule *inputSwizzlingModule;
@end

@implementation OPMonitor

+(void)initializeMonitoring {
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"AppSCD" ofType:@"json"];
    NSString *fileText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    if (!fileText || fileText.length == 0) {
        NSString *message = [NSString stringWithFormat:@"Could not find JSON document AppSCD.json in the app bundle! PPCloak will not monitor this app."];
        [CommonViewUtils showOkAlertWithMessage:message completion:nil];
        return;
    }
    
    NSData *data = [fileText dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    
    if (json) {
        [[OPMonitor sharedInstance] beginMonitoringWithAppDocument:json text:fileText];
    } else {
        NSString *message = [NSString stringWithFormat:@"Could not find json document at path %@ or the text is not a valid JSON object: %@", fileText, path];
        [CommonViewUtils showOkAlertWithMessage:message completion:nil];
    }
    
}

+(instancetype)sharedInstance{
    static OPMonitor *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[OPMonitor alloc] init];
    });
    
    return  shared;
}

+(void)load{
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        checkNoSwizzlingForOPMonitor();
        checkNoSwizzlingForApiHooks();
        checkForOtherFrameworks();
    });
    
    [self initializeMonitoring];
}


+(void)displayFlow{
    [[self sharedInstance] displayFlowIfNecessary];
}

-(void)beginMonitoringWithAppDocument:(NSDictionary *)document text:(NSString*)jsonText {

    [[CommonTypeBuilder sharedInstance] buildSCDDocumentWith:document in: ^void(SCDDocument * _Nullable scdDocument, NSError * _Nullable error) {
        
        if (error || !scdDocument) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *errorMessage = [error description];
                [CommonViewUtils showOkAlertWithMessage:errorMessage completion:nil];
                [CommonViewUtils showOkAlertWithMessage:@"PlusPrivacy will not begin monitoring!" completion:nil];
                [self displayNotificationIfPossible:errorMessage];
            });
            return;
        }
        self.scdSender = [[SCDSender alloc] init];
        [self.scdSender sendSCDParameters:[self buildSCDParametersWithJSON:jsonText] withCompletion:^(NSError * _Nullable errorIfAny) {
            if (errorIfAny) {
                NSString *message = [NSString stringWithFormat:@"Could not synchronize the SCD with the PlusPrivacy server, reason: %@", errorIfAny.localizedDescription];
                [CommonViewUtils showOkAlertWithMessage:message completion:nil];
            }
        }];
        
        self.monitorSettings = [[OPMonitorSettings alloc] initFromDefaults];
        
        self.scdJson = document;
        self.document = scdDocument;
        
        [self installInputSwizzlersWithEventDispatcher:[PPEventDispatcher sharedInstance]];
        [self installSupervisorsWithDocument:scdDocument eventsDispatcher:[PPEventDispatcher sharedInstance]];
    }];
    

}

-(void)installInputSwizzlersWithEventDispatcher:(PPEventDispatcher*)eventsDispatcher {
    
}

-(void)installSupervisorsWithDocument:(SCDDocument*)scd eventsDispatcher:(PPEventDispatcher*)eventsDispatcher {
    self.supervisingModule = [[PPSupervisingModule alloc] init];
    
    WEAKSELF
    PPSupervisingModuleModel *model = [[PPSupervisingModuleModel alloc] initWithSCD:scd eventsDispatcher:eventsDispatcher];
    
    PPSupervisingModuleCallbacks *callbacks = [[PPSupervisingModuleCallbacks alloc] init];
    callbacks.presentNotificationCallback = ^(NSString *notificationMessage) {
        [weakSelf displayNotificationIfPossible:notificationMessage];
    };
    
    [self.supervisingModule beginSupervisingWithModel:model callbacks:callbacks];
}

-(SCDSendParamaters*)buildSCDParametersWithJSON:(NSString*)jsonText {
    return [[SCDSendParamaters alloc] initWithJSON:jsonText
                                     deviceId:UIDevice.currentDevice.identifierForVendor.UUIDString
                                     bundleId:[[NSBundle mainBundle] bundleIdentifier]];
}

-(void)displayFlowIfNecessary {
    
    static BOOL isFlowDisplayed = NO;
    
    if (isFlowDisplayed) {
        return;
    }
    OneDocumentRepository *repo = [[OneDocumentRepository alloc] initWithDocument:self.document];
    
    __weak UIViewController *rootViewController = [[[UIApplication sharedApplication] delegate] window].rootViewController;
    
    __block UIViewController *flowRoot = nil;
    __weak typeof(self) weakSelf = self;
    

    
    PPReportsSourcesBundle *reportSources = [[PPReportsSourcesBundle alloc] init];
    reportSources.accessFrequencyReportsSource = self.plistRepository;
    reportSources.privacyViolationReportsSource = self.plistRepository;
    reportSources.unlistedHostReportsSource = self.plistRepository;
    reportSources.unlistedInputReportsSource = self.plistRepository;
    reportSources.moduleDeniedAccessReportsSource = self.plistRepository;
    
    PPFlowBuilderModel *flowModel = [[PPFlowBuilderModel alloc] init];
    flowModel.monitoringSettings = self.monitorSettings;
    flowModel.reportSources = reportSources;
    flowModel.scdRepository = repo;
    flowModel.scdJSON = self.scdJson;
    
    PPFlowBuilderLocationModel *locationRelated = [[PPFlowBuilderLocationModel alloc] init];
    
    locationRelated.getCurrentActiveLocationIndex = ^NSInteger{
        return weakSelf.locationInputSwizzler.indexOfCurrentSentLocation;
    };
    
    locationRelated.registerChangeCallback = ^(CurrentActiveLocationIndexChangedCallback  _Nullable callback) {
        [weakSelf.locationInputSwizzler registerNewChangeCallback:callback];
    };
    
    locationRelated.removeChangeCallback = ^(CurrentActiveLocationIndexChangedCallback  _Nullable callback) {
        [weakSelf.locationInputSwizzler removeChangeCallback:callback];
    };
    
    locationRelated.getCurrentRandomWalkSettings = ^RandomWalkLocationSettingsModel * _Nonnull{
        RandomWalkLocationSettingsModel *model = [[RandomWalkLocationSettingsModel alloc] init];
        model.currentSettings = weakSelf.locationInputSwizzler.currentSettings;
        model.randomWalkGenerator = [[RandomWalkGenerator alloc] init];
        
        return model;
    };
    
    locationRelated.onSaveCurrentRandomWalkSettings = ^(RandomWalkSwizzlerSettings *settings) {
        [weakSelf.locationInputSwizzler applyNewRandomWalkSettings:settings];
        [settings synchronizeToDefaults:[NSUserDefaults standardUserDefaults]];
        [CommonViewUtils showOkAlertWithMessage:@"Done" completion:nil];
    };
    
    flowModel.eveythingLocationRelated = locationRelated;
    
    flowModel.onExitCallback = ^{
        [rootViewController ppRemoveChildContentController:flowRoot];
        isFlowDisplayed = NO;
    };
    
    PPFlowBuilder *flowBuilder = [[PPFlowBuilder alloc] init];
    flowRoot = [flowBuilder buildFlowWithModel:flowModel];
    
    isFlowDisplayed = YES;
    [rootViewController ppAddChildContentController:flowRoot];
}

#pragma mark - Reports from input supervisors


#pragma mark -

-(void)displayNotificationIfPossible:(NSString*)notification {
    if (!self.monitorSettings.allowNotifications) {
        return;
    }
    
    UIViewController *rootViewController = [[[UIApplication sharedApplication] delegate] window].rootViewController;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UINotificationViewController presentBadNotificationMessage:notification inController:rootViewController atDistanceFromTop:20];
    });
}





@end
