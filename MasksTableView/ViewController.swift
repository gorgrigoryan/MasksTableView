//
//  ViewController.swift
//  MasksTableView
//
//  Created by Gor Grigoryan on 10/31/19.
//  Copyright © 2019 Narek Safaryan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableData = [Mask]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        parseJSON()
        configureTableView()
    }
    
    func configureTableView() {
        let tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.register(CustomCell.self, forCellReuseIdentifier: "cellId")
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
    }
    
    func parseJSON() {
        if let path = Bundle.main.path(forResource: "mask", ofType: "json") {
            let url = URL(fileURLWithPath: path)
            
            do {
                let data = try Data(contentsOf: url)
                let arrayOfDictionaries = try JSONSerialization.jsonObject(with: data, options: []) as! [[String : String]]
                for dict in arrayOfDictionaries {
                    let mask = Mask(icon_url: dict["icon_url"]!,
                                    loc_key: dict["loc_key"]!,
                                    resource_id: dict["resource_id"]!,
                                    blendMode: dict["blendMode"]!,
                                    orientation: dict["orientation"]!)
                    tableData.append(mask)
                }
            } catch {
                print(error)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellId") as! CustomCell
        config(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func config(cell: CustomCell, indexPath: IndexPath) {
        let mask = tableData[indexPath.row]
        
        let url = mask.icon_url
        cell.tag = indexPath.row
        let loader = ImageLoader(url: url) { [weak cell] (image) in
            if let cell = cell, cell.tag == indexPath.row {
                cell.imageView?.image = image
                cell.textLabel?.text = mask.loc_key
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
            url == self.urlString else {
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
        DispatchQueue.global().async {
            let url = URL(string: urlString)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            
            let imageName = (url!.deletingPathExtension()).lastPathComponent + ".jpg"
            let imagePath = documentsDirectory!.appendingPathComponent(imageName)
            var image = UIImage()
            
            if FileManager.default.fileExists(atPath: imagePath.path) {
                image = UIImage(contentsOfFile: imagePath.path)!
            } else {
                let data = try? Data(contentsOf: URL(string: urlString)!)
                if let data = data {
                    image = UIImage(data: data)!
                    try? data.write(to: imagePath)
                }
            }
            
            DispatchQueue.main.async {
                var info = Dictionary() as [String : Any]
                info["image"] = image
                info["url"] = urlString
                NotificationCenter.default.post(name: NSNotification.Name.init("download-success"),
                                                object: nil,
                                                userInfo: info)
            }
        }
    }
}
