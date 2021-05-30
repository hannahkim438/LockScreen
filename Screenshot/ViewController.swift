//
//  ViewController.swift
//  Screenshot
//
//  Created by Maximiliano Laguna on 2021/03/27.
//

import Cocoa

class ViewController: NSViewController {
    var screenShotView: NSImageView?
    var displayCount: UInt32 = 0;
    var activeDisplays: UnsafeMutablePointer<CGDirectDisplayID>?
    var selDisplayId: CGDirectDisplayID?
    var buttons = [NSButton]()

    override func viewDidLoad() {
        super.viewDidLoad()

        getActiveDisplays()
        createRadioButtons()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
        case [.command, .shift] where event.characters == "f":
            if (screenShotView == nil) {
                showScreenShot()
            } else {
                removeScreenShot()
            }
        default:
            break
        }
    }
    
    func showScreenShot() {
        if selDisplayId != nil {
            let img = CGDisplayCreateImage(selDisplayId!)
            let screenImg = NSImage(cgImage: img!, size: .zero)
            screenShotView = NSImageView(frame:NSRect(x: 0, y: 0, width: screenImg.size.width, height: screenImg.size.height))
            screenShotView?.image = screenImg
            self.view.window?.toggleFullScreen(true)
            self.view.addSubview(screenShotView!)
        }
    }
    
    func removeScreenShot() {
        screenShotView?.removeFromSuperview()
        screenShotView = nil
        self.view.window?.toggleFullScreen(true)
    }
    
    func createRadioButtons() {
        var count = 0
        for i in 1...displayCount {
            let yPos = self.view.frame.size.height - 40 * CGFloat(count) - 60
            let radioButton = NSButton(frame: CGRect(x: 40, y: yPos, width: 200, height: 40))
            let displayId = activeDisplays?[Int(i-1)]
            if let displayName = getDisplayName(displayId!) {
                radioButton.title = displayName
            } else {
                radioButton.title = "Display \(i)"
            }
            radioButton.image = NSImage(named: "radio_off")
            radioButton.alternateImage = NSImage(named: "radio_on")
            radioButton.imagePosition = .imageLeft
            radioButton.target = self
            radioButton.setButtonType(.radio)
            radioButton.action = #selector(self.buttonAction(_:))
            if count == 0 {
                radioButton.state = NSControl.StateValue.on
                selDisplayId = displayId
            }
            self.view.addSubview(radioButton)
            buttons.append(radioButton)
            count += 1
        }
    }
    
    @objc func buttonAction(_ sender: NSButton!){
        for button in buttons {
            button.state = NSControl.StateValue.off
        }
        sender.state = NSControl.StateValue.on
        let buttonIndex = buttons.firstIndex(of: sender)
        let displayId = activeDisplays?[buttonIndex!]
        selDisplayId = displayId
    }
    
    func getActiveDisplays() {
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if (result != CGError.success) {
            print("error: \(result)")
            return
        }
        let allocated = Int(displayCount)
        activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)

        if (result != CGError.success) {
            print("error: \(result)")
            return
        }
    }
    
    func IOServicePortFromCGDisplayID(_ displayID: CGDirectDisplayID) -> io_service_t {
        var object : io_object_t
        var serialPortIterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")
        var servicePort : io_service_t = 0

        let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                    matching,
                                                    &serialPortIterator)
        if KERN_SUCCESS == kernResult && serialPortIterator != 0 {
            repeat {
                var vendorID: UInt32?
                var productID: UInt32?
                var serialNumber: UInt32?
                
                object = IOIteratorNext(serialPortIterator)
                let info = IODisplayCreateInfoDictionary(object, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary as! [String:AnyObject]
                
                vendorID = info["DisplayVendorID"] as? UInt32
                productID = info["DisplayProductID"] as? UInt32
                serialNumber = info["DisplaySerialNumber"] as? UInt32
                
                // If the vendor and product id along with the serial don't match
                // then we are not looking at the correct monitor.
                // NOTE: The serial number is important in cases where two monitors
                //       are the exact same.
                if (CGDisplayVendorNumber(displayID) != vendorID  ||
                    CGDisplayModelNumber(displayID) != productID  ||
                    CGDisplaySerialNumber(displayID) != serialNumber)
                {
                    continue;
                }

                servicePort = object
                break
            } while object != 0
        }
        IOObjectRelease(serialPortIterator)
        return servicePort
    }
    
    func getDisplayName(_ displayID: CGDirectDisplayID) -> String? {
        let info = IODisplayCreateInfoDictionary(IOServicePortFromCGDisplayID(displayID), UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary as! [String:AnyObject]
        if let productName = info["DisplayProductName"] as? [String:String],
           let firstKey = Array(productName.keys).first {
              return productName[firstKey]!
        }
        
        return nil
    }
}

