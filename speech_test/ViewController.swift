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
    @IBOutlet weak var questionView: UIView!
    
    // MARK: -Video and Speech vars
    private var bestString: String?
    private let controller = AVPlayerViewController()
    
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    // let speechRecognizer: SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private let request = SFSpeechAudioBufferRecognitionRequest()
    // If the audio was pre-recorded and stored in memory - SFSpeechURLRecognitionRequest instead
    private var recognitionTask: SFSpeechRecognitionTask?  // to manage, cancel, or stop the current recognition task
    
    // MARK: -Data
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
    
    private var animals = ["Animal ???", "Animal ???", "Animal ???"]
    
    // MARK: -Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDefaultUI()
    
        levels = generateLevels()!
        
        configureAudioSession()
        requestSpeechAuthorization()
        
        TableViewCell.registerCellNib(in: self.tableView)
    }
   
    // MARK: -IBActions
    @IBAction func buttonIsPressing(_ sender: UIButton) {
        recordAndRecognizeSpeech()
        setupUI(true)
    }
    
    @IBAction func cancelRecording(_ sender: UIButton) {
        setupUI(false)
        stopSpeechRecognition()
    }
    
    // MARK: -Generate Levels
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
    
    // MARK: -UI
    private func setupUI(_ speeking: Bool) {
        if speeking {
            answerView.isHidden = speeking
            micImage.image = UIImage(named: "micro")
        } else
        {
            detectedTextLabel.text = ""
            micImage.image = nil
        }
    }
    
    private func setupAnswerUI(_ isCorrect: Bool) {
        answerView.isHidden = false
        if isCorrect {
            self.answerView.backgroundColor = UIColor.green
            self.answerLabel.text = "Correct!"
            questionView.isHidden = false
            
            if currentLevel != levels.count-1 {
                let alert = UIAlertController(title: "Yees! Keep her steady!", message: "Do you want complete one more level?", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Watch video", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
                    self.playVideo(self.currentLevel)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            else {
                let alert = UIAlertController(title: "Wow! Well done!", message: "Category completed!", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            }
        }
        else {
            self.answerView.backgroundColor = UIColor.red
            self.answerLabel.text = "Oops! You're wrong :("
        }
        tableView.reloadData()
    }
    
    private func setupDefaultUI() {
        detectedTextLabel.text = ""
        answerView.isHidden = true
        questionView.isHidden = true
    }
    
    // MARK: -Video player
    private func playVideo(_ selectedLevel: Int) {
        guard let path = Bundle.main.path(forResource: levels[selectedLevel].url, ofType: "mp4") else {
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
        questionView.isHidden = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: -Speech recognition
    private func configureAudioSession() {
        do {
            try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(true)
        } catch { }
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
                    self.animals[self.currentLevel] = self.levels[self.currentLevel].name
                    self.setupAnswerUI(true)
                    if self.currentLevel <= 1 {
                        self.currentLevel += 1
                    }
                }
                else {
                    self.setupAnswerUI(false)
                }
                
            } else if let error = error {
                print(error)
            }
        })
    }

    // MARK: -Recognition request
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

 // MARK: -TableView extension
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return levels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = TableViewCell.dequeueReusableCell(in: tableView, for: indexPath)
        cell.animalButton.backgroundColor = indexPath.row > currentLevel ? UIColor.lightGray : UIColor.green
        cell.animalLabel.text = animals[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row <= currentLevel {
            playVideo(indexPath.row)
        } else {
            let alert = UIAlertController(title: "Oops.. Level is not available", message: "Please complete the previous level", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: -TableViewCell extension
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
