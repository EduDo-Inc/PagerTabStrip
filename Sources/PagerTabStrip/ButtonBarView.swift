//  ButtonBarView.swift
//  XLPagerTabStrip ( https://github.com/xmartlabs/XLPagerTabStrip )
//
//  Copyright (c) 2017 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import CocoaExtensions
import PagerTabStripCore

public struct CornerStyle {
  public var radius: CGFloat = 12
  public var curve: CALayerCornerCurve = .continuous
  public var mask: CACornerMask = [
    .layerMinXMinYCorner,
    .layerMaxXMinYCorner,
    .layerMinXMaxYCorner,
    .layerMaxXMaxYCorner
  ]
  
  func apply(to layer: CALayer) {
    layer.configure { $0
      .cornerRadius(radius)
      .cornerCurve(curve)
      .maskedCorners(mask)
    }
    
  }
}

public struct ButtonBarSettings {
  public struct Style {
    public struct Alignment {
      public enum Vertical {
        case top
        case middle
        case bottom
      }
      
      public enum Horizontal {
        case left
        case center
        case right
        case progressive
      }
      
      public var vertical: Vertical = .middle
      public var horizontal: Horizontal = .progressive
    }
    
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor = .systemBlue.withAlphaComponent(0.1)
    public var height: CGFloat = 4
    public var corner: CornerStyle = .init()
    public var insets: HorizontalInsets = .init()
    public var horizontalMargin: CGFloat = 8
    public var alignment: Alignment = .init()
  }
  
  public var style = Style()
}

public enum PagerScroll {
  case enabled
  case disabled
  case outOfScreenOnly
}

open class ButtonBarView: CustomCocoaCollectionView {
  public class SelectorView: UIView {}
  open lazy var selectorView: SelectorView = { [unowned self] in
    let bar  = SelectorView(frame: CGRect(x: 0, y: self.frame.size.height - CGFloat(self.settings.style.height), width: 0, height: CGFloat(self.settings.style.height)))
    return bar
  }()
  
  var settings: ButtonBarSettings = .init()
  var selectedIndex = 0
  
  open override func _commonInit() {
    super._commonInit()
    insertSubview(selectorView, at: 0)
  }
  
  open func moveTo(index: Int, animated: Bool, swipeDirection: SwipeDirection, pagerScroll: PagerScroll) {
    selectedIndex = index
    updateselectorViewPosition(animated, swipeDirection: swipeDirection, pagerScroll: pagerScroll)
  }
  
  open func move(fromIndex: Int, toIndex: Int, progressPercentage: CGFloat, pagerScroll: PagerScroll) {
    selectedIndex = progressPercentage > 0.5 ? toIndex : fromIndex
    
    let fromFrame = layoutAttributesForItem(at: IndexPath(item: fromIndex, section: 0))!.frame
    let numberOfItems = dataSource!.collectionView(self, numberOfItemsInSection: 0)
    
    var toFrame: CGRect
    
    if toIndex < 0 || toIndex > numberOfItems - 1 {
      if toIndex < 0 {
        let cellAtts = layoutAttributesForItem(at: IndexPath(item: 0, section: 0))
        toFrame = cellAtts!.frame.offsetBy(dx: -cellAtts!.frame.size.width, dy: 0)
      } else {
        let cellAtts = layoutAttributesForItem(at: IndexPath(item: (numberOfItems - 1), section: 0))
        toFrame = cellAtts!.frame.offsetBy(dx: cellAtts!.frame.size.width, dy: 0)
      }
    } else {
      toFrame = layoutAttributesForItem(at: IndexPath(item: toIndex, section: 0))!.frame
    }
    
    var targetFrame = fromFrame
    targetFrame.size.height = selectorView.frame.size.height
    targetFrame.size.width += (toFrame.size.width - fromFrame.size.width) * progressPercentage
    targetFrame.origin.x += (toFrame.origin.x - fromFrame.origin.x) * progressPercentage
    
    selectorView.frame = CGRect(x: targetFrame.origin.x, y: selectorView.frame.origin.y, width: targetFrame.size.width, height: selectorView.frame.size.height)
    
    var targetContentOffset: CGFloat = 0.0
    if contentSize.width > frame.size.width {
      let toContentOffset = contentOffsetForCell(withFrame: toFrame, andIndex: toIndex)
      let fromContentOffset = contentOffsetForCell(withFrame: fromFrame, andIndex: fromIndex)
      
      targetContentOffset = fromContentOffset + ((toContentOffset - fromContentOffset) * progressPercentage)
    }
    
    setContentOffset(CGPoint(x: targetContentOffset, y: 0), animated: false)
  }
  
  open func updateselectorViewPosition(_ animated: Bool, swipeDirection: SwipeDirection, pagerScroll: PagerScroll) {
    var selectorViewFrame = selectorView.frame
    
    let selectedCellIndexPath = IndexPath(item: selectedIndex, section: 0)
    let attributes = layoutAttributesForItem(at: selectedCellIndexPath)
    let selectedCellFrame = attributes!.frame
    
    updateContentOffset(animated: animated, pagerScroll: pagerScroll, toFrame: selectedCellFrame, toIndex: (selectedCellIndexPath as NSIndexPath).row)
    
    selectorViewFrame.size.width = selectedCellFrame.size.width
    selectorViewFrame.origin.x = selectedCellFrame.origin.x
    
    if animated {
      UIView.animate(withDuration: 0.3, animations: { [weak self] in
        self?.selectorView.frame = selectorViewFrame
      })
    } else {
      selectorView.frame = selectorViewFrame
    }
  }
  
  // MARK: - Helpers
  
  private func updateContentOffset(animated: Bool, pagerScroll: PagerScroll, toFrame: CGRect, toIndex: Int) {
    guard pagerScroll != .disabled || (pagerScroll != .outOfScreenOnly && (toFrame.origin.x < contentOffset.x || toFrame.origin.x >= (contentOffset.x + frame.size.width - contentInset.left))) else { return }
    let targetContentOffset = contentSize.width > frame.size.width ? contentOffsetForCell(withFrame: toFrame, andIndex: toIndex) : 0
    setContentOffset(CGPoint(x: targetContentOffset, y: 0), animated: animated)
  }
  
  private func contentOffsetForCell(withFrame cellFrame: CGRect, andIndex index: Int) -> CGFloat {
    let sectionInset = (collectionViewLayout as! UICollectionViewFlowLayout).sectionInset // swiftlint:disable:this force_cast
    var alignmentOffset: CGFloat = 0.0
    
    switch settings.style.alignment.horizontal {
    case .left:
      alignmentOffset = sectionInset.left
    case .right:
      alignmentOffset = frame.size.width - sectionInset.right - cellFrame.size.width
    case .center:
      alignmentOffset = (frame.size.width - cellFrame.size.width) * 0.5
    case .progressive:
      let cellHalfWidth = cellFrame.size.width * 0.5
      let leftAlignmentOffset = sectionInset.left + cellHalfWidth
      let rightAlignmentOffset = frame.size.width - sectionInset.right - cellHalfWidth
      let numberOfItems = dataSource!.collectionView(self, numberOfItemsInSection: 0)
      let progress = index / (numberOfItems - 1)
      alignmentOffset = leftAlignmentOffset + (rightAlignmentOffset - leftAlignmentOffset) * CGFloat(progress) - cellHalfWidth
    }
    
    var contentOffset = cellFrame.origin.x - alignmentOffset
    contentOffset = max(0, contentOffset)
    contentOffset = min(contentSize.width - frame.size.width, contentOffset)
    return contentOffset
  }
  
  private func updateselectorViewYPosition() {
    var selectorViewFrame = selectorView.frame
    
    switch settings.style.alignment.vertical {
    case .top: 
      selectorViewFrame.origin.y = 0
    case .middle:
      selectorViewFrame.origin.y = (frame.size.height - settings.style.height) / 2
    case .bottom:
      selectorViewFrame.origin.y = frame.size.height - settings.style.height
    }
    
    selectorViewFrame.size.height = settings.style.height
    selectorView.frame = selectorViewFrame
  }
  
  override open func layoutSubviews() {
    super.layoutSubviews()
    updateselectorViewYPosition()
  }
}
