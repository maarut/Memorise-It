//
//  AppDelegate.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 02/12/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import GoogleMobileAds

public let kMemoriseItDidBecomeActiveNotification = NSNotification.Name("net.maarut.Memorise-It.didBecomeActive")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    var dataController: DataController!

    func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        dataController = DataController(withModelName: "FlashCards")
        let rootVC = window?.rootViewController as? ImageCollectionViewController
        rootVC?.dataController = dataController
        GADMobileAds.configure(withApplicationID: kAdMobAppId)
        pruneDocumentsDirectory()
        return true
    }

    func pruneDocumentsDirectory()
    {
        
        guard let flashCardFileNames = dataController.allFlashCards().fetchedObjects?.map( { $0.audioFileName! } ),
            let directory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first else {
                return
        }
        do {
            let directoryFileNames = try FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: nil).map( { $0.lastPathComponent } )
            let directoryFileNamesSet = Set(directoryFileNames)
            let flashCardFileNamesSet = Set(flashCardFileNames)
            let extraneousFiles = directoryFileNamesSet.subtracting(flashCardFileNamesSet)
                .map { directory.appendingPathComponent($0) }
            for filePath in extraneousFiles { try FileManager.default.removeItem(at: filePath) }
        }
        catch let error as NSError {
            NSLog("\(error)\n\(error.localizedDescription)")
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication)
    {
        NotificationCenter.default.post(name: kMemoriseItDidBecomeActiveNotification, object: self)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

