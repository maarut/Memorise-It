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
    
    fileprivate let imagePickerController = UIImagePickerController()
    fileprivate var allFlashCards: NSFetchedResultsController<FlashCard>!
    
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        switch segue.identifier ?? "" {
        case "playSegue":
            if let nextVC = segue.destination as? PlayFlashCardViewController,
                let flashCard = sender as? FlashCard {
                nextVC.flashCard = flashCard
            }
            break
        default:
            break
        }
    }
    
    @IBAction func addButtonTapped(_ sender: Any)
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
}

// MARK: - UICollectionViewDelegate Implementation
extension ImageCollectionViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if let card = allFlashCards.fetchedObjects?[indexPath.row] {
            performSegue(withIdentifier: "playSegue", sender: card)
        }
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
        return collectionView.dequeueReusableCell(withReuseIdentifier: "image", for: indexPath)
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
