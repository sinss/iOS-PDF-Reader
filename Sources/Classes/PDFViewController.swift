//  PDFViewController.swift
//  PDFReader
//
//  Created by ALUA KINZHEBAYEVA on 4/19/15.
//  Copyright (c) 2015 AK. All rights reserved.
//

import UIKit

extension PDFViewController {
    /// Initializes a new `PDFViewController`
    ///
    /// - parameter document:            PDF document to be displayed
    /// - parameter title:               title that displays on the navigation bar on the PDFViewController; 
    ///                                  if nil, uses document's filename
    /// - parameter actionButtonImage:   image of the action button; if nil, uses the default action system item image
    /// - parameter actionStyle:         sytle of the action button
    /// - parameter backButton:          button to override the default controller back button
    /// - parameter isThumbnailsEnabled: whether or not the thumbnails bar should be enabled
    /// - parameter startPageIndex:      page index to start on load, defaults to 0; if out of bounds, set to 0
    ///
    /// - returns: a `PDFViewController`
    public class func createNew(with document: PDFDocument, title: String? = nil, actionButtonImage: UIImage? = nil, actionStyle: ActionStyle = .print, backButton: UIBarButtonItem? = nil, isThumbnailsEnabled: Bool = true, startPageIndex: Int = 0) -> PDFViewController {
        let storyboard = UIStoryboard(name: "PDFReader", bundle: Bundle(for: PDFViewController.self))
        let controller = storyboard.instantiateInitialViewController() as! PDFViewController
        controller.document = document
        controller.actionStyle = actionStyle
        
        if let title = title {
            controller.title = title
        } else {
            controller.title = document.fileName
        }
        
        if startPageIndex >= 0 && startPageIndex < document.pageCount {
            controller.currentPageIndex = startPageIndex
        } else {
            controller.currentPageIndex = 0
        }
        
        controller.backButton = backButton
        
        if let actionButtonImage = actionButtonImage {
            controller.actionButton = UIBarButtonItem(image: actionButtonImage, style: .plain, target: controller, action: #selector(actionButtonPressed))
        } else {
            controller.actionButton = UIBarButtonItem(barButtonSystemItem: .action, target: controller, action: #selector(actionButtonPressed))
        }
        controller.isThumbnailsEnabled = isThumbnailsEnabled
        return controller
    }
}

/// Controller that is able to interact and navigate through pages of a `PDFDocument`
public final class PDFViewController: UIViewController {
    /// Action button style
    public enum ActionStyle {
        /// Brings up a print modal allowing user to print current PDF
        case print
        
        /// Brings up an activity sheet to share or open PDF in another app
        case activitySheet
        
        /// Performs a custom action
        case customAction(() -> ())
    }
    
    /// Collection veiw where all the pdf pages are rendered
    @IBOutlet public var collectionView: UICollectionView!
    
    /// Height of the thumbnail bar (used to hide/show)
    @IBOutlet private var thumbnailCollectionControllerHeight: NSLayoutConstraint!
    
    /// Distance between the bottom thumbnail bar with bottom of page (used to hide/show)
    @IBOutlet private var thumbnailCollectionControllerBottom: NSLayoutConstraint!
    
    /// Width of the thumbnail bar (used to resize on rotation events)
    @IBOutlet private var thumbnailCollectionControllerWidth: NSLayoutConstraint!
    
    @IBOutlet weak var pageNoLabel: UILabel!
    
    @IBOutlet weak var pageNoContainer: UIView!
    
    /// PDF document that should be displayed
    private var document: PDFDocument!
    
    private var actionStyle = ActionStyle.print
    
    /// Image used to override the default action button image
    private var actionButtonImage: UIImage?
    
    /// Current page being displayed
    private var currentPageIndex: Int = 0
    
    /// Bottom thumbnail controller
    private var thumbnailCollectionController: PDFThumbnailCollectionViewController?
    
    /// UIBarButtonItem used to override the default action button
    private var actionButton: UIBarButtonItem?
    
    /// Backbutton used to override the default back button
    private var backButton: UIBarButtonItem?
    
    /// Background color to apply to the collectionView.
    public var backgroundColor: UIColor? = .lightGray {
        didSet {
            collectionView?.backgroundColor = backgroundColor
        }
    }
    
    /// Whether or not the thumbnails bar should be enabled
    private var isThumbnailsEnabled = true {
        didSet {
            if thumbnailCollectionControllerHeight == nil {
                _ = view
            }
            if !isThumbnailsEnabled {
                thumbnailCollectionControllerHeight.constant = 0
            }
        }
    }
    
    /// Slides horizontally (from left to right, default) or vertically (from top to bottom)
    public var scrollDirection: UICollectionView.ScrollDirection = .horizontal {
        didSet {
            if collectionView == nil {  // if the user of the controller is trying to change the scrollDiecton before it
                _ = view                // is on the sceen, we need to show it ofscreen to access it's collectionView.
            }
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.scrollDirection = scrollDirection
            }
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    
        collectionView.backgroundColor = backgroundColor
        collectionView.register(PDFPageCollectionViewCell.self, forCellWithReuseIdentifier: "page")
        
        navigationItem.rightBarButtonItem = actionButton
        if let backItem = backButton {
            navigationItem.leftBarButtonItem = backItem
        }
        
        let numberOfPages = CGFloat(document.pageCount)
        let cellSpacing = CGFloat(2.0)
        let totalSpacing = (numberOfPages - 1.0) * cellSpacing
        let thumbnailWidth = (numberOfPages * PDFThumbnailCell.cellSize.width) + totalSpacing
        let width = min(thumbnailWidth, view.bounds.width)
        thumbnailCollectionControllerWidth.constant = width
        thumbnailCollectionControllerHeight.constant = 106
        
        pageNoContainer.layer.cornerRadius = 25
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hidePageNoLabel()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        didSelectIndexPath(IndexPath(row: currentPageIndex, section: 0))
        
        //更新頁數
        pageNoLabel.text = String(format: "%d / %d", (currentPageIndex + 1),  document.pageCount)
    }
    
    override public var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden == true
    }
    
    override public var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    public override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return isThumbnailsEnabled
    }
    
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PDFThumbnailCollectionViewController {
            thumbnailCollectionController = controller
            controller.document = document
            controller.delegate = self
            controller.currentPageIndex = currentPageIndex
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { context in
            let currentIndexPath = IndexPath(row: self.currentPageIndex, section: 0)
            self.collectionView.reloadItems(at: [currentIndexPath])
            self.collectionView.scrollToItem(at: currentIndexPath, at: .centeredHorizontally, animated: false)
            }) { context in
                self.thumbnailCollectionController?.currentPageIndex = self.currentPageIndex
        }
        
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    /// Takes an appropriate action based on the current action style
    @objc func actionButtonPressed() {
        switch actionStyle {
        case .print:
            print()
        case .activitySheet:
            presentActivitySheet()
        case .customAction(let customAction):
            customAction()
        }
    }
    
    /// Presents activity sheet to share or open PDF in another app
    private func presentActivitySheet() {
        let controller = UIActivityViewController(activityItems: [document.fileData], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = actionButton
        present(controller, animated: true, completion: nil)
    }
    
    /// Presents print sheet to print PDF
    private func print() {
//        guard UIPrintInteractionController.isPrintingAvailable else { return }
//        guard UIPrintInteractionController.canPrint(document.fileData) else { return }
//        guard document.password == nil else { return }
//        let printInfo = UIPrintInfo.printInfo()
//        printInfo.duplex = .longEdge
//        printInfo.outputType = .general
//        printInfo.jobName = document.fileName
//
//        let printInteraction = UIPrintInteractionController.shared
//        printInteraction.printInfo = printInfo
//        printInteraction.printingItem = document.fileData
//        printInteraction.showsPageRange = true
//        printInteraction.present(animated: true, completionHandler: nil)
        guard let document = document, let fileUrl = document.fileURL else { return }
        let vc = UIDocumentInteractionController(url: fileUrl)
        if let actionButton = self.actionButton {
            vc.presentOpenInMenu(from: actionButton, animated: true)
        } else {
            vc.presentOpenInMenu(from: CGRect(origin: self.view.center, size: CGSize.zero), in: self.view, animated: true)
        }
    }
}

extension PDFViewController: PDFThumbnailControllerDelegate {
    func didSelectIndexPath(_ indexPath: IndexPath) {
        collectionView.scrollToItem(at: indexPath, at: .left, animated: false)
        thumbnailCollectionController?.currentPageIndex = currentPageIndex
    }
}

extension PDFViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return document.pageCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath) as! PDFPageCollectionViewCell
        cell.setup(indexPath.row, collectionViewBounds: collectionView.bounds, document: document, pageCollectionViewCellDelegate: self)
        return cell
    }
}

extension PDFViewController: PDFPageCollectionViewCellDelegate {
    /// Toggles the hiding/showing of the thumbnail controller
    ///
    /// - parameter shouldHide: whether or not the controller should hide the thumbnail controller
    private func hideThumbnailController(_ shouldHide: Bool) {
        self.thumbnailCollectionControllerBottom.constant = shouldHide ? -self.thumbnailCollectionControllerHeight.constant : 0
    }
    
    func handleSingleTap(_ cell: PDFPageCollectionViewCell, pdfPageView: PDFPageView) {
        //        TODO: 點擊不要關閉上面Bar
        var shouldHide: Bool {
            return (thumbnailCollectionControllerBottom.constant == 0)
        }
        UIView.animate(withDuration: 0.25) {
            self.hideThumbnailController(shouldHide)
            //self.navigationController?.setNavigationBarHidden(shouldHide, animated: true)
        }
    }
}

extension PDFViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 1, height: collectionView.frame.height)
    }
}

extension PDFViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let updatedPageIndex: Int
        if self.scrollDirection == .vertical {
            updatedPageIndex = Int(round(max(scrollView.contentOffset.y, 0) / scrollView.bounds.height))
        } else {
            updatedPageIndex = Int(round(max(scrollView.contentOffset.x, 0) / scrollView.bounds.width))
        }
        
        if updatedPageIndex != currentPageIndex {
            currentPageIndex = updatedPageIndex
            thumbnailCollectionController?.currentPageIndex = currentPageIndex
            
            //更新頁數
            pageNoLabel.text = String(format: "%d / %d", (currentPageIndex + 1),  document.pageCount)
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        showPageNoLabel()
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hidePageNoLabel()
    }
}

//頁數Label的顯示控制
extension PDFViewController {
    fileprivate func showPageNoLabel() {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.15, delay: 0, options: .curveLinear, animations: {
            self.pageNoContainer.alpha = 1
        }, completion: nil)
    }
    
    fileprivate func hidePageNoLabel() {
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.15, delay: 0, options: .curveLinear, animations: {
            self.pageNoContainer.alpha = 0
        }, completion: nil)
    }
}
