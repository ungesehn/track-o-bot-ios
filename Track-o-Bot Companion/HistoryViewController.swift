//
//  HistoryViewController.swift
//  Track-o-Bot Companion
//
//  Created by Julian Eberius on 08.09.15.
//  Copyright (c) 2015 Julian Eberius.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//

import UIKit


class HistoryViewController: TrackOBotViewController, UITableViewDataSource, UITableViewDelegate {

    var games = [Game]()

    var total_count: Int = 0
    var retrieved_pages: Int = 0
    var max_requested_idx : Int = 0
    var retrieving = false

    let WIN_COLOR = UIColor(red: 0, green: 1.0, blue: 0, alpha: 0.8)
    let LOSS_COLOR = UIColor(red: 1.0, green: 0, blue: 0, alpha: 0.8)

    @IBOutlet weak var historyTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(animated: Bool) {
        resetView()
    }

    @IBAction func unwindFromLogin(unwindSegue: UIStoryboardSegue) {

    }

    func resetView() {
        self.historyTableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)

        self.games = [Game]()
        self.total_count = 0
        self.retrieved_pages = 0
        self.max_requested_idx = 0
        self.retrieving = false

        retrievePage(1)
    }

    func retrieveNextPage() {
        retrievePage(self.retrieved_pages + 1)
    }

    func retrievePage(page: Int) {
        retrieving = true
        TrackOBot.instance.getResults(page, onComplete: {
            (result) -> Void in
            self.retrieving = false
            switch result {
            case .Success(let historyPage):
                if (historyPage.page == self.retrieved_pages+1) {
                    self.games += historyPage.games
                    self.retrieved_pages = historyPage.page;
                }
                self.total_count = historyPage.totalCount
                self.historyTableView.reloadData()
                self.historyTableView.flashScrollIndicators()
            case .Failure(let err):
                self.alert("Error", message: "Error retrieving game results: \(err)")
            }
        })
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.total_count;
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("matchCell", forIndexPath: indexPath) as! ResultTableViewCell
        if (indexPath.item >= self.games.count) {
            if (indexPath.item > max_requested_idx) {
                if (!retrieving) {
                    max_requested_idx = indexPath.item
                    self.retrieveNextPage()
                }
            }

            // "loading" cell
            cell.heroImageView.image = nil
            cell.opponentsHeroImageView.image = nil
            cell.heroLabel.text = "Loading"
            cell.opponentsHeroLabel.text = "Loading"
            cell.winLabel.text = ""
            cell.timeLabel.text = ""
            return cell
        }
        else
        {
            let match = self.games[indexPath.item]
            cell.heroImageView.image = UIImage(named: "\(match.hero)")
            cell.opponentsHeroImageView.image = UIImage(named: "\(match.opponentsHero)")
            if let deckName = match.deck {
                cell.heroLabel.text = deckName
            } else {
                cell.heroLabel.text = match.hero
            }
            if let deckName = match.opponentsDeck {
                cell.opponentsHeroLabel.text = deckName
            } else {
                cell.opponentsHeroLabel.text = match.opponentsHero
            }
            if (match.won) {
                cell.winLabel.text = "Win"
                cell.winLabel.textColor = WIN_COLOR
            } else {
                cell.winLabel.text = "Loss"
                cell.winLabel.textColor = LOSS_COLOR
            }
            cell.timeLabel.text = match.timeLabel
            return cell
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true;
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch editingStyle {
        case .Delete:
            let game = self.games[indexPath.row]
            guard let gameId = game.id,
                    timeLabel = game.timeLabel else {
                return
            }

            let wonLost = game.won == true ? "won" : "lost"
            let alertController = UIAlertController(title: nil, message: "Do you really want to delete the game you \(wonLost) with \"\(game.deckName)\" against \"\(game.opponentsDeckName)\" at \(timeLabel)?", preferredStyle: .ActionSheet)

            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }
            alertController.addAction(cancelAction)

            let OKAction = UIAlertAction(title: "Delete", style: .Destructive) { (action) in
                TrackOBot.instance.deleteResult(gameId, onComplete: {
                    (result) -> Void in
                    switch result {
                    case .Success:
                        self.games.removeAtIndex(indexPath.row)
                        self.total_count -= 1
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                    case .Failure(let err):
                        self.alert("Error", message: "Deleting game failed: \(err)")
                    }
                })
            }

            if let popoverController = alertController.popoverPresentationController {
                guard let cellView = tableView.cellForRowAtIndexPath(indexPath) else {
                    return
                }
                popoverController.sourceView = cellView
                popoverController.sourceRect = cellView.bounds
            }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) { }
        default:
            break
        }
    }
}
