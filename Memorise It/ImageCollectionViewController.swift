//
//  ViewController.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 02/12/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import MobileCoreServices
import CoreData
import GoogleMobileAds

private let kPortraitAdViewHeight: CGFloat = 50.0
private let kLandscapeAdViewHeight: CGFloat = 32.0

class ImageCollectionViewController: UIViewController
{
    var dataController: DataController!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var customNavBar: UINavigationBar!
    @IBOutlet weak var adViewToCollectionViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var adView: GADBannerView!
    
    fileprivate let imagePickerController = UIImagePickerController()
    fileprivate var allFlashCards: NSFetchedResultsController<FlashCard>!
    fileprivate var selectedCell: IndexPath?
    fileprivate var changes = [NSFetchedResultsChangeType : [IndexPath]]()
    fileprivate weak var detailViewController: UIViewController?
    fileprivate var selectedCells = Set<IndexPath>()
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        adView.delegate = self
        adView.adUnitID = kAdMobAdUnitId
        adView.rootViewController = self
        adView.adSize = kGADAdSizeBanner
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        allFlashCards = dataController.allFlashCards()
        allFlashCards.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)),
            name: kMemoriseItDidBecomeActiveNotification, object: nil)
        if let topItem = customNavBar.topItem {
            topItem.setRightBarButtonItems([editButtonItem, topItem.rightBarButtonItem!], animated: false)
        }
        do { try allFlashCards.performFetch() }
        catch let error as NSError { NSLog("\(error)\n\(error.localizedDescription)") }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool)
    {
        guard isEditing != editing else { return }
        super.setEditing(editing, animated: animated)
        editing ? startEditing() : endEditing()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        presentAds()
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem)
    {
        present(nextVCOnAddButtonTap(), animated: true, completion: nil)
    }
    
    @IBAction func longPressRecognised(_ sender: UILongPressGestureRecognizer)
    {
        switch sender.state {
        case .ended:    setEditing(true, animated: true)
        default:        break
        }
    }
    
    @IBAction func playTapped(_ sender: UIBarButtonItem)
    {
        if let nextVC = storyboard?.instantiateViewController(withIdentifier: "continuousPlayViewController")
            as? ContinuousPlayViewController {
            nextVC.flashCards = allFlashCards.fetchedObjects ?? []
            present(nextVC, animated: true, completion: nil)
        }
    }
    
}

// MARK: - Dynamic Functions
fileprivate extension ImageCollectionViewController
{
    @objc func applicationDidBecomeActive(_ notification: Notification)
    {
        let selector = isEditing ?
            #selector(UICollectionViewCell.startWobbling) :
            #selector(UICollectionViewCell.endWobble)
        DispatchQueue.main.async { [weak self] in
            guard let visibleCells = self?.collectionView.visibleCells else { return }
            for cell in visibleCells { cell.perform(selector) }
        }
    }
    
    @objc func editButtonTapped(_ sender: UIBarButtonItem)
    {
        setEditing(true, animated: true)
    }
    
    @objc func doneTapped(_ sender: UIBarButtonItem)
    {
        setEditing(false, animated: true)
    }
    
    @objc func deleteSelected(_ sender: UIBarButtonItem)
    {
        let flashCards = selectedCells.flatMap { allFlashCards.fetchedObjects?[$0.row] }
        dataController.delete(flashCards)
        selectedCells = []
    }
}

// MARK: - Private Functions
fileprivate extension ImageCollectionViewController
{
    func presentAds()
    {
        let request = GADRequest()
        request.testDevices = MCConstants.adMobTestDevices()
        adView.load(request)
    }
    
    func startEditing()
    {
        let title = customNavBar.topItem?.title
        let item = UINavigationItem(title: "")
        item.setRightBarButton(
            editButtonItem,
            animated: false)
        item.setLeftBarButton(
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelected(_:))),
            animated: false)
        UIView.animate(withDuration: 0.3, animations: {
            self.customNavBar.topItem?.title = nil
            self.customNavBar.barTintColor = UIColor.green
            self.customNavBar.tintColor = UIColor.white
            self.customNavBar.layoutIfNeeded()
        }, completion: { _ in
            self.customNavBar.backItem?.title = title
        })
        customNavBar.pushItem(item, animated: true)
        for cell in collectionView.visibleCells { cell.startWobbling() }
    }
    
    func endEditing()
    {
        let title = customNavBar.backItem?.title
        customNavBar.backItem?.title = nil
        UIView.animate(withDuration: 0.3, animations: {
            self.customNavBar.barTintColor = nil
            self.customNavBar.tintColor = nil
        }, completion: { _ in
            self.customNavBar.topItem?.title = title
        })
        for ip in selectedCells {
            let cell = collectionView.cellForItem(at: ip)!
            cell.layer.borderWidth = 0.0
        }
        selectedCells = []
        customNavBar.popItem(animated: true)
        for cell in collectionView.visibleCells { cell.endWobble() }
        
    }
    
    func nextVCOnAddButtonTap() -> UIViewController
    {
        let sourceTypes = availableSourceTypes()
        if sourceTypes.count < 2 { return configuredImagePickerController(sourceTypes) }
        
        return alertController(for: sourceTypes)
    }
    
    func configuredImagePickerController(_ sourceTypes: [UIImagePickerControllerSourceType]) -> UIImagePickerController
    {
        if sourceTypes.count == 1 {
            switch sourceTypes[0] {
            case .camera:           selectCamera(for: imagePickerController)
            case .savedPhotosAlbum: selectCameraRoll(for: imagePickerController)
            case .photoLibrary:     selectLibrary(for: imagePickerController)
            }
        }
        return imagePickerController
    }
    
    func alertController(for sourceTypes: [UIImagePickerControllerSourceType]) -> UIAlertController
    {
        let alertVC = UIAlertController(title: "Image Source",
            message: "Please select whether you would like to choose an image from the camera or the photo library.",
            preferredStyle: .actionSheet)
        for action in buttons(for: sourceTypes) { alertVC.addAction(action) }
        return alertVC
    }
    
    func buttons(for sourceTypes: [UIImagePickerControllerSourceType]) -> [UIAlertAction]
    {
        var buttons = [UIAlertAction]()
        for sourceType in sourceTypes {
            switch sourceType {
            case .camera:
                buttons.append(UIAlertAction(title: "Take Picture", style: .default, handler: { _ in
                    self.selectCamera(for: self.imagePickerController)
                    self.present(self.imagePickerController, animated: true, completion: nil)
                }))
                break
            case .photoLibrary:
                buttons.append(UIAlertAction(title: "Library", style: .default, handler: { _ in
                    self.selectLibrary(for: self.imagePickerController)
                    self.present(self.imagePickerController, animated: true, completion: nil)
                }))
                break
            case .savedPhotosAlbum:
                buttons.append(UIAlertAction(title: "Camera Roll", style: .default, handler: { _ in
                    self.selectCameraRoll(for: self.imagePickerController)
                    self.present(self.imagePickerController, animated: true, completion: nil)
                }))
                break
            }
        }
        buttons.append(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return buttons
    }
    
    func selectCameraRoll(for imagePickerController: UIImagePickerController)
    {
        imagePickerController.sourceType = .savedPhotosAlbum
        imagePickerController.allowsEditing = false
    }
    
    func selectCamera(for imagePickerController: UIImagePickerController)
    {
        imagePickerController.sourceType = .camera
        imagePickerController.cameraDevice = .rear
        imagePickerController.allowsEditing = true
    }
    
    func selectLibrary(for imagePickerController: UIImagePickerController)
    {
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.allowsEditing = true
    }
    
    func availableSourceTypes() -> [UIImagePickerControllerSourceType]
    {
        var sources = [UIImagePickerControllerSourceType]()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { sources.append(.camera) }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) { sources.append(.photoLibrary) }
        else if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) { sources.append(.savedPhotosAlbum) }
        return sources.sorted(by: { $0.rawValue < $1.rawValue } )
    }
    
    func adjacentCells(to current: IndexPath) -> (previous: IndexPath, next: IndexPath)
    {
        var adjacentRows = (previous: current.row - 1, next: current.row + 1)
        if adjacentRows.next >= (allFlashCards.fetchedObjects?.count ?? 0) { adjacentRows.next = 0 }
        if adjacentRows.previous < 0 { adjacentRows.previous = (allFlashCards.fetchedObjects?.count ?? 1) - 1 }
        return (IndexPath(row: adjacentRows.previous, section: current.section),
            IndexPath(row: adjacentRows.next, section: current.section))
    }
    
    func expandItem(at indexPath: IndexPath)
    {
        guard let detailVC = storyboard?.instantiateViewController(
            withIdentifier: "flashCardDetailViewController") as? PlayFlashCardViewController else {
            return
        }
        selectedCell = indexPath
        detailVC.delegate = self
        addChildViewController(detailVC)
        view.addSubview(detailVC.view)
        detailVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        detailVC.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        detailVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        detailVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        detailVC.didMove(toParentViewController: self)
        detailVC.view.layoutIfNeeded()
        detailViewController = detailVC
    }
    
    func selectItem(at indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        if selectedCells.contains(indexPath) {
            selectedCells.remove(indexPath)
            cell.layer.borderWidth = 0.0
        }
        else {
            selectedCells.insert(indexPath)
            cell.layer.borderWidth = 2.0
        }
    }
}

// MARK: - UICollectionViewDelegate Implementation
extension ImageCollectionViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        isEditing ? selectItem(at: indexPath) : expandItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath)
    {
        isEditing ? cell.startWobbling() : cell.endWobble()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath)
    {
        cell.endWobble()
    }
    
}

// MARK: - UICollectionViewDataSource Implementation
extension ImageCollectionViewController: UICollectionViewDataSource
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return allFlashCards.fetchedObjects?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let view = collectionView.dequeueReusableCell(withReuseIdentifier: "image", for: indexPath)
        if let imageView = view.viewWithTag(1) as? UIImageView,
            let imageData = allFlashCards.fetchedObjects?[indexPath.row].image {
            imageView.image = UIImage(data: imageData as Data)
        }
        view.layer.borderColor = UIColor.green.cgColor
        view.contentView.isHidden = indexPath == selectedCell
        if isEditing { view.startWobbling() }
        return view
    }
}

// MARK: - UIImagePickerControllerDelegate Implementation
extension ImageCollectionViewController: UIImagePickerControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        if let nextVC = storyboard?.instantiateViewController(
            withIdentifier: "addSoundViewController") as? AddSoundViewController {
            nextVC.dataController = dataController
            if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
                nextVC.image = editedImage
            }
            else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                nextVC.image = originalImage
            }
            picker.isNavigationBarHidden = false
            picker.pushViewController(nextVC, animated: true)
        }
    }
}

// MARK: - UINavigationControllerDelegate Implementation
extension ImageCollectionViewController: UINavigationControllerDelegate { }

// MARK: - NSFetchResultsControllerDelegate Implementation
extension ImageCollectionViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        collectionView.performBatchUpdates({
            for (type, indexPaths) in self.changes {
                switch type {
                case .insert:   self.collectionView.insertItems(at: indexPaths)
                case .delete:   self.collectionView.deleteItems(at: indexPaths)
                default:        break
                }
            }
        }, completion: { _ in self.changes = [:] })
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any,
        at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type {
        case .insert:
            if changes[.insert] == nil { changes[.insert] = [] }
            changes[.insert]!.append(newIndexPath!)
            break
        case .delete:
            if changes[.delete] == nil { changes[.delete] = [] }
            changes[.delete]!.append(indexPath!)
            break
        default:
            break
        }
    }
}

// MARK: - UINavigationBarDelegate Implementation
extension ImageCollectionViewController: UINavigationBarDelegate
{
    func position(for bar: UIBarPositioning) -> UIBarPosition
    {
        return .topAttached
    }
}

// MARK: - PlayFlashCardViewControllerDelegate Implementation
extension ImageCollectionViewController: PlayFlashCardViewControllerDelegate
{
    func willZoomContent()
    {
        guard let selectedCell = selectedCell, let cell = collectionView.cellForItem(at: selectedCell) else { return }
        cell.contentView.isHidden = true
    }
    
    func didPan(to position: Position)
    {
        guard let selectedCell = selectedCell else { return }
        let newIndexPath: IndexPath
        switch position {
        case .next:     newIndexPath = adjacentCells(to: selectedCell).next
        case .previous: newIndexPath = adjacentCells(to: selectedCell).previous
        default:        return
        }
        if let currentCell = collectionView.cellForItem(at: selectedCell) { currentCell.contentView.isHidden = false }
        collectionView.scrollToItem(at: newIndexPath, at: .centeredVertically, animated: false)
        self.selectedCell = newIndexPath
        UIView.animate(withDuration: 0, animations: { }, completion: { _ in
            if let newCell = self.collectionView.cellForItem(at: newIndexPath) { newCell.contentView.isHidden = true }
        })
    }
    
    func dismissContentTo(in view: UIView) -> CGRect
    {
        guard let selectedCell = selectedCell, let cell = collectionView.cellForItem(at: selectedCell) else {
            return CGRect.zero
        }
        let origin = cell.convert(CGPoint.zero, to: view)
        collectionView.scrollToItem(at: selectedCell, at: .bottom, animated: true)
        return CGRect(origin: origin, size: cell.frame.size)
    }
    
    func didDismissContent()
    {
        defer {
            detailViewController?.willMove(toParentViewController: nil)
            detailViewController?.view.removeFromSuperview()
            detailViewController?.removeFromParentViewController()
            detailViewController = nil
        }
        guard let selectedCell = selectedCell, let cell = collectionView.cellForItem(at: selectedCell) else {
            return
        }
        self.selectedCell = nil
        cell.contentView.isHidden = false
    }
    
    func flashCard(for position: Position) -> FlashCard
    {
        guard let selectedCell = selectedCell else { return allFlashCards.fetchedObjects!.first! }
        let adjacentPaths = adjacentCells(to: selectedCell)
        switch position {
        case .previous: return allFlashCards.fetchedObjects![adjacentPaths.previous.row]
        case .current:  return allFlashCards.fetchedObjects![selectedCell.row]
        case .next:     return allFlashCards.fetchedObjects![adjacentPaths.next.row]
        }
    }
    
    func zoomContentFrom(in view: UIView) -> CGRect
    {
        guard let selectedCell = selectedCell,
            let cell = collectionView.cellForItem(at: selectedCell) else {
            return CGRect.zero
        }
        let origin = cell.convert(CGPoint.zero, to: view)
        return CGRect(origin: origin, size: cell.frame.size)
    }
}

// MARK: - GADBannerViewDelegate Implementation
extension ImageCollectionViewController: GADBannerViewDelegate
{
    func adViewDidReceiveAd(_ bannerView: GADBannerView)
    {
        UIView.animate(withDuration: 0.3) {
            self.adViewToCollectionViewConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError)
    {
        NSLog("\(error.description)\n\(error.localizedDescription)")
    }
}

// MARK: - Private Functions on UICollectionViewCell
// Code found from http://stackoverflow.com/a/15842191/7140876. Some values adjusted to get a better animation.
fileprivate extension UICollectionViewCell
{
    @objc func endWobble()
    {
        layer.removeAllAnimations()
    }
    
    @objc func startWobbling()
    {
        layer.add(rotationAnimation(), forKey: "rotation")
        layer.add(bounceAnimation(), forKey: "bounce")
        layer.add(translationAnimation(), forKey: "translation")
    }
}

fileprivate func rotationAnimation() -> CAAnimation
{
    let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
    animation.values = [0.02, -0.02]
    animation.autoreverses = true
    animation.duration = animationDuration(startPoint: 0.13, variance: 0.025)
    animation.repeatCount = Float.greatestFiniteMagnitude
    return animation
}

fileprivate func bounceAnimation() -> CAAnimation
{
    let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
    animation.values = [0.3, -0.3]
    animation.autoreverses = true
    animation.duration = animationDuration(startPoint: 0.13, variance: 0.025)
    animation.repeatCount = Float.greatestFiniteMagnitude
    return animation
}

fileprivate func translationAnimation() -> CAAnimation
{
    let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
    animation.values = [0.3, -0.3]
    animation.autoreverses = true
    animation.duration = animationDuration(startPoint: 0.13, variance: 0.025)
    animation.repeatCount = Float.greatestFiniteMagnitude
    return animation
}

fileprivate func animationDuration(startPoint: CFTimeInterval, variance: CFTimeInterval) -> CFTimeInterval
{
    let random = CFTimeInterval(Int(arc4random_uniform(1000)) - 500) / 500.0
    return startPoint + variance * random
}
