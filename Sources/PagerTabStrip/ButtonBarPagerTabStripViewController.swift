//  ButtonBarPagerTabStripViewController.swift
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

import Foundation
import UIKit
import PagerTabStripCore
import CocoaExtensions

public struct ButtonBarItemSpec {
  public init(
    width: @escaping ((IndicatorInfo) -> CGFloat)
  ) {
    self.width = width
  }
  
  public var width: ((IndicatorInfo) -> CGFloat)
}

  public struct HorizontalInsets {
    public var leading: CGFloat?
    public var trailing: CGFloat?
  }

public struct ButtonBarOffsets {
  public var top: CGFloat?
  public var bottom: CGFloat?
  public var leading: CGFloat?
  public var trailing: CGFloat?
}

public struct ButtonBarPagerTabStripSettings {
  public struct BarStyle {
    
    public var height: CGFloat = 44
    public var corner: CornerStyle = .init()
    public var backgroundColor: UIColor = .clear
    public var minimalInterItemSpacing: CGFloat?
    public var minimalLineSpacing: CGFloat?
    public var itemsShouldFillAvailableWidth = true
    public var offset: ButtonBarOffsets = .init()
    public var itemBackgroundColor: UIColor = .clear
    public var selectedItem: ButtonBarSettings.Style = .init()
    
  }
  
  public var style: BarStyle = .init()
}

open class ButtonBarPagerTabStripViewController:
  PagerTabStripViewController,
  PagerTabStripDataSource,
  PagerTabStripIsProgressiveDelegate,
  UICollectionViewDelegate,
  UICollectionViewDataSource
{
  open var settings = ButtonBarPagerTabStripSettings()
  
  public var buttonBarItemSpec: ButtonBarItemSpec!
  
  public var changeCurrentIndex: (
    (
      _ oldCell: ButtonBarViewCell?,
      _ newCell: ButtonBarViewCell?,
      _ animated: Bool
    ) -> Void
  )?
  
  public var changeCurrentIndexProgressive: (
    (
      _ oldCell: ButtonBarViewCell?,
      _ newCell: ButtonBarViewCell?,
      _ progressPercentage: CGFloat,
      _ changeCurrentIndex: Bool,
      _ animated: Bool
    ) -> Void
  )?
  
  public var buttonBarView: ButtonBarView!
  
  lazy private var cachedCellWidths: [CGFloat]? = { [unowned self] in
    return self.calculateWidths()
  }()
  
  override public init(
    nibName nibNameOrNil: String?,
    bundle nibBundleOrNil: Bundle?
  ) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.delegate = self
    self.dataSource = self
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.delegate = self
    self.dataSource = self
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    
    self.buttonBarItemSpec = .init { [weak self] (childItemInfo) -> CGFloat in
      let label = UILabel()
      label.translatesAutoresizingMaskIntoConstraints = false
      label.attributedText = childItemInfo.attributedTitle
      let labelSize = label.intrinsicContentSize
      return labelSize.width + (
        self?.settings.style.selectedItem.horizontalMargin ?? 8
      ) * 2
    }
    
    self.buttonBarView = {
      let flowLayout = UICollectionViewFlowLayout()
      flowLayout.scrollDirection = .horizontal
      let buttonBarHeight = settings.style.height
      let buttonBar = ButtonBarView(
        frame: CGRect(
          x: settings.style.offset.leading.or(0),
          y: settings.style.offset.top.or(0),
          width: view.frame.size.width - (
            settings.style.offset.leading.or(0) + settings.style.offset.trailing.or(0)
          ),
          height: buttonBarHeight
        ),
        collectionViewLayout: flowLayout
      )
      buttonBar.autoresizingMask = .flexibleWidth
      var newContainerViewFrame = containerView.frame
      newContainerViewFrame.origin.y = settings.style.height +
        settings.style.offset.top.or(0) +
        settings.style.offset.bottom.or(0)
      newContainerViewFrame.size.height = containerView.frame.size.height - (
        buttonBarHeight - containerView.frame.origin.y
      )
      containerView.frame = newContainerViewFrame
      return buttonBar
    }()
    
    if buttonBarView.superview == nil {
      view.addSubview(buttonBarView)
    }
    if buttonBarView.delegate == nil {
      buttonBarView.delegate = self
    }
    if buttonBarView.dataSource == nil {
      buttonBarView.dataSource = self
    }
    buttonBarView.scrollsToTop = false
    
    let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
    flowLayout.scrollDirection = .horizontal
    
    settings.style.minimalInterItemSpacing
      .assign(to: \.minimumInteritemSpacing, on: flowLayout)
    settings.style.minimalLineSpacing
      .assign(to: \.minimumLineSpacing, on: flowLayout)
    
    settings.style.selectedItem.insets.leading
      .assign(to: \.sectionInset.left, on: flowLayout)
    settings.style.selectedItem.insets.trailing
      .assign(to: \.sectionInset.right, on: flowLayout)
    
    buttonBarView.showsHorizontalScrollIndicator = false
    buttonBarView.backgroundColor = settings.style.backgroundColor
    buttonBarView.selectorView.backgroundColor = settings.style.selectedItem.backgroundColor
    
    settings.style.corner.apply(to: buttonBarView.layer)
    settings.style.selectedItem.corner.apply(to: buttonBarView.selectorView.layer)
    
    
    buttonBarView.settings.style = settings.style.selectedItem
    
    // register button bar item cell
    
    buttonBarView.register(ButtonBarViewCell.self)
    //-
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    buttonBarView.layoutIfNeeded()
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    guard isViewAppearing || isViewRotating else { return }
    
    // Force the UICollectionViewFlowLayout to get laid out again with the new size if
    // a) The view is appearing.  This ensures that
    //    collectionView:layout:sizeForItemAtIndexPath: is called for a second time
    //    when the view is shown and when the view *frame(s)* are actually set
    //    (we need the view frame's to have been set to work out the size's and on the
    //    first call to collectionView:layout:sizeForItemAtIndexPath: the view frame(s)
    //    aren't set correctly)
    // b) The view is rotating.  This ensures that
    //    collectionView:layout:sizeForItemAtIndexPath: is called again and can use the views
    //    *new* frame so that the buttonBarView cell's actually get resized correctly
    cachedCellWidths = calculateWidths()
    buttonBarView.collectionViewLayout.invalidateLayout()
    // When the view first appears or is rotated we also need to ensure that the barButtonView's
    // selectedBar is resized and its contentOffset/scroll is set correctly (the selected
    // tab/cell may end up either skewed or off screen after a rotation otherwise)
    buttonBarView.moveTo(index: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .outOfScreenOnly)
    buttonBarView.selectItem(at: IndexPath(item: currentIndex, section: 0), animated: false, scrollPosition: [])
  }
  
  // MARK: - Public Methods
  
  open override func reloadPagerTabStripView() {
    super.reloadPagerTabStripView()
    guard isViewLoaded else { return }
    buttonBarView.reloadData()
    cachedCellWidths = calculateWidths()
    buttonBarView.moveTo(index: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .enabled)
  }
  
  open func calculateStretchedCellWidths(_ minimumCellWidths: [CGFloat], suggestedStretchedCellWidth: CGFloat, previousNumberOfLargeCells: Int) -> CGFloat {
    var numberOfLargeCells = 0
    var totalWidthOfLargeCells: CGFloat = 0
    
    for
      minimumCellWidthValue in minimumCellWidths
    where minimumCellWidthValue > suggestedStretchedCellWidth {
      totalWidthOfLargeCells += minimumCellWidthValue
      numberOfLargeCells += 1
    }
    
    guard numberOfLargeCells > previousNumberOfLargeCells
    else { return suggestedStretchedCellWidth }
    
    let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
    let collectionViewAvailiableWidth = buttonBarView.frame.size.width -
      flowLayout.sectionInset.left -
      flowLayout.sectionInset.right
    let numberOfCells = minimumCellWidths.count
    let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
    
    let numberOfSmallCells = numberOfCells - numberOfLargeCells
    let newSuggestedStretchedCellWidth = (
      collectionViewAvailiableWidth -
        totalWidthOfLargeCells -
        cellSpacingTotal
    ) / CGFloat(numberOfSmallCells)
    
    return calculateStretchedCellWidths(
      minimumCellWidths,
      suggestedStretchedCellWidth: newSuggestedStretchedCellWidth,
      previousNumberOfLargeCells: numberOfLargeCells
    )
  }
  
  open func updateIndicator(for viewController: PagerTabStripViewController, fromIndex: Int, toIndex: Int) {
    guard shouldUpdateButtonBarView else { return }
    buttonBarView.moveTo(
      index: toIndex,
      animated: false,
      swipeDirection: toIndex < fromIndex ? .right : .left,
      pagerScroll: .enabled
    )
    
    if let changeCurrentIndex = changeCurrentIndex {
      let oldIndexPath = IndexPath(
        item: currentIndex != fromIndex ? fromIndex : toIndex,
        section: 0
      )
      let newIndexPath = IndexPath(item: currentIndex, section: 0)
      
      let cells = cellsForItems(
        at: [oldIndexPath, newIndexPath],
        reloadIfNotVisible: collectionViewDidLoad
      )
      
      changeCurrentIndex(cells.first!, cells.last!, true)
    }
  }
  
  open func updateIndicator(
    for viewController: PagerTabStripViewController,
    fromIndex: Int,
    toIndex: Int,
    withProgressPercentage progressPercentage: CGFloat,
    indexWasChanged: Bool
  ) {
    guard shouldUpdateButtonBarView else { return }
    buttonBarView.move(
      fromIndex: fromIndex,
      toIndex: toIndex,
      progressPercentage: progressPercentage,
      pagerScroll: .enabled
    )
    if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
      let oldIndexPath = IndexPath(
        item: currentIndex != fromIndex ? fromIndex : toIndex,
        section: 0
      )
      let newIndexPath = IndexPath(item: currentIndex, section: 0)
      
      let cells = cellsForItems(
        at: [oldIndexPath, newIndexPath],
        reloadIfNotVisible: collectionViewDidLoad
      )
      
      changeCurrentIndexProgressive(
        cells.first!,
        cells.last!,
        progressPercentage,
        indexWasChanged, true
      )
    }
  }
  
  private func cellsForItems(
    at indexPaths: [IndexPath],
    reloadIfNotVisible reload: Bool = true
  ) -> [ButtonBarViewCell?] {
    let cells = indexPaths.map { buttonBarView.cellForItem(at: $0) as? ButtonBarViewCell }
    
    if reload {
      let indexPathsToReload = cells.enumerated()
        .compactMap { (arg) -> IndexPath? in
          let (index, cell) = arg
          return cell == nil ? indexPaths[index] : nil
        }
        .compactMap { (indexPath: IndexPath) -> IndexPath? in
          return (
            indexPath.item >= 0 &&
              indexPath.item < buttonBarView.numberOfItems(inSection: indexPath.section)
          )
            ? indexPath
            : nil
        }
      
      if !indexPathsToReload.isEmpty {
        buttonBarView.reloadItems(at: indexPathsToReload)
      }
    }
    
    return cells
  }
  
  // MARK: - UICollectionViewDelegateFlowLayut
  
  @objc open func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: IndexPath
  ) -> CGSize {
    guard let cellWidthValue = cachedCellWidths?[indexPath.row] else {
      fatalError("cachedCellWidths for \(indexPath.row) must not be nil")
    }
    return CGSize(width: cellWidthValue, height: collectionView.frame.size.height)
  }
  
  open func collectionView(
    _ collectionView: UICollectionView,
    didSelectItemAt indexPath: IndexPath
  ) {
    guard indexPath.item != currentIndex else { return }
    
    buttonBarView.moveTo(
      index: indexPath.item,
      animated: true,
      swipeDirection: .none,
      pagerScroll: .enabled
    )
    
    shouldUpdateButtonBarView = false
    
    let oldIndexPath = IndexPath(item: currentIndex, section: 0)
    let newIndexPath = IndexPath(item: indexPath.item, section: 0)
    
    let cells = cellsForItems(
      at: [oldIndexPath, newIndexPath],
      reloadIfNotVisible: collectionViewDidLoad
    )
    
    if pagerBehaviour.isProgressiveIndicator {
      if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
        changeCurrentIndexProgressive(cells.first!, cells.last!, 1, true, true)
      }
    } else {
      if let changeCurrentIndex = changeCurrentIndex {
        changeCurrentIndex(cells.first!, cells.last!, true)
      }
    }
    
    moveToViewController(at: indexPath.item)
  }
  
  // MARK: - UICollectionViewDataSource
  
  open func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int { viewControllers.count }
  
  open func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(ButtonBarViewCell.self, at: indexPath)
      .or(ButtonBarViewCell())
    
    collectionViewDidLoad = true
    
    cell.controller = viewControllers[indexPath.item]
    let childController = viewControllers[indexPath.item] as! IndicatorInfoProvider
    let info = childController.indicatorInfo(isCurrent: indexPath.item == currentIndex)
    configureCell(
      cell,
      indicatorInfo: info
    )
    
    if pagerBehaviour.isProgressiveIndicator {
      if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
        changeCurrentIndexProgressive(
          currentIndex == indexPath.item ? nil : cell,
          currentIndex == indexPath.item ? cell : nil,
          1,
          true,
          false
        )
      }
    } else {
      if let changeCurrentIndex = changeCurrentIndex {
        changeCurrentIndex(
          currentIndex == indexPath.item ? nil : cell,
          currentIndex == indexPath.item ? cell : nil,
          false
        )
      }
    }
    cell.isAccessibilityElement = true
    cell.accessibilityLabel = info.accessibilityLabel ?? cell.label.text
    cell.accessibilityTraits.insert([.button, .header])
    buttonBarView.sendSubviewToBack(buttonBarView.selectorView)
    return cell
  }
  
  // MARK: - UIScrollViewDelegate
  
  open override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    super.scrollViewDidEndScrollingAnimation(scrollView)
    
    guard scrollView == containerView else { return }
    shouldUpdateButtonBarView = true
  }
  
  open func configureCell(_ cell: ButtonBarViewCell, indicatorInfo: IndicatorInfo) {
    cell.label.attributedText = indicatorInfo.attributedTitle
    cell.contentView.backgroundColor = settings.style.itemBackgroundColor
    cell.backgroundColor = settings.style.itemBackgroundColor
    if let image = indicatorInfo.image {
      cell.imageView.image = image
    }
    if let highlightedImage = indicatorInfo.highlightedImage {
      cell.imageView.highlightedImage = highlightedImage
    }
    
  }
  
  private func calculateWidths() -> [CGFloat] {
    let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
    let numberOfCells = viewControllers.count
    
    var minimumCellWidths = [CGFloat]()
    var collectionViewContentWidth: CGFloat = 0
    
    for (index, viewController) in viewControllers.enumerated() {
      let childController = viewController as! IndicatorInfoProvider
      let width = buttonBarItemSpec.width(childController.indicatorInfo(isCurrent: index == currentIndex))
      minimumCellWidths.append(width)
      collectionViewContentWidth += width
    }
    
    let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
    collectionViewContentWidth += cellSpacingTotal
    
    let collectionViewAvailableVisibleWidth = buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
    
    let isMinimalCellWidths = !settings.style.itemsShouldFillAvailableWidth ||
      collectionViewAvailableVisibleWidth < collectionViewContentWidth
    if isMinimalCellWidths {
      return minimumCellWidths
      
    } else {
      let stretchedCellWidthIfAllEqual = (
        collectionViewAvailableVisibleWidth - cellSpacingTotal
      ) / CGFloat(numberOfCells)
      
      let generalMinimumCellWidth = calculateStretchedCellWidths(
        minimumCellWidths,
        suggestedStretchedCellWidth: stretchedCellWidthIfAllEqual,
        previousNumberOfLargeCells: 0
      )
      
      var stretchedCellWidths = [CGFloat]()
      
      for minimumCellWidthValue in minimumCellWidths {
        let cellWidth = (minimumCellWidthValue > generalMinimumCellWidth)
          ? minimumCellWidthValue
          : generalMinimumCellWidth
        stretchedCellWidths.append(cellWidth)
      }
      
      return stretchedCellWidths
    }
  }
  
  private var shouldUpdateButtonBarView = true
  private var collectionViewDidLoad = false
  
}
