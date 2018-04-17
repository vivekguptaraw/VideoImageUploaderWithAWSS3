//
//  FirstViewController.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 02/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import UIKit
import MobileCoreServices
import AssetsLibrary
import AWSS3

class FirstViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    @IBOutlet weak var takeVideo: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var resumeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var callbackUrlLabel: UILabel!
    
    let imagePicker = UIImagePickerController()
    var isTakeVideo: Bool = false
    var isUploadVideo: Bool = false
    var transferId: String = ""
    var callbackUrl: String = ""
    @IBAction func uploadClicked(_ sender: UIButton) {
        self.isUploadVideo = true
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerControllerSourceType.photoLibrary
        controller.mediaTypes = [kUTTypeMovie as! String]
        controller.delegate = self
        present(controller, animated: true, completion: nil)
        
    }
    var urlString: String = ""
    @IBOutlet weak var viewLibrary: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.progressView.progress = 0.0;
        self.statusLabel.text = "Ready"
        NotificationCenter.default.addObserver(self, selector: #selector(getProgressDataUpdate), name: NSNotification.Name(rawValue: didProgressUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getCompletionUpdate), name: NSNotification.Name(rawValue: completionNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getFailedUpdate), name: NSNotification.Name(rawValue: failedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getContinuationUpdate), name: NSNotification.Name(rawValue: continuationNotification), object: nil)
        UploadManager.sharedInstance.dictTaskStatus.removeAll()
        self.callbackUrlLabel.text = "Callback URL will be here when your upload complete"
    }
    
    @objc func getContinuationUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String, key == urlString{
                self.setUpdatedData(key: key, status: .InProgress)
            }
        }
    }
    
    @objc func getProgressDataUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String, key == urlString{
                self.setUpdatedData(key: key, status: .InProgress)
            }
        }
    }
    
    @objc func getCompletionUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String, key == urlString{
                self.setUpdatedData(key: key, status: .Success)
            }
        }
    }
    
    @objc func getFailedUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String, key == urlString{
                self.setUpdatedData(key: key, status: .Failed)
            }
        }
    }
    
    func setUpdatedData(key: String, status: UploadStatus){
        if let uploadModel = UploadManager.sharedInstance.dictTaskStatus[key]{
            self.transferId = uploadModel.tranferId
            self.callbackUrl = uploadModel.callbackUrlFormat.replacingOccurrences(of: fileNameUploaded, with: self.urlString)
            if status == .Success{
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.2, animations: {
                        DispatchQueue.main.async {
                            self.callbackUrlLabel.text = self.callbackUrl
                        }
                    }, completion: { (bool) in
                        UIView.animate(withDuration: 1, animations: {
                            DispatchQueue.main.async {
                                self.callbackUrlLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
                            }
                        }, completion: { (bool) in
                            DispatchQueue.main.async {
                                self.callbackUrlLabel.backgroundColor = UIColor.clear
                            }
                        })
                    })
                    
                }
            }
            DispatchQueue.main.async {
                self.progressView.progress = Float(uploadModel.progress)
                self.statusLabel.text = uploadModel.status
            }
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func takeVideoClicked(_ sender: UIButton) {
        isTakeVideo = true
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera){
            let controller = UIImagePickerController()
            controller.sourceType = .camera
            controller.mediaTypes = [kUTTypeMovie as! String]
            controller.delegate = self
            controller.videoMaximumDuration = 10000
            present(controller, animated: true, completion: {
                
            })
        }else {
            isTakeVideo = false
            print("Camera is not available")
        }
    }
    
    @IBAction func viewLibrary(_ sender: UIButton) {
        // Display Photo Library
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerControllerSourceType.photoLibrary
        controller.mediaTypes = [kUTTypeMovie as! String]
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ////self.uploadManager.uploadTask?.resume()
    }
    
    @IBAction func pauseClicked(_ sender: UIButton) {
        handleCLicks(status: .Pause)
    }
    
    @IBAction func resumeClicked(_ sender: UIButton) {
        handleCLicks(status: .Resume)
    }
    
    @IBAction func cancelClicked(_ sender: UIButton) {
       handleCLicks(status: .Cancelled)
    }
    
    func handleCLicks(status: UploadStatus){
        if self.transferId != ""{
            UploadManager.sharedInstance.reloadTaskDict(transferId: self.transferId, status: status, urlString: self.urlString, completion: { (model) in
                if let uploadModel = model {
                    self.statusLabel.text = uploadModel.status
                    self.progressView.progress = Float(uploadModel.progress)
                }
            })
            
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if self.isTakeVideo {
            let mediaType: Any? = info[UIImagePickerControllerMediaType]
            if let type:Any = mediaType{
                if type is String{
                    let stringType = type as! String
                    if stringType == kUTTypeMovie as String {
                        let urlOfVideo = info[UIImagePickerControllerMediaURL] as? URL
                        if let url = urlOfVideo {
                            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(FirstViewController.completionSavingVideo(video:error:contextInfo:)) , nil)
                        }
                    }
                }
            }
        }else if self.isUploadVideo{
            if let fileURL = info[UIImagePickerControllerMediaURL] as? URL {
                //self.urlString = fileURL.absoluteString
                let keyUrl = fileURL.pathComponents.last!
                self.urlString = keyUrl
                do{
                    if let videoData = try Data(contentsOf: fileURL) as? Data {
                        print(videoData.count)
                        print("simple upload fired \(Date())")
                        UploadManager.sharedInstance.uploadFile(with: videoData, name: self.urlString, contentType: .Video)
                    }
                }catch{
                    
                }
                
            }
        }else if self.isMultipartUpload{
            
            if let fileURL = info[UIImagePickerControllerMediaURL] as? URL {
                print("fired \(Date())")
//                self.uploadManager.+(_completionHandler: { (task, error) in
//                    DispatchQueue.main.async {
//                        if let error = error {
//                            print("Failed with error: \(error)")
//                            self.statusLabel.text = "Failed"
//                        }
//                        else if(self.progressView.progress != 1.0) {
//                            self.statusLabel.text = "Failed"
//                            print("task.progress...")
//                            NSLog("Error: Failed - Likely due to invalid region / filename",task.progress)
//                        }
//                        else{
//                            print("Success \(Date())")
//                            self.statusLabel.text = "Success"
//                        }
//                    }
//                }, _progressBlock: { (task, progress) in
//                    DispatchQueue.main.async {
//                        self.progressView.progress = Float(progress.fractionCompleted)
//                        self.statusLabel.text = "Uploading..."
//                        print("uploaded--- \(task.progress.completedUnitCount)")
//                        //print("Uploaded...\(task.sessionTask.countOfBytesSent)")
//                    }
//                })
//                self.uploadManager.multipartUploadFile(file: fileURL, _contentType: .Video, continuationTaskBlock: { (error, task) in
//                    if let e = error{
//                        print("error... \(e)")
//                    }
//                    if let t = task{
//                        
//                    } 
//                })
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    var isMultipartUpload: Bool = false
    @IBAction func multipartUploadClicked(_ sender: UIButton) {
        self.isMultipartUpload = true
        self.isTakeVideo = false
        self.isUploadVideo = false
        self.openGallery()
    }
    
    func openGallery(){
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerControllerSourceType.photoLibrary
        controller.mediaTypes = [kUTTypeMovie as! String]
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    
    
    
    @objc func completionSavingVideo(video: String, error: Error,contextInfo: () -> Void){
        print(video)
        if error != nil{
            print(error)            
        }
        isTakeVideo = false
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        isTakeVideo = false
        isUploadVideo = false
    }
}


