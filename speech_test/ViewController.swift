//
//  ViewController.swift
//  speech_test
//
//  Created by user on 17.06.2020.
//  Copyright © 2020 user. All rights reserved.
//

import UIKit
import Speech
import AVKit

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var detectedTextLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var micImage: UIImageView!
    @IBOutlet weak var answerView: UIView!
    @IBOutlet weak var answerLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    private var bestString: String?
    private let controller = AVPlayerViewController()
    
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    // let speechRecognizer: SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private let request = SFSpeechAudioBufferRecognitionRequest()
    // If the audio was pre-recorded and stored in memory - SFSpeechURLRecognitionRequest instead
    private var recognitionTask: SFSpeechRecognitionTask?  // to manage, cancel, or stop the current recognition task
    
    struct Level: Decodable {
        var id: Int?
        var name = ""
        var url = ""
    }
    
    struct ResponseData: Decodable {
        var levels: [Level]
    }
    
    private var levels = [Level]()
    private var currentLevel = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        levels = generateLevels()!
        startButton.isUserInteractionEnabled = false
        detectedTextLabel.text = ""
        answerView.isHidden = true
        requestSpeechAuthorization()
        
        TableViewCell.registerCellNib(in: self.tableView)
        
    }
    
    @IBAction func buttonIsPressing(_ sender: UIButton) {
        recordAndRecognizeSpeech()
        answerView.isHidden = true
        micImage.image = UIImage(named: "micro")
    }
    
    @IBAction func cancelRecording(_ sender: UIButton) {
        detectedTextLabel.text = ""
        micImage.image = nil
        stopSpeechRecognition()
    }
    
    @IBAction func play(_ sender: UIButton) {
        guard let path = Bundle.main.path(forResource: levels[currentLevel].url, ofType: "mp4") else {
            return
        }
        let videoURL = NSURL(fileURLWithPath: path)

        let player = AVPlayer(url: videoURL as URL)
        controller.player = player
        present(controller, animated: true) {
            player.play()
        }
        
        controller.removeFromParent()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fileComplete),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    @objc func fileComplete() {
        self.controller.dismiss(animated: true, completion: nil)
        startButton.isUserInteractionEnabled = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func generateLevels() -> [Level]? {
        if let url = Bundle.main.url(forResource: "data", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let jsonData = try decoder.decode(ResponseData.self, from: data)
                return jsonData.levels
            } catch {
                print("error: \(error)")
            }
        }
        return nil
    }
    
    
    private func stopSpeechRecognition() {
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        
        self.request.endAudio()
        self.audioEngine?.stop()
        self.audioEngine?.inputNode.removeTap(onBus: 0)
    }
    
    private func recordAndRecognizeSpeech() {
        audioEngine = AVAudioEngine()
        let node = audioEngine?.inputNode
        let outputBus = 0
        let recordingFormat = node?.outputFormat(forBus: outputBus)
        
        node?.installTap(onBus: outputBus, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer)
        }
        
        do {
            try audioEngine?.start()
        } catch  {
            return print(error)
        }
        
        guard let myRecognizer = speechRecognizer else {
            print("recognizer is not support for current locale")
            return
        }
        
        if !myRecognizer.isAvailable {
            print("recognizer is not available now")
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
            if let result = result {
                self.bestString = result.bestTranscription.formattedString
                self.detectedTextLabel.text = self.bestString
                
                if self.bestString == self.levels[self.currentLevel].name {
                    self.answerView.isHidden = false
                    self.answerView.backgroundColor = UIColor.green
                    self.answerLabel.text = "Correct!"
                    if self.currentLevel <= 1 {
                        self.currentLevel += 1
                    }
                } else {
                    self.answerView.backgroundColor = UIColor.red
                    self.answerLabel.text = "Oops! You're wrong :("
                    self.answerView.isHidden = false
                }
                
            } else if let error = error {
                print(error)
            }
        })
    }


    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.startButton.isEnabled = true
                case .denied:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return levels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = TableViewCell.dequeueReusableCell(in: tableView, for: indexPath)
        if indexPath.row > currentLevel {
            cell.animalButton.backgroundColor = UIColor.lightGray
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row <= currentLevel {
            print("OK")
        } else {
            let alert = UIAlertController(title: "Oops.. Level is not available", message: "Please complete the previous level", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
}

extension UITableViewCell {
    class func registerCellNib(_ nibName: String? = nil,
                              bundle bundleOrNil: Bundle? = nil,
                              forCellReuseIdentifier identifier: String? = nil,
                              in tableView: UITableView) {
       
    let nib = UINib(nibName: nibName ?? String(describing: self), bundle: bundleOrNil)
    tableView.register(nib, forCellReuseIdentifier: identifier ?? String(describing: self))
   }
    
    class func dequeueReusableCell(in tableView: UITableView, for indexPath: IndexPath, reuseIdentifier identifier: String? = nil) -> Self {
        return dequeueReusableCellPrivate(in: tableView, for: indexPath, reuseIdentifier: identifier ?? String(describing: self))
    }
    
    private class func dequeueReusableCellPrivate<T>(in tableView: UITableView, for indexPath: IndexPath, reuseIdentifier: String) -> T {
           let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
           return cell as! T
       }
}
