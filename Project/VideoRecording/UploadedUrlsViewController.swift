//
//  UploadedUrlsViewController.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 16/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import UIKit

class UploadedUrlsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    let cellReuseIdentifier = "deleteCellIdentifier"
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(UINib(nibName: "DeleteUrlTableViewCell", bundle: nil), forCellReuseIdentifier: cellReuseIdentifier)
        // Do any additional setup after loading the view.
        UploadManager.sharedInstance.callbackDeleteResponse = {[weak self](keyUrlString, error) in
            guard let slf = self else {
                return
            }
            DispatchQueue.main.async {
                slf.tableView.reloadData()
            }
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension UploadedUrlsViewController: UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UploadManager.sharedInstance.uploadedKeyUrlsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as! DeleteUrlTableViewCell
        
        let text = UploadManager.sharedInstance.uploadedKeyUrlsArray[indexPath.row]
        
        cell.urlLabel.text = text
        cell.deleteUrlDelegate = self
        return cell
    }
}

extension UploadedUrlsViewController: DeleteUrlDelegate{
    func deleteClicked(keyUrl: String) {
        UploadManager.sharedInstance.deleteFile(with: keyUrl)
    }
}
extension UploadedUrlsViewController: UITableViewDelegate{
    
}
