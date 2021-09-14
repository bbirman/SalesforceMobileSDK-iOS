/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFSmartStoreUpgrade.h"
#import "SFSmartStore+Internal.h"
#import "SFSmartStoreUtils.h"
#import "SFSmartStoreDatabaseManager+Internal.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/UIDevice+SFHardware.h>
#import <SalesforceSDKCore/SFCrypto.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFSDKDataSharinghelper.h>
#import "FMDatabase.h"

static NSString * const kLegacyDefaultPasscodeStoresKey = @"com.salesforce.smartstore.defaultPasscodeStores";
static NSString * const kLegacyDefaultEncryptionTypeKey = @"com.salesforce.smartstore.defaultEncryptionType";
static NSString * const kKeyStoreEncryptedStoresKey = @"com.salesforce.smartstore.keyStoreEncryptedStores";
static NSString * const kKeyStoreHasExternalSalt = @"com.salesforce.smartstore.external.hasExternalSalt";
static NSString * const kKeyStoreBBUpgrade = @"com.salesforce.smartstore.bbupgrade"; // BB TODO: Rename variable and string

@implementation SFSmartStoreUpgrade

+ (void)updateEncryptionSalt {
    
    if ( ![SFSDKDatasharingHelper sharedInstance].appGroupEnabled || [[NSUserDefaults msdkUserDefaults] boolForKey:kKeyStoreHasExternalSalt]) {
        //already migrated or does not need Externalizing of Salt
        return;
    }
    
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Updating encryption salt for stores in shared mode."];
    NSArray *allStoreNames = [[SFSmartStoreDatabaseManager sharedManager] allStoreNames];
    [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Number of stores to update: %d", [allStoreNames count]];
    SFUserAccount *currentUser = [SFUserAccountManager sharedInstance].currentUser;
    for (NSString *storeName in allStoreNames) {
        if (![SFSmartStoreUpgrade updateSaltForStore:storeName user:currentUser]) {
             [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to upgrade store for sharing mode: %@", storeName];
        }
    }
}

+ (BOOL)updateEncryptionKeyForStore:(NSString *)storeName user:(SFUserAccount *)user {
    
    SFSmartStoreDatabaseManager *databaseManager = [SFSmartStoreDatabaseManager sharedManagerForUser:user];
    if (![databaseManager persistentStoreExists:storeName]) {
        //NEW Database no need for encryption key
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Store '%@' does not exist on the filesystem. Skipping Externalized Salt based migration is not required. ", storeName];
        return NO;
    }
    
    NSError *openDbError = nil;
    
    //get Key and new Salt
    NSString *key = [SFSmartStore encKey];
    NSString *newSalt = [SFSmartStore salt];
    
    FMDatabase *originalEncyptedDB = [databaseManager openStoreDatabaseWithName:storeName
                                                                            key:key
                                                                           salt:nil
                                                                          error:&openDbError];
    if (originalEncyptedDB == nil || openDbError != nil) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error opening store '%@' to update encryption: %@", storeName, [openDbError localizedDescription]];
        return NO;
    } else if (![[databaseManager class] verifyDatabaseAccess:originalEncyptedDB error:&openDbError]) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error reading the content of store '%@' during externalized salt encryption upgrade: %@", storeName, [openDbError  localizedDescription]];
        [originalEncyptedDB close];
        return NO;
    }
    
    if ([key length] > 0) {
        // Unencrypt with previous key.
        NSString *origDatabasePath = originalEncyptedDB.databasePath;
        
        NSString *storePath = [databaseManager fullDbFilePathForStoreName:storeName];
        NSString *backupStorePath = [NSString stringWithFormat:@"%@_%@",storePath,@"backup"];
        NSError *backupError = nil;
        
        // backup and attempt to copy the reencryopted db with the new key + salt
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *origDatabaseURL = [NSURL fileURLWithPath:origDatabasePath isDirectory:NO];
        NSURL *backupDatabaseURL = [NSURL fileURLWithPath:backupStorePath isDirectory:NO];
        
        if ([fileManager fileExistsAtPath:backupStorePath]) {
            [fileManager removeItemAtPath:backupStorePath error:nil];
        }
        
        [fileManager copyItemAtURL:origDatabaseURL toURL:backupDatabaseURL error:&backupError];
        if (backupError) {
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to backup db from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
            return NO;
        }
        
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db, did backup db first from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
        NSError *decryptDbError = nil;
        
        //lets decryptDB
        FMDatabase *decryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:originalEncyptedDB name:storeName  path:originalEncyptedDB.databasePath  oldKey:key newKey:nil salt:nil error:&decryptDbError];
        if (decryptDbError || ![SFSmartStoreDatabaseManager verifyDatabaseAccess:decryptedDB error:&decryptDbError] ) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to decrypt  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        // Now encrypt with new SALT + KEY
        NSError *reEncryptDbError = nil;
        FMDatabase *reEncryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:decryptedDB name:storeName  path:decryptedDB.databasePath  oldKey:@"" newKey:key salt:newSalt error:&reEncryptDbError];
        if (!reEncryptedDB || reEncryptDbError) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to reencrypt DB %@:", [reEncryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [fileManager removeItemAtPath:decryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        if (![SFSmartStoreDatabaseManager verifyDatabaseAccess:reEncryptedDB error:&decryptDbError]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Failed to verify reencrypted  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', %@", storePath,errorDesc];
            [fileManager removeItemAtPath:reEncryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        [reEncryptedDB close];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Migration complete.", storePath];
        [fileManager removeItemAtPath:backupStorePath error:nil];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Removed backup.", backupStorePath];
        [[NSUserDefaults msdkUserDefaults] setBool:YES forKey:kKeyStoreHasExternalSalt];
        return YES;
    }
    return NO;
}

+ (BOOL)updateSaltForStore:(NSString *)storeName user:(SFUserAccount *)user {
    
    SFSmartStoreDatabaseManager *databaseManager = [SFSmartStoreDatabaseManager sharedManagerForUser:user];
    if (![databaseManager persistentStoreExists:storeName]) {
        //NEW Database no need for External Salt migration
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Store '%@' does not exist on the filesystem. Skipping Externalized Salt based migration is not required. ", storeName];
        return NO;
    }
    
    NSError *openDbError = nil;
    
    //get Key and new Salt
    NSString *key = [SFSmartStore encKey];
    NSString *newSalt = [SFSmartStore salt];
    
    FMDatabase *originalEncyptedDB = [databaseManager openStoreDatabaseWithName:storeName
                                                                            key:key
                                                                           salt:nil
                                                                          error:&openDbError];
    if (originalEncyptedDB == nil || openDbError != nil) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error opening store '%@' to update encryption: %@", storeName, [openDbError localizedDescription]];
        return NO;
    } else if (![[databaseManager class] verifyDatabaseAccess:originalEncyptedDB error:&openDbError]) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Error reading the content of store '%@' during externalized salt encryption upgrade: %@", storeName, [openDbError  localizedDescription]];
        [originalEncyptedDB close];
        return NO;
    }
    
    if ([key length] > 0) {
        // Unencrypt with previous key.
        NSString *origDatabasePath = originalEncyptedDB.databasePath;
        
        NSString *storePath = [databaseManager fullDbFilePathForStoreName:storeName];
        NSString *backupStorePath = [NSString stringWithFormat:@"%@_%@",storePath,@"backup"];
        NSError *backupError = nil;
        
        // backup and attempt to copy the reencryopted db with the new key + salt
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *origDatabaseURL = [NSURL fileURLWithPath:origDatabasePath isDirectory:NO];
        NSURL *backupDatabaseURL = [NSURL fileURLWithPath:backupStorePath isDirectory:NO];
        
        if ([fileManager fileExistsAtPath:backupStorePath]) {
            [fileManager removeItemAtPath:backupStorePath error:nil];
        }
        
        [fileManager copyItemAtURL:origDatabaseURL toURL:backupDatabaseURL error:&backupError];
        if (backupError) {
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Failed to backup db from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
            return NO;
        }
        
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db, did backup db first from '%@' to '%@'", origDatabaseURL, backupDatabaseURL];
        NSError *decryptDbError = nil;
        
        //lets decryptDB
        FMDatabase *decryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:originalEncyptedDB name:storeName  path:originalEncyptedDB.databasePath  oldKey:key newKey:nil salt:nil error:&decryptDbError];
        if (decryptDbError || ![SFSmartStoreDatabaseManager verifyDatabaseAccess:decryptedDB error:&decryptDbError] ) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to decrypt  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        // Now encrypt with new SALT + KEY
        NSError *reEncryptDbError = nil;
        FMDatabase *reEncryptedDB = [SFSmartStoreDatabaseManager encryptOrUnencryptDb:decryptedDB name:storeName  path:decryptedDB.databasePath  oldKey:@"" newKey:key salt:newSalt error:&reEncryptDbError];
        if (!reEncryptedDB || reEncryptDbError) {
            NSString *errorDesc = [NSString stringWithFormat:@"Migrating db, Failed to reencrypt DB %@:", [reEncryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db '%@', %@", storePath, errorDesc];
            [fileManager removeItemAtPath:decryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        
        if (![SFSmartStoreDatabaseManager verifyDatabaseAccess:reEncryptedDB error:&decryptDbError]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Failed to verify reencrypted  DB %@:", [decryptedDB lastErrorMessage]];
            [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', %@", storePath,errorDesc];
            [fileManager removeItemAtPath:reEncryptedDB.databasePath error:nil];
            [self restoreBackupTo:origDatabaseURL from:backupDatabaseURL];
            return NO;
        }
        [reEncryptedDB close];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Migration complete.", storePath];
        [fileManager removeItemAtPath:backupStorePath error:nil];
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db '%@',  Removed backup.", backupStorePath];
        [[NSUserDefaults msdkUserDefaults] setBool:YES forKey:kKeyStoreHasExternalSalt];
        return YES;
    }
    return NO;
}

+ (BOOL)restoreBackupTo:(NSURL *)origDatabaseURL from:(NSURL *)backupDatabaseURL {
    BOOL success = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *restoreBackupError = nil;
    [fileManager removeItemAtPath:origDatabaseURL.path error:nil];
    [fileManager copyItemAtURL:backupDatabaseURL toURL:origDatabaseURL error:&restoreBackupError];
    if (restoreBackupError) {
        [SFSDKSmartStoreLogger e:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Could not restore  from backup.", origDatabaseURL];
    } else {
        success = YES;
        [SFSDKSmartStoreLogger i:[SFSmartStoreUpgrade class] format:@"Migrating db at '%@', Recovered from backup.", origDatabaseURL];
    }
    return success;
}

@end
