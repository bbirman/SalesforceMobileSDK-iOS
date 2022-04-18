//
//  BriefcaseSyncDownTarget.swift
//  MobileSync
//
//  Created by Brianna Birman on 4/6/22.
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

@objc(SFBriefcaseObjectInfo)
public class BriefcaseObjectInfo: NSObject, Codable {
    let sobjectType: String
    let fieldlist: [String]
    var idFieldName: String
    var modificationDateFieldName: String
    let soupName: String
    
    public convenience init(soupName: String, sobjectType: String, fieldlist: [String]) {
        self.init(soupName: soupName, sobjectType: sobjectType, fieldlist: fieldlist, idFieldName: nil, modificationDateFieldName: nil)
    }
    
    public init(soupName: String, sobjectType: String, fieldlist: [String], idFieldName: String?, modificationDateFieldName: String?) {
        self.soupName = soupName
        self.sobjectType = sobjectType
        self.fieldlist = fieldlist
        self.idFieldName = idFieldName ?? kId
        self.modificationDateFieldName = modificationDateFieldName ?? kLastModifiedDate
        
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.soupName = try container.decode(String.self, forKey: .soupName)
        self.sobjectType = try container.decode(String.self, forKey: .sobjectType)
        self.fieldlist = try container.decode([String].self, forKey: .fieldlist)
        self.idFieldName = try container.decodeIfPresent(String.self, forKey: .idFieldName) ?? kId
        self.modificationDateFieldName = try container.decodeIfPresent(String.self, forKey: .modificationDateFieldName) ?? kLastModifiedDate
    }
    
//    init(sobjectType: String, fieldlist: [String], idFieldName: String) {
//       BriefcaseObjectInfo(sobjectType: sobjectType, fieldlist: fieldlist, idFieldName: idFieldName)
//    }
}

@objc(SFBriefcaseSyncDownTarget)
public class BriefcaseSyncDownTarget: SyncDownTarget {
    private var relayToken: String? = nil
    private var maxTimeStamp: Int64 = 0
    private var infos: [BriefcaseObjectInfo]
    private var infosMap = [String : BriefcaseObjectInfo]() // TODO: Is this the right style to initialize?

    // TODO
    override public init(dict: [AnyHashable : Any]) {
       
        
        
        if let i = dict["infos"]  {
            do  {
                print(i)
                let json = try JSONSerialization.data(withJSONObject: i)
                let briefcaseInfos = try JSONDecoder().decode([BriefcaseObjectInfo].self, from: json)
                infos = briefcaseInfos
            } catch {
                print(error)
                infos = [BriefcaseObjectInfo]()
            }
           
        } else {
            infos = [BriefcaseObjectInfo]() // TODO
        }
        for info in infos {
            infosMap[info.sobjectType] = info
        }
        
        super.init(dict: dict)
        
    }
    
    override public class func new(fromDict dict: [AnyHashable : Any]) -> Self? {
        return nil
    }
    
    override public func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        
        let data = try! JSONEncoder().encode(infos)
        let json = try! JSONSerialization.jsonObject(with: data, options: [])
//        let encodedData = try? JSONEncoder().encode(infos)
//        let jsonString = String(data: encodedData!,
//                                encoding: .utf8)
        dict["infos"] = json
        return dict
    }
    
    public init(infos: [BriefcaseObjectInfo]) {
        self.infos = infos
        super.init()
        self.queryType = QueryType.briefcase
        for info in infos {
            infosMap[info.sobjectType] = info
        }
        // TODO register AILTN feature marker
        //MobileSyncSDKManager.getInstance().registerUsedAppFeature(Features.FEATURE_RELATED_RECORDS);
    }
    
//    public BriefcaseSyncDownTarget(List<BriefcaseObjectInfo> infos) {
//           this.infos = infos;
//           this.queryType = QueryType.briefcase;
//           MobileSyncSDKManager.getInstance().registerUsedAppFeature(Features.FEATURE_RELATED_RECORDS);
//
//           // Build infosMap
//           infosMap = new HashMap<>();
//           for (BriefcaseObjectInfo info : infos) {
//               infosMap.put(info.sobjectType, info);
//           }
//        }
    
    
    override public func startFetch(syncManager: SyncManager, maxTimeStamp: Int64, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        self.maxTimeStamp = maxTimeStamp
        relayToken = nil
        totalSize = 0 // -1 //Negative integer '-1' overflows when stored into unsigned type 'UInt'
        getIdsFromBriefcasesAndFetchFromServer(syncManager: syncManager, relayToken: relayToken, onFail: errorBlock, onComplete: completeBlock)
    }
    
    override public func continueFetch(syncManager: SyncManager, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: SyncDownCompletionBlock? = nil) {
        if let relayToken = relayToken {
            getIdsFromBriefcasesAndFetchFromServer(syncManager: syncManager, relayToken: relayToken, onFail: errorBlock, onComplete: completeBlock)
        } else {
            completeBlock?(nil)
        }
    }
    
    private func getIdsFromBriefcasesAndFetchFromServer(syncManager: SyncManager, relayToken: String?, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: SyncDownCompletionBlock?) {
        
        // Run priming record request
        getIdsFromBriefcases(syncManager: syncManager, relayToken: relayToken, maxTimeStamp: maxTimeStamp) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let (objectTypeToIds, relayToken)):
                self.relayToken = relayToken
                
                // Prep info for fetch calls so we can know in advance how many calls there will be
                let objectFetches = objectTypeToIds.compactMap { (objectType, recordIds) -> (String, BriefcaseObjectInfo, [String])?  in
                    if let objectInfo = self.infosMap[objectType], !recordIds.isEmpty {
                        return (objectType, objectInfo, recordIds)
                    }
                    return nil
                }
                
                let totalCalls = objectFetches.count // TODO: what if this is zero?
                var successfulCalls = 0
                var records = [Any]()
                
                // Get records using SOQL one object type at a time
                objectFetches.forEach { (objectType, objectInfo, recordIds) in
                    var fieldList = Set(objectInfo.fieldlist)
                    fieldList.insert(objectInfo.idFieldName)
                    fieldList.insert(objectInfo.modificationDateFieldName)

                    self.fetchRecordsFromServer(sobjectType: objectType, ids: recordIds, fieldList: Array(fieldList)) { result in
                        switch result {
                        case .failure(let error):
                            errorBlock(error)
                        case .success(let fetchedRecords):
                            if let fetchedRecords = fetchedRecords {
                                records.append(contentsOf: fetchedRecords)
                            }
                            
                            // Only call success when all fetches have returned
                            successfulCalls += 1
                            if successfulCalls == totalCalls {
                                if (self.totalSize == 0) {
                                    // FIXME once 238 is GA
                                    //  - this will only be correct if there is only one "page" of results
                                    //  - using response.stats.recordCountTotal would only be correct if the filtering by
                                    //  timestamp did not exclude any results
                                    //  - also in 236, response.stats.recordCountTotal seems wrong (it says 1000 all the time)
                                    self.totalSize = UInt(records.count)
                                }
                                completeBlock?(records)
                            }
                        }
                    }
                }
            case .failure(let error):
                errorBlock(error)
            }
        }
    }
    /**
        * Method that calls the priming records API to get ids to fetch
        * then use SOQL to get record fields
        *
        * @param syncManager
        * @return
        */
//       private JSONArray getIdsFromBriefcasesAndFetchFromServer(SyncManager syncManager)
//           throws IOException, JSONException {
//           JSONArray records = new JSONArray();
//
//           // Run priming record request
//           Map<String, List<String>> objectTypeToIds = new HashMap<>();
//           relayToken = getIdsFromBriefcases(syncManager, objectTypeToIds, relayToken, maxTimeStamp);
//
//           // Get records using SOQL one object type at a time
//           for (Entry<String, List<String>> entry : objectTypeToIds.entrySet()) {
//               String objectType = entry.getKey();
//               List<String> idsToFetch = entry.getValue();
//               if (idsToFetch.size() > 0) {
//                   BriefcaseObjectInfo info = infosMap.get(objectType);
//
//                   ArrayList<String> fieldlistToFetch = new ArrayList<>(info.fieldlist);
//                   for (String fieldName : Arrays.asList(info.idFieldName, info.modificationDateFieldName)) {
//                       if (!fieldlistToFetch.contains(fieldName)) {
//                           fieldlistToFetch.add(fieldName);
//                       }
//                   }
//                   JSONArray fetchedRecords = fetchFromServer(syncManager, info.sobjectType, idsToFetch, fieldlistToFetch);
//                   for (int i = 0; i < fetchedRecords.length(); i++) {
//                       records.put(fetchedRecords.getJSONObject(i));
//                   }
//               }
//           }
//
//           if (totalSize == -1) {
//               // FIXME once 238 is GA
//               //  - this will only be correct if there is only one "page" of results
//               //  - using response.stats.recordCountTotal would only be correct if the filtering by
//               //  timestamp did not exclude any results
//               //  - also in 236, response.stats.recordCountTotal seems wrong (it says 1000 all the time)
//               totalSize = records.length();
//           }
//
//           return records;
//       }
    
    private func getIdsFromBriefcases(syncManager: SyncManager, relayToken: String?, maxTimeStamp: Int64, completion: @escaping (Result<([String: [String]], String?), Error>) -> Void) {
        
        let request = RestClient.shared.request(forPrimingRecords: relayToken, apiVersion: nil)
        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
            completion(.failure(error ?? NSError(domain: "test", code: 101))) // TODO
        } successBlock: { [weak self] response, urlResponse in
            guard let self = self else { return }
            
            guard let response = response as? [AnyHashable: Any] else {
                completion(.failure(NSError(domain: "", code: 1))) // TODO
                return
            }
            let primingResponse = PrimingRecordsResponse(response)
            print("BB priming response \(primingResponse)")
            let allPrimingRecords = primingResponse.primingRecords
            
            var objectTypeToIds = [String: [String]]() // right way to initialize?
            self.infos.forEach({ objectInfo in
                guard let recordLists = allPrimingRecords[objectInfo.sobjectType]?.values else { return }
                objectTypeToIds[objectInfo.sobjectType] = recordLists.flatMap { records in
                    return records.filter { record in
                        // Filtering by maxTimeStamp
                        // TODO Remove once 238 is GA (filtering will happen on server)
                        Int64(record.systemModstamp.timeIntervalSince1970) > maxTimeStamp
                    }
                }.compactMap { $0.objectId }  // TODO
            })
            completion(.success((objectTypeToIds, primingResponse.relayToken)))
        }
    }

    private func fetchRecordsFromServer(sobjectType: String, ids: [String], fieldList: [String], completion: @escaping (Result<[Any]?, Error>) -> Void){
        let whereClause = "\(idFieldName) IN ('\(ids.joined(separator: "', '"))')" // TODO
        
        // SOQL query size limit is 100,000 characters (so ~5000 ids)
        // See https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_soslsoql.htm
        // We won't get that many returned in one response from the priming record API so we don't need to chunk them in multiple requests
        
        // TODO: The response is 2000 records at a time, is the briefcase size less than that so we don't need to use
        // "nextRecordsUrl"?
        // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
        let soql = SFSDKSoqlBuilder.withFieldsArray(fieldList).from(sobjectType).whereClause(whereClause).build()!
        let request = RestClient.shared.request(forQuery: soql, apiVersion: nil)
       
        
        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, urlResponse in
            completion(.failure(error ?? NSError(domain: "", code: 0)))
        } successBlock: { response, urlResponse in
            
            if let queryResponse = response as? [String: Any],
                let records = queryResponse["records"] as? [Any]? {
                completion(.success(records))
            } else {
                completion(.failure(NSError(domain: "", code: 1)))
            }
        }
    }
    
    
    // TODO: Need to test recursion
    func getAllIdsFromBriefcases(syncManager: SyncManager, relayToken: String?, maxTimeStamp: Int64, completion: @escaping (Result<([String: [String]], String?), Error>) -> Void) {
        getIdsFromBriefcases(syncManager: syncManager, relayToken: relayToken, maxTimeStamp: maxTimeStamp) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success((let records, let relayToken)):
                
                if let relayToken = relayToken {
                    print("BB: relayToken \(relayToken)")
                    self.getAllIdsFromBriefcases(syncManager: syncManager, relayToken: relayToken, maxTimeStamp: maxTimeStamp) { result in
                        switch result {
                        case .success((let nextRecords, let nextRelayToken)):
                            let combinedRecords = records.merging(nextRecords) { $0 + $1 }
                            completion(.success((combinedRecords, nextRelayToken)))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.success((records, nil)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
            
        }
    }
    
    func nonDirtyRecordsIds(syncManager: SyncManager, soupName: String, idField: String, additionalPredicate: String) -> NSOrderedSet {
        let sql = "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(kSyncTargetLocal)} = '0' \(additionalPredicate) ORDER BY {\(soupName):\(idField)} ASC"
        
       return idsWithQuery(sql, syncManager: syncManager)
    }
    
    func idsWithQuery(_ query: String, syncManager: SyncManager) -> NSOrderedSet {
        return NSOrderedSet()
        // TODO: Below
    }
    
//    - (NSOrderedSet *)getIdsWithQuery:idsSql syncManager:(SFMobileSyncSyncManager *)syncManager {
//        NSMutableOrderedSet* ids = [NSMutableOrderedSet new];
//        SFQuerySpec* querySpec = [SFQuerySpec newSmartQuerySpec:idsSql withPageSize:kSyncTargetPageSize];
//
//        BOOL hasMore = YES;
//        for (NSUInteger pageIndex=0; hasMore; pageIndex++) {
//            NSArray* results = [syncManager.store queryWithQuerySpec:querySpec pageIndex:pageIndex error:nil];
//            hasMore = (results.count == kSyncTargetPageSize);
//            [ids addObjectsFromArray:[self flatten:results]];
//        }
//        return ids;
//    }
    
    
//    - (NSOrderedSet *)getNonDirtyRecordIds:(SFMobileSyncSyncManager *)syncManager soupName:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate {
//        NSString* nonDirtyRecordsSql = [self getNonDirtyRecordIdsSql:soupName idField:idField additionalPredicate:additionalPredicate];
//        return [self getIdsWithQuery:nonDirtyRecordsSql syncManager:syncManager];
//    }

//    - (NSString *)getNonDirtyRecordIdsSql:(NSString *)soupName idField:(NSString *)idField additionalPredicate:(NSString *)additionalPredicate {
//        return [NSString stringWithFormat:@"SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = '0' %@ ORDER BY {%@:%@} ASC",
//                                          soupName, idField, soupName, soupName, kSyncTargetLocal, additionalPredicate, soupName, idField];
//    }
    
    override public func cleanGhosts(syncManager: SyncManager, soupName: String, syncId: NSNumber, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        
        getAllIdsFromBriefcases(syncManager: syncManager, relayToken: nil, maxTimeStamp: maxTimeStamp) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let records, _):
                records.map { (objectName, records) in
                    let objectInfo = self.infosMap[objectName]
                    //clean
                }
                
            case .failure(let error):
                errorBlock(error)
            }
        }
        
        
        
    }
//        int countGhosts = 0;
//
//            // Get all ids
//            Map<String, List<String>> objectTypeToIds = new HashMap<>();
//            String relayToken = null;
//            do {
//                relayToken = getIdsFromBriefcases(syncManager, objectTypeToIds, relayToken, 0);
//            } while (relayToken != null);
//
//            // Cleaning up ghosts one object type at a time
//            for (Entry<String, List<String>> entry : objectTypeToIds.entrySet()) {
//                String objectType = entry.getKey();
//                BriefcaseObjectInfo info = infosMap.get(objectType);
//                SortedSet<String> remoteIds = new TreeSet<>(entry.getValue());
//                SortedSet<String> localIds = getNonDirtyRecordIds(syncManager, info.soupName, info.idFieldName,
//                    buildSyncIdPredicateIfIndexed(syncManager, info.soupName, syncId));
//                localIds.removeAll(remoteIds);
//                int localIdSize = localIds.size();
//                if (localIdSize > 0) {
//                    deleteRecordsFromLocalStore(syncManager, info.soupName, localIds, info.idFieldName);
//                }
//                countGhosts += localIdSize;
//            }
//
//            return countGhosts;

    // Overriding because records could be in different soups
    override public func cleanAndSaveRecordsToLocalStore(syncManager: SyncManager, soupName: String, records: [Any], syncId: NSNumber) {
        let store = syncManager.store
        //let db = store.da
        
       // super.sa'
        
       // TODO: Single DB transaction
        
        records.forEach { record in
            guard var record = record as? [String: Any],
                  let info = briefcaseInfo(for: record) else {
                // TODO: Log
                return
            }
            super.cleanAndSaveRecordsToLocalStore(syncManager: syncManager, soupName: info.soupName, records: [record], syncId: syncId)
            
//            - (void)cleanAndSaveRecordsToLocalStore:(SFMobileSyncSyncManager *)syncManager soupName:(NSString *)soupName records:(NSArray *)records syncId:(NSNumber *)syncId {
//                [self saveInSmartStore:syncManager.store soupName:soupName records:records idFieldName:self.idFieldName syncId:syncId lastError:nil cleanFirst:YES];
//            }

            
            // cleanAndSaveInSmartStore(smartStore, info.soupName, record, info.idFieldName, false);
//            NSMutableArray* recordsFromSmartStore = [NSMutableArray new];
//            NSMutableArray* recordsFromServer = [NSMutableArray new];
//
//            for (NSDictionary * record in records) {
//                NSMutableDictionary *mutableRecord = [record mutableCopy];
//                if (cleanFirst) {
//                    [self cleanRecord:mutableRecord];
//                }
//                [self addSyncId:mutableRecord syncId:syncId];
//                [self addLastError:mutableRecord lastError:lastError];
//                if (mutableRecord[SOUP_ENTRY_ID]) {
//                    // Record came from smartstore
//                    [recordsFromSmartStore addObject:mutableRecord];
//                } else {
//                    // Record came from server
//                    [recordsFromServer addObject:mutableRecord];
//                }
//            }
//
//            // Saving in bulk
//            [smartStore upsertEntries:recordsFromSmartStore toSoup:soupName];
//            [smartStore upsertEntries:recordsFromServer toSoup:soupName withExternalIdPath:idFieldName error:nil];
            
        }

    }
    
    
    
    private func briefcaseInfo(for record: [String: Any]) -> BriefcaseObjectInfo? {
        if let attributes = record["attributes"] as? [String: Any],
           let objectType = attributes["type"] as? String {
            return infosMap[objectType]
        }
        return nil
    }
}
