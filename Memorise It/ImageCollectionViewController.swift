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

class ImageCollectionViewController: UIViewController
{
    var dataController: DataController!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var customNavBar: UINavigationBar!
    
    fileprivate let imagePickerController = UIImagePickerController()
    fileprivate var allFlashCards: NSFetchedResultsController<FlashCard>!
    fileprivate var selectedCell: IndexPath?
    fileprivate var changes = [NSFetchedResultsChangeType : [IndexPath]]()
    fileprivate weak var detailViewController: UIViewController?
    fileprivate var selectedCells = Set<IndexPath>()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        allFlashCards = dataController.allFlashCards()
        allFlashCards.delegate = self
        if let topItem = customNavBar.topItem {
            topItem.setRightBarButtonItems([editButtonItem, topItem.rightBarButtonItem!], animated: false)
        }
        do { try allFlashCards.performFetch() }
        catch let error as NSError { NSLog("\(error)\n\(error.localizedDescription)") }
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem)
    {
        present(nextVCOnAddButtonTap(), animated: true, completion: nil)
    }
    
    @IBAction func editButtonTapped(_ sender: UIBarButtonItem)
    {
        setEditing(true, animated: true)
    }
    
    @IBAction func longPressRecognised(_ sender: UILongPressGestureRecognizer)
    {
        switch sender.state {
        case .ended:    setEditing(true, animated: true)
        default:        break
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool)
    {
        guard isEditing != editing else { return }
        super.setEditing(editing, animated: animated)
        editing ? startEditing() : endEditing()
    }
}

// MARK: - Dynamic Functions
fileprivate extension ImageCollectionViewController
{
    dynamic func doneTapped(_ sender: UIBarButtonItem)
    {
        setEditing(false, animated: true)
    }
    
    dynamic func deleteSelected(_ sender: UIBarButtonItem)
    {
        
    }
}

// MARK: - Private Functions
fileprivate extension ImageCollectionViewController
{
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
        customNavBar.popItem(animated: true)
        
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
        guard let cell = collectionView.cellForItem(at: indexPath),
            let detailVC = storyboard?.instantiateViewController(
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
        detailViewController = detailVC
        cell.contentView.isHidden = true
    }
    
    func selectItem(at indexPath: IndexPath)
    {
        
    }
}

// MARK: - UICollectionViewDelegate Implementation
extension ImageCollectionViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        isEditing ? expandItem(at: indexPath) : selectItem(at: indexPath)
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
extension ImageCollectionViewController: UINavigationControllerDelegate
{
    
}

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
        if let newCell = collectionView.cellForItem(at: newIndexPath) { newCell.contentView.isHidden = true }
        self.selectedCell = newIndexPath
    }
    
    func dismissContentTo(in view: UIView) -> CGRect
    {
        guard let selectedCell = selectedCell else { return CGRect.zero }
        collectionView.scrollToItem(at: selectedCell, at: .centeredVertically, animated: false)
        let cell = collectionView.cellForItem(at: selectedCell)!
        let origin = cell.convert(CGPoint.zero, to: view)
        return CGRect(origin: origin, size: cell.frame.size)
    }
    
    func didDismissContent()
    {
        guard let vc = detailViewController, let selectedCell = selectedCell,
            let cell = collectionView.cellForItem(at: selectedCell) else {
            return
        }
        vc.willMove(toParentViewController: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParentViewController()
        detailViewController = nil
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
