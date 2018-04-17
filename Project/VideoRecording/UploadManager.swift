//
//  UploadManager.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 03/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import Foundation
import AWSS3

enum MediaContentType: String {
    case Video = "movie/mov"
    case Image = "image/png"
}

enum UploadStatus: String {
    case Pause = "Pause"
    case Resume = "Resume"
    case Cancelled = "Cancelled"
    case InProgress = "InProgress"
    case Failed = "Failed"
    case Success = "Success"
}
let failedNotification = "postFailedNotification"
let didProgressUpdateNotification = "progressDidUpdateNotification"
let completionNotification = "postCompletionNotification"
let continuationNotification = "postContinuationNotification"
let readyStatus = "Ready"
let failedStatus = "Failed"
let successStatus = "Upload Success"
let uploadingStatus = "Uploading...."
let pausedStatus = "Paused"
let canceledStatus = "Cancelled"

class UploadManager {
    static let sharedInstance = UploadManager()
    private init() {
        self.setAnonymousCallbacks()
    }
    let S3BucketName: String = "YourBucketName"
    var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
    var progressBlock: AWSS3TransferUtilityProgressBlock?
    var uploadTask: AWSS3TransferUtilityUploadTask?
    lazy var transferUtility: AWSS3TransferUtility = {
        return AWSS3TransferUtility.default()
    }()
    var arrayUploadtask: [Int : AWSS3TransferUtilityUploadTask] = [:]
    var multipartProgressBlock: AWSS3TransferUtilityMultiPartProgressBlock?
    var multipartUploadTask: AWSS3TransferUtilityMultiPartUploadTask?
    var multipartCompletionHandler: AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock?
    let multiPartUploadExpression = AWSS3TransferUtilityMultiPartUploadExpression()
    lazy var dictTaskStatus: [String: UploadModel] = [:]
    lazy var uploadedKeyUrlsArray: [String] = []
    var continuationTaskBlock: ((_ errr: Error?,_ result: AWSS3TransferUtilityUploadTask?) -> Void)?
    let uploadExpression = AWSS3TransferUtilityUploadExpression()
    var shouldRemoveSuccessfullUploadFromArray: Bool = true
    var callbackDeleteResponse: ((_ keyUrlString: String?,_ error: Error?) -> Void)?
    
    func setAnonymousCallbacks(){
        self.continuationTaskBlock = {(error, result) in
            if let err = error{
                let key = result != nil ? result!.key : ""
                self.postFailedNotification(key: key, errorString: "Failed with error \(err.localizedDescription)")
                
            }else{
                if let task = result{
                    self.dictTaskStatus[task.key] = UploadModel(_tranferId: task.transferID, _progress: task.progress.fractionCompleted, _status: readyStatus)
                    print("from Conti => \(self.dictTaskStatus.keys)")
                    self.postContinuationNotification(key: task.key)
                }
            }
        }
        
        self.completionHandler = {(task, error) in
            if error == nil{
                _ =  self.dictTaskStatus.filter{
                    if task.transferID == $0.value.tranferId {
                        $0.value.progress = task.progress.fractionCompleted
                        if $0.value.progress == 1.0{
                            $0.value.status = UploadStatus.Success.rawValue
                            $0.value.completed = true
                            $0.value.failed = false
                            $0.value.inProgess = false
                            $0.value.paused = false
                            $0.value.cancelled = false
                        }else if $0.value.progress != 1.0{
                            $0.value.status = UploadStatus.Failed.rawValue
                            $0.value.completed = false
                            $0.value.failed = true
                            $0.value.inProgess = false
                            $0.value.paused = false
                            $0.value.cancelled = false
                            
                        }
                        self.postCompletionNotification(key: task.key)
                        
                        self.addUrlToUploadsStringArray(keyUrlString: task.key)
                    }
                    return true
                }
            }else{
                _ =  self.dictTaskStatus.filter{
                    if task.transferID == $0.value.tranferId {
                        $0.value.progress = task.progress.fractionCompleted
                        $0.value.status = UploadStatus.Failed.rawValue
                        $0.value.failed = true
                        $0.value.completed = false
                        $0.value.inProgess = false
                        $0.value.paused = false
                        $0.value.cancelled = false
                    }
                    return true
                }
                self.postFailedNotification(key: task.key, errorString: "Failed with error \(error?.localizedDescription)")
            }
        }
        
        self.progressBlock = {(task, progress) in
            _ =  self.dictTaskStatus.filter{
                if task.transferID == $0.value.tranferId {
                    $0.value.progress = task.progress.fractionCompleted
                    if $0.value.progress != 1.0{
                        $0.value.status = UploadStatus.InProgress.rawValue
                        $0.value.inProgess = true
                        $0.value.failed = false
                        $0.value.completed = false
                        $0.value.paused = false
                        $0.value.cancelled = false
                    }else if $0.value.progress == 1.0{
                        $0.value.status = UploadStatus.Success.rawValue
                        $0.value.inProgess = false
                        $0.value.failed = false
                        $0.value.completed = true
                        $0.value.paused = false
                        $0.value.cancelled = false
                    }
                    self.postProgressNotification(key: task.key)
                    return true
                }
                return false
            }
            
        }
    }
    
    func addUrlToUploadsStringArray(keyUrlString: String){
        if self.uploadedKeyUrlsArray.contains(keyUrlString){
            //Already present
        }else{
            self.uploadedKeyUrlsArray.append(keyUrlString)
        }
        
    }
    
    func reloadTaskDict(transferId: String,status: UploadStatus, urlString: String, completion: @escaping ((UploadModel?) -> Void)){
        let array = UploadManager.sharedInstance.transferUtility.getUploadTasks()
        if let swiftArray = array.result as! NSArray as? [AWSS3TransferUtilityUploadTask]{
            weak var slf = self
            if swiftArray.count > 0{
                _ = swiftArray.filter{obj in
                    if obj.transferID == transferId{
                        switch status{
                        case .Resume:
                            obj.resume()
                        case .Cancelled:
                            obj.cancel()
                        case .Pause:
                            obj.suspend()
                        default:
                            return false
                        }
                        if let model = UploadManager.sharedInstance.dictTaskStatus[urlString]{
                            switch status{
                            case .InProgress:
                                model.inProgess = true
                                model.paused = false
                                model.failed = false
                                model.completed = false
                                model.cancelled = false
                                model.status = UploadStatus.InProgress.rawValue
                            case .Cancelled:
                                model.cancelled = true
                                model.paused = false
                                model.inProgess = false
                                model.failed = false
                                model.completed = false
                                model.progress = 0.0
                                model.status = UploadStatus.Cancelled.rawValue
                                UploadManager.sharedInstance.dictTaskStatus.removeValue(forKey: urlString)
                            case .Failed:
                                model.failed = true
                                model.paused = false
                                model.inProgess = false
                                model.completed = false
                                model.cancelled = false
                                model.status = UploadStatus.Failed.rawValue
                            case .Success:
                                model.completed = true
                                model.paused = false
                                model.inProgess = false
                                model.failed = false
                                model.cancelled = false
                                model.status = UploadStatus.Success.rawValue
                            case .Resume:
                                model.inProgess = true
                                model.paused = false
                                model.failed = false
                                model.completed = false
                                model.cancelled = false
                                model.status = UploadStatus.Resume.rawValue
                            case .Pause:
                                model.paused = true
                                model.inProgess = false
                                model.failed = false
                                model.completed = false
                                model.cancelled = false
                                model.status = UploadStatus.Pause.rawValue
                            default:
                                return false
                            }
                            DispatchQueue.main.async {
                                completion(model)
                            }
                        }
                    }
                    return true
                }
            }else{
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        
    }
    
    
    func reloadTaskDictionary(progress: Double, status: UploadStatus, urlString: String, completion: @escaping ((UploadModel?) -> Void) ){
        
        _ = UploadManager.sharedInstance.dictTaskStatus.map{
            if $0.key == urlString{                
                $0.value.progress = progress
                switch status{
                case .InProgress:
                    $0.value.inProgess = true
                    $0.value.paused = false
                    $0.value.failed = false
                    $0.value.completed = false
                    $0.value.cancelled = false
                    $0.value.status = UploadStatus.InProgress.rawValue
                case .Cancelled:
                    $0.value.cancelled = true
                    $0.value.paused = false
                    $0.value.inProgess = false
                    $0.value.failed = false
                    $0.value.completed = false
                    $0.value.progress = 0.0
                    $0.value.status = UploadStatus.Cancelled.rawValue
                    UploadManager.sharedInstance.dictTaskStatus.removeValue(forKey: $0.key)
                case .Failed:
                    $0.value.failed = true
                    $0.value.paused = false
                    $0.value.inProgess = false
                    $0.value.completed = false
                    $0.value.cancelled = false
                    $0.value.status = UploadStatus.Failed.rawValue
                case .Success:
                    $0.value.completed = true
                    $0.value.paused = false
                    $0.value.inProgess = false
                    $0.value.failed = false
                    $0.value.cancelled = false
                    $0.value.status = UploadStatus.Success.rawValue
                case .Resume:
                    $0.value.inProgess = true
                    $0.value.paused = false
                    $0.value.failed = false
                    $0.value.completed = false
                    $0.value.cancelled = false
                    $0.value.status = UploadStatus.Resume.rawValue
                case .Pause:
                    $0.value.paused = true
                    $0.value.inProgess = false
                    $0.value.failed = false
                    $0.value.completed = false
                    $0.value.cancelled = false
                    $0.value.status = UploadStatus.Pause.rawValue
                default:
                    return
                }
                let model = $0.value
                DispatchQueue.main.async {
                    completion(model)
                }
                //print("reloadAtIndex \($0.key) ==  \(urlString)  == \($0.value.progress)")
                
            }
        }
    }
    
    func UpdateTaskDictionary(keyUrl: String){
        if self.shouldRemoveSuccessfullUploadFromArray{
            self.dictTaskStatus.removeValue(forKey: keyUrl)
        }
    }
    
    func postFailedNotification(key: String, errorString: String){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: failedNotification), object: errorString, userInfo: ["taskKey" : key])
    }
    
    func postProgressNotification(key: String){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: didProgressUpdateNotification), object: dictTaskStatus, userInfo: ["taskKey" : key])
    }
    
    func postCompletionNotification(key: String){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: completionNotification), object: dictTaskStatus, userInfo: ["taskKey" : key])
    }
    func postContinuationNotification(key: String){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: continuationNotification), object: dictTaskStatus, userInfo: ["taskKey" : key])
    }
    
    
    init(_completionHandler: @escaping AWSS3TransferUtilityUploadCompletionHandlerBlock, _progressBlock: @escaping AWSS3TransferUtilityProgressBlock ){
        self.completionHandler = _completionHandler
        self.progressBlock = _progressBlock
    }
    
    func setMultipartCallbacks(_completionHandler: @escaping AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock, _progressBlock: @escaping AWSS3TransferUtilityMultiPartProgressBlock){
        self.multipartCompletionHandler = _completionHandler
        self.multipartProgressBlock = _progressBlock
    }
    
    func setCallBacks(_completionHandler: @escaping AWSS3TransferUtilityUploadCompletionHandlerBlock, _progressBlock: @escaping AWSS3TransferUtilityProgressBlock ){
        self.completionHandler = _completionHandler
        self.progressBlock = _progressBlock
        transferUtility.enumerateToAssignBlocks(forUploadTask: { [weak self] task, progressRef, completionRef in
            guard let strongSelf = self else { return }
            print("idddd \(task.taskIdentifier)")
            
            let progressPointer = AutoreleasingUnsafeMutablePointer<AWSS3TransferUtilityProgressBlock?>(&strongSelf.progressBlock)
            let completionPointer = AutoreleasingUnsafeMutablePointer<AWSS3TransferUtilityUploadCompletionHandlerBlock?>(&strongSelf.completionHandler)
            
            progressRef?.pointee = progressPointer.pointee
            completionRef?.pointee = completionPointer.pointee
            }, downloadTask: nil)
    }
    
    func setTaskStatus(status: UploadStatus, transferId: String){
        transferUtility.enumerateToAssignBlocks(forUploadTask: { [weak self] task, progressRef, completionRef in
            guard let strongSelf = self else { return }
            if task.transferID == transferId{
                switch status{
                case .InProgress:
                    task.resume()
                case .Cancelled:
                    task.cancel()
                case .Pause:
                    task.suspend()
                default:
                    return
                }
            }
            
            let progressPointer = AutoreleasingUnsafeMutablePointer<AWSS3TransferUtilityProgressBlock?>(&strongSelf.progressBlock)
            let completionPointer = AutoreleasingUnsafeMutablePointer<AWSS3TransferUtilityUploadCompletionHandlerBlock?>(&strongSelf.completionHandler)
            
            progressRef?.pointee = progressPointer.pointee
            completionRef?.pointee = completionPointer.pointee
            }, downloadTask: nil)
    }
    
    func multipartUploadFile(file url: URL, _contentType: MediaContentType, continuationTaskBlock: @escaping (_ errr: Error?,_ result: AWSS3TransferUtilityMultiPartUploadTask?) -> Void ){
        let bucket = self.S3BucketName
        let key = url.pathComponents.last!
        let contentType = _contentType.rawValue
        multiPartUploadExpression.progressBlock = multipartProgressBlock
        
        let uploadUtility = transferUtility.uploadUsingMultiPart(fileURL: url, bucket: bucket, key: key, contentType: contentType, expression: multiPartUploadExpression, completionHandler: multipartCompletionHandler)
        
        
        uploadUtility.continueWith { (task) -> Any? in
            if let uploadTask = task.result {
                self.multipartUploadTask = uploadTask
            }
            continuationTaskBlock(task.error, task.result)
            return nil
        }
    }
    
    func upload(file url: URL, continuationTaskBlock: @escaping (_ errr: Error?,_ result: AWSS3TransferUtilityUploadTask?) -> Void ) {
        let bucket = self.S3BucketName
        let key = "44"
        let contentType = "video/mp4"
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = progressBlock
        
        
        let task = transferUtility.uploadFile(url,
                                              bucket: bucket,
                                              key: key,
                                              contentType: contentType,
                                              expression: expression,
                                              completionHandler: completionHandler)
        
        task.continueWith { (task) -> Any? in
            if let error = task.error {
                return nil
            }
            if let uploadTask = task.result {
                self.uploadTask = uploadTask
                self.continuationTaskBlock?(task.error, task.result)
            }
            ///continuationTaskBlock(task.error, task.result)
            return nil
        }
    }
    
   func uploadFile(with data: Data, name: String, contentType: MediaContentType,continuationTaskBlock: @escaping (_ errr: Error?,_ result: AWSS3TransferUtilityUploadTask?) -> Void ){
        uploadExpression.progressBlock = self.progressBlock
        transferUtility.uploadData(
            data,
            bucket: self.S3BucketName,
            key: name,
            contentType: contentType.rawValue,
            expression: uploadExpression,
            completionHandler: completionHandler).continueWith { (task) -> Any? in
                if let uploadTask = task.result {
                    self.uploadTask = uploadTask
                    self.continuationTaskBlock?(task.error, task.result)
                }
                return nil
                
        }
    }
    //MARK: Currently used
    func uploadFile(with data: Data, name: String, contentType: MediaContentType){
        if UploadManager.sharedInstance.dictTaskStatus[name] == nil {
            uploadExpression.progressBlock = self.progressBlock
            transferUtility.uploadData(
                data,
                bucket: self.S3BucketName,
                key: name,
                contentType: contentType.rawValue,
                expression: uploadExpression,
                completionHandler: completionHandler).continueWith { (task) -> Any? in
                    if let uploadTask = task.result {
                        self.uploadTask = uploadTask
                        self.continuationTaskBlock?(task.error, task.result)
                    }
                    return nil
                    
            }
        }else{
            self.UploadAlreadyInProgress(urlString: name)
        }
    }
    
    func deleteFile(with fileName: String){
        let deleteObjectRequest = AWSS3DeleteObjectRequest()
        deleteObjectRequest?.bucket = self.S3BucketName
        deleteObjectRequest?.key = fileName
        let s3 = AWSS3.default()
        s3.deleteObject(deleteObjectRequest!) { (objectOutput, error) in
            print(objectOutput)
            if error == nil{
                let i = self.uploadedKeyUrlsArray.index(of: fileName)
                self.uploadedKeyUrlsArray = self.uploadedKeyUrlsArray.filter{
                    $0 != fileName
                }
                self.callbackDeleteResponse?(fileName, nil)
            }else{
                self.callbackDeleteResponse?(nil, error)
            }
        }
       
    }
    
    func UploadAlreadyInProgress(urlString: String){
        if let model = dictTaskStatus[urlString]{
            if model.inProgess{
                self.postProgressNotification(key: urlString)
            }else if model.completed {
                self.postCompletionNotification(key: urlString)
            }else if model.failed{
                self.dictTaskStatus.removeValue(forKey: urlString)
                self.postFailedNotification(key: urlString, errorString: "Error")
            }
        }
    }
    
    func removeCustomTaskModel(urlString: String){
        self.dictTaskStatus.removeValue(forKey: urlString)
    }
    
    func indexOfUploadTask(index: Int) -> Bool{
        for (_, item) in self.arrayUploadtask.enumerated() {
           return item.key == index
        }
        return false
    }
    
}
