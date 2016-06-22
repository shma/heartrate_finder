//
//  ViewController.swift
//  finder
//
//  Created by Shunya Matsuno on 2016/06/22.
//  Copyright © 2016年 Shunya Matsuno. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation
import SystemConfiguration
import CoreMotion
import CoreLocation

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var rateNum: UILabel!

    var isScanning = false
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripheral1: CBPeripheral!
    
    
    var locationManager: CLLocationManager!
    
    
    // カメラの処理
    var CapSession : AVCaptureSession!
    var CapDevice : AVCaptureDevice!
    var ImageOut : AVCaptureStillImageOutput!
    
    var rate: Int8!
    var beforeRate: Int8!
    
    var rates: [Int8] = []
    var average_rates: [Int] = [0,0,0,0,0,0,0,0,0,0]
    
    let session: NSURLSession = NSURLSession.sharedSession()
    
    // ファイル管理系
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
    let rateFile = "rate.txt"
    let rriFile = "rri.txt"
    let sanjikuFile = "sanjiku.txt"
    let photoFile = "photo.txt"
    
    let formatter = NSDateFormatter()
    let formatterDate = NSDateFormatter()
    
    var currentTime : String!
    var currentDate : String!
    
    
    var latitude : String!
    var longitude : String!
    
    // 加速度
    let manager = CMMotionManager()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
        }
        formatter.dateFormat = "HH:mm:ss"
        formatterDate.dateFormat = "yyyy_MM_dd"
        
        if manager.accelerometerAvailable {
            // センサーの更新間隔の指定
            manager.accelerometerUpdateInterval = 5;
            
            // ハンドラを指定
            let accelerometerHandler:CMAccelerometerHandler = {
                [weak self] (data: CMAccelerometerData?, error: NSError?) -> Void in
                
                //                print("".stringByAppendingFormat("x %.4f", data!.acceleration.x))
                //                self?.yLabel.text = "".stringByAppendingFormat("y %.4f", data!.acceleration.y)
                //                self?.zLabel.text = "".stringByAppendingFormat("z %.4f", data!.acceleration.z)
                
                let now = NSDate()
                let date = self!.formatterDate.stringFromDate(now)
                let time = self!.formatter.stringFromDate(now)
                
                let sanjikuOutput = NSOutputStream(toFileAtPath: self!.documentsPath + "/" + date + "_" + self!.sanjikuFile, append: true)
                sanjikuOutput?.open()
                let text = time + ", \(data!.acceleration.x), \(data!.acceleration.y) , \(data!.acceleration.z)\r\n"
                
                let cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
                let bytes = UnsafePointer<UInt8>(cstring!)
                let size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
                sanjikuOutput?.write(bytes, maxLength: size)
                sanjikuOutput?.close()
                
                print("x: \(data!.acceleration.x) y: \(data!.acceleration.y) z: \(data!.acceleration.z)")
            }
            
            // 加速度の取得開始
            manager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!,
                                                     withHandler: accelerometerHandler)
        }
        
        rate = 0
        beforeRate = 0
        
        // セントラルマネージャ初期化
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        CapSession = AVCaptureSession()
        let devices = AVCaptureDevice.devices()
        for device in devices {
            if (device.position == AVCaptureDevicePosition.Back) {
                CapDevice = device as! AVCaptureDevice
            }
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: CapDevice)
            CapSession.addInput(videoInput)
        } catch {
            
        }
        
        // 出力先を生成
        ImageOut = AVCaptureStillImageOutput()
        
        // セッションに追加
        CapSession.addOutput(ImageOut)
        
        // 画像を表示するレイヤーを制し絵
        let videoLayer : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: CapSession!) as AVCaptureVideoPreviewLayer
        
        videoLayer.frame = self.view.bounds
        videoLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        // Viewに追加
        //self.view.layer.addSublayer(videoLayer)
        
        CapSession.startRunning()
        
        /**
         print(string)
         
         let hogeDic: Dictionary = ["rate" : "100", "date": string]
         let hogeDic1: Dictionary = ["rate" : "120", "date": string]
         
         var partyA = Array<AnyObject>()
         partyA.append(hogeDic)
         partyA.append(hogeDic1)
         // print(partyA);
         
         
         NSUserDefaults.standardUserDefaults().setObject(partyA, forKey: "hogeDic")
         NSUserDefaults.standardUserDefaults().synchronize()
         
         let arr: AnyObject! = NSUserDefaults.standardUserDefaults().arrayForKey("hogeDic")
         
         print(arr);
         **/
        // 通信状況を見るやーつ
        // print(CheckReachability("shma.jp"))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // =========================================================================
    // MARK: CBCentralManagerDelegate
    
    // セントラルマネージャの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        print("state: \(central.state)")
    }
    
    // ペリフェラルを発見すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didDiscoverPeripheral peripheral: CBPeripheral,
                                              advertisementData: [String : AnyObject],
                                              RSSI: NSNumber)
    {
        print("発見したBLEデバイス: \(peripheral)")
        
        if peripheral.name == "Polar H7 B6B3C416" {
            self.peripheral = peripheral
            
            // 接続開始
            self.centralManager.connectPeripheral(self.peripheral, options: nil)
        }
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didConnectPeripheral peripheral: CBPeripheral)
    {
        print("接続成功！")
        
        // サービス探索結果を受け取るためにデリゲートをセット
        peripheral.delegate = self
        
        // サービス探索開始
        peripheral.discoverServices(nil)
        
        
        self.centralManager.stopScan()
    }
    
    // ペリフェラルへの接続が失敗すると呼ばれる
    func centralManager(central: CBCentralManager,
                        didFailToConnectPeripheral peripheral: CBPeripheral,
                                                   error: NSError?)
    {
        print("接続失敗・・・")
    }
    
    // =========================================================================
    // MARK:CBPeripheralDelegate
    // サービス発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if (error != nil) {
            print("エラー: \(error)")
            return
        }
        
        if !(peripheral.services?.count > 0) {
            print("no services")
            return
        }
        
        let services = peripheral.services!
        
        print("\(services.count) 個のサービスを発見！ \(services)")
        
        for service in services {
            print(service.UUID);
            // キャラクタリスティック探索開始
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    // キャラクタリスティック発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didDiscoverCharacteristicsForService service: CBService,
                                                         error: NSError?)
    {
        if (error != nil) {
            print("エラー: \(error)")
            return
        }
        
        if !(service.characteristics?.count > 0) {
            print("no characteristics")
            return
        }
        
        let characteristics = service.characteristics!
        
        for characteristic in characteristics {
            
            // konashi の PIO_INPUT_NOTIFICATION キャラクタリスティック
            if characteristic.UUID.isEqual(CBUUID(string: "3003")) {
                
            }
            
            peripheral.readValueForCharacteristic(characteristic)
            
            if characteristic.UUID.isEqual(CBUUID(string: "2A37")) {
                // 更新通知受け取りを開始する
                peripheral.setNotifyValue(
                    true,
                    forCharacteristic: characteristic)
            }
        }
    }
    
    // Notify開始／停止時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic,
                                                                error: NSError?)
    {
        if error != nil {
            print("Notify状態更新失敗...error: \(error)")
        }
        else {
            print("Notify状態更新成功！characteristic UUID:\(characteristic.UUID), isNotifying: \(characteristic.isNotifying)")
            
            //var byte: CUnsignedChar = 0
            // 1バイト取り出す
            var aBuffer = Array<Int8>(count: 16, repeatedValue: 0)
            // aBufferにバイナリデータを格納。
            characteristic.value?.getBytes(&aBuffer, length: 16)
            for aChar in aBuffer {
                print("\(aChar)") // 各文字のutf-8の文字コードが出力される。
            }
        }
    }
    
    // データ更新時に呼ばれる
    func peripheral(peripheral: CBPeripheral,
                    didUpdateValueForCharacteristic characteristic: CBCharacteristic,
                                                    error: NSError?)
    {
        if error != nil {
            print("データ更新通知エラー: \(error)")
            return
        }
        
        if (characteristic.UUID.isEqual(CBUUID(string: "2A37"))) {
            
            //print("データ更新！ characteristic UUID: \(characteristic.UUID), value: \(characteristic.value)")
            var aBuffer = Array<Int8>(count: 8, repeatedValue: 0)
            
            // aBufferにバイナリデータを格納。
            characteristic.value?.getBytes(&aBuffer, length: 8)
            
            rate = abs(aBuffer[1])
            
            if (rates.count == 3) {
                rates.removeFirst()
            }
            
            rates.append(rate)
            
            var rateSum : Int = 0
            
            for cas_rate in rates {
                rateSum += numericCast(cas_rate)
            }
            
            if (rates.count > 0) {
                let average : Int = rateSum / rates.count;
                
                if (average_rates.count == 10) {
                    average_rates.removeFirst()
                }
                
                average_rates.append(average)
            }
            
            print(average_rates)
            rateNum.text = String(rate)
            
            
            if (abs(average_rates[9] - average_rates[0]) > 10) {
                if (average_rates[0] > 0) {
                    takeStillPicture();
                    average_rates = [0,0,0,0,0,0,0,0,0,0]
                }
            }
            
            // ログ出力用の処理へ
            let now = NSDate()
            currentDate = formatterDate.stringFromDate(now)
            currentTime = formatter.stringFromDate(now)
            
            
            let rateOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + currentDate + "_" + rateFile, append: true)
            rateOutput?.open()
            let text = currentTime + " , " + String(rate) + "\r\n"
            
            var cstring = text.cStringUsingEncoding(NSUTF8StringEncoding)
            var bytes = UnsafePointer<UInt8>(cstring!)
            var size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            rateOutput?.write(bytes, maxLength: size)
            rateOutput?.close()
            
            let rri1 : Int = abs(numericCast(aBuffer[2]))
            let rri2 : Int = abs(numericCast(aBuffer[3]))
            let rriBinary : String = (toBinary(rri2) + toBinary(rri1))
            
            let rriSec = Int(rriBinary, radix: 2) ?? 0
            
            if (rriSec > 0) {
                var rri : Float;
                rri = Float(rriSec) / 1024
                
                let rriOutput = NSOutputStream(toFileAtPath: documentsPath + "/" + currentDate + "_" + rriFile, append: true)
                rriOutput?.open()
                let rriText = currentTime + " , " + String(rri) + " \r\n"
                
                cstring = rriText.cStringUsingEncoding(NSUTF8StringEncoding)
                bytes = UnsafePointer<UInt8>(cstring!)
                size = text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
                rriOutput?.write(bytes, maxLength: size)
                rriOutput?.close()
            }
        }
        
        /**
         for aChar in aBuffer {
         //print("\(aChar)") // 各文字のutf-8の文字コードが出力される。
         }
         **/
    }
    
    // =========================================================================
    // MARK: Actions
    
    @IBAction func scanBtnTapped(sender: UIButton) {
        
        if !isScanning {
            
            isScanning = true
            
            self.centralManager.scanForPeripheralsWithServices(nil, options: nil)
            
            sender.setTitle("STOP SCAN", forState: UIControlState.Normal)
        }
        else {
            self.centralManager.stopScan()
            sender.setTitle("START SCAN", forState: UIControlState.Normal)
            isScanning = false
        }
    }
    
    func takeStillPicture(){
        
        // ビデオ出力に接続.
        if let connection:AVCaptureConnection? = ImageOut.connectionWithMediaType(AVMediaTypeVideo){
            // ビデオ出力から画像を非同期で取得
            ImageOut.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (imageDataBuffer, error) -> Void in
                
                // 取得画像のDataBufferをJpegに変換
                let imageData:NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataBuffer)
                
                // JpegからUIImageを作成.
                let image:UIImage = UIImage(data: imageData)!
                
                let newImage:UIImage = self.drawText(image)
                
                
                
                // アルバムに追加.
                UIImageWriteToSavedPhotosAlbum(newImage, self, nil, nil)
                
            })
        }
    }
    
    func drawText(image :UIImage) ->UIImage
    {
        let text = "♥" + String(rate)
        
        let font = UIFont.boldSystemFontOfSize(82)
        
        let imageRect = CGRectMake(0,0,image.size.width,image.size.height)
        
        UIGraphicsBeginImageContext(image.size);
        
        image.drawInRect(imageRect)
        
        let textRect  = CGRectMake(5, 5, image.size.width - 5, image.size.height - 5)
        let textStyle = NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        let textFontAttributes = [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.redColor(),
            NSParagraphStyleAttributeName: textStyle
        ]
        text.drawInRect(textRect, withAttributes: textFontAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func toBinary(value: Int) -> String {
        let str = String(value, radix:2)
        let size = 8
        let padd = String(count: (size - str.characters.count),
                          repeatedValue: Character("0"))
        return padd + str
    }
    
    func CheckReachability(host_name:String)->Bool{
        
        let reachability = SCNetworkReachabilityCreateWithName(nil, host_name)!
        var flags = SCNetworkReachabilityFlags.ConnectionAutomatic
        if !SCNetworkReachabilityGetFlags(reachability, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
    
    func post(url: NSURL, body: NSMutableDictionary, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) {
        let request: NSMutableURLRequest = NSMutableURLRequest(URL: url)
        
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(body, options: NSJSONWritingOptions.init(rawValue: 2))
        } catch {
            // Error Handling
            print("NSJSONSerialization Error")
            return
        }
        session.dataTaskWithRequest(request, completionHandler: completionHandler).resume()
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .Restricted, .Denied:
            break
        case .Authorized, .AuthorizedWhenInUse:
            break
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        latitude = "".stringByAppendingFormat("%.4f", newLocation.coordinate.latitude)
        longitude = "".stringByAppendingFormat("%.4f", newLocation.coordinate.longitude)
        
        print("".stringByAppendingFormat("%.4f", newLocation.coordinate.latitude))
        print("".stringByAppendingFormat("%.4f", newLocation.coordinate.longitude))
    }
    
}

