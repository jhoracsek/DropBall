//
//  mod.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-07.
//

import Foundation
import SpriteKit

func mod(_ a: CGFloat, _ n: CGFloat) -> CGFloat {
    let r = remainder(a, n)
    return r >= 0 ? r : r + n
}
