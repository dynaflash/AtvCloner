//
//  AtvController.m
//  AtvCloner
//
//  Created by Joseph Crain on 5/12/09.
//  Copyright 2009 DynaFlash Technologies. All rights reserved.
//

#include <IOKit/IOKitLib.h>
//#include <IOKit/storage/IOMedia.h>
//#include <IOKit/storage/IODVDMedia.h>

#import "AtvController.h"


@implementation AtvController



- (void)registerUserDefaults
{
    NSString *desktopDirectory =  [@"~/Desktop" stringByExpandingTildeInPath];

    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
        @"YES",             @"CheckForUpdates",
        desktopDirectory,   @"OutputImagesDirectory",
        desktopDirectory,   @"StoredImagesDirectory",
        @"YES",             @"AlertWhenDone",
        @"YES",             @"ScanAtLaunch",
        nil]];
}

- (id)init
{
    self = [super init];
    if( !self )
    {
        return nil;
    }

  
  diskutilPath = @"/usr/sbin/diskutil";
  //diskutilPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"diskutil"];	
	
  gptPath = @"/usr/sbin/gpt";
  ddPath = @"/bin/dd";
  newfs_hfsPath = @"/sbin/newfs_hfs";
  mkdirPath = @"/bin/mkdir";
  chmodPath = @"/bin/chmod";
  
  taskSpoolArray = [[NSMutableArray alloc] init];
  taskIsRunning = NO;
  versionName = @"AtvCloner 0.2.1";
  
  
  return self;      
}

- (void) awakeFromNib
{
    [self registerUserDefaults];
    [fWindow makeKeyAndOrderFront:nil];
    [fWindow setExcludedFromWindowsMenu:YES];
    
    [self setPreferenceWidgets];
    
    [fTaskProgressIndicator setHidden: YES];
    [fTaskProgressIndicator setIndeterminate: YES];
    [fTaskProgressIndicator startAnimation: nil];
    /* Call UpdateUI every 1/2 sec */
    [[NSRunLoop currentRunLoop] addTimer:[NSTimer
                                          scheduledTimerWithTimeInterval:0.5 target:self
                                          selector:@selector(updateUI:) userInfo:nil repeats:YES]
                                 forMode:NSDefaultRunLoopMode];
                                 
   
    /* Check to see if the image output directory has been set,use if so, if not, use Desktop */
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"OutputImagesDirectory"])
    {
        [fSourceImagesDirectoryField setStringValue: [NSString stringWithFormat:
                                                      @"%@/", [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputImagesDirectory"]]];
    }
    else
    {
        [fSourceImagesDirectoryField setStringValue: [NSString stringWithFormat:
                                                      @"%@/Desktop/", NSHomeDirectory()]];
    }
   
	// Print Version info to the activity window
    [fOutputTextView insertText:[NSString stringWithFormat:@"%@\n\n",versionName]];
	
	// Print system lib paths to the activity window ...
	[fOutputTextView insertText:[NSString stringWithFormat:@"System Libs Used:\n"]];
	[fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",diskutilPath]];
    [fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",gptPath]];
	[fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",ddPath]];
	[fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",newfs_hfsPath]];
	[fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",mkdirPath]];
	[fOutputTextView insertText:[NSString stringWithFormat:@"%@\n",chmodPath]];
	
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ScanAtLaunch"])
    {
        /* List disks with Diskutil */
        operationName = @"Disk Scan";
        canUseOperationCompleteAlert = NO;
        [self scanAllDisks:nil];
    }
   
}


- (void) applicationDidFinishLaunching: (NSNotification *) notification
{

}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) app
{
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    if (task !=  nil)
    {
        [task release];
    }
    [taskSpoolArray release];
}


- (IBAction) openMainWindow: (id) sender
{
    [fWindow  makeKeyAndOrderFront:nil];
}

#pragma mark -
#pragma mark Timer
/* This timer fires every 1/2 second and checks on the status of the taskSpool
 */
- (void) updateUI: (NSTimer *) timer
{
    
    
    /* Update our progress info field */
    if (taskIsRunning == NO)
    {
        [fScanDisksButton setEnabled:YES];
        
        /* Destination Tab widgets */
        [fDestDiskBrowseButton setEnabled:YES];
        [fDestDiskDeviceField setEnabled:YES];
        
        /* Though we need these initially set them to disabled, will get enabled below */
        [fBrowseEfiImgButton setEnabled:NO];
        [fEfiPathField setEnabled:NO];
        [fBrowseRecoveryImgButton setEnabled:NO];
        [fRecoveryPathField setEnabled:NO];
        
        [fStartFullCloneButton setEnabled:NO];
        
        /* If we have a destination disk ... */
        if ([[fDestDiskDeviceField stringValue] length] > 1)
            
        {
            
            /* No matter what formatting option is chosen, we need to be
             * Able to set both efi and recovery ... */
            [fBrowseEfiImgButton setEnabled:YES];
            [fEfiPathField setEnabled:YES];
            [fBrowseRecoveryImgButton setEnabled:YES];
            [fRecoveryPathField setEnabled:YES];
            
            /* Do a quick check for large disk formatting, if its checked turn off linux
             * since it doesn't work and disable it. If its not, make sure we reenable linux. */
            if ([fLargeCloneFormatCheck state] == NSOnState)
            {
                [fXmbcLinuxCloneFormatCheck setEnabled:NO];
                [fXmbcLinuxCloneFormatCheck setState:NSOffState];
            }
            else
            {
                [fXmbcLinuxCloneFormatCheck setEnabled:YES];
            }
            
            /* Do a quick check for Linux, if its checked turn off large disk
             * since it doesn't work and disable it. If its not, make sure we reenable large disk. */
            if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
            {
                [fLargeCloneFormatCheck setEnabled:NO];
                [fLargeCloneFormatCheck setState:NSOffState];
            }
            else
            {
                [fLargeCloneFormatCheck setEnabled:YES];
            }
            
            
            
            
            /* We are not xbmc linux ... */
            if ([fXmbcLinuxCloneFormatCheck state] == NSOffState)
            {
                /* Enable Boot path widgets ... */
                [fBrowseOsBootImgButton setEnabled:YES];
                [fOsBootPathField setEnabled:YES];
                
                /* Disable the Linux path widgets ... */
                [fBrowseatvLinuxImgButton setEnabled:NO];
                [fatvLinuxPathField setEnabled:NO];
                
                /* If boot, efi and recovery are filled in, allow cloning ... */
                if ([[fOsBootPathField stringValue] length] > 1 && 
                    [[fEfiPathField stringValue] length] > 1 && 
                    [[fRecoveryPathField stringValue] length] > 1)
                {
                    [fStartFullCloneButton setEnabled:YES];
                }
                else
                {
                    [fStartFullCloneButton setEnabled:NO];
                }
            }
            /* We are Linux formatting ... */
            if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
            {
                /* Disable Boot path widgets ... */
                [fBrowseOsBootImgButton setEnabled:NO];
                [fOsBootPathField setEnabled:NO];
                
                /* Enable the Linux path widgets ... */
                [fBrowseatvLinuxImgButton setEnabled:YES];
                [fatvLinuxPathField setEnabled:YES];
                
                /* If efi and recovery and linux are filled in, allow cloning ... */
                if ([[fEfiPathField stringValue] length] > 1 && 
                    [[fRecoveryPathField stringValue] length] > 1 && 
                    [[fatvLinuxPathField stringValue] length] > 1)
                {
                    [fStartFullCloneButton setEnabled:YES];
                }
                else
                {
                    [fStartFullCloneButton setEnabled:NO];
                }
            }
            
        }
        else
        {
            /* If we do not have a destination disk make sure these are disabled ... */
            [fBrowseOsBootImgButton setEnabled:NO];
            [fOsBootPathField setEnabled:NO];
            [fBrowseEfiImgButton setEnabled:NO];
            [fEfiPathField setEnabled:NO];
            [fBrowseRecoveryImgButton setEnabled:NO];
            [fRecoveryPathField setEnabled:NO];
            
            [fBrowseatvLinuxImgButton setEnabled:NO];
            [fatvLinuxPathField setEnabled:NO];
            
            [fXmbcLinuxCloneFormatCheck setEnabled:NO];
            [fLargeCloneFormatCheck setEnabled:NO];
            
            [fStartFullCloneButton setEnabled:NO];
            
        }
        
        /* Source Tab widgets */
        [fSourceDiskBrowseButton setEnabled:YES];
        [fSourceDiskDeviceField setEnabled:YES];
        [fSourceImagesDirectoryBrowseButton setEnabled:YES];
        [fSourceImagesDirectoryField setEnabled:YES];
        
        if ([[fSourceDiskDeviceField stringValue] length] > 1 &&
            [[fSourceImagesDirectoryField stringValue] length] > 1)
        {
            [fSourceImagesCopyButton setEnabled:YES];
        }
        else
        {
            [fSourceImagesCopyButton setEnabled:NO];
        }
        
        if ([taskSpoolArray count] > 0)
        {
            taskIsRunning = YES;
            [fTaskProgressField setStringValue:@"starting task spool ..."];
            
            [self startTaskSpool];
        }
    }
    else if (taskIsRunning == YES)
    {
        [fScanDisksButton setEnabled:NO];
        [fShowDiskPartitionsButton setEnabled:NO];
        
        [fDestDiskBrowseButton setEnabled:NO];
        [fDestDiskDeviceField setEnabled:NO];
        [fBrowseOsBootImgButton setEnabled:NO];
        [fOsBootPathField setEnabled:NO];
        [fBrowseEfiImgButton setEnabled:NO];
        [fEfiPathField setEnabled:NO];
        [fBrowseRecoveryImgButton setEnabled:NO];
        [fRecoveryPathField setEnabled:NO];
        [fStartFullCloneButton setEnabled:NO];
        
        [fLargeCloneFormatCheck setEnabled:NO];
        
        [fXmbcLinuxCloneFormatCheck setEnabled:NO];
        [fatvLinuxPathField setEnabled:NO];
        [fBrowseatvLinuxImgButton setEnabled:NO];
        
        [fSourceDiskBrowseButton setEnabled:NO];
        [fSourceDiskDeviceField setEnabled:NO];
        [fSourceImagesDirectoryBrowseButton setEnabled:NO];
        [fSourceImagesDirectoryField setEnabled:NO];
        [fSourceImagesCopyButton setEnabled:NO];
    }
}


#pragma mark -
#pragma mark Get Source Disk

/*Opens the source browse window, called from Open Source widgets */
- (IBAction) chooseSourceDisk: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    NSString * sourceDirectory;
	sourceDirectory = @"~/Desktop";
    sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    
    /* we open up the browse sources sheet here and call for browseSourcesDone after the sheet is closed
     * to evaluate whether we want to specify a title, we pass the sender in the contextInfo variable
     */
    [panel beginSheetForDirectory: sourceDirectory file: nil types: nil
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseSourceDiskDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseSourceDiskDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        NSString *sourcepath = [[sheet filenames] objectAtIndex: 0];
        /* we order out sheet, which is the browse window as we need to open
         * the title selection sheet right away
         */
        [sheet orderOut: self];
        /* Full Path */
        [fSourceDiskField setStringValue:sourcepath];
        
        // Volume Path
        path = sourcepath;
        [fSourceDiskVolumeField setStringValue:[self devicePath]];
        //Device Path
        /* for now use cocoa's NSRange to shave off the volume parameter */
        NSString *volumePathToDevice = [fSourceDiskVolumeField stringValue];
        NSRange splitDeviceRange = [volumePathToDevice rangeOfString:@"disk"];
        // strips the path
        volumePathToDevice = [volumePathToDevice substringFromIndex:splitDeviceRange.location];
        // removes the volume id so disk1s2 becomes disk1 */
        volumePathToDevice = [volumePathToDevice substringToIndex:splitDeviceRange.location];
        // Total Hack: add the path back in to get /dev/disk1 with stringWithAppendingString
        [fSourceDiskDeviceField setStringValue:[@"/dev/" stringByAppendingString:volumePathToDevice]];
        [fSourceDiskVolumeField setStringValue:[self devicePath]];
        //deviceDrivePath = [[fDestDiskDeviceField stringValue] UTF8String];
        //bsdName = nil;
    }
}

#pragma mark -
#pragma mark Get Source Images Output Path

- (IBAction) chooseSourceImageOutputDirectory: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
    
    NSString * sourceDirectory;
    if ([fSourceImagesDirectoryField stringValue])
    {
	sourceDirectory = [fSourceImagesDirectoryField stringValue];
    }
    else
    {
    sourceDirectory = @"~/Desktop";
    sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    }
    
    //NSArray *fileTypes = [NSArray arrayWithObjects:@"img", @"dmg", nil];
    [panel beginSheetForDirectory: sourceDirectory file: nil types: nil
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseSourceImageOutputDirectoryDone:returnCode:contextInfo: )
                      contextInfo: sender];
}

- (void) chooseSourceImageOutputDirectoryDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        /* Full Path */
        [fSourceImagesDirectoryField setStringValue:[[sheet filenames] objectAtIndex: 0]];
        
/* Save this path to the prefs so that on next browse destination window it opens there */
        NSString *destinationDirectory = [fSourceImagesDirectoryField stringValue];
        [[NSUserDefaults standardUserDefaults] setObject:destinationDirectory forKey:@"OutputImagesDirectory"];


        [sheet orderOut: self];


    }
}


/* First post a warning that this could start the computer on fire ... */
- (IBAction) showSourceImageCopyingWarning: (id) sender
{
NSBeginCriticalAlertSheet( NSLocalizedString( @"This operation will copy the three atv drive partitions to dmg files! This operation may take a while.", @"" ),
                                  NSLocalizedString( @"Cancel", @"" ), NSLocalizedString( @"Continue", @"" ), nil, fWindow, self,
                                  @selector( showSourceImageCopyingWarningDone:returnCode:contextInfo: ),
                                  NULL, NULL, [NSString stringWithFormat:
                                               NSLocalizedString( @"Do you wish to continue ?", @"" )] );
}

- (void) showSourceImageCopyingWarningDone: (NSWindow *) sheet
    returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if( returnCode == NSAlertAlternateReturn )
    {
        [self startFullSourceImageCopying];
    }
}


#pragma mark -
#pragma mark Source Image Methods

/* Method Below fills the task spool and then starts the process timer.
 * Note: order of tasks is crucial for a successful clone.
 */
- (void) startFullSourceImageCopying
{
    operationName = @"Source Partition Imaging";
    canUseOperationCompleteAlert = YES;
    
    /* make sure the destination drive is unmounted */
    [self unmountSourceDrive];
    /* Destroy and create a new gpt partition table on disk */
    [self ddCopySourceEfiImage];
    [self ddCopySourceRecoveryImage];
    [self ddCopySourceBootImage];
    /* List disks with Diskutil */
    [self scanAllDisks:nil];
}

/* Unmount source drive with diskutil */
- (void) unmountSourceDrive
{
    
    NSArray *arguments = [NSArray arrayWithObjects: @"unmountDisk", [fSourceDiskDeviceField stringValue], nil];
    /* we add the item to the taskSpoolArray */
    NSString *logOutput = @"Unmounting disk with diskutil ...\n";
    [self addTaskToSpool:diskutilPath taskArgs:arguments logOutput:logOutput];    
}

- (void) ddCopySourceEfiImage
{
    [fOutputTextView insertText:@"Copying efi.dmg with dd (approx. 34 mb)...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:[[fSourceDiskDeviceField stringValue]stringByAppendingString:@"s1"]];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fSourceImagesDirectoryField stringValue]stringByAppendingString:@"/efi.dmg"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying efi.dmg with dd (approx. 34 mb)...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}

- (void) ddCopySourceRecoveryImage
{
    [fOutputTextView insertText:@"Copying recovery.img with dd (approx. 400 mb) ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:[[fSourceDiskDeviceField stringValue]stringByAppendingString:@"s2"]];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fSourceImagesDirectoryField stringValue]stringByAppendingString:@"/recovery.dmg"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying recovery.img with dd (approx. 400 mb) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}

- (void) ddCopySourceBootImage
{
    [fOutputTextView insertText:@"Copying boot.img with dd (approx. 900 mb) ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:[[fSourceDiskDeviceField stringValue]stringByAppendingString:@"s3"]];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fSourceImagesDirectoryField stringValue]stringByAppendingString:@"/boot.dmg"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying boot.img with dd (approx. 900 mb) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}


#pragma mark -
#pragma mark Get Destination Disk

/*Opens the source browse window, called from Open Source widgets */
- (IBAction) chooseDestinationDisk: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    NSString * sourceDirectory;
	sourceDirectory = @"~/Desktop";
    sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    
    /* we open up the browse sources sheet here and call for browseSourcesDone after the sheet is closed
     * to evaluate whether we want to specify a title, we pass the sender in the contextInfo variable
     */
    [panel beginSheetForDirectory: sourceDirectory file: nil types: nil
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseDestinationDiskDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseDestinationDiskDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        NSString *destpath = [[sheet filenames] objectAtIndex: 0];
        /* we order out sheet, which is the browse window as we need to open
         * the title selection sheet right away
         */
        [sheet orderOut: self];
        /* Full Path */
        [fDestDiskField setStringValue:destpath];
        
        // Volume Path
        path = destpath;
        [fDestDiskVolumeField setStringValue:[self devicePath]];
        //Device Path
        /* for now use cocoa's NSRange to shave off the volume parameter */
        NSString *volumePathToDevice = [fDestDiskVolumeField stringValue];
        NSRange splitDeviceRange = [volumePathToDevice rangeOfString:@"disk"];
        // strips the path
        volumePathToDevice = [volumePathToDevice substringFromIndex:splitDeviceRange.location];
        // removes the volume id so disk1s2 becomes disk1 */
        volumePathToDevice = [volumePathToDevice substringToIndex:splitDeviceRange.location];
        // Total Hack: add the path back in to get /dev/disk1 with stringWithAppendingString
        [fDestDiskDeviceField setStringValue:[@"/dev/" stringByAppendingString:volumePathToDevice]];
        [fDestDiskVolumeField setStringValue:[self devicePath]];
        //deviceDrivePath = [[fDestDiskDeviceField stringValue] UTF8String];
        //bsdName = nil;
        
        /* we should try to get the disk size in both bytes and sectors here */
        
    }
}




#pragma mark -
#pragma mark Show Drive Information

/* Scan all connected drives with diskutil */
- (IBAction) scanAllDisks: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"list", nil];
    /* we add the item to the taskSpoolArray */
    NSString *logOutput = @"Listing available disks with diskutil ... \n";
    [self addTaskToSpool:diskutilPath taskArgs:arguments logOutput:logOutput];
    
}

- (IBAction) showDiskPartitions: (id) sender
{
[self unmountDestinationDrive:nil];
[self gptShowDestinationDrivePartitions:nil];
}

#pragma mark -
#pragma mark  Start Full Cloning

/* First post a warning that this could start the computer on fire ... */
- (IBAction) showFullCloningWarning: (id) sender
{
NSBeginCriticalAlertSheet( NSLocalizedString( @"This operation will format the selected drive for use with the ATV. All existing information will be destroyed!", @"" ),
                                  NSLocalizedString( @"Cancel", @"" ), NSLocalizedString( @"Continue", @"" ), nil, fWindow, self,
                                  @selector( showFullCloningWarningDone:returnCode:contextInfo: ),
                                  NULL, NULL, [NSString stringWithFormat:
                                               NSLocalizedString( @"Do you wish to continue ?", @"" )] );
}

- (void) showFullCloningWarningDone: (NSWindow *) sheet
                         returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if( returnCode == NSAlertAlternateReturn )
    {
        [self startFullCloning];
    }
}

/* Method Below fills the task spool and then starts the process timer.
 * Note: order of tasks is crucial for a successful clone.
 */
- (void) startFullCloning
{
    if ([fLargeCloneFormatCheck state] == NSOnState)
    {
        operationName = @"New ATV Disk (Diskutil) Setup";
    }
    else
    {
        operationName = @"New ATV Disk (NewHfs) Setup";
    }
    
    canUseOperationCompleteAlert = YES;
    [fOutputTextView insertText:[NSString stringWithFormat:@"%@\n\n",operationName]];
    /* Initially partiton the target disk in hfs+ */
    [self diskutilPartitionDestinationDrive:nil];
    /* make sure the destination drive is unmounted */
    [self unmountDestinationDrive:nil];
    /* Destroy and create a new gpt partition table on disk */
    [self gptDestroyDestinationDrivePartitions:nil];
    [self gptCreateDestinationDrivePartitions:nil];
    
    /* Create EFI Partition */
    [self unmountDestinationDrive:nil];
    [self gptAddEfiDrivePartition:nil];
    
    /* Create Recovery Partition */
    [self unmountDestinationDrive:nil];
    [self gptAddRecoveryDrivePartition:nil];
    
    /* Create BOOT Partition only if we are NOT doing linux.
     * If we are doing Linux we do not image the boot partition
     * as we are doing single boot */
    if ([fXmbcLinuxCloneFormatCheck state] == NSOffState)
    {
        [self unmountDestinationDrive:nil];
        [self gptAddOsBootDrivePartition:nil];
    }
 // Here we diverge for regular vs. large file.
 // regular uses new hfs
 // large uses diskutil

    if ([fLargeCloneFormatCheck state] == NSOnState)
    {
        [self formatUsingDiskutil];

    }
    else
    {
        [self formatUsingNewhfs];
    }  
    
    /// Now that we are done formatting, show the target disk results.
    /* Show disk with gpt */
    [self unmountDestinationDrive:nil];
    [self gptShowDestinationDrivePartitions:nil];
    
    /* List disks with Diskutil */
    [self scanAllDisks:nil];
    

    
}

- (void) formatUsingNewhfs
{
    if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
    {
    /* Create the XBMC/Linux Partition with gpt */
        [self unmountDestinationDrive:nil];
        [self gptLinuxXbmcDrivePartition:nil];

    }
       
    /* Copy the boot image to the boot partition only if
     * we are NOT doing Linux */
    if ([fXmbcLinuxCloneFormatCheck state] == NSOffState)
    {
        [self unmountDestinationDrive:nil];
        [self ddCopyOsBootDriveImage:nil];
    }
    
    /* Copy the efi image to the efi partition */
    [self unmountDestinationDrive:nil];
    [self ddCopyEfiDriveImage:nil];
    
    /* Copy the recovery image to the recovery partition */
    [self unmountDestinationDrive:nil];
    [self ddCopyRecoveryDriveImage:nil];
    
    if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
    { 
        /* zero out the first 200 mb of the new partition to prevent ghosting */
        //[self ddZeroLinuxXbmcDrivePartition:nil];
        
        
        /* Copy the XBMC/Linux image to the Linux partition */
       [self unmountDestinationDrive:nil];
       [self ddCopyLinuxXbmcDriveImage:nil];
    }
   
    /* Create the Media Partition with gpt */
    [self unmountDestinationDrive:nil];
    [self gptAddMediaDrivePartition:nil];
    /* zero out the first 200 mb of the new partition to prevent ghosting */
    //[self ddZeroMediaDrivePartition:nil];
    
    /* Format the media Partition */
    [self unmountDestinationDrive:nil];
    [self newhsfFormatMediaPartition:nil];
}

- (void) formatUsingDiskutil
{
    
    canUseOperationCompleteAlert = YES;
    [fOutputTextView insertText:[NSString stringWithFormat:@"%@\n\n",operationName]];
    
    /* Copy the boot image to the boot partition */
    //[self unmountDestinationDrive:nil];
    //[self ddCopyOsBootDriveImage:nil];
    
    /* Copy the efi image to the efi partition */
    //[self unmountDestinationDrive:nil];
    //[self ddCopyEfiDriveImage:nil];
    
    /* Copy the recovery image to the recovery partition */
    //[self unmountDestinationDrive:nil];
    //[self ddCopyRecoveryDriveImage:nil];
    
    /* Create the Media Partition with gpt */
    [self unmountDestinationDrive:nil];
    [self gptAddMediaDrivePartition:nil];
    
    /* Format the media Partition */
    /* Note: for some reason formatting the media partition
     * causes the final partition indexes to get screwed up.
     * On test WD drives it still ends up getting called "Media".
     * On a test atv drive the partition has no name. I have
     * no clue why.*/
     [self unmountDestinationDrive:nil];
     //[self newhsfFormatMediaPartition:nil];
     [self diskutilFormatMediaPartition:nil];
     
     /* Now formatting the media partition with diskutil *will* screw up the partition order.
      * testing shows we might be able to fix it by removing the partitions indexes 1 - 3
      * and recreate them. Its a fucking kludge, but might work, seems to in testing
      */
      
     /* Remove partitions 1 - 3 */
    [self unmountDestinationDrive:nil];
    [self gptRemoveDrivePartion1:nil];
    [self unmountDestinationDrive:nil];
    [self gptRemoveDrivePartion2:nil];
    [self unmountDestinationDrive:nil];
    [self gptRemoveDrivePartion3:nil];
    
     /* Now recreate them since 4 is already exisiting */
    /* Create EFI Partition */
    [self unmountDestinationDrive:nil];
    [self gptAddEfiDrivePartition:nil];
    
    /* Create Recovery Partition */
    [self unmountDestinationDrive:nil];
    [self gptAddRecoveryDrivePartition:nil];
    
    /* Create BOOT Partition */
    [self unmountDestinationDrive:nil];
    [self gptAddOsBootDrivePartition:nil];
    
    /* if this bullshit works then we would image the empty partitions */
    /* Copy the boot image to the boot partition */
    [self unmountDestinationDrive:nil];
    [self ddCopyOsBootDriveImage:nil];
    
    /* Copy the efi image to the efi partition */
    [self unmountDestinationDrive:nil];
    [self ddCopyEfiDriveImage:nil];
    
    /* Copy the recovery image to the recovery partition */
    [self unmountDestinationDrive:nil];
    [self ddCopyRecoveryDriveImage:nil];
    
    /* lets try formatting the media partition here */
    [self unmountDestinationDrive:nil];
    [self newhsfFormatMediaPartition:nil];
    
    
}

#pragma mark -
#pragma mark  Individual Task Spool Methods

/* Unmount destination drive with diskutil */
- (void) unmountDestinationDrive: (id) sender
{
    
    NSArray *arguments = [NSArray arrayWithObjects: @"unmountDisk", [fDestDiskDeviceField stringValue], nil];
    /* we add the item to the taskSpoolArray */
    NSString *logOutput = @"Unmounting disk with diskutil ...\n";
    [self addTaskToSpool:diskutilPath taskArgs:arguments logOutput:logOutput];    
}


/* show the destination drive with gpt */
- (IBAction) gptShowDestinationDrivePartitions: (id) sender
{

    /* make sure the destination drive is unmounted */
    [self unmountDestinationDrive:nil];
    
    NSArray *arguments = [NSArray arrayWithObjects: @"show", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Getting partitions with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];
}



/* show the destination drive with gpt */
- (IBAction) diskutilPartitionDestinationDrive: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"partitionDisk", 
                         [fDestDiskDeviceField stringValue],@"1", @"GPTFormat", @"HFS+",@"AtvTargetDrive",@"100.0%", nil];
    NSString *logOutput = @"Performing initial partition with diskutil ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:diskutilPath taskArgs:arguments logOutput:logOutput];
}

/* destroy partition tables with gpt */
- (IBAction) gptDestroyDestinationDrivePartitions: (id) sender
{
    
    NSArray *arguments = [NSArray arrayWithObjects: @"destroy", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Destroying partition table with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

/* create partition tables with gpt */
- (IBAction) gptCreateDestinationDrivePartitions: (id) sender
{

    
    NSArray *arguments = [NSArray arrayWithObjects: @"create", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Creating partition table with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];
}


#pragma mark -
#pragma mark  Create Partitions

/* properly formatting an atv drive requires that partitons are created in an exact order
 * 1. EFI
 * 2. Recovery
 * 3. Boot

 */

/* add Efi partition with gpt */
- (IBAction) gptAddEfiDrivePartition: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"add",@"-b", @"40",@"-i",@"1",@"-s",@"69632",@"-t",@"efi", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Adding Efi partition with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

/* add Recovery partition with gpt */
- (IBAction) gptAddRecoveryDrivePartition: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"add",@"-b", @"69672",@"-i",@"2",@"-s",@"819200",@"-t",@"5265636F-7665-11AA-AA11-00306543ECAC", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Adding Recovery partition with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}


/* add OSBoot partition with gpt */
- (IBAction) gptAddOsBootDrivePartition: (id) sender
{

    
    [fOutputTextView insertText:@"Adding OSBoot partition with gpt ...\n"];
    
    NSArray *arguments = [NSArray arrayWithObjects: @"add",@"-b", @"888872",@"-i",@"3",@"-s",@"1843200",@"-t",@"hfs", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Adding OSBoot partition with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

#pragma mark  Create xbmc partition ...

- (IBAction) gptLinuxXbmcDrivePartition: (id) sender
{

    /* When adding the linuxxbmc partition it goes into slot 4 with the same block start as the Media partiton would get in a
     * stock atv install. ending block need to be calculated as per the source linux xbmc expaned image size.*/
    [fOutputTextView insertText:@"Adding LinuxXbmcDrive partition with gpt ...\n"];
    
    /* Putting Linux at the number 4 position  (dual boot capable as we are keeping the OSBoot partition */
    //NSArray *arguments = [NSArray arrayWithObjects: @"add",@"-b", @"2732072",@"-i",@"4",@"-s",@"41008050",@"-t",@"EBD0A0A2-B9E5-4433-87C0-68B6B72699C7", [fDestDiskDeviceField stringValue], nil];
    
    /* Putting Linux at the number 3 position  (Single boot as we DON't use the OSBoot partition */
    NSArray *arguments = [NSArray arrayWithObjects: @"add",@"-b", @"888872",@"-i",@"3",@"-s",@"41008050",@"-t",@"EBD0A0A2-B9E5-4433-87C0-68B6B72699C7", [fDestDiskDeviceField stringValue], nil];
    
    
    NSString *logOutput = @"Adding LinuxXbmc partition with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

- (IBAction) ddZeroLinuxXbmcDrivePartition: (id) sender
{


    [fOutputTextView insertText:@"Zeroing out the linux partition with dd ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = @"if=/dev/zero";
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m",@"count=200", nil];
    NSString *logOutput = @"Zeroing out 200 mb of the linux partition with dd ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}


#pragma mark  Create Media partition ...
- (IBAction) gptAddMediaDrivePartition: (id) sender
{
     
     // Okay for here we need to be able to use a given start size, and get gpt to make it go to the end of the disk
    // Since we currently have no way of grokking that, lets try not specifying Size and just use a given start
    // which appears to be the same regardless of disk size ... I think -b 2732072
    NSArray *arguments;
    if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
    {
        // For XBMC Linux we need to change the start size as well as the index 43740122 and 5 ... start size for media is based on the size of the linux partition.
        /* dual boot (puts Media at 5 since linux is 4 and we are keeping the OSboot image at 3 for potential dual boot */
        //arguments = [NSArray arrayWithObjects: @"add",@"-b", @"43740122",@"-i",@"5",@"-t",@"hfs", [fDestDiskDeviceField stringValue], nil];
        
        /* Single boot (puts Media at 4 since linux is 3 and we are not using the OSBoot Image */
        /* Note: start point may need 1 added to it. 41896922 is linux start + linux size*/
        arguments = [NSArray arrayWithObjects: @"add",@"-b", @"41896922",@"-i",@"4",@"-t",@"hfs", [fDestDiskDeviceField stringValue], nil];
    }
    else
    {
        // Stock ATV Install:
        arguments = [NSArray arrayWithObjects: @"add",@"-b", @"2732072",@"-i",@"4",@"-t",@"hfs", [fDestDiskDeviceField stringValue], nil];
    }

    
    
    NSString *logOutput = @"Adding Media partition table with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];
    
}

- (IBAction) ddZeroMediaDrivePartition: (id) sender
{


    [fOutputTextView insertText:@"Zeroing out the Media partition with dd ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = @"if=/dev/zero";
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m",@"count=200", nil];
    NSString *logOutput = @"Zeroing out 200 mb of the media partition with dd ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}

#pragma mark -
#pragma mark  GPT Remove partitions

/* remove partition 1 with gpt */
- (IBAction) gptRemoveDrivePartion1: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"remove",@"-i",@"1", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Removing Partition 1 with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

/* remove partition 2 with gpt */
- (IBAction) gptRemoveDrivePartion2: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"remove",@"-i",@"2", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Removing Partition 2 with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

/* remove partition 3 with gpt */
- (IBAction) gptRemoveDrivePartion3: (id) sender
{
    NSArray *arguments = [NSArray arrayWithObjects: @"remove",@"-i",@"3", [fDestDiskDeviceField stringValue], nil];
    NSString *logOutput = @"Removing Partition 3 with gpt ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];

    
}

#pragma mark -
#pragma mark  Update Partitions with Images

- (IBAction) chooseOSBootImage: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
    NSString * sourceDirectory;
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"])
    {
        sourceDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"];
    }
    else
    {
        sourceDirectory = @"~/Desktop";
        sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    }
    
    NSArray *fileTypes = [NSArray arrayWithObjects:@"img", @"dmg", nil];
    [panel beginSheetForDirectory: sourceDirectory file: nil types: fileTypes
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseOSBootImageDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseOSBootImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        pathOSBootImg = [[sheet filenames] objectAtIndex: 0];
        /* Full Path */
        [fOsBootPathField setStringValue:pathOSBootImg];
        
        /* Save this path to the prefs so that on next browse destination window it opens there */
        NSString *destinationDirectory = [[fOsBootPathField stringValue] stringByDeletingLastPathComponent];
        [[NSUserDefaults standardUserDefaults] setObject:destinationDirectory forKey:@"StoredImagesDirectory"];
         
        [sheet orderOut: self];
         //[self ddCopyOsBootDriveImage:nil];

    }
}

- (IBAction) ddCopyOsBootDriveImage: (id) sender
{
    [fOutputTextView insertText:@"Copying osboot.img with dd ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:pathOSBootImg];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s3"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying boot image with dd (approx. 900 MB) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];
}


- (IBAction) chooseEfiImage: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
    NSString * sourceDirectory;
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"])
    {
        sourceDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"];
    }
    else
    {
        sourceDirectory = @"~/Desktop";
        sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    }
    
    NSArray *fileTypes = [NSArray arrayWithObjects:@"img", @"dmg", nil];
    [panel beginSheetForDirectory: sourceDirectory file: nil types: fileTypes
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseEfiImageDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseEfiImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        pathEfiImg = [[sheet filenames] objectAtIndex: 0];
        
        /* Full Path */
        [fEfiPathField setStringValue:pathEfiImg];
        /* Save this path to the prefs so that on next browse destination window it opens there */
        NSString *destinationDirectory = [[fEfiPathField stringValue] stringByDeletingLastPathComponent];
        [[NSUserDefaults standardUserDefaults] setObject:destinationDirectory forKey:@"StoredImagesDirectory"];
        
        [sheet orderOut: self];

    }
}

- (IBAction) ddCopyEfiDriveImage: (id) sender
{
    /* make sure the destination drive is unmounted */
     NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:pathEfiImg];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s1"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying efi image with dd (approx. 34 MB) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];

}


- (IBAction) chooseRecoveryImage: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
    NSString * sourceDirectory;
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"])
    {
        sourceDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"];
    }
    else
    {
        sourceDirectory = @"~/Desktop";
        sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    }
    
    NSArray *fileTypes = [NSArray arrayWithObjects:@"img", @"dmg", nil];
    [panel beginSheetForDirectory: sourceDirectory file: nil types: fileTypes
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseRecoveryImageDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseRecoveryImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        pathRecoveryImg = [[sheet filenames] objectAtIndex: 0];
        /* Full Path */
        [fRecoveryPathField setStringValue:pathRecoveryImg];
        /* Save this path to the prefs so that on next browse destination window it opens there */
        NSString *destinationDirectory = [[fRecoveryPathField stringValue] stringByDeletingLastPathComponent];
        [[NSUserDefaults standardUserDefaults] setObject:destinationDirectory forKey:@"StoredImagesDirectory"];
        
        [sheet orderOut: self];

    }
}

- (IBAction) ddCopyRecoveryDriveImage: (id) sender
{
    [fOutputTextView insertText:@"Copying recovery.img with dd ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:pathRecoveryImg];
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s2"]];
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying recovery image with dd (approx. 400 MB) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];

}


- (IBAction) chooseLinuxXbmcImage: (id) sender
{
    NSOpenPanel * panel;
	
    panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
    NSString * sourceDirectory;
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"])
    {
        sourceDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"StoredImagesDirectory"];
    }
    else
    {
        sourceDirectory = @"~/Desktop";
        sourceDirectory = [sourceDirectory stringByExpandingTildeInPath];
    }
    
    NSArray *fileTypes = [NSArray arrayWithObjects:@"img", @"dmg", nil];
    [panel beginSheetForDirectory: sourceDirectory file: nil types: fileTypes
                   modalForWindow: fWindow modalDelegate: self
                   didEndSelector: @selector( chooseLinuxXbmcImageDone:returnCode:contextInfo: )
                      contextInfo: sender]; 
}

- (void) chooseLinuxXbmcImageDone: (NSOpenPanel *) sheet
                        returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    /* we convert the sender content of contextInfo back into a variable called sender
     * mostly just for consistency for evaluation later
     */
    //id sender = (id)contextInfo;
    /* User selected a Destination Disk to open */
	if( returnCode == NSOKButton )
    {
        
        
        pathLinuxXbmcImg = [[sheet filenames] objectAtIndex: 0];
        /* Full Path */
        [fatvLinuxPathField setStringValue:pathLinuxXbmcImg];
        /* Save this path to the prefs so that on next browse destination window it opens there */
        NSString *destinationDirectory = [[fatvLinuxPathField stringValue] stringByDeletingLastPathComponent];
        [[NSUserDefaults standardUserDefaults] setObject:destinationDirectory forKey:@"StoredImagesDirectory"];
        
        [sheet orderOut: self];

    }
}
#pragma mark  Update xbmc partition with image ...
- (IBAction) ddCopyLinuxXbmcDriveImage: (id) sender
{
    [fOutputTextView insertText:@"Copying the atv/linux/xbmc.img with dd ...\n"];
    
    NSArray *arguments;
    NSString *inputFileArg = [@"if=" stringByAppendingString:pathLinuxXbmcImg];
    // Dual Boot
    //NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"]];
    // Single Boot
    NSString *outputFileArg = [@"of=" stringByAppendingString:[[fDestDiskDeviceField stringValue]stringByAppendingString:@"s3"]];
    
    arguments = [NSArray arrayWithObjects: inputFileArg,outputFileArg, @"bs=1m", nil];
    NSString *logOutput = @"Copying atv/linux/xbmc image with dd (approx. 20 GB) ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:ddPath taskArgs:arguments logOutput:logOutput];

}


#pragma mark  Format Media partition ...


- (IBAction) newhsfFormatMediaPartition: (id) sender
{
    
    NSArray *arguments;
    if ([fXmbcLinuxCloneFormatCheck state] == NSOnState)
    {
        // For linux install its number 5 for dual boot and 4 for single boot
        //NSString *mediaPartitonToFormat = [[fDestDiskDeviceField stringValue]stringByAppendingString:@"s5"];
        NSString *mediaPartitonToFormat = [[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"];
        // Linux cannot mount a journaled hfs patition so remove the "-J" parameter for a linux setup
        arguments = [NSArray arrayWithObjects:@"-v",@"Media",mediaPartitonToFormat, nil];
    }
    else
    {
        // For stock install media is #4
        NSString *mediaPartitonToFormat = [[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"];
        // Use Journaling for stock atv setup
        arguments = [NSArray arrayWithObjects:@"-J", @"-v",@"Media",mediaPartitonToFormat, nil];
    }
    
    NSString *logOutput = @"Formatting media partition with newfs_hfs ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:newfs_hfsPath taskArgs:arguments logOutput:logOutput];
    
    
}

- (IBAction) diskutilFormatMediaPartition: (id) sender
{
    
    NSArray *arguments;
    NSString *mediaPartitonToFormat = [[fDestDiskDeviceField stringValue]stringByAppendingString:@"s4"];
    arguments = [NSArray arrayWithObjects: @"eraseVolume",@"Journaled HFS+",@"Media",mediaPartitonToFormat, nil];
    NSString *logOutput = @"Formatting media partition with diskutil ...\n";
    /* we add the item to the taskSpoolArray */
    //[self addTaskToSpool:gptPath taskArgs:arguments logOutput:logOutput];
    [self addTaskToSpool:diskutilPath taskArgs:arguments logOutput:logOutput];
}

#pragma      mark -
#pragma mark  Linux add Media Directories and Chmod ...
- (IBAction) createAndChmodMediaDirectories: (id) sender
{
/* Somehow we need to get it to wait until its mounted before trying */
        /* create the Directories on the Media Partition */
        [self mkdirMediaPartitionMovieDirectory:nil];
        [self mkdirMediaPartitionTVShowsDirectory:nil];
        [self mkdirMediaPartitionMusicDirectory:nil];
        [self mkdirMediaPartitionPicturesDirectory:nil];
        [self mkdirMediaPartitionStorageDirectory:nil];
        
        /* Now chmod the Media Partition */
        [self chmodMediaPartition:nil];
}



- (IBAction) mkdirMediaPartitionMovieDirectory: (id) sender
{
    NSArray *arguments;
    NSString *volumeToMake = @"/Volumes/Media/Movies";
    arguments = [NSArray arrayWithObjects: volumeToMake, nil];
    NSString *logOutput = @"Creating Movies on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:mkdirPath taskArgs:arguments logOutput:logOutput];
}

- (IBAction) mkdirMediaPartitionTVShowsDirectory: (id) sender
{
    NSArray *arguments;
    NSString *volumeToMake = @"/Volumes/Media/TVShows";
    arguments = [NSArray arrayWithObjects: volumeToMake, nil];
    NSString *logOutput = @"Creating TVShows on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:mkdirPath taskArgs:arguments logOutput:logOutput];
}

- (IBAction) mkdirMediaPartitionMusicDirectory: (id) sender
{
    NSArray *arguments;
    NSString *volumeToMake = @"/Volumes/Media/Music";
    arguments = [NSArray arrayWithObjects: volumeToMake, nil];
    NSString *logOutput = @"Creating Music on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:mkdirPath taskArgs:arguments logOutput:logOutput];
}

- (IBAction) mkdirMediaPartitionPicturesDirectory: (id) sender
{
    NSArray *arguments;
    NSString *volumeToMake = @"/Volumes/Media/Pictures";
    arguments = [NSArray arrayWithObjects: volumeToMake, nil];
    NSString *logOutput = @"Creating Pictures on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:mkdirPath taskArgs:arguments logOutput:logOutput];
}

- (IBAction) mkdirMediaPartitionStorageDirectory: (id) sender
{
    NSArray *arguments;
    NSString *volumeToMake = @"/Volumes/Media/Storage";
    arguments = [NSArray arrayWithObjects: volumeToMake, nil];
    NSString *logOutput = @"Creating Storage on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:mkdirPath taskArgs:arguments logOutput:logOutput];
}


- (IBAction) chmodMediaPartition: (id) sender
{
    //now chmod the Media Partition recursively
    // Terminal example: sudo chmod -R a+rwx /Volumes/Media

    NSArray *arguments;
    NSString *volumeToChmod = @"/Volumes/Media";
    arguments = [NSArray arrayWithObjects: @"-R",@"a+rwx",volumeToChmod, nil];
    NSString *logOutput = @"Setting Permissions on the Media Partition ...\n";
    /* we add the item to the taskSpoolArray */
    [self addTaskToSpool:chmodPath taskArgs:arguments logOutput:logOutput];
          
          
}



#pragma      mark -
#pragma mark Task Management

- (void) addTaskToSpool:(NSString *) launchPath taskArgs: (NSArray *) taskArgs logOutput: (NSString *) logOutput
{
    
    NSMutableDictionary *taskSpoolItem = [[NSMutableDictionary alloc] init];
    [taskSpoolItem setObject:launchPath forKey:@"taskPath"];
    [taskSpoolItem setObject:[NSMutableArray arrayWithArray: taskArgs] forKey:@"taskArgs"];
    [taskSpoolItem setObject:logOutput forKey:@"taskLogOutput"];
    /* add the new task item to the task spool array */
    [taskSpoolArray addObject: taskSpoolItem];
    [taskSpoolItem release];
    [fTaskProgressField setStringValue:@"added task to spool"];
    
}

- (void) startTaskSpool
{

    if ([taskSpoolArray count] > 0)
    {
        //taskIsRunning = YES;
        /*grab our task out of the taskSpoolArray and send it off to launchTask*/
        //NSMutableDictionary *taskSpoolItem = [[NSMutableDictionary alloc] init];
        //taskSpoolItem = [taskSpoolArray objectAtIndex:0];
        NSMutableDictionary *taskSpoolItem = [taskSpoolArray objectAtIndex:0];
        
        [self launchTask:(NSString *) [taskSpoolItem objectForKey:@"taskPath"] taskArgs:(NSArray *) [taskSpoolItem objectForKey:@"taskArgs"] logOutput:(NSString *) [taskSpoolItem objectForKey:@"taskLogOutput"] ];
        //[taskSpoolItem autorelease];
        /* Now that we've sent the task off to be processed, remove it from the taskSpoolArray */
        [taskSpoolArray removeObjectAtIndex:0];

    }

}

/* Scan all connected drives with diskutil */
- (void) launchTask:(NSString *) launchPath taskArgs: (NSArray *) taskArgs logOutput: (NSString *) logOutput
{
    //taskIsRunning = YES;
    [fTaskProgressIndicator setHidden: NO];
    [fTaskProgressIndicator startAnimation: nil];
    
    
    
    task = [[NSTask alloc] init];
    [task setLaunchPath: launchPath];
    [task setArguments: taskArgs];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task setStandardError: pipe];

    NSFileHandle *file = [pipe fileHandleForReading];
    /* we use this method to try to keep [file readDataToEndOfFile];
     * from blocking the ui until its done
     */
    
    [file readInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(readTaskOutput:) 
                                                     name:NSFileHandleReadCompletionNotification 
                                                   object:nil];
    
    /* actually cross our fingers and hope we got it */
    [task launch];
    /* Update our progress info field */
    [fTaskProgressField setStringValue:logOutput];



    
}


- (void)readTaskOutput:(NSNotification *)aNotification 
{
    NSData *taskData = [[aNotification userInfo]
                objectForKey:@"NSFileHandleNotificationDataItem"];
    

    NSString *outputString = [[NSString alloc] initWithData: taskData encoding: NSUTF8StringEncoding];
    [fOutputTextView insertText:outputString];
    [outputString release];
    
    if ([taskData length]) 
    {
        [[aNotification object] readInBackgroundAndNotify];
    }
    else
    {
    [self taskFinished:nil];
    }
}

- (void)taskFinished:(NSNotification *)aNotification 
{
    
    // We've been notified we are done!
    
    [[NSNotificationCenter defaultCenter] 
     removeObserver:self 
     name:NSTaskDidTerminateNotification 
     object:task];
    
    [[NSNotificationCenter defaultCenter] 
     removeObserver:self 
     name:NSFileHandleReadCompletionNotification 
     object:nil];
    
	[task release]; // Don't forget to clean up memory
    task = nil; // Just in case...
    
    [fTaskProgressField setStringValue:@"Task Completed!"];
    
    [fTaskProgressIndicator stopAnimation: nil];
    [fTaskProgressIndicator setHidden: YES];
    taskIsRunning = NO;
    
    /* if the task spool is empty, the show the operation complete notification operationName */
    if ([taskSpoolArray count] == 0)
    {
        [fTaskProgressField setStringValue:[NSString stringWithFormat:@"%@ Completed!",operationName]];
        
        /* Alert when done checkbox */
        if (canUseOperationCompleteAlert == YES)
        {
            /*On Screen Notification*/
            int status;
            NSBeep();
            if ([fXmbcLinuxCloneFormatCheck state] == NSOnState && [operationName isEqualToString:@"New ATV Disk (NewHfs) Setup"])
            {
                status = NSRunAlertPanel(@"AtvCloner has finished your linux setup! We will now setup you Media Partition. Please wait until the Media volume mounts on your Desktop, then click OK ...",[NSString stringWithFormat:@"%@ Completed!",operationName], @"OK", nil, nil);
                [self createAndChmodMediaDirectories:nil];
            }
            else
            {
                status = NSRunAlertPanel(@"AtvCloner has finished!",[NSString stringWithFormat:@"%@ Completed!",operationName], @"OK", nil, nil);
            }
            [NSApp requestUserAttention:NSCriticalRequest];
            
            canUseOperationCompleteAlert = NO;
        }
    }
}
#pragma mark -
#pragma mark Home Page and User Guide Windows
- (IBAction) openHomepage: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
        URLWithString:@"http://dynaflashtech.net/atvcloner/"]];
}

- (IBAction) openUserGuide: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
        URLWithString:@"http://dynaflashtech.net/atvcloner/atvcloner-user-guide/"]];
}

- (IBAction) openForums: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
        URLWithString:@"http://forum.dynaflashtech.net/index.php"]];
}

#pragma mark -
#pragma mark Preferences

- (IBAction) showPreferences: (id) sender
{
	
    [fPreferencesWindow makeKeyAndOrderFront:nil];

}


- (IBAction) setPreferences: (id) sender
{
    if ([fPrefScanAtLaunchCheck state] == NSOnState)
    {
        [[NSUserDefaults standardUserDefaults] setObject: @"YES" forKey:@"ScanAtLaunch"];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject: @"NO" forKey:@"ScanAtLaunch"];
    }
    
    
    if ([fPrefAlertWhenDoneCheck state] == NSOnState)
    {
        [[NSUserDefaults standardUserDefaults] setObject: @"YES" forKey:@"AlertWhenDone"];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject: @"NO" forKey:@"AlertWhenDone"];
    } 
}

- (void) setPreferenceWidgets
{
    /* Scan at Launch checkbox */
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ScanAtLaunch"])
    {
        [fPrefScanAtLaunchCheck setState:NSOnState];
    }
    else
    {
        [fPrefScanAtLaunchCheck setState:NSOffState];
    }
    
    
    /* Alert when done checkbox */
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AlertWhenDone"])
    {
        [fPrefAlertWhenDoneCheck setState:NSOnState];
    }
    else
    {
        [fPrefAlertWhenDoneCheck setState:NSOffState];
    } 
}

#pragma mark -
#pragma mark Resolve path name to block device

- (NSString *)devicePath
{
    //if( !bsdName )
    //{
        bsdName = [[self bsdNameForPath] retain];
    //}
    return [NSString stringWithFormat:@"/dev/%@", bsdName];
}

- (NSString *)bsdNameForPath
{
    OSStatus err;
    FSRef ref;
    err = FSPathMakeRef( (const UInt8 *) [path fileSystemRepresentation],
                         &ref, NULL );	
    if( err != noErr )
    {
        return nil;
    }

    // Get the volume reference number.
    FSCatalogInfo catalogInfo;
    err = FSGetCatalogInfo( &ref, kFSCatInfoVolume, &catalogInfo, NULL, NULL,
                            NULL);
    if( err != noErr )
    {
        return nil;
    }
    FSVolumeRefNum volRefNum = catalogInfo.volume;

    // Now let's get the device name
    GetVolParmsInfoBuffer volumeParms;
    err = FSGetVolumeParms ( volRefNum, &volumeParms, sizeof( volumeParms ) );

    if( err != noErr )
    {
        return nil;
    }

    // A version 4 GetVolParmsInfoBuffer contains the BSD node name in the vMDeviceID field.
    // It is actually a char * value. This is mentioned in the header CoreServices/CarbonCore/Files.h.
    if( volumeParms.vMVersion < 4 )
    {
        return nil;
    }

    // vMDeviceID might be zero as is reported with experimental ZFS (zfs-119) support in Leopard.
    if( !volumeParms.vMDeviceID )
    {
        return nil;
    }
    /* this gives us something like disk1s2 */
    return [NSString stringWithUTF8String:(const char *)volumeParms.vMDeviceID];
    
}

@end
