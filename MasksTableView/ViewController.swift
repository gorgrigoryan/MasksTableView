//
//  ViewController.swift
//  MasksTableView
//
//  Created by Gor Grigoryan on 10/31/19.
//  Copyright © 2019 Gor Grigoryan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableData:Array<Dictionary<String, String>> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //JSONSerialization.jsonObject(with: <#T##Data#>, options: <#T##JSONSerialization.ReadingOptions#>)
        
        
        let tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.register(CustomCell.self, forCellReuseIdentifier: "cellId")
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellId") as! CustomCell
        
        config(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func config(cell:CustomCell, indexPath:IndexPath) {
        let object = tableData[indexPath.row]
        cell.textLabel?.text = object["title"]!
        
        let url:String = object["url"]!
        cell.tag = indexPath.row
        let loader = ImageLoader(url: url) { [weak cell] (image) in
            
            if let cell = cell, cell.tag == indexPath.row {
                cell.imageView?.image = image
            }
            
        }
        
        cell.setImageLoader(loader: loader)
    }
}

class CustomCell: UITableViewCell {
    var imageLoader:ImageLoader?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setImageLoader(loader:ImageLoader) {
        imageLoader?.cancel()
        self.imageView?.image = nil
        
        imageLoader = loader
        imageLoader?.load()
    }
}

class ImageLoader {
    var urlString:String!
    var completionBlock: ((UIImage?) -> Void)?
    
    init(url:String, completion:@escaping (UIImage?) -> Void) {
        self.urlString = url
        self.completionBlock = completion
    }
    
    func load() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(downloadComplete),
                                               name: NSNotification.Name.init("download-success"),
                                               object: nil)
        Downloader.shared().download(urlString: self.urlString)
        
    }
    
    @objc func downloadComplete(note:NSNotification) {
        guard let info = note.userInfo,
            let url = info["url"] as? String,
            url != self.urlString else {
            return
        }
                
        let img:UIImage? = info["image"] as? UIImage
        
        if let block = self.completionBlock {
            block(img)
        }
    }
    
    func cancel() {
        NotificationCenter.default.removeObserver(self)
        self.completionBlock = nil
    }
}


class Downloader {
    static let imageDownloader = Downloader()
    
    static func shared() -> Downloader{
        return imageDownloader
    }
    
    func download(urlString:String) {
        //keep downloading urls and check for double or more download
        DispatchQueue.global().async {
            //check in file sytem and create from file (data), otherwise download from url
            
            let data = try! Data(contentsOf: URL(string: urlString)!)
            
            //Write into file system (documents directory)
            
            let image = UIImage(data: data)
            
            DispatchQueue.main.async {
                var info = Dictionary() as Dictionary<String, Any>
                info["image"] = image
                info["url"] = urlString
                NotificationCenter.default.post(name: NSNotification.Name.init("download-success"),
                                                object: nil,
                                                userInfo: info)
            }
        }
    }
}
