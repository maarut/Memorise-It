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
import AVFoundation

fileprivate let kImageCollectionViewControllerErrorDomain = "net.maarut.Memorise-It.ImageCollectionViewController"

class ImageCollectionViewController: UIViewController
{
    var dataController: DataController!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var customNavBar: UINavigationBar!
    
    fileprivate let imagePickerController = UIImagePickerController()
    fileprivate var allFlashCards: NSFetchedResultsController<FlashCard>!
    fileprivate var selectedCell: IndexPath?
    fileprivate var audioPlayer: AVAudioPlayer?
    fileprivate weak var tapGestureRecogniser: UITapGestureRecognizer?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        allFlashCards = dataController.allFlashCards()
        allFlashCards.delegate = self
        do { try allFlashCards.performFetch() }
        catch let error as NSError { NSLog("\(error)\n\(error.localizedDescription)") }
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem)
    {
        present(nextVCOnAddButtonTap(), animated: true, completion: nil)
    }
}

// MARK: - Private Functions
fileprivate extension ImageCollectionViewController
{
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
    
    func determineDirection(_ point: CGPoint) -> UISwipeGestureRecognizerDirection?
    {
        switch (point.x, point.y) {
        case let (x, y) where x < y && y <= 0:  return UISwipeGestureRecognizerDirection.left
        case let (x, y) where x > y && y >= 0:  return UISwipeGestureRecognizerDirection.right
        case let (x, y) where y < x && x <= 0:  return UISwipeGestureRecognizerDirection.up
        case let (x, y) where y > x && x >= 0:  return UISwipeGestureRecognizerDirection.down
        default:                                return nil
        }
        
    }
    
    func retrieveCells(for indexes: (previous: IndexPath, next: IndexPath)) ->
        (previous: UICollectionViewCell, current: UICollectionViewCell, next: UICollectionViewCell)
    {
        collectionView.scrollToItem(at: indexes.previous, at: .centeredVertically, animated: false)
        let previousCell = collectionView.cellForItem(at: indexes.previous)!
        collectionView.scrollToItem(at: selectedCell!, at: .centeredVertically, animated: false)
        let currentCell = collectionView.cellForItem(at: selectedCell!)!
        collectionView.scrollToItem(at: indexes.next, at: .centeredVertically, animated: false)
        let nextCell = collectionView.cellForItem(at: indexes.next)!
        return (previousCell, currentCell, nextCell)
    }
    
    func adjacentCells(to current: IndexPath) -> (previous: IndexPath, next: IndexPath)
    {
        var adjacentRows = (previous: current.row - 1, next: current.row + 1)
        if adjacentRows.next >= (allFlashCards.fetchedObjects?.count ?? 0) { adjacentRows.next = 0 }
        if adjacentRows.previous < 0 { adjacentRows.previous = (allFlashCards.fetchedObjects?.count ?? 1) - 1 }
        return (IndexPath(row: adjacentRows.previous, section: current.section),
            IndexPath(row: adjacentRows.next, section: current.section))
    }
    
    dynamic func panToNextImage(using sender: UIPanGestureRecognizer)
    {
        guard let expandableView = sender.view, let selectedCell = selectedCell else { return }
        let translation = sender.translation(in: self.view)
        let adjacentIndexPaths = adjacentCells(to: selectedCell)
        let cells = retrieveCells(for: adjacentIndexPaths)
        switch sender.state {
        case .changed:
            if expandableView.subviews.count == 1 {
                let prevImage = UIImageView(frame: expandableView.frame)
                prevImage.frame.origin.x -= (prevImage.frame.width + 44)
                prevImage.contentMode = .scaleAspectFit
                prevImage.image = (cells.previous.viewWithTag(1) as! UIImageView).image
                let nextImage = UIImageView(frame: expandableView.frame)
                nextImage.frame.origin.x += (nextImage.frame.width + 44)
                nextImage.contentMode = .scaleAspectFit
                nextImage.image = (cells.next.viewWithTag(1) as! UIImageView).image
                expandableView.addSubview(prevImage)
                expandableView.addSubview(nextImage)
            }
            for view in expandableView.subviews {
                view.transform = CGAffineTransform(translationX: translation.x, y: 0)
            }
        case .ended:
            let width = expandableView.frame.width
            let newOriginMagnitude = (width / 2) < abs(translation.x) ? (width + 44) : 0
            let newOriginVector = translation.x > 0 ? newOriginMagnitude : -newOriginMagnitude
            UIView.animate(withDuration: 0.3, animations: {
                for view in expandableView.subviews {
                    view.transform = CGAffineTransform(translationX: newOriginVector, y: 0)
                }
            }, completion: { _ in
                for view in expandableView.subviews {
                    view.transform = CGAffineTransform.identity
                    view.frame.origin.x += newOriginVector
                    if !expandableView.point(inside: view.convert(view.center, to: expandableView), with: nil) {
                        view.removeFromSuperview()
                    }
                }
            })
            revertTargetAction(for: sender)
            switch newOriginVector {
            case let x where x < 0:
                cells.current.contentView.isHidden = false
                self.selectedCell = adjacentIndexPaths.next
                cells.next.contentView.isHidden = true
                break
            case let x where x > 0:
                cells.current.contentView.isHidden = false
                self.selectedCell = adjacentIndexPaths.previous
                cells.previous.contentView.isHidden = true
                break
            default:
                return
            }
            break
        default:
            return
        }
    }
    
    dynamic func panToDismiss(using sender: UIPanGestureRecognizer)
    {
        guard let expandableView = sender.view, let imageView = expandableView.subviews.first else { return }
        let translation = sender.translation(in: self.view)
        let magnitude = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
        switch sender.state {
        case .changed:
            let center = CGPoint(x: expandableView.center.x + translation.x, y: expandableView.center.y + translation.y)
            imageView.center = center
            imageView.frame.size = CGSize(width: expandableView.frame.width * max(1.0 - magnitude / 1000, 0.8),
                height: expandableView.frame.height * max(1.0 - magnitude / 1000, 0.8))
            expandableView.backgroundColor = UIColor(white: 0, alpha: 1.0 - magnitude / 500.0)
            break
        case .ended:
            if magnitude > 25 {
                dismiss(view: expandableView, resizingView: imageView)
            }
            else {
                UIView.animate(withDuration: 0.3) {
                    expandableView.backgroundColor = UIColor.black
                    imageView.frame = expandableView.frame
                }
            }
            revertTargetAction(for: sender)
            break
        default:
            return
        }
    }
    
    func revertTargetAction(for gesture: UIPanGestureRecognizer)
    {
        gesture.removeTarget(self, action: nil)
        gesture.addTarget(self, action: #selector(panGestureRecognised(_:)))
    }
    
    dynamic func panGestureRecognised(_ sender: UIPanGestureRecognizer)
    {
        guard let direction = determineDirection(sender.translation(in: self.view)) else { return }
        let selector: Selector
        switch direction {
        case UISwipeGestureRecognizerDirection.up,
             UISwipeGestureRecognizerDirection.down:    selector = #selector(panToDismiss(using:))
        case UISwipeGestureRecognizerDirection.left,
             UISwipeGestureRecognizerDirection.right:   selector = #selector(panToNextImage(using:))
        default:                                        return
        }
        sender.removeTarget(self, action: nil)
        sender.addTarget(self, action: selector)
    }
    
    dynamic func tapGestureRecognised(_ sender: UITapGestureRecognizer)
    {
        guard let selectedCell = selectedCell, let card = allFlashCards.fetchedObjects?[selectedCell.row] else {
            return
        }
        do {
            if let audioURLString = card.audioFileName {
                let audioURL = try pathToAudioFile(audioURLString)
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.delegate = self
                sender.removeTarget(self, action: #selector(tapGestureRecognised(_:)))
                sender.addTarget(self, action: #selector(stopPlayback(_:)))
                audioPlayer?.currentTime = 0.0
                audioPlayer?.play()
            }
        }
        catch let error as NSError {
            NSLog("\(error.description)\n\(error.localizedDescription)")
        }
    }
    
    func dismiss(view: UIView, resizingView: UIView)
    {
        guard let selectedCell = selectedCell, let cell = collectionView.cellForItem(at: selectedCell) else { return }
        UIView.animate(withDuration: 0.3, animations: {
            view.backgroundColor = UIColor.clear
            let newOrigin = cell.convert(CGPoint.zero, to: view)
            resizingView.frame = CGRect(x: newOrigin.x, y: newOrigin.y,
                width: cell.frame.width, height: cell.frame.height)
        }, completion: { _ in
            cell.contentView.isHidden = false
            view.removeFromSuperview()
        })
        tapGestureRecogniser = nil
        audioPlayer = nil
    }
    
    func pathToAudioFile(_ fileName: String) throws -> URL
    {
        if let directory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first {
            return directory.appendingPathComponent(fileName)
        }
        throw NSError(domain: kImageCollectionViewControllerErrorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey :"Could not get a path to the Documents directory for the current user",
            ])
    }
    
    dynamic func stopPlayback(_ sender: UITapGestureRecognizer)
    {
        sender.removeTarget(self, action: #selector(stopPlayback(_:)))
        sender.addTarget(self, action: #selector(tapGestureRecognised(_:)))
        audioPlayer?.stop()
    }
}

// MARK: - UICollectionViewDelegate Implementation
extension ImageCollectionViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        let expandableView = UIView()
        let imageView = UIImageView(image: (cell.viewWithTag(1) as! UIImageView).image)
        expandableView.frame = cell.frame
        expandableView.frame.origin = cell.convert(CGPoint.zero, to: view)
        imageView.frame = CGRect(x: 0, y: 0, width: expandableView.frame.width, height: expandableView.frame.height)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        expandableView.translatesAutoresizingMaskIntoConstraints = false
        expandableView.addSubview(imageView)
        imageView.bottomAnchor.constraint(equalTo: expandableView.bottomAnchor).isActive = true
        imageView.topAnchor.constraint(equalTo: expandableView.topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: expandableView.leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: expandableView.trailingAnchor).isActive = true
        view.addSubview(expandableView)
        expandableView.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognised(_:))))
        let tapGestureRecogniser = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognised(_:)))
        expandableView.addGestureRecognizer(tapGestureRecogniser)
        cell.contentView.isHidden = true
        UIView.animate(withDuration: 0.3) {
            expandableView.backgroundColor = UIColor.black
            expandableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            expandableView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            expandableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
            expandableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
            self.view.layoutIfNeeded()
        }
        selectedCell = indexPath
        self.tapGestureRecogniser = tapGestureRecogniser
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
    
}

// MARK: - UINavigationBarDelegate Implementation
extension ImageCollectionViewController: UINavigationBarDelegate
{
    func position(for bar: UIBarPositioning) -> UIBarPosition
    {
        return .topAttached
    }
}

// MARK: - AVAudioPlayerDelegate Implementation
extension ImageCollectionViewController: AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        guard let tapGestureRecogniser = tapGestureRecogniser else { return }
        stopPlayback(tapGestureRecogniser)
    }
}
