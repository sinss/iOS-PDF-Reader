//
//  PDFThumbnailCollectionViewController.swift
//  PDFReader
//
//  Created by Ricardo Nunez on 7/9/16.
//  Copyright © 2016 AK. All rights reserved.
//

import UIKit

/// Delegate that is informed of important interaction events with the current thumbnail collection view
protocol PDFThumbnailControllerDelegate: class {
    /// User has tapped on thumbnail
    func didSelectIndexPath(_ indexPath: IndexPath)
}

/// Bottom collection of thumbnails that the user can interact with
internal final class PDFThumbnailCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    /// Current document being displayed
    var document: PDFDocument!
    
    /// Current page index being displayed
    var currentPageIndex: Int = 0 {
        didSet {
            guard let collectionView = collectionView else { return }
            guard let pageImages = pageImages else { return }
            guard pageImages.count > 0 else { return }
            let curentPageIndexPath = IndexPath(row: currentPageIndex, section: 0)
            if !collectionView.indexPathsForVisibleItems.contains(curentPageIndexPath) {
                collectionView.scrollToItem(at: curentPageIndexPath, at: .centeredHorizontally, animated: true)
            }
            collectionView.reloadData()
        }
    }
    
    /// Calls actions when certain cells have been interacted with
    weak var delegate: PDFThumbnailControllerDelegate?
    
    /// Small thumbnail image representations of the pdf pages
    private var pageImages: [UIImage]? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = UIColor.clear
        DispatchQueue.global(qos: .background).async {
            self.document.allPageImages(callback: { (images) in
                DispatchQueue.main.async {
                    self.pageImages = images
                }
            })
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pageImages?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PDFThumbnailCell
        cell.backgroundColor = UIColor.clear
        cell.imageView?.backgroundColor = UIColor.clear
        cell.imageView?.image = pageImages?[indexPath.row]
        if currentPageIndex == indexPath.row {
            cell.layer.borderColor = UIColor.red.cgColor
            cell.layer.borderWidth = 3
        } else {
            cell.layer.borderWidth = 0
        }
//        cell.alpha = currentPageIndex == indexPath.row ? 1 : 0.2
        
        return cell
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return PDFThumbnailCell.cellSize
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 15
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectIndexPath(indexPath)
    }
}
