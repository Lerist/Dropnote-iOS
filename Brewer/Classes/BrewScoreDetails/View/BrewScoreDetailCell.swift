//
//  BrewScoreDetailCell.swift
//  Brewer
//
//  Created by Maciej Oczko on 01.05.2016.
//  Copyright © 2016 Maciej Oczko. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

final class BrewScoreDetailCell: UITableViewCell {
    private let disposeBag = DisposeBag()
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
}

extension BrewScoreDetailCell: PresentableConfigurable {
    
    func configureWithPresentable(presentable: ScoreCellPresentable) {
        accessibilityHint = "Slider for \(presentable.title) value, current is \(presentable.value)"
        titleLabel.text = presentable.title
        valueLabel.text = presentable.value
        slider.value = presentable.sliderValue.value
        slider.rx_value.bindTo(presentable.sliderValue).addDisposableTo(disposeBag)
        slider.rx_value.map { $0.format(".1") }.bindTo(valueLabel.rx_text).addDisposableTo(disposeBag)
    }
}

extension BrewScoreDetailCell {
    
    func configureWithTheme(theme: ThemeConfiguration?) {
        backgroundColor = theme?.lightColor
        slider.configureWithTheme(theme)
        [titleLabel, valueLabel].forEach {
            $0.configureWithTheme(theme)
        }
    }
}
