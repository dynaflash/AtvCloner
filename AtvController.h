//
//  AtvController.h
//  AtvCloner
//
//  Created by Joseph Crain on 5/12/09.
//  Copyright 2009 DynaFlash Technologies. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AtvController : NSWindowController {

IBOutlet NSWindow             * fWindow;

IBOutlet NSButton             * fScanDisksButton;
IBOutlet NSButton             * fShowDiskPartitionsButton;

/* Source Disk Copy Tab */
IBOutlet NSButton             * fSourceDiskBrowseButton;
IBOutlet NSTextField          * fSourceDiskField;
IBOutlet NSTextField          * fSourceDiskDeviceField; // Holds the actual /dev/disk1 field used
IBOutlet NSTextField          * fSourceDiskVolumeField;

IBOutlet NSButton             * fSourceImagesDirectoryBrowseButton;
IBOutlet NSTextField          * fSourceImagesDirectoryField;

IBOutlet NSButton             * fSourceImagesCopyButton;

/* Destination Disk Clone Tab */
IBOutlet NSButton             * fDestDiskBrowseButton;
IBOutlet NSTextField          * fDestDiskField;
IBOutlet NSTextField          * fDestDiskDeviceField;// Holds the actual /dev/disk1 field used
IBOutlet NSTextField          * fDestDiskVolumeField;


IBOutlet NSButton             * fBrowseOsBootImgButton;
IBOutlet NSTextField          * fOsBootPathField;
IBOutlet NSButton             * fBrowseEfiImgButton;
IBOutlet NSTextField          * fEfiPathField;
IBOutlet NSButton             * fBrowseRecoveryImgButton;
IBOutlet NSTextField          * fRecoveryPathField;
// linux atv only outlets ...
IBOutlet NSButton             * fBrowseatvLinuxImgButton;
IBOutlet NSTextField          * fatvLinuxPathField;


IBOutlet NSButton             * fStartFullCloneButton;
IBOutlet NSButton             * fXmbcLinuxCloneFormatCheck;
IBOutlet NSButton             * fLargeCloneFormatCheck;

IBOutlet NSProgressIndicator  * fTaskProgressIndicator;
IBOutlet NSTextField          * fTaskProgressField;

IBOutlet NSTextView           *fOutputTextView;

NSTask *task;
NSString *versionName;
NSString *operationName; // used to identify the name of the current operation (series of tasks)
BOOL taskIsRunning;
BOOL canUseOperationCompleteAlert;

NSMutableArray *taskSpoolArray;
NSMutableArray *taskSpoolItemDict;

NSString *diskutilPath;
NSString *gptPath;
NSString *ddPath;
NSString *newfs_hfsPath;

NSString *mkdirPath;
NSString *chmodPath;

NSString *bsdName;
NSString *path;

NSString *deviceDrivePath;


NSString *pathOSBootImg;
NSString *pathEfiImg;
NSString *pathRecoveryImg;
NSString *pathLinuxXbmcImg;
/*Preferences */
IBOutlet NSWindow             * fPreferencesWindow;
IBOutlet NSButton             * fPrefScanAtLaunchCheck;
IBOutlet NSButton             * fPrefAlertWhenDoneCheck;

}
- (IBAction) showPreferences: (id) sender;
- (IBAction) setPreferences: (id) sender;
- (void) setPreferenceWidgets;

- (void)registerUserDefaults;

- (IBAction) openMainWindow: (id) sender;

- (void) startTaskSpool;
- (void) updateUI: (NSTimer *) timer;

/* Copy Images From Source Disk */
- (IBAction) chooseSourceDisk: (id) sender;


- (void) chooseSourceDiskDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;
                        
- (IBAction) chooseSourceImageOutputDirectory: (id) sender;
                        
- (void) chooseSourceImageOutputDirectoryDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;


- (IBAction) showSourceImageCopyingWarning: (id) sender;

- (void) showSourceImageCopyingWarningDone: (NSWindow *) sheet
    returnCode: (int) returnCode contextInfo: (void *) contextInfo;

- (void) unmountSourceDrive;
- (void) startFullSourceImageCopying;
- (void) ddCopySourceEfiImage;
- (void) ddCopySourceRecoveryImage;
- (void) ddCopySourceBootImage;

/* Clone Destination Disk */
- (IBAction) showFullCloningWarning: (id) sender;

- (void) showFullCloningWarningDone: (NSWindow *) sheet
    returnCode: (int) returnCode contextInfo: (void *) contextInfo;
    
- (void) startFullCloning;

- (IBAction) scanAllDisks: (id) sender;

- (IBAction) chooseDestinationDisk: (id) sender;
- (void) chooseDestinationDiskDone: (NSOpenPanel *) sheet
                returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (NSString *)devicePath;
- (NSString *)bsdNameForPath;

- (IBAction) newhsfFormatMediaPartition: (id) sender;
- (IBAction) unmountDestinationDrive: (id) sender;
- (IBAction) gptShowDestinationDrivePartitions: (id) sender;

- (IBAction) gptDestroyDestinationDrivePartitions: (id) sender;
- (IBAction) gptCreateDestinationDrivePartitions: (id) sender;

- (IBAction) gptAddOsBootDrivePartition: (id) sender;

- (IBAction) gptLinuxXbmcDrivePartition: (id) sender;

- (IBAction) gptAddMediaDrivePartition: (id) sender;

- (IBAction) gptAddEfiDrivePartition: (id) sender;

- (IBAction) gptAddRecoveryDrivePartition: (id) sender;

- (IBAction) chooseOSBootImage: (id) sender;
- (void) chooseOSBootImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;

- (IBAction) ddCopyOsBootDriveImage: (id) sender;

- (IBAction) chooseEfiImage: (id) sender;
- (void) chooseEfiImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (IBAction) ddCopyEfiDriveImage: (id) sender;


- (IBAction) chooseRecoveryImage: (id) sender;

- (void) chooseRecoveryImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;
                        
- (IBAction) ddCopyRecoveryDriveImage: (id) sender;
                        
- (IBAction) chooseLinuxXbmcImage: (id) sender;

- (void) chooseLinuxXbmcImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo;

- (IBAction) ddCopyLinuxXbmcDriveImage: (id) sender;

- (IBAction) diskutilPartitionDestinationDrive: (id) sender;

- (void) addTaskToSpool:(NSString *) launchPath taskArgs: (NSArray *) taskArgs logOutput: (NSString *) logOutput;

- (void) launchTask:(NSString *) launchPath taskArgs: (NSArray *) taskArgs logOutput: (NSString *) logOutput;

- (void)taskFinished:(NSNotification *)aNotification;

- (void)readTaskOutput:(NSNotification *)aNotification;

- (IBAction) showDiskPartitions: (id) sender;

- (IBAction) openHomepage: (id) sender;

- (IBAction) openUserGuide: (id) sender;

- (IBAction) openForums: (id) sender;



- (void) formatUsingNewhfs;
- (void) formatUsingDiskutil;

- (IBAction) diskutilFormatMediaPartition: (id) sender;


- (IBAction) createAndChmodMediaDirectories: (id) sender;

- (IBAction) chmodMediaPartition: (id) sender;


- (IBAction) mkdirMediaPartitionMovieDirectory: (id) sender;
///////

- (IBAction) mkdirMediaPartitionTVShowsDirectory: (id) sender;

- (IBAction) mkdirMediaPartitionMusicDirectory: (id) sender;

- (IBAction) mkdirMediaPartitionPicturesDirectory: (id) sender;


- (IBAction) mkdirMediaPartitionStorageDirectory: (id) sender;




- (IBAction) gptRemoveDrivePartion1: (id) sender;

- (IBAction) gptRemoveDrivePartion2: (id) sender;

- (IBAction) gptRemoveDrivePartion3: (id) sender;

- (IBAction) ddZeroMediaDrivePartition: (id) sender;

- (IBAction) ddZeroLinuxXbmcDrivePartition: (id) sender;

@end
